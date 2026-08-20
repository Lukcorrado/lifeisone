-- ═══════════════════════════════════════════════════════════════════════════
--  0004 — the universe, and knocking on doors.
--
--  Until now a wall had two audiences: the owner, and everyone. This adds the
--  third and most important one — people you have actually let in.
--
--    · ONE stays public. It is the shop window, visible in the universe.
--    · Everything else is private by default.
--    · A visitor knocks. The owner accepts. From then on that person can walk
--      in whenever, until the owner revokes them.
--
--  All of it is enforced in Postgres. The client is never trusted to decide
--  who sees what — it only asks, and the database answers.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── who has been let in ────────────────────────────────────────────────────
create table if not exists public.wall_access (
  id         uuid primary key default gen_random_uuid(),
  owner      uuid not null references auth.users(id) on delete cascade,
  visitor    uuid not null references auth.users(id) on delete cascade,
  status     text not null default 'pending'
             check (status in ('pending','granted','denied')),
  note       text,                                  -- "hey, it's your sister"
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  unique (owner, visitor),
  constraint no_knocking_on_your_own_door check (owner <> visitor),
  constraint note_is_short check (note is null or length(note) <= 240)
);

create index if not exists wall_access_owner_idx   on public.wall_access (owner, status);
create index if not exists wall_access_visitor_idx on public.wall_access (visitor, status);

alter table public.wall_access enable row level security;

-- You can see the knocks at your door, and the ones you sent. Nothing else —
-- who visits whom is not public information.
drop policy if exists "see my own access rows" on public.wall_access;
create policy "see my own access rows" on public.wall_access for select
  using (owner = auth.uid() or visitor = auth.uid());

-- Writes go through the functions below, never straight from the client:
-- otherwise a visitor could insert their own row with status 'granted'.

