/* ═══════════════════════════════════════════════════════════════════════════
   MURO × Supabase — the live layer.

   Fill these two in. The anon key is MEANT to be public: row level security
   is what protects the data, not secrecy of this string.
   Supabase dashboard → Project Settings → API.
   ═══════════════════════════════════════════════════════════════════════════ */

window.MURO_SUPABASE = {
  url:     "https://YOUR-PROJECT-REF.supabase.co",
  anonKey: "YOUR-ANON-PUBLIC-KEY",

  /* The wall served at the root of the domain. */
  rootHandle: "luk",
};

/* Delete this file (or leave the placeholders) and the site still works —
   it just falls back to muro.config.js and runs fully static. */
