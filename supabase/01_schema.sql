-- ═══════════════════════════════════════════════════════════════
-- CLINICA CARDURI — SCHEMA v3
--
-- Caracteristici:
--   • Discount direct pe pacient (numeric)
--   • DOUĂ tipuri de useri:
--     - useri_admin (1-3 admini, văd tot)
--     - useri_partener (câte unul per partener, văd doar datele lor)
--   • Recepționera (la partener) SE LOGHEAZĂ cu contul partenerului
--   • Partener_id pe tranzacție = derivat din contul logat
--   • CNP opțional pe pacient
-- ═══════════════════════════════════════════════════════════════

-- ───────────────────────────────────────────────────────────────
-- 1. PARTENERI (creat ÎNAINTE de useri_partener din cauza FK)
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

  -- Comision negociat de tine cu acest partener (procent)
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
  cnp text,                              -- OPȚIONAL — pentru factură fiscală
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

  -- Cine a procesat (recepționera logată ca user partener)
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
-- 6. TRIGGERS: updated_at automat
-- ───────────────────────────────────────────────────────────────

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

-- ───────────────────────────────────────────────────────────────
-- 7. TRIGGER: calcul comision automat
-- ───────────────────────────────────────────────────────────────

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

-- ───────────────────────────────────────────────────────────────
-- 8. AUDIT LOG
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

-- ───────────────────────────────────────────────────────────────
-- 9. ROW LEVEL SECURITY (RLS)
-- ───────────────────────────────────────────────────────────────

alter table useri_admin enable row level security;
alter table useri_partener enable row level security;
alter table pacienti enable row level security;
alter table parteneri enable row level security;
alter table tranzactii enable row level security;
alter table audit_log enable row level security;

-- ─── Helpers ───
create or replace function is_admin()
returns boolean as $$
  select exists(
    select 1 from useri_admin
    where id = auth.uid() and activ = true
  );
$$ language sql security definer;

create or replace function is_partener()
returns boolean as $$
  select exists(
    select 1 from useri_partener
    where id = auth.uid() and activ = true
  );
$$ language sql security definer;

create or replace function get_partener_id()
returns uuid as $$
  select partener_id from useri_partener
  where id = auth.uid() and activ = true
  limit 1;
$$ language sql security definer;

-- ─── useri_admin ───
create policy "useri_admin_self" on useri_admin for select
  using (auth.uid() = id or is_admin());
create policy "useri_admin_modify" on useri_admin for all
  using (is_admin());

-- ─── useri_partener ───
create policy "useri_partener_self" on useri_partener for select
  using (auth.uid() = id or is_admin());
create policy "useri_partener_admin_all" on useri_partener for all
  using (is_admin());

-- ─── pacienti ───
-- Admin vede/modifică tot
create policy "pacienti_admin" on pacienti for all
  using (is_admin());
-- Partenerii pot citi DOAR view-ul public (fără date sensibile) — fără policy aici
-- Pacientul tabel direct = doar admin

-- ─── parteneri ───
-- Admin vede/modifică tot (inclusiv comision_pct)
create policy "parteneri_admin" on parteneri for all
  using (is_admin());
-- Partener vede doar propriul rând (fără comision)
create policy "parteneri_self_select" on parteneri for select
  using (is_partener() and id = get_partener_id());

-- ─── tranzactii ───
-- Admin vede/modifică/șterge tot
create policy "tranzactii_admin_all" on tranzactii for all
  using (is_admin());
-- Partener INSERT — doar pentru propriul partener_id
create policy "tranzactii_partener_insert" on tranzactii for insert
  with check (
    is_partener()
    and partener_id = get_partener_id()
    and exists(select 1 from pacienti where id = pacient_id and activ = true)
  );
-- Partener SELECT — doar tranzacțiile propriului partener
create policy "tranzactii_partener_select" on tranzactii for select
  using (
    is_partener() and partener_id = get_partener_id()
  );

-- ─── audit_log ───
create policy "audit_admin_only" on audit_log for select
  using (is_admin());

-- ───────────────────────────────────────────────────────────────
-- 10. VIEW PUBLIC pentru cardul scanat
-- ───────────────────────────────────────────────────────────────
-- Folosit doar dacă userul e LOGAT ca partener.
-- Returnează datele cardului fără info sensibile (tel, email, CNP).

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

-- ───────────────────────────────────────────────────────────────
-- 11. VIEWS pentru rapoarte
-- ───────────────────────────────────────────────────────────────

-- Per partener (admin only)
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

-- Per pacient (admin only)
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

-- Permisii
grant select on pacient_card_public to authenticated;

-- ───────────────────────────────────────────────────────────────
-- 12. FUNCȚIE: generare cod card unic
-- ───────────────────────────────────────────────────────────────

create or replace function genereaza_cod_card()
returns text as $$
declare
  chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
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
-- GATA. Rulează tot scriptul în Supabase SQL Editor.
-- Apoi rulează 02_seed_data.sql pentru date inițiale.
-- ═══════════════════════════════════════════════════════════════
