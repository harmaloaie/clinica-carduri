// ═══════════════════════════════════════════════════════════════
// CONFIG ENVIRONMENT-AWARE
// Detectează automat dacă suntem pe staging sau prod
// și încarcă credențialele Supabase corecte
// ═══════════════════════════════════════════════════════════════

(function() {
  var hostname = window.location.hostname;
  var isStaging = (
    hostname.indexOf('staging') >= 0 ||
    hostname.indexOf('pages.dev') >= 0 ||
    hostname === 'localhost' ||
    hostname === '127.0.0.1'
  );

  // ─── PROD CONFIG ───
  var PROD_CONFIG = {
    SUPABASE_URL: "https://hqfobteziomffildcssy.supabase.co",
    SUPABASE_ANON_KEY: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhxZm9idGV6aW9tZmZpbGRjc3N5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcxNjA3MjIsImV4cCI6MjA5MjczNjcyMn0.fVvWISCGZY-RzI0f1VC8xDOzn5NYWbCtxQwztqenJp0",
    CLINICA_NUME: "Clinica Central",
    ENV: "production"
  };

  // ─── STAGING CONFIG ───
  var STAGING_CONFIG = {
    SUPABASE_URL: "https://bqlypbpxyhvvdmjybygw.supabase.co",
    SUPABASE_ANON_KEY: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJxbHlwYnB4eWh2dmRtanlieWd3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc4NTgzOTEsImV4cCI6MjA5MzQzNDM5MX0.fGdjLm1fJfNW6dZJQSG9E3A-L1XrPtUHFN9YtO5q9o0",
    CLINICA_NUME: "Clinica Central [STAGING]",
    ENV: "staging"
  };

  window.CLINICA_CONFIG = isStaging ? STAGING_CONFIG : PROD_CONFIG;

  // Banner vizibil pe staging — ca să nu confundi mediile
  if (isStaging) {
    window.addEventListener('DOMContentLoaded', function() {
      var banner = document.createElement('div');
      banner.style.cssText = 'position:fixed;top:0;left:0;right:0;background:#f59e0b;color:#000;padding:6px;text-align:center;font-family:monospace;font-size:11px;font-weight:700;letter-spacing:0.1em;z-index:99999;border-bottom:2px solid #000';
      banner.textContent = '⚠ STAGING ENVIRONMENT — DATELE NU SUNT REALE ⚠';
      document.body.appendChild(banner);
      document.body.style.paddingTop = '28px';
    });
  }

  console.log('[Clinica Config] Environment:', window.CLINICA_CONFIG.ENV);
})();
