// ═══════════════════════════════════════════════════════════════
// SUPABASE CLIENT
// ═══════════════════════════════════════════════════════════════

(function() {
  if (!window.CLINICA_CONFIG) {
    console.error("[Clinica] config.js nu e încărcat!");
    return;
  }
  var cfg = window.CLINICA_CONFIG;
  if (cfg.SUPABASE_URL.indexOf("PUNE_AICI") === 0) {
    console.warn("[Clinica] Supabase nu e configurat. Editează shared/config.js");
  }
  if (typeof supabase === "undefined") {
    console.error("[Clinica] Supabase JS nu e încărcat.");
    return;
  }
  window.sb = supabase.createClient(cfg.SUPABASE_URL, cfg.SUPABASE_ANON_KEY, {
    auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
  });
})();

window.Clinica = {
  // ─── Auth ───
  async getCurrentUser() {
    var { data } = await sb.auth.getUser();
    return data && data.user ? data.user : null;
  },
  async signIn(email, password) {
    return await sb.auth.signInWithPassword({ email, password });
  },
  async signOut() {
    return await sb.auth.signOut();
  },

  // ─── User type detection ───
  async getAdminProfile() {
    var user = await this.getCurrentUser();
    if (!user) return null;
    var { data } = await sb.from("useri_admin").select("*").eq("id", user.id).maybeSingle();
    return data;
  },
  async getPartenerProfile() {
    var user = await this.getCurrentUser();
    if (!user) return null;
    var { data } = await sb
      .from("useri_partener")
      .select("*, parteneri(id, cod, denumire, oras)")
      .eq("id", user.id)
      .maybeSingle();
    return data;
  },
  // Returnează tipul userului ('admin', 'partener', null)
  async getUserType() {
    var user = await this.getCurrentUser();
    if (!user) return null;
    var admin = await this.getAdminProfile();
    if (admin && admin.activ) return "admin";
    var partener = await this.getPartenerProfile();
    if (partener && partener.activ) return "partener";
    return null;
  },

  async requireAdmin() {
    var user = await this.getCurrentUser();
    if (!user) {
      var current = encodeURIComponent(window.location.pathname + window.location.search);
      window.location.href = "login.html?type=admin&next=" + current;
      return null;
    }
    var profile = await this.getAdminProfile();
    if (!profile || !profile.activ) {
      alert("Nu ai permisiuni de admin.");
      await this.signOut();
      window.location.href = "login.html?type=admin";
      return null;
    }
    return profile;
  },

  async requirePartener() {
    var user = await this.getCurrentUser();
    if (!user) {
      var current = encodeURIComponent(window.location.pathname + window.location.search);
      window.location.href = "login.html?type=partener&next=" + current;
      return null;
    }
    var profile = await this.getPartenerProfile();
    if (!profile || !profile.activ) {
      alert("Nu ai permisiuni de partener.");
      await this.signOut();
      window.location.href = "login.html?type=partener";
      return null;
    }
    return profile;
  },

  // ─── Pacienți ───
  async getPacientPublic(codCard) {
    var { data, error } = await sb
      .from("pacient_card_public")
      .select("*")
      .eq("cod_card", codCard)
      .maybeSingle();
    return { data, error };
  },
  async listPacienti() {
    var { data, error } = await sb
      .from("pacienti")
      .select("*")
      .eq("activ", true)
      .order("created_at", { ascending: false });
    return { data, error };
  },
  async createPacient(payload) {
    return await sb.from("pacienti").insert(payload).select().single();
  },
  async updatePacient(id, payload) {
    return await sb.from("pacienti").update(payload).eq("id", id).select().single();
  },
  async generateCodCard() {
    var { data } = await sb.rpc("genereaza_cod_card");
    return data;
  },

  // ─── Parteneri ───
  async listParteneri() {
    var { data, error } = await sb
      .from("parteneri")
      .select("*")
      .eq("activ", true)
      .order("denumire");
    return { data, error };
  },
  async createPartener(payload) {
    return await sb.from("parteneri").insert(payload).select().single();
  },

  // ─── Tranzacții ───
  // Partenerul logat creează tranzacția — partener_id vine din contul logat
  async createTranzactie(payload) {
    return await sb.from("tranzactii").insert(payload).select().single();
  },
  // Pentru admin — vede tot
  async listTranzactiiAdmin(filters) {
    filters = filters || {};
    var query = sb.from("tranzactii")
      .select("*, pacienti(cod_card, nume, prenume, discount_pct), parteneri(cod, denumire, comision_pct)")
      .order("created_at", { ascending: false });
    if (filters.from) query = query.gte("created_at", filters.from);
    if (filters.to) query = query.lte("created_at", filters.to);
    if (filters.partener_id) query = query.eq("partener_id", filters.partener_id);
    var { data, error } = await query;
    return { data, error };
  },
  // Pentru partener — vede doar tranzacțiile lui (RLS filtrează automat)
  async listTranzactiiPartener(filters) {
    filters = filters || {};
    var query = sb.from("tranzactii")
      .select("*, pacienti(cod_card, nume, prenume, discount_pct)")
      .order("created_at", { ascending: false });
    if (filters.from) query = query.gte("created_at", filters.from);
    if (filters.to) query = query.lte("created_at", filters.to);
    var { data, error } = await query;
    return { data, error };
  },
  async getRaportPartener() {
    return await sb.from("raport_partener").select("*");
  },
  async getRaportPacient() {
    return await sb.from("raport_pacient").select("*");
  },

  // ─── Utility ───
  formatRON(n) {
    if (n == null || isNaN(n)) return "0,00 RON";
    return Number(n).toLocaleString("ro-RO", { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + " RON";
  },
  formatDate(iso) {
    if (!iso) return "—";
    var d = new Date(iso);
    return d.toLocaleDateString("ro-RO", { day: "2-digit", month: "short", year: "numeric" }) +
      " " + d.toLocaleTimeString("ro-RO", { hour: "2-digit", minute: "2-digit" });
  },
  generateTxRef() {
    var d = new Date();
    var ts = d.getFullYear().toString().slice(2) +
      String(d.getMonth() + 1).padStart(2, "0") +
      String(d.getDate()).padStart(2, "0") +
      String(d.getHours()).padStart(2, "0") +
      String(d.getMinutes()).padStart(2, "0");
    var rand = Math.random().toString(36).substring(2, 6).toUpperCase();
    return "TX-" + ts + "-" + rand;
  },
  escapeHtml(s) {
    if (s == null) return "";
    return String(s).replace(/[&<>"']/g, function(c) {
      return {"&":"&amp;","<":"&lt;",">":"&gt;","\"":"&quot;","'":"&#39;"}[c];
    });
  }
};
