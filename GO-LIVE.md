# lifeisone.co — from this folder to live, in your terminal

Everything below is copy-paste. Roughly 25 minutes, most of it waiting for DNS.

Prerequisites: `node`, `git`, `gh`, and a domain you control.

---

## 0 · Tools (once)

```bash
npm i -g supabase vercel
# macOS alternative for supabase: brew install supabase/tap/supabase
supabase --version && vercel --version
```

---

## 1 · The repo

```bash
cd ~/where-you-keep-things
# unzip lifeisone-site.zip here, then:
cd lifeisone
git init && git add -A && git commit -m "la vida es una"
gh repo create lifeisone --public --source=. --push
```

Check it runs static first — it should work with zero backend:

```bash
python3 -m http.server 8000
# open http://localhost:8000  → your wall, static mode
```

`Ctrl-C` when you've seen it.

---

## 2 · Supabase project

```bash
supabase login                       # opens a browser once
supabase projects create lifeisone --region eu-central-1 --plan free
# ↑ note the project ref it prints, e.g. abcdefghijklmnop
```

> Amsterdam-adjacent regions: `eu-central-1` (Frankfurt) or `eu-west-2` (London).
> Pick the closest one; it's the latency your visitors feel.

```bash
export REF=abcdefghijklmnop            # ← paste your ref here
supabase link --project-ref $REF
```

That rewrites `supabase/config.toml` with your ref.

---

## 3 · The schema

```bash
supabase db push
```

If it asks about `supabase/migrations/0001_muro_init.sql` — yes, that's the one.

> **If `db push` gives you trouble**, the fallback always works: open
> `https://supabase.com/dashboard/project/$REF/sql/new`, paste the entire contents
> of `supabase/migrations/0001_muro_init.sql`, hit Run. Same result.

Verify:

```bash
supabase db execute --linked "select handle from public.walls limit 1;" 2>/dev/null || \
  echo "no walls yet — correct, you haven't claimed one"
```

---

## 4 · Keys into the site

```bash
supabase projects api-keys --project-ref $REF
```

Copy the **anon / public** key (never the `service_role` one — that's for the edge
function only, and Supabase keeps it server-side for you).

```bash
cat > muro.supabase.js <<EOF
window.MURO_SUPABASE = {
  url:     "https://$REF.supabase.co",
  anonKey: "PASTE_THE_ANON_KEY_HERE",
  rootHandle: "luk",
};
EOF
```

The anon key belongs in public HTML. Row Level Security is what protects the data —
with that key a stranger can read published walls and nothing else.

---

## 5 · The edge function

```bash
supabase functions deploy resolve --no-verify-jwt
```

This is what turns a pasted Suno link into a card with the real cover art and title.
`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are injected automatically — you don't
set them.

Test it:

```bash
curl -s -X POST "https://$REF.supabase.co/functions/v1/resolve" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://www.youtube.com/watch?v=dQw4w9WgXcQ"}' | head -c 400
```

You should get JSON with a `title` and a `thumb`.

---

## 6 · Auth redirect URLs

Magic links break silently if this is wrong, so do it now.

Dashboard → **Authentication → URL Configuration**:

| Field | Value |
|---|---|
| Site URL | `https://lifeisone.co` |
| Additional redirect URLs | `http://localhost:8000`, `https://lifeisone.vercel.app`, `https://*.vercel.app` |

---

## 7 · Ship it

```bash
vercel                # link the project; accept every default, it's a static site
vercel --prod
```

Then the domain:

```bash
vercel domains add lifeisone.co
vercel domains inspect lifeisone.co     # prints the exact DNS records to set
```

Set those records at your registrar. Usually either:

- nameservers → `ns1.vercel-dns.com` / `ns2.vercel-dns.com`, **or**
- an `A` record `@` → `76.76.21.21` and a `CNAME` `www` → `cname.vercel-dns.com`

Propagation is minutes, occasionally an hour. Watch it:

```bash
dig +short lifeisone.co
```

---

## 8 · Become the owner

1. Open `https://lifeisone.co` → **Sign in** → your email → click the link in your inbox.
2. Give yourself the first invite. Dashboard → SQL editor:

```sql
insert into public.invites (code, note) values ('la-vida-es-una', 'founder');

update public.invites
   set claimed_by = (select id from auth.users where email = 'blueimpactfund@gmail.com'),
       claimed_at = now()
 where code = 'la-vida-es-una';
```

3. Back on the site: **Publish** → handle `luk` → invite code `la-vida-es-una` → Claim it.

`lifeisone.co/luk` is now live, and `lifeisone.co` serves it at the root (that's
`rootHandle` in `muro.supabase.js`).

---

## 9 · The loop from here

| You want to | Do this |
|---|---|
| Move things around | Press `E`, drag, then **Save** (or `⌘S`) |
| Add a link | Edit mode → paste in the dock → **Pin** |
| Add a painting | Edit mode → **↑ Image** → it uploads to Supabase Storage |
| Change words | Edit `muro.config.js`, or edit in place and Save |
| Rebuild the seed file | **Config → ⇩ Download** → replaces `muro.config.js` |
| Invite someone | SQL: `insert into public.invites (code, note, created_by) values ('their-name','how you met', auth.uid());` |
| Open to everyone | SQL: `update public.muro_settings set value='true' where key='open_signups';` |

Deploys after the first one are just:

```bash
git add -A && git commit -m "…" && git push
```

Vercel builds on push once the repo is linked.

---

## Troubleshooting

**"you need a valid invite code" when claiming.** The RLS insert policy is doing its
job. Your `auth.users` row must appear in `invites.claimed_by`. Re-run the `update`
in step 8 — the email must match exactly.

**Magic link lands on a blank page.** Step 6. The redirect URL must match the origin
you're browsing, including `http` vs `https` and the port.

**Cards show titles but no images.** The edge function isn't deployed or the anon key
in `muro.supabase.js` is wrong. Check the browser console for the `resolve` call.

**Twitch embeds are blank.** Twitch requires `?parent=` naming every host. The client
sends `location.hostname`, so it works on the real domain but not on a Vercel preview
URL unless you add that host too.

**Everything static again after a deploy.** `muro.supabase.js` wasn't committed —
check it isn't caught by `.gitignore`. It's meant to be public.

---

*La vida es una.*
