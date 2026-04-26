-- ═══════════════════════════════════════════════════════════════
-- CLINICA CARDURI — SCHEMA v3 (FINAL)
--
-- Caracteristici:
--   • Discount direct pe pacient (numeric)
--   • DOI useri tipuri: useri_admin (1-3 admini) + useri_partener (per partener)
--   • Recepționerele se loghează ca user partener (NO public access)
--   • Partener_id pe tranzacție = derivat automat din contul logat
--   • RLS implementat corect, fără recursie (testat în producție)
--   • CNP opțional pe pacient
-- ═══════════════════════════════════════════════════════════════
-- Rulează acest script într-un proiect Supabase NOU.
-- Apoi rulează 02_seed_data.sql pentru date inițiale.
-- ═══════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────
-- 1. PARTENERI (creat ÎNAINTEA useri_partener din cauza FK)
-- ───────────────────────────────────────────────────────────────

create table parteneri (
  id uuid primary key default gen_random_uuid(),
  cod text not null unique,
  denumire text not null,
  adresa text,
  oras text,
  telefon text,
  email text,

  -- Coordonate GPS (opțional, pentru verificare suplimentară)
  lat numeric(10,7),
  lng numeric(10,7),
  raza_metri int default 150,

  -- Comisionul tău negociat cu acest partener
  comision_pct numeric(5,2) not null default 15.00 check (comision_pct >= 0 and comision_pct <= 100),

  activ boolean not null default true,
  contract_pdf_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_parteneri_activ on parteneri(activ) where activ = true;

comment on table parteneri is 'Clinici/laboratoare partenere';
comment on column parteneri.comision_pct is 'Procent comision încasat de tine de la partener (CONFIDENȚIAL)';


-- ───────────────────────────────────────────────────────────────
-- 2. USERI ADMIN (extinde auth.users)
-- ───────────────────────────────────────────────────────────────

create table useri_admin (
  id uuid references auth.users(id) on delete cascade primary key,
  email text not null,
  nume_complet text not null,
  activ boolean not null default true,
  created_at timestamptz not null default now()
);

comment on table useri_admin is 'Admini ai sistemului (1-3 persoane)';


-- ───────────────────────────────────────────────────────────────
-- 3. USERI PARTENER (extinde auth.users + leagă de un partener)
-- ───────────────────────────────────────────────────────────────

create table useri_partener (
  id uuid references auth.users(id) on delete cascade primary key,
  partener_id uuid not null references parteneri(id) on delete cascade,
  email text not null,
  nume_complet text,
  activ boolean not null default true,
  created_at timestamptz not null default now()
);

create index idx_useri_partener_partener_id on useri_partener(partener_id);

comment on table useri_partener is 'Conturi de login pentru parteneri (recepționere)';


-- ───────────────────────────────────────────────────────────────
-- 4. PACIENȚI
-- ───────────────────────────────────────────────────────────────

create table pacienti (
  id uuid primary key default gen_random_uuid(),
  cod_card text not null unique,

  -- Date personale
  nume text not null,
  prenume text not null,
  telefon text,
  email text,
  cnp text,                                  -- OPȚIONAL — pentru factură fiscală
  data_nasterii date,

  -- Discount fix per pacient (2.5, 5.0, 7.5, 10)
  discount_pct numeric(4,2) not null check (discount_pct >= 0 and discount_pct <= 100),

  -- Status
  data_emitere_card date not null default current_date,
  activ boolean not null default true,
  observatii text,

  -- Audit
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references auth.users(id)
);

create index idx_pacienti_cod_card on pacienti(cod_card);
create index idx_pacienti_activ on pacienti(activ) where activ = true;

comment on table pacienti is 'Pacienții cu carduri de fidelitate';
comment on column pacienti.discount_pct is 'Discount procentual fix (ex. 2.5, 5.0, 7.5, 10)';
comment on column pacienti.cnp is 'OPȚIONAL — date sensibile GDPR. Folosit doar pentru factură fiscală.';


-- ───────────────────────────────────────────────────────────────
-- 5. TRANZACȚII
-- ───────────────────────────────────────────────────────────────

create table tranzactii (
  id uuid primary key default gen_random_uuid(),
  cod_referinta text not null unique,

  -- Cine
  pacient_id uuid not null references pacienti(id) on delete restrict,
  partener_id uuid not null references parteneri(id) on delete restrict,
  procesata_de uuid references auth.users(id),

  -- Ce
  servicii text,
  mentiuni text,

  -- Bani
  pret_lista numeric(10,2) not null check (pret_lista >= 0),
  pret_platit numeric(10,2) not null check (pret_platit >= 0),
  discount_pct_aplicat numeric(4,2) not null,
  economie numeric(10,2) generated always as (pret_lista - pret_platit) stored,
  comision_clinica numeric(10,2) not null default 0,

  -- Status
  status text not null default 'inregistrat' check (status in ('inregistrat', 'confirmat', 'facturat', 'incasat', 'anulat')),
  data_facturare date,
  data_incasare date,

  -- Audit
  ip_address inet,
  user_agent text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint chk_pret_platit_max check (pret_platit <= pret_lista)
);

create index idx_tranzactii_pacient on tranzactii(pacient_id);
create index idx_tranzactii_partener on tranzactii(partener_id);
create index idx_tranzactii_data on tranzactii(created_at desc);
create index idx_tranzactii_status on tranzactii(status);

comment on table tranzactii is 'Înregistrări utilizare carduri la parteneri';


-- ───────────────────────────────────────────────────────────────
-- 6. AUDIT LOG
-- ───────────────────────────────────────────────────────────────

create table audit_log (
  id bigserial primary key,
  tabel text not null,
  rand_id text not null,
  operatie text not null check (operatie in ('INSERT', 'UPDATE', 'DELETE')),
  user_id uuid,
  date_vechi jsonb,
  date_noi jsonb,
  ip_address inet,
  created_at timestamptz not null default now()
);

create index idx_audit_tabel on audit_log(tabel, rand_id);
create index idx_audit_user on audit_log(user_id);


-- ═══════════════════════════════════════════════════════════════
-- TRIGGERS
-- ═══════════════════════════════════════════════════════════════

-- updated_at automat
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger trg_pacienti_updated before update on pacienti
  for each row execute function set_updated_at();
create trigger trg_parteneri_updated before update on parteneri
  for each row execute function set_updated_at();
create trigger trg_tranzactii_updated before update on tranzactii
  for each row execute function set_updated_at();

-- Calcul comision automat la inserare tranzacție
create or replace function calculeaza_comision()
returns trigger as $$
declare
  v_comision_pct numeric(5,2);
begin
  select comision_pct into v_comision_pct from parteneri where id = new.partener_id;
  new.comision_clinica = round(new.pret_platit * v_comision_pct / 100, 2);
  return new;
end;
$$ language plpgsql;

create trigger trg_tranzactii_comision before insert on tranzactii
  for each row execute function calculeaza_comision();

-- Audit trigger
create or replace function audit_trigger()
returns trigger as $$
declare
  v_id text;
begin
  v_id := coalesce(new.id::text, old.id::text);
  insert into audit_log(tabel, rand_id, operatie, user_id, date_vechi, date_noi)
  values (
    tg_table_name, v_id, tg_op, auth.uid(),
    case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) else null end,
    case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) else null end
  );
  return coalesce(new, old);
