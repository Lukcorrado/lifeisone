/**
 * MURO · edge function `resolve`
 *
 *   POST { url }  ->  { provider, label, color, kind, ratio, iframe?, title, thumb, desc, audio?, video? }
 *
 * Three tiers, cheapest first:
 *   1. iframe — deterministic URL transform. Zero network calls.
 *   2. oEmbed — one server-side call (these endpoints send no CORS headers,
 *      which is exactly why this has to live on the server).
 *   3. Open Graph — parse the page's meta tags. The only path for Suno,
 *      Bandcamp, Higgsfield and every other platform with no embed product.
 *
 * Cached in public.embed_cache for 24h. Never called on page render.
 *
 *   supabase functions deploy resolve --no-verify-jwt
 */
import { createClient } from "jsr:@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type Prov = {
  key: string; label: string; color: string; kind: string; ratio: number;
  match: RegExp; iframe?: (m: RegExpMatchArray, u: string) => string;
  oembed?: (u: string) => string; block?: boolean; note?: string;
};

const PROVIDERS: Prov[] = [
  { key:"youtube", label:"YouTube", color:"#FF0033", kind:"video", ratio:16/9,
    match:/(?:youtube\.com\/(?:watch\?v=|shorts\/|live\/)|youtu\.be\/)([\w-]{11})/,
    iframe:m=>`https://www.youtube-nocookie.com/embed/${m[1]}?rel=0`,
    oembed:u=>`https://www.youtube.com/oembed?format=json&url=${encodeURIComponent(u)}` },
  { key:"vimeo", label:"Vimeo", color:"#1AB7EA", kind:"video", ratio:16/9,
    match:/vimeo\.com\/(\d+)/, iframe:m=>`https://player.vimeo.com/video/${m[1]}`,
    oembed:u=>`https://vimeo.com/api/oembed.json?url=${encodeURIComponent(u)}` },
  { key:"spotify", label:"Spotify", color:"#1DB954", kind:"audio", ratio:1.55,
    match:/open\.spotify\.com\/(?:intl-\w+\/)?(track|album|playlist|artist|episode|show)\/(\w+)/,
    iframe:m=>`https://open.spotify.com/embed/${m[1]}/${m[2]}`,
    oembed:u=>`https://open.spotify.com/oembed?url=${encodeURIComponent(u)}` },
  { key:"soundcloud", label:"SoundCloud", color:"#FF5500", kind:"audio", ratio:2.1,
    match:/soundcloud\.com\/[\w-]+\/[\w-]+/,
    iframe:(_m,u)=>`https://w.soundcloud.com/player/?url=${encodeURIComponent(u)}&color=%23ff4d2e&show_comments=false`,
    oembed:u=>`https://soundcloud.com/oembed?format=json&url=${encodeURIComponent(u)}` },
  { key:"applemusic", label:"Apple Music", color:"#FA2D48", kind:"audio", ratio:1.5,
    match:/music\.apple\.com\//, iframe:(_m,u)=>u.replace("music.apple.com","embed.music.apple.com") },
  // Tokenless since 15 June 2026 — no App Review, no access token, public posts only.
  { key:"instagram", label:"Instagram", color:"#E4489B", kind:"post", ratio:0.8,
    match:/instagram\.com\/(?:p|reel|tv)\/([\w-]+)/,
    iframe:m=>`https://www.instagram.com/p/${m[1]}/embed/captioned/`,
    oembed:u=>`https://graph.facebook.com/v25.0/instagram_oembed?url=${encodeURIComponent(u)}&omitscript=true` },
  { key:"facebook", label:"Facebook", color:"#1877F2", kind:"post", ratio:1.1,
    match:/facebook\.com\/[\w.]+\/(posts|videos)\//,
    iframe:(_m,u)=>`https://www.facebook.com/plugins/post.php?href=${encodeURIComponent(u)}&show_text=true`,
    oembed:u=>`https://graph.facebook.com/v25.0/oembed_post?url=${encodeURIComponent(u)}&omitscript=true` },
  { key:"threads", label:"Threads", color:"#EDEDED", kind:"post", ratio:1.2,
    match:/threads\.(?:net|com)\/@[\w.-]+\/post\//,
    oembed:u=>`https://graph.threads.net/v1.0/oembed?url=${encodeURIComponent(u)}&omitscript=true` },
  { key:"tiktok", label:"TikTok", color:"#EDEDED", kind:"video", ratio:0.62,
    match:/tiktok\.com\/@[\w.-]+\/video\/(\d+)/, iframe:m=>`https://www.tiktok.com/embed/v2/${m[1]}`,
    oembed:u=>`https://www.tiktok.com/oembed?url=${encodeURIComponent(u)}` },
  { key:"bluesky", label:"Bluesky", color:"#0085FF", kind:"post", ratio:1.5,
    match:/bsky\.app\/profile\/[\w.:-]+\/post\//,
    oembed:u=>`https://embed.bsky.app/oembed?url=${encodeURIComponent(u)}&format=json` },
  { key:"mastodon", label:"Mastodon", color:"#6364FF", kind:"post", ratio:1.4,
    match:/^https?:\/\/[\w.-]+\/@[\w.-]+\/\d+/, iframe:(_m,u)=>`${u}/embed` },
  { key:"twitch", label:"Twitch", color:"#9146FF", kind:"video", ratio:16/9,
    match:/twitch\.tv\/(\w+)\/?$/, note:"needs ?parent= your domain — the client adds it" },
  { key:"kick", label:"Kick", color:"#53FC18", kind:"video", ratio:16/9,
    match:/kick\.com\/([\w-]+)\/?$/, iframe:m=>`https://player.kick.com/${m[1]}` },
  { key:"kickstarter", label:"Kickstarter", color:"#05CE78", kind:"page", ratio:1.15,
    match:/kickstarter\.com\/projects\/([\w-]+\/[\w-]+)/,
    iframe:m=>`https://www.kickstarter.com/projects/${m[1]}/widget/card.html` },
  { key:"calendly", label:"Calendly", color:"#006BFF", kind:"page", ratio:0.95,
    match:/calendly\.com\/[\w-]/, iframe:(_m,u)=>u },
  // No supported embed exists for these. OG card, on purpose.
  { key:"suno", label:"Suno", color:"#EDEDED", kind:"audio", ratio:1.3, match:/suno\.(com|ai)\/song\// },
  { key:"bandcamp", label:"Bandcamp", color:"#629AA9", kind:"audio", ratio:1.4, match:/\.bandcamp\.com\/(album|track)\// },
  { key:"x", label:"X", color:"#EDEDED", kind:"post", ratio:1.3, match:/(?:twitter|x)\.com\/\w+\/status\// },
  { key:"github", label:"GitHub", color:"#8B95A8", kind:"page", ratio:1.35, match:/github\.com\// },
  { key:"substack", label:"Substack", color:"#FF6719", kind:"page", ratio:1.25, match:/substack\.com\// },
  { key:"adult", label:"Blocked", color:"#8B0000", kind:"page", ratio:1, match:/(onlyfans|fansly)\.com/, block:true,
    note:"Adult platforms pull your whole payment stack under Mastercard BRAM and Visa VIRP. Blocked at ingest." },
];

const UA = "MuroBot/1.0 (+https://lifeisone.co)";

/** Minimal, dependency-free Open Graph / Twitter Card reader. */
function readMeta(html: string) {
  const out: Record<string, string> = {};
  const tag = /<meta\s+[^>]*>/gi;
  let m: RegExpExecArray | null;
  while ((m = tag.exec(html))) {
    const t = m[0];
    const key = /(?:property|name)\s*=\s*["']([^"']+)["']/i.exec(t)?.[1]?.toLowerCase();
    const val = /content\s*=\s*["']([^"']*)["']/i.exec(t)?.[1];
    if (key && val && !(key in out)) out[key] = val;
  }
  const title = /<title[^>]*>([\s\S]*?)<\/title>/i.exec(html)?.[1]?.trim();
  return {
    title: out["og:title"] ?? out["twitter:title"] ?? title ?? null,
    desc:  out["og:description"] ?? out["twitter:description"] ?? out["description"] ?? null,
    image: out["og:image:secure_url"] ?? out["og:image"] ?? out["twitter:image"] ?? null,
    video: out["og:video:secure_url"] ?? out["og:video:url"] ?? out["og:video"] ?? null,
    audio: out["og:audio:secure_url"] ?? out["og:audio"] ?? null,
    site:  out["og:site_name"] ?? null,
  };
}

const decode = (s: string | null) => s ? s
  .replace(/&amp;/g,"&").replace(/&lt;/g,"<").replace(/&gt;/g,">")
  .replace(/&quot;/g,'"').replace(/&#0?39;|&apos;/g,"'").trim() : null;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  const json = (b: unknown, status = 200) =>
    new Response(JSON.stringify(b), { status, headers: { ...CORS, "Content-Type": "application/json" } });

  let url: string;
  try { url = (await req.json()).url; } catch { return json({ error: "bad body" }, 400); }
  if (typeof url !== "string" || !/^https?:\/\//i.test(url) || url.length > 2048)
    return json({ error: "bad url" }, 400);

  // Don't let a wall become an SSRF tool.
  const host = new URL(url).hostname;
  if (/^(localhost|127\.|10\.|192\.168\.|169\.254\.|\[?::1)/i.test(host))
    return json({ error: "refused" }, 400);

  const db = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );

  const { data: hit } = await db.from("embed_cache")
    .select("payload, fetched_at").eq("url", url).maybeSingle();
  if (hit && Date.now() - Date.parse(hit.fetched_at) < 864e5) return json(hit.payload);

  let p: Prov | null = null, m: RegExpMatchArray | null = null;
  for (const cand of PROVIDERS) { const mm = url.match(cand.match); if (mm) { p = cand; m = mm; break; } }
  if (p?.block) return json({ error: "blocked", note: p.note }, 451);

  const out: Record<string, unknown> = {
    url,
    provider: p?.key ?? "generic",
    label: p?.label ?? host.replace(/^www\./, ""),
    color: p?.color ?? "#8A857D",
    kind: p?.kind ?? "page",
    ratio: p?.ratio ?? 1.3,
    note: p?.note ?? null,
  };
  if (p?.iframe && m) out.iframe = p.iframe(m, url);

  if (p?.oembed) {
    try {
      const r = await fetch(p.oembed(url), { headers: { "user-agent": UA }, signal: AbortSignal.timeout(6000) });
      if (r.ok) {
        const j = await r.json();
        out.title = j.title ?? null;
        out.author = j.author_name ?? null;
        out.thumb = j.thumbnail_url ?? null;
        if (j.width && j.height) out.ratio = j.width / j.height;
      }
    } catch { /* fall through */ }
  }

  if (!out.thumb || !out.title) {
    try {
      const r = await fetch(url, {
        headers: { "user-agent": UA, "accept": "text/html,*/*" },
        redirect: "follow", signal: AbortSignal.timeout(8000),
      });
      const html = (await r.text()).slice(0, 400_000);   // meta tags live in <head>
      const meta = readMeta(html);
      out.title ??= decode(meta.title);
      out.desc  = decode(meta.desc);
      out.thumb ??= meta.image;
      if (meta.video) { out.video = meta.video; out.kind = "video"; }
      if (meta.audio) { out.audio = meta.audio; out.kind = "audio"; }  // ← how Suno gets a real player
    } catch { out.title ??= out.label; }
  }

  await db.from("embed_cache").upsert({ url, payload: out, fetched_at: new Date().toISOString() });
  return json(out);
});
