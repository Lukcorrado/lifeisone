-- ═══════════════════════════════════════════════════════════════════════════
-- LIFE IS ONE · MURO — Supabase schema
--
--   supabase db push          (or paste this whole file into the SQL editor)
--
-- Design notes that matter:
--  · A wall is ONE ROW. items/regions/identity are jsonb — the exact shape
--    muro.config.js already uses. No joins, no ORM, no migration pain when you
--    invent a new card type at 2am.
--  · RLS is on everywhere. The anon key in your HTML is safe: it can read
--    published walls and nothing else.
--  · Invite-gated by default. Ten good MUROs is a collective; a thousand is a
--    graveyard. Flip `muro.open_signups` to true when you're ready.
-- ═══════════════════════════════════════════════════════════════════════════

create extension if not exists citext;
create extension if not exists pgcrypto;

-- ── settings ───────────────────────────────────────────────────────────────
create table if not exists public.muro_settings (
  key   text primary key,
  value jsonb not null
);
insert into public.muro_settings (key, value) values ('open_signups', 'false'::jsonb)
  on conflict (key) do nothing;
alter table public.muro_settings enable row level security;
create policy "settings readable" on public.muro_settings for select using (true);

-- ── reserved handles ───────────────────────────────────────────────────────
create table if not exists public.reserved_handles (handle citext primary key);
insert into public.reserved_handles (handle) values
  ('api'),('app'),('www'),('admin'),('login'),('logout'),('signin'),('signup'),
  ('auth'),('about'),('brand'),('manifesto'),('collective'),('muro'),('muros'),
  ('new'),('claim'),('settings'),('account'),('help'),('support'),('privacy'),
  ('terms'),('legal'),('blog'),('podcast'),('press'),('assets'),('static'),
  ('public'),('_next'),('favicon'),('robots'),('sitemap'),('lifeisone'),('one')
  on conflict do nothing;
alter table public.reserved_handles enable row level security;
create policy "reserved readable" on public.reserved_handles for select using (true);

-- ── walls ──────────────────────────────────────────────────────────────────
create table if not exists public.walls (
  id          uuid primary key default gen_random_uuid(),
  handle      citext unique not null,
  owner       uuid not null references auth.users(id) on delete cascade,

  identity    jsonb not null default '{}'::jsonb,   -- { name, tag, seoTitle, seoDesc }
  regions     jsonb not null default '[]'::jsonb,   -- the six wavelengths + ONE
  items       jsonb not null default '[]'::jsonb,   -- every card

  published   boolean not null default false,
  views       bigint  not null default 0,

  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),

  constraint handle_shape check (handle ~ '^[a-z0-9](?:[a-z0-9_-]{1,30}[a-z0-9])$'),
  constraint items_is_array   check (jsonb_typeof(items)   = 'array'),
  constraint regions_is_array check (jsonb_typeof(regions) = 'array'),
  -- a wall is a room, not a warehouse. keeps one bad paste from nuking the row.
  constraint items_sane check (jsonb_array_length(items) <= 400)
);
create index if not exists walls_owner_idx on public.walls (owner);
create index if not exists walls_published_idx on public.walls (published, updated_at desc);

create or replace function public.touch_updated_at() returns trigger
language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

drop trigger if exists walls_touch on public.walls;
create trigger walls_touch before update on public.walls
  for each row execute function public.touch_updated_at();

-- reserved handles can't be claimed
create or replace function public.block_reserved_handle() returns trigger
language plpgsql as $$
begin
  if exists (select 1 from public.reserved_handles r where r.handle = new.handle) then
    raise exception 'handle % is reserved', new.handle using errcode = '23514';
  end if;
  return new;
end $$;
drop trigger if exists walls_reserved on public.walls;
create trigger walls_reserved before insert or update of handle on public.walls
  for each row execute function public.block_reserved_handle();

-- ── invites ────────────────────────────────────────────────────────────────
create table if not exists public.invites (
  code        text primary key default encode(gen_random_bytes(6), 'hex'),
  note        text,                                   -- "met at Radion, makes ceramics"
  created_by  uuid references auth.users(id) on delete set null,
  claimed_by  uuid references auth.users(id) on delete set null,
  claimed_at  timestamptz,
  expires_at  timestamptz,
  created_at  timestamptz not null default now()
);
create index if not exists invites_claimed_idx on public.invites (claimed_by);

-- ── row level security ─────────────────────────────────────────────────────
alter table public.walls   enable row level security;
alter table public.invites enable row level security;

-- read: anyone sees published walls; you always see your own
create policy "read published or own" on public.walls for select
  using (published = true or owner = auth.uid());