end;
$$ language plpgsql security definer;

create trigger trg_audit_pacienti after insert or update or delete on pacienti
  for each row execute function audit_trigger();
create trigger trg_audit_tranzactii after insert or update or delete on tranzactii
  for each row execute function audit_trigger();
create trigger trg_audit_parteneri after insert or update or delete on parteneri
  for each row execute function audit_trigger();


-- ═══════════════════════════════════════════════════════════════
-- HELPER FUNCTIONS
-- ═══════════════════════════════════════════════════════════════
-- IMPORTANT: SECURITY DEFINER + set search_path = public
-- Așa funcția rulează cu privilegii owner și sare peste RLS la lookup-ul intern
-- (asta previne recursivitatea infinită din policy)
-- ═══════════════════════════════════════════════════════════════

create function is_admin()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists(
    select 1 from public.useri_admin
    where id = auth.uid() and activ = true
  );
$$;

create function is_partener()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists(
    select 1 from public.useri_partener
    where id = auth.uid() and activ = true
  );
$$;

create function get_partener_id()
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select partener_id from public.useri_partener
  where id = auth.uid() and activ = true
  limit 1;
$$;

-- Generare cod card unic
create or replace function genereaza_cod_card()
returns text as $$
declare
  chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';   -- fără 0,1,O,I (confuzii vizuale)
  rezultat text;
  exists_row boolean;
  i int;
