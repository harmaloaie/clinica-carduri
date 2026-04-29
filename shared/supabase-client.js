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
  // Magic link pentru pacienți — trimite link pe email
  async sendMagicLink(email, redirectTo) {
    return await sb.auth.signInWithOtp({
      email: email,
      options: {
        emailRedirectTo: redirectTo || window.location.origin + window.location.pathname.replace(/[^/]+$/, "pacient.html"),
        shouldCreateUser: true  // creează userul dacă nu există încă
      }
    });
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
  async getReceptionerProfile() {
    var user = await this.getCurrentUser();
    if (!user) return null;
    var { data } = await sb
      .from("useri_receptioner")
      .select("*, parteneri(id, cod, denumire, oras)")
      .eq("id", user.id)
      .maybeSingle();
    return data;
  },
  // Profil pacient — caută prin email
  async getPacientProfile() {
    var user = await this.getCurrentUser();
    if (!user || !user.email) return null;
    var { data } = await sb
      .from("pacienti")
      .select("*, niveluri_discount(denumire, culoare)")
      .ilike("email", user.email)
      .eq("activ", true)
      .maybeSingle();
    return data;
  },
  // Returnează tipul userului ('admin', 'partener', 'receptioner', 'pacient', null)
  async getUserType() {
    var user = await this.getCurrentUser();
    if (!user) return null;
    var admin = await this.getAdminProfile();
    if (admin && admin.activ) return "admin";
    var partener = await this.getPartenerProfile();
    if (partener && partener.activ) return "partener";
    var recept = await this.getReceptionerProfile();
    if (recept && recept.activ) return "receptioner";
    var pacient = await this.getPacientProfile();
    if (pacient) return "pacient";
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
      alert("Nu ai permisiuni de admin partener.");
      await this.signOut();
      window.location.href = "login.html?type=partener";
      return null;
    }
    return profile;
  },

  async requireReceptioner() {
    var user = await this.getCurrentUser();
    if (!user) {
      var current = encodeURIComponent(window.location.pathname + window.location.search);
      window.location.href = "login.html?type=receptioner&next=" + current;
      return null;
    }
    var profile = await this.getReceptionerProfile();
    if (!profile || !profile.activ) {
      alert("Nu ai permisiuni de recepționer.");
      await this.signOut();
      window.location.href = "login.html?type=receptioner";
      return null;
    }
    return profile;
  },

  async requirePacient() {
    var user = await this.getCurrentUser();
    if (!user) {
      window.location.href = "login.html?type=pacient";
      return null;
    }
    var profile = await this.getPacientProfile();
    if (!profile) {
      alert("Nu există un cont de pacient asociat acestui email. Cere admin-ului să verifice email-ul tău în profil.");
      await this.signOut();
      window.location.href = "login.html?type=pacient";
      return null;
    }
    return profile;
  },

  // ─── Oferte ───
  async listOferteActive() {
    var { data, error } = await sb
      .from("oferte")
      .select("*")
      .eq("activ", true)
      .order("created_at", { ascending: false });
    return { data, error };
  },
  async listOferteAdmin() {
    var { data, error } = await sb
      .from("oferte")
      .select("*")
      .order("created_at", { ascending: false });
    return { data, error };
  },
  async createOferta(payload) {
    return await sb.from("oferte").insert(payload).select().single();
  },
  async updateOferta(id, payload) {
    return await sb.from("oferte").update(payload).eq("id", id).select().single();
  },
  async deleteOferta(id) {
    return await sb.from("oferte").delete().eq("id", id);
  },

  // ─── Tranzacții pacient ───
  async listTranzactiiPacient() {
    var { data, error } = await sb
      .from("tranzactii")
      .select("*, parteneri(cod, denumire, oras)")
      .order("created_at", { ascending: false });
    return { data, error };
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
    // Admin vede TOȚI pacienții, activi și dezactivați
    var { data, error } = await sb
      .from("pacienti")
      .select("*")
      .order("activ", { ascending: false })  // activii primii
      .order("created_at", { ascending: false });
    return { data, error };
  },
  async createPacient(payload) {
    return await sb.from("pacienti").insert(payload).select().single();
  },
  async updatePacient(id, payload) {
    return await sb.from("pacienti").update(payload).eq("id", id).select().single();
  },
  async togglePacientActiv(id, activ) {
    return await sb.from("pacienti").update({ activ: activ }).eq("id", id).select().single();
  },
  async generateCodCard() {
    var { data } = await sb.rpc("genereaza_cod_card");
    return data;
  },

  // ─── Niveluri discount ───
  async listNiveluri() {
    var { data, error } = await sb
      .from("niveluri_discount")
      .select("*")
      .order("ordine", { ascending: true });
    return { data, error };
  },
  async listNiveluriActive() {
    var { data, error } = await sb
      .from("niveluri_discount")
      .select("*")
      .eq("activ", true)
      .order("ordine", { ascending: true });
    return { data, error };
  },
  async createNivel(payload) {
    return await sb.from("niveluri_discount").insert(payload).select().single();
  },
  async updateNivel(id, payload) {
    return await sb.from("niveluri_discount").update(payload).eq("id", id).select().single();
  },
  async deleteNivel(id) {
    return await sb.from("niveluri_discount").delete().eq("id", id);
  },

  // ─── Parteneri ───
  async listParteneri() {
    var { data, error } = await sb
      .from("parteneri")
      .select("*")
      .order("activ", { ascending: false })
      .order("denumire", { ascending: true });
    return { data, error };
  },
  async listParteneriActivi() {
    var { data, error } = await sb
      .from("parteneri")
      .select("id, cod, denumire, oras")
      .eq("activ", true)
      .order("denumire", { ascending: true });
    return { data, error };
  },
  async createPartener(payload) {
    return await sb.from("parteneri").insert(payload).select().single();
  },
  async updatePartener(id, payload) {
    return await sb.from("parteneri").update(payload).eq("id", id).select().single();
  },
  async togglePartenerActiv(id, activ) {
    return await sb.from("parteneri").update({ activ: activ }).eq("id", id).select().single();
  },

  // ─── Useri parteneri (admin partener accounts) ───
  async listUseriPartener() {
    var { data, error } = await sb
      .from("useri_partener")
      .select("*, parteneri(id, cod, denumire)")
      .order("created_at", { ascending: false });
    return { data, error };
  },

  // Helper: salvează sesiunea curentă, face signUp, apoi restaurează sesiunea
  async _createAuthUserAndRestore(email, password, metadata) {
    // 1. Salvează sesiunea curentă (admin)
    var { data: sessionData } = await sb.auth.getSession();
    var currentSession = sessionData ? sessionData.session : null;
    if (!currentSession) {
      return { error: { message: 'Nu există sesiune activă. Loghează-te din nou.' } };
    }

    // 2. signUp pentru noul user (asta deconectează admin)
    var { data: signUpData, error: signUpError } = await sb.auth.signUp({
      email: email,
      password: password,
      options: {
        data: metadata || {}
      }
    });

    // 3. Restaurează sesiunea admin imediat — indiferent dacă signUp a mers sau nu
    var { error: restoreError } = await sb.auth.setSession({
      access_token: currentSession.access_token,
      refresh_token: currentSession.refresh_token
    });

    if (restoreError) {
      console.error("Session restore failed:", restoreError);
      // Nu e fatal — admin va trebui să se logheze din nou
    }

    if (signUpError) return { error: signUpError };
    if (!signUpData || !signUpData.user) return { error: { message: 'Userul nu a fost creat.' } };

    return { data: signUpData };
  },

  async createUserPartener(email, password, partener_id, nume_complet) {
    // Pas 1 — creează auth user păstrând sesiunea admin
    var authResult = await this._createAuthUserAndRestore(email, password, {
      nume_complet: nume_complet, role: 'partener'
    });
    if (authResult.error) return { error: authResult.error };

    var newUserId = authResult.data.user.id;

    // Pas 2 — bagă rândul în useri_partener
    var { data: userData, error: userError } = await sb
      .from("useri_partener")
      .insert({
        id: newUserId,
        partener_id: partener_id,
        email: email,
        nume_complet: nume_complet || email,
        activ: true
      })
      .select()
      .single();

    if (userError) {
      return { error: userError, partial: { auth_user_id: newUserId } };
    }

    return { data: userData };
  },
  async toggleUserPartenerActiv(id, activ) {
    return await sb.from("useri_partener").update({ activ: activ }).eq("id", id).select().single();
  },

  // ─── Useri recepționere ───
  async listUseriReceptioner() {
    var { data, error } = await sb
      .from("useri_receptioner")
      .select("*, parteneri(id, cod, denumire)")
      .order("created_at", { ascending: false });
    return { data, error };
  },
  async createUserReceptioner(email, password, partener_id, nume_complet) {
    var authResult = await this._createAuthUserAndRestore(email, password, {
      nume_complet: nume_complet, role: 'receptioner'
    });
    if (authResult.error) return { error: authResult.error };

    var newUserId = authResult.data.user.id;

    var { data: userData, error: userError } = await sb
      .from("useri_receptioner")
      .insert({
        id: newUserId,
        partener_id: partener_id,
        email: email,
        nume_complet: nume_complet || email,
        activ: true
      })
      .select()
      .single();

    if (userError) {
      return { error: userError, partial: { auth_user_id: newUserId } };
    }

    return { data: userData };
  },
  async toggleUserReceptionerActiv(id, activ) {
    return await sb.from("useri_receptioner").update({ activ: activ }).eq("id", id).select().single();
  },
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
