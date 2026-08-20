-- ═══════════════════════════════════════════════════════════════════════════
--  0002 — ONE is the shop window.
--
--  Until now a wall was all-or-nothing: publish it and every card on it was
--  readable by anyone holding the anon key. That is the wrong shape for a
--  room you actually live in.
--
--  From here, an item carries a boolean `pub`, set by the client when its
--  centre lands inside the ONE circle. Only those items leave the database.
--  Everything else — the notes, the half-finished things, the thinking — is
--  visible to the owner and to nobody else.
--
--  Two changes are needed, and BOTH matter. Filtering get_wall() alone would
--  be theatre, because the old SELECT policy let any visitor read the raw
--  row and simply ignore the function.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. visitors lose direct read access to the row ─────────────────────────
-- The old policy was `published = true or owner = auth.uid()`, which handed
-- the complete items array to anyone who asked for it. get_wall() is now the
-- only public door in, and it is the door that does the filtering.
drop policy if exists "read published or own" on public.walls;

create policy "read own wall" on public.walls for select
  using (owner = auth.uid());

-- ── 2. the public door withholds private items ─────────────────────────────
create or replace function public.get_wall(p_handle citext)
returns table (handle citext, identity jsonb, regions jsonb, items jsonb, views bigint)
language plpgsql security definer set search_path = public as $$
declare
  v_owner uuid;
  v_me    uuid := auth.uid();
begin
  select w.owner into v_owner
    from public.walls w
   where w.handle = p_handle and w.published = true;

  if v_owner is null then
    return;                       -- no such wall, or not published
  end if;

  -- your own visits are not an audience
  if v_me is null or v_me <> v_owner then
    update public.walls w set views = w.views + 1
     where w.handle = p_handle and w.published = true;
  end if;

  return query
    select w.handle,
           w.identity,
           w.regions,             -- the rooms themselves are not a secret
           case
             when v_me = w.owner then w.items
             else coalesce(
               (select jsonb_agg(i)
                  from jsonb_array_elements(w.items) i
                 where coalesce((i->>'pub')::boolean, false)),
               '[]'::jsonb)
           end,
           w.views
      from public.walls w
     where w.handle = p_handle and w.published = true;
end $$;

grant execute on function public.get_wall(citext) to anon, authenticated;

-- ── notes ──────────────────────────────────────────────────────────────────
-- `pub` is written by the client from the geometry of the ONE circle. That is
-- safe: only the owner can write their own wall (the update policy is
-- unchanged), so the flag can only ever be set by the person it belongs to.
-- The database's job here is narrower and more important — to make sure a
-- visitor is never sent an item that isn't flagged, whatever the client does.