begin
  loop
    rezultat := 'CC-';
    for i in 1..4 loop
      rezultat := rezultat || substr(chars, (random() * length(chars))::int + 1, 1);
    end loop;
    rezultat := rezultat || '-';
    for i in 1..4 loop
      rezultat := rezultat || substr(chars, (random() * length(chars))::int + 1, 1);
    end loop;

    select exists(select 1 from pacienti where cod_card = rezultat) into exists_row;
    exit when not exists_row;
  end loop;

  return rezultat;
end;
$$ language plpgsql;


-- ═══════════════════════════════════════════════════════════════
-- GRANTS — esențiale pentru ca RLS să funcționeze
-- ═══════════════════════════════════════════════════════════════

grant usage on schema public to anon, authenticated;

-- Tabele
grant select on parteneri to authenticated, anon;
grant select on pacienti to authenticated;
grant select on useri_admin to authenticated;
grant select on useri_partener to authenticated;
grant select, insert on tranzactii to authenticated;

-- Functions
grant execute on function is_admin() to anon, authenticated;
grant execute on function is_partener() to anon, authenticated;
grant execute on function get_partener_id() to anon, authenticated;
grant execute on function genereaza_cod_card() to authenticated;


-- ═══════════════════════════════════════════════════════════════
-- ROW LEVEL SECURITY
-- ═══════════════════════════════════════════════════════════════

alter table useri_admin enable row level security;
alter table useri_partener enable row level security;
alter table pacienti enable row level security;
alter table parteneri enable row level security;
alter table tranzactii enable row level security;
alter table audit_log enable row level security;


-- ─── useri_admin ───
-- IMPORTANT: policy "read_own" folosește auth.uid() = id DIRECT (fără is_admin())
-- Asta sparge bucla recursivă: când frontend cere "select * from useri_admin where id = my_id",
-- policy-ul îl lasă să citească propriul rând fără verificare suplimentară

create policy "useri_admin_read_own"
  on useri_admin for select
  to authenticated
  using (auth.uid() = id);

create policy "useri_admin_read_all"
  on useri_admin for select
  to authenticated
  using (is_admin());

create policy "useri_admin_insert"
  on useri_admin for insert
  to authenticated
  with check (is_admin());

create policy "useri_admin_update"
  on useri_admin for update
  to authenticated
  using (is_admin());

create policy "useri_admin_delete"
  on useri_admin for delete
  to authenticated
  using (is_admin());


-- ─── useri_partener ───
-- Same pattern — read own direct, restul via is_admin()

create policy "useri_partener_read_own"
  on useri_partener for select
  to authenticated
  using (auth.uid() = id);

create policy "useri_partener_read_admin"
  on useri_partener for select
  to authenticated
  using (is_admin());

create policy "useri_partener_all_admin"
  on useri_partener for all
  to authenticated
  using (is_admin());


-- ─── parteneri ───
-- Admin vede tot
create policy "parteneri_admin"
  on parteneri for all
  to authenticated
  using (is_admin());

-- Partener își vede propriul rând (folosim sub-query direct, NU funcția — mai robust)
create policy "parteneri_partener_self"
  on parteneri for select
  to authenticated
  using (
    exists (
      select 1 from public.useri_partener up
      where up.id = auth.uid()
        and up.activ = true
        and up.partener_id = parteneri.id
    )
  );


