# lifeisone.co — Luk's MURO

*La vida es una.* One life, undivided. This is the room.

## Files

```
index.html                            the engine + the room. Rarely needs touching.
muro.config.js                        YOUR WALL. Every card, word, position. Edit this.
muro.supabase.js                      your project url + anon key. Delete it → static mode.
vercel.json                           makes /anyhandle route to the app
supabase/migrations/0001_muro_init.sql  tables, RLS, invites, storage
supabase/functions/resolve/index.ts     turns a pasted link into a real card
GO-LIVE.md                            ← the step-by-step terminal guide
```

No build step, no framework, no npm install. It's a static site with a database
behind it. **Without `muro.supabase.js` it still runs, fully static, off
`muro.config.js`** — the live layer is additive, never a dependency.

## Run it

```bash
python3 -m http.server 8000     # or: npx serve .
open http://localhost:8000
```

Or just double-click `index.html`.

## Ship it to lifeisone.co

```bash
git init && git add -A && git commit -m "la vida es una"
gh repo create lifeisone --public --source=. --push

npm i -g vercel
vercel                       # accept defaults, it's a static site
vercel --prod
vercel domains add lifeisone.co
```

Then point the domain's nameservers (or an A/CNAME record) at Vercel — the CLI prints
exactly what to set. Deploys take about 12 seconds after that.

## The two ways to edit — they're the same loop

**Visually.** Press `E`. Drag the bars, shift-drag to tilt, corner to resize, paste links
into the dock. When it looks right, hit **⇩ Config** — it writes `muro.config.js` back out
with your exact layout. Drop that file in, commit, done.

**In code.** Open `muro.config.js` and change things. Every field is commented. Ask Claude
to "add a SOUND card linking to X and put it near the vinyl note" and it has everything it
needs — the file is the whole state.

Neither one is the "real" way. That's the point.

## What's in the room

Six wavelengths around a centre. Change a hex in `regions[]` and the whole site re-tunes.

| Region | Colour | Holds |
|---|---|---|
| **ONE** | paper | the manifesto. the centre. |
| **MAKE** | `#2E5BFF` | code, products, the venture builder, Blue House World |
| **SOUND** | `#FF4D2E` | music, vinyl, the noise |
| **PAINT** | `#E4489B` | canvas, colour, hands |
| **MIND** | `#2F8F5B` | books, thinking, notes |
| **VOICE** | `#F5A623` | the podcast, words out loud |
| **LIFE** | `#7B5CFF` | Amsterdam, people, style |

## Fill these in

Search `muro.config.js` for **TODO**. Right now that's: your real GitHub/product links,
your actual tracks, photos of your paintings, your Instagram handle, what's on the
turntable, what you're reading.

## What works when you paste a link

Live embeds, no API keys: YouTube, Vimeo, Spotify, SoundCloud, Apple Music, Instagram
posts, TikTok, Twitch, Kick, Mastodon, Kickstarter, Calendly.

Designed link cards (no embed exists — this is correct, not broken): Suno, Bandcamp,
Bluesky, X, GitHub, Substack.

Nothing loads until you click it. No Meta or Google script runs when someone arrives —
that's a performance decision and a privacy one at the same time.

## When you outgrow the static version

The wall is already portable: **Share** encodes the entire room into a URL. When you want
`lifeisone.co/somebody-else`, that's Postgres, one table, and about an hour — the schema
is in the earlier `muro-repo.zip`.


## Going live

See **GO-LIVE.md** — Supabase project, schema, edge function, Vercel, domain, in order.

The database layer gives you: real auth (magic link), `lifeisone.co/anyone`, image
uploads for the paintings, invite-gated signups, view counts, and server-side link
resolution so pasted URLs come back with real titles and cover art.
