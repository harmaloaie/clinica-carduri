// ═══════════════════════════════════════════════════════════════
// CONFIG — Editează aceste valori cu cele din Supabase Dashboard
// Project Settings → API → "Project URL" și "anon public" key
// ═══════════════════════════════════════════════════════════════

window.CLINICA_CONFIG = {
  // URL-ul proiectului tău Supabase (ex. "https://abcdefghij.supabase.co")
  SUPABASE_URL: "PUNE_AICI_URL_SUPABASE",

  // Cheia "anon public" — proiectată să fie publică, e ok să stea în frontend
  // Securitatea reală vine din Row Level Security (RLS) configurată în SQL
  SUPABASE_ANON_KEY: "PUNE_AICI_ANON_KEY",

  // Numele clinicii tale — apare în titluri și branding
  CLINICA_NUME: "Clinica Central"
};