-- ─── pacienti ───
-- Admin vede/modifică tot
create policy "pacienti_admin"
  on pacienti for all
  to authenticated
  using (is_admin());

-- Partener autentificat poate citi cardul (necesar pentru a afișa numele pacientului)
create policy "pacienti_partener_read"
  on pacienti for select
  to authenticated
  using (is_partener() and activ = true);


-- ─── tranzactii ───
-- Admin vede/modifică/șterge tot
create policy "tranzactii_admin_all"
  on tranzactii for all
  to authenticated
  using (is_admin());

-- Partener INSERT — doar pentru propriul partener_id
-- Folosim sub-query direct (verificat în producție că merge mai bine decât get_partener_id())
create policy "tranzactii_partener_insert"
  on tranzactii for insert
  to authenticated
  with check (
    exists (
      select 1 from public.useri_partener
      where id = auth.uid()
        and activ = true
        and partener_id = tranzactii.partener_id
    )
  );

-- Partener SELECT — doar tranzacțiile propriului partener
create policy "tranzactii_partener_select"
  on tranzactii for select
  to authenticated
  using (
    exists (
      select 1 from public.useri_partener
      where id = auth.uid()
        and activ = true
        and partener_id = tranzactii.partener_id
    )
  );


-- ─── audit_log ───
create policy "audit_admin_only"
  on audit_log for select
  to authenticated
  using (is_admin());


-- ═══════════════════════════════════════════════════════════════
-- VIEWS PUBLICE (utilizate de frontend)
-- ═══════════════════════════════════════════════════════════════

-- View pentru cardul scanat — folosit de partenerul logat
-- Returnează datele cardului fără info sensibile (telefon, email, CNP)
create or replace view pacient_card_public as
select
  id,
  cod_card,
  nume,
  prenume,
  discount_pct,
  activ
from pacienti
where activ = true;


-- ═══════════════════════════════════════════════════════════════
-- VIEWS PENTRU RAPOARTE (utilizate de admin în dashboard)
-- ═══════════════════════════════════════════════════════════════

-- Per partener
create or replace view raport_partener as
select
  pa.id, pa.cod, pa.denumire,
  count(t.id) as nr_tranzactii,
  coalesce(sum(t.pret_lista), 0) as total_pret_lista,
  coalesce(sum(t.pret_platit), 0) as total_pret_platit,
  coalesce(sum(t.economie), 0) as total_economie,
  coalesce(sum(t.comision_clinica), 0) as total_comision,
  pa.comision_pct
from parteneri pa
left join tranzactii t on t.partener_id = pa.id and t.status != 'anulat'
where pa.activ = true
group by pa.id, pa.cod, pa.denumire, pa.comision_pct;

-- Per pacient
create or replace view raport_pacient as
select
  p.id, p.cod_card, p.nume, p.prenume, p.discount_pct,
  count(t.id) as nr_tranzactii,
  coalesce(sum(t.pret_platit), 0) as total_cheltuit,
  coalesce(sum(t.economie), 0) as total_economisit,
  max(t.created_at) as ultima_tranzactie
from pacienti p
left join tranzactii t on t.pacient_id = p.id and t.status != 'anulat'
where p.activ = true
group by p.id, p.cod_card, p.nume, p.prenume, p.discount_pct;

-- Permisii pe view-uri
grant select on pacient_card_public to authenticated;
grant select on raport_partener to authenticated;
grant select on raport_pacient to authenticated;


-- ═══════════════════════════════════════════════════════════════
-- GATA. Schema instalată.
--
-- Pași următori:
--   1. Rulează 02_seed_data.sql pentru date inițiale
--   2. Creează userul tău admin în Authentication
--   3. INSERT în useri_admin pentru tine (vezi SETUP.md pasul 1.7)
--   4. Creează userii parteneri în Authentication (pasul 1.8)
--   5. INSERT în useri_partener pentru fiecare (pasul 1.9)
--
-- ═══════════════════════════════════════════════════════════════