-- may this user create a wall at all?
create or replace function public.can_create_wall(uid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select (value)::text::boolean from public.muro_settings where key='open_signups'), false)
      or exists (select 1 from public.invites i where i.claimed_by = uid);
$$;

create policy "insert own wall with invite" on public.walls for insert
  with check (owner = auth.uid() and public.can_create_wall(auth.uid()));

create policy "update own wall" on public.walls for update
  using (owner = auth.uid()) with check (owner = auth.uid());

create policy "delete own wall" on public.walls for delete
  using (owner = auth.uid());

-- invites: you can see the ones you made and the one you claimed. Nothing else.
create policy "see own invites" on public.invites for select
  using (created_by = auth.uid() or claimed_by = auth.uid());
create policy "create invites" on public.invites for insert
  with check (created_by = auth.uid());

-- claiming is a function, not a policy — the caller must never be able to
-- read unclaimed codes, only to prove they hold one.
create or replace function public.claim_invite(p_code text)
returns boolean language plpgsql security definer set search_path = public as $$
declare ok boolean;
begin
  if auth.uid() is null then raise exception 'sign in first'; end if;
  update public.invites
     set claimed_by = auth.uid(), claimed_at = now()
   where code = lower(trim(p_code))
     and claimed_by is null
     and (expires_at is null or expires_at > now())
  returning true into ok;
  return coalesce(ok, false);
end $$;

-- ── public read helpers ────────────────────────────────────────────────────
-- One call for the whole page load. Bumps the view counter as a side effect,
-- which RLS would otherwise forbid for an anonymous visitor.
create or replace function public.get_wall(p_handle citext)
returns table (handle citext, identity jsonb, regions jsonb, items jsonb, views bigint)
language plpgsql security definer set search_path = public as $$
begin
  update public.walls w set views = w.views + 1
   where w.handle = p_handle and w.published = true;
  return query
    select w.handle, w.identity, w.regions, w.items, w.views
      from public.walls w
     where w.handle = p_handle and w.published = true;
end $$;

create or replace function public.handle_available(p_handle citext)
returns boolean language sql stable security definer set search_path = public as $$
  select p_handle ~ '^[a-z0-9](?:[a-z0-9_-]{1,30}[a-z0-9])$'
     and not exists (select 1 from public.reserved_handles r where r.handle = p_handle)
     and not exists (select 1 from public.walls w where w.handle = p_handle);
$$;

grant execute on function public.get_wall(citext)          to anon, authenticated;
grant execute on function public.handle_available(citext)  to anon, authenticated;
grant execute on function public.claim_invite(text)        to authenticated;

-- ── embed cache (written by the `resolve` edge function) ───────────────────
create table if not exists public.embed_cache (
  url        text primary key,
  payload    jsonb not null,
  fetched_at timestamptz not null default now()
);
create index if not exists embed_cache_fetched_idx on public.embed_cache (fetched_at);
alter table public.embed_cache enable row level security;
create policy "cache readable" on public.embed_cache for select using (true);
-- no insert/update policy: only the service role (the edge function) writes.

-- ── storage: paintings, photos, poster art ─────────────────────────────────
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('muro', 'muro', true, 10485760,
        array['image/jpeg','image/png','image/webp','image/gif','image/avif'])
on conflict (id) do update
  set public = true, file_size_limit = 10485760,
      allowed_mime_types = array['image/jpeg','image/png','image/webp','image/gif','image/avif'];

drop policy if exists "muro images are public" on storage.objects;
create policy "muro images are public" on storage.objects for select
  using (bucket_id = 'muro');

-- everyone writes only inside their own uid/ folder
drop policy if exists "own folder insert" on storage.objects;
create policy "own folder insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'muro' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "own folder update" on storage.objects;
create policy "own folder update" on storage.objects for update to authenticated
  using (bucket_id = 'muro' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "own folder delete" on storage.objects;
create policy "own folder delete" on storage.objects for delete to authenticated
  using (bucket_id = 'muro' and (storage.foldername(name))[1] = auth.uid()::text);

-- ═══════════════════════════════════════════════════════════════════════════
-- AFTER RUNNING THIS, ONCE:
--
--   1. Sign in on the site with your email (magic link).
--   2. Back here, give yourself the first invite and claim it:
--
--        insert into public.invites (code, note) values ('la-vida-es-una', 'founder');
--        update public.invites set claimed_by = (select id from auth.users
--          where email = 'blueimpactfund@gmail.com'), claimed_at = now()
--          where code = 'la-vida-es-una';
--
--   3. Reload the site and hit Publish. lifeisone.co/luk is live.
--
--   4. To invite someone:
--        insert into public.invites (code, note, created_by)
--        values ('ceramics-marta', 'met at Radion', auth.uid()) returning code;
-- ═══════════════════════════════════════════════════════════════════════════
