-- ═══════════════════════════════════════════════════════════════════════════
--  0003 — bring already-claimed walls onto the circle model.
--
--  A wall is a snapshot: claiming one copies muro.config.js into the row, and
--  from then on the row is the truth. Walls claimed before 0002 therefore
--  still carry the old seven rectangles, a region keyed `paint`, and items
--  with no `pub` flag at all — which under the new get_wall() means their
--  owner sees everything and visitors see nothing.
--
--  This rewrites those rows in place:
--    · ONE becomes the circle, centred where the manifesto already sits
--    · paint becomes art, in the region list and on every item
--    · pub is derived from geometry — centre inside the circle, same rule
--      the client uses, so the two can never disagree
--
--  Idempotent: it writes fixed values, so running it twice changes nothing.
-- ═══════════════════════════════════════════════════════════════════════════

update public.walls w
set
  regions = coalesce((
    select jsonb_agg(
      case
        when r->>'key' = 'one' then
          r || jsonb_build_object('x', 1925, 'y', 860, 'w', 1050, 'h', 1050,
                                  'shape', 'circle',
                                  'sub', 'public · everyone can see')
        when r->>'key' = 'paint' then
          r || jsonb_build_object('key', 'art', 'name', 'ART')
        else r
      end
      order by ord)
      from jsonb_array_elements(w.regions) with ordinality t(r, ord)
  ), w.regions),

  items = coalesce((
    select jsonb_agg(
      (case when i->>'region' = 'paint'
            then i || jsonb_build_object('region', 'art')
            else i end)
      || jsonb_build_object('pub',
           -- centre of the card, against the ONE circle: (2450, 1385) r 525
           ( power(coalesce((i->>'x')::numeric, 0) + coalesce((i->>'w')::numeric, 0)/2 - 2450, 2)
           + power(coalesce((i->>'y')::numeric, 0) + coalesce((i->>'h')::numeric, 0)/2 - 1385, 2)
           ) <= power(525, 2))
      order by ord)
      from jsonb_array_elements(w.items) with ordinality t(i, ord)
  ), '[]'::jsonb)

where w.regions is not null;