-- ── does this person have the run of that wall? ────────────────────────────
create or replace function public.has_access(p_owner uuid, p_visitor uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select p_visitor is not null and (
    p_owner = p_visitor
    or exists (select 1 from public.wall_access a
                where a.owner = p_owner and a.visitor = p_visitor
                  and a.status = 'granted')
  );
$$;

-- ── the universe ───────────────────────────────────────────────────────────
-- Every claimed handle, oldest first, with where the caller stands in relation
-- to it. Names and handles only — never an email, never an item.
create or replace function public.directory()
returns table (handle citext, name text, ord bigint, access text, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select w.handle,
         coalesce(nullif(w.identity->>'name',''), w.handle::text) as name,
         row_number() over (order by w.created_at) as ord,
         case
           when auth.uid() is null            then 'anon'
           when w.owner = auth.uid()          then 'mine'
           when public.has_access(w.owner, auth.uid()) then 'granted'
           else coalesce((select a.status from public.wall_access a
                           where a.owner = w.owner and a.visitor = auth.uid()), 'none')
         end as access,
         w.created_at
    from public.walls w
   where w.published = true
   order by w.created_at;
$$;

-- ── knock knock ────────────────────────────────────────────────────────────
create or replace function public.knock(p_handle citext, p_note text default null)
returns text language plpgsql security definer set search_path = public as $$
declare v_owner uuid; v_me uuid := auth.uid(); v_status text;
begin
  if v_me is null then return 'sign-in-required'; end if;

  select w.owner into v_owner from public.walls w
   where w.handle = p_handle and w.published = true;
  if v_owner is null then return 'no-such-wall'; end if;
  if v_owner = v_me  then return 'thats-you';    end if;

  -- You need a room of your own before you can ask to see someone else's.
  if not exists (select 1 from public.walls w where w.owner = v_me) then
    return 'claim-a-handle-first';
  end if;

  select a.status into v_status from public.wall_access a
   where a.owner = v_owner and a.visitor = v_me;

  if v_status = 'granted' then return 'already-in';  end if;
  if v_status = 'pending' then return 'already-knocked'; end if;

  -- A previous 'denied' can be knocked on again — people change their minds.
  insert into public.wall_access (owner, visitor, note, status)
       values (v_owner, v_me, left(coalesce(p_note,''), 240), 'pending')
  on conflict (owner, visitor)
    do update set status = 'pending', note = excluded.note,
                  created_at = now(), decided_at = null;
  return 'knocked';
end $$;

-- ── who is at my door ──────────────────────────────────────────────────────
create or replace function public.knocks()
returns table (id uuid, handle citext, name text, status text, note text, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select a.id,
         w.handle,
         coalesce(nullif(w.identity->>'name',''), w.handle::text) as name,
         a.status, a.note, a.created_at
    from public.wall_access a
    join public.walls w on w.owner = a.visitor
   where a.owner = auth.uid()
   order by (a.status = 'pending') desc, a.created_at desc;
$$;

-- ── come in / not today ────────────────────────────────────────────────────
create or replace function public.respond_knock(p_id uuid, p_accept boolean)
returns text language plpgsql security definer set search_path = public as $$
declare v_me uuid := auth.uid(); n int;
begin
  if v_me is null then return 'sign-in-required'; end if;
  update public.wall_access a
     set status = case when p_accept then 'granted' else 'denied' end,
         decided_at = now()
   where a.id = p_id and a.owner = v_me;
  get diagnostics n = row_count;
  if n = 0 then return 'not-yours'; end if;
  return case when p_accept then 'granted' else 'denied' end;
end $$;

-- ── changed my mind ────────────────────────────────────────────────────────
create or replace function public.revoke_access(p_id uuid)
returns text language plpgsql security definer set search_path = public as $$
declare v_me uuid := auth.uid(); n int;
begin
  if v_me is null then return 'sign-in-required'; end if;
  delete from public.wall_access a where a.id = p_id and a.owner = v_me;
  get diagnostics n = row_count;
  return case when n = 0 then 'not-yours' else 'revoked' end;
end $$;

-- ── the door itself ────────────────────────────────────────────────────────
-- Same shape as 0002, with one clause added: someone you let in sees the whole
-- room, exactly as you do. Everyone else still gets ONE and nothing more.
-- The signature gains an `access` column, and Postgres will not let you change
-- a function's return type in place, so it goes and comes back.
drop function if exists public.get_wall(citext);

create function public.get_wall(p_handle citext)
returns table (handle citext, identity jsonb, regions jsonb, items jsonb,
               views bigint, access text)
language plpgsql security definer set search_path = public as $$
declare
  v_owner uuid;
  v_me    uuid := auth.uid();
  v_full  boolean;
begin
  select w.owner into v_owner
    from public.walls w
   where w.handle = p_handle and w.published = true;

  if v_owner is null then
    return;
  end if;

  v_full := public.has_access(v_owner, v_me);

  if v_me is null or v_me <> v_owner then
    update public.walls w set views = w.views + 1
     where w.handle = p_handle and w.published = true;
  end if;

  return query
    select w.handle,
           w.identity,
           w.regions,
           case
             when v_full then w.items
             else coalesce(
               (select jsonb_agg(i)
                  from jsonb_array_elements(w.items) i
                 where coalesce((i->>'pub')::boolean, false)),
               '[]'::jsonb)
           end,
           w.views,
           case when v_me = w.owner then 'mine'
                when v_full         then 'granted'
                when v_me is null   then 'anon'
                else coalesce((select a.status from public.wall_access a
                                where a.owner = w.owner and a.visitor = v_me), 'none')
           end
      from public.walls w
     where w.handle = p_handle and w.published = true;
end $$;

grant execute on function public.get_wall(citext)               to anon, authenticated;
grant execute on function public.directory()                    to anon, authenticated;
grant execute on function public.has_access(uuid, uuid)         to anon, authenticated;
grant execute on function public.knock(citext, text)            to authenticated;
grant execute on function public.knocks()                       to authenticated;
grant execute on function public.respond_knock(uuid, boolean)   to authenticated;
grant execute on function public.revoke_access(uuid)            to authenticated;
