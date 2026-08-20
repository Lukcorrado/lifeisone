/* ═══════════════════════════════════════════════════════════════════════════
   MURO × Supabase — the live layer.

   The anon key is MEANT to be public: row level security is what protects
   the data, not secrecy of this string.
   ═══════════════════════════════════════════════════════════════════════════ */

window.MURO_SUPABASE = {
  url:     "https://llxuoaywxohqlfswaafq.supabase.co",
  anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxseHVvYXl3eG9ocWxmc3dhYWZxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcyMTQxMDIsImV4cCI6MjEwMjc5MDEwMn0.9vD61fmyfLrhvX88lRBxrphMnZ8DOQwfLnp7L2PCfAY",

  /* The wall served at the root of the domain. */
  rootHandle: null,   /* the root is the universe now; Luk lives at /luk */
};
