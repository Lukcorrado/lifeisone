-- ═══════════════════════════════════════════════════════════════════════════
--  0005 — RAÍZ. The ground under the room.
--
--  An item inside a locked region carries `priv: true` and, in place of its
--  words, an `enc` blob that was sealed in the owner's browser with a key
--  derived from a six-digit code. The database never sees the code and cannot
--  read the blob.
--
--  So why filter at all, if it's already ciphertext? Defence in depth, and
--  metadata. The blob is unreadable, but its existence, size and position are
--  not — and none of that is anyone else's business either. A private item
--  now leaves the database for exactly one person: the owner.
--
--  Note the ordering below: `priv` is checked BEFORE `pub`. A card dragged
--  from ONE into a RAÍZ must go dark even if a stale pub flag rode along with
--  it, so the private test wins every tie.
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.get_wall(p_handle citext)
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
             -- the owner gets everything, sealed blobs included; only their
             -- browser holds the key that turns those back into words
             when v_me = w.owner then w.items
             -- someone you let in: the whole room EXCEPT the locked ground
             when v_full then coalesce(
               (select jsonb_agg(i)
                  from jsonb_array_elements(w.items) i
                 where not coalesce((i->>'priv')::boolean, false)),
               '[]'::jsonb)
             -- a stranger: the shop window, and nothing else
             else coalesce(
               (select jsonb_agg(i)
                  from jsonb_array_elements(w.items) i
                 where not coalesce((i->>'priv')::boolean, false)
                   and coalesce((i->>'pub')::boolean, false)),
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

grant execute on function public.get_wall(citext) to anon, authenticated;
