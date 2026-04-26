-- ═══════════════════════════════════════════════════════════════
-- DATE INIȚIALE — PARTENERI ȘI PACIENȚI DEMO
-- Rulează DUPĂ 01_schema.sql
-- ═══════════════════════════════════════════════════════════════

do $$
declare
  v_inserare_pitesti boolean := false;
  v_inserare_tenerife boolean := true;
  v_inserare_pacienti_demo boolean := true;
  v_curata_parteneri boolean := false;
begin

  if v_curata_parteneri then
    delete from parteneri;
  end if;

  -- ═══════════════════════════════════════════════════════════
  -- PARTENERI PRODUCȚIE — Pitești, România
  -- ═══════════════════════════════════════════════════════════
  if v_inserare_pitesti then
    insert into parteneri (cod, denumire, adresa, oras, lat, lng, raza_metri, comision_pct) values
      ('BINISAN_CENTRAL',  'Binisan — Sediu Central',  'Str. Exemplu 1', 'Pitești', 44.8565, 24.8698, 150, 15.00),
      ('DERZELIUS_PIT',    'Derzelius — Pitești',      'Str. Exemplu 2', 'Pitești', 44.8601, 24.8735, 150, 15.00),
      ('MEDILAB_CENTRU',   'Medilab — Pitești Centru', 'Str. Exemplu 3', 'Pitești', 44.8558, 24.8680, 150, 12.00),
      ('POLIANA_TRIVALE',  'Poliana — Trivale',        'Str. Exemplu 4', 'Pitești', 44.8525, 24.8494, 150, 15.00),
      ('SOLOMED_GAVANA',   'Solomed — Găvana',         'Str. Exemplu 5', 'Pitești', 44.8642, 24.8825, 150, 15.00),
      ('SANTE_PIT',        'Clinica Sante — Pitești',  'Str. Exemplu 6', 'Pitești', 44.8587, 24.8712, 150, 10.00)
    on conflict (cod) do nothing;
    raise notice 'Inserați 6 parteneri Pitești.';
  end if;

  -- ═══════════════════════════════════════════════════════════
  -- PARTENERI TEST — pentru testare
  -- ═══════════════════════════════════════════════════════════
  if v_inserare_tenerife then
    insert into parteneri (cod, denumire, adresa, oras, lat, lng, raza_metri, comision_pct) values
      ('BINISAN_TEST',
       'Binisan (TEST)',
       'Calle Valleseco s/n',
       'Santa Cruz de Tenerife',
       28.4800, -16.2470, 1500, 15.00),

      ('SANTE_TEST',
       'Sante (TEST)',
       'Plaza de España',
       'Santa Cruz de Tenerife',
       28.4682, -16.2546, 8000, 10.00),

      ('MEDILAB_TEST',
       'Medilab (TEST)',
       'Calle Heraclio Sánchez',
       'San Cristóbal de La Laguna',
       28.4853, -16.3201, 2000, 12.00),

      ('DERZELIUS_TEST',
       'Derzelius (TEST)',
       'Test Address',
       'Test City',
       28.4900, -16.2500, 1500, 15.00),

      ('POLIANA_TEST',
       'Poliana (TEST)',
       'Test Address 2',
       'Test City',
       28.4750, -16.2600, 1500, 15.00),

      ('SOLOMED_TEST',
       'Solomed (TEST)',
       'Test Address 3',
       'Test City',
       28.4850, -16.2400, 1500, 15.00)
    on conflict (cod) do nothing;
    raise notice 'Inserați 6 parteneri test.';
  end if;

  -- ═══════════════════════════════════════════════════════════
  -- PACIENȚI DEMO
  -- ═══════════════════════════════════════════════════════════
  if v_inserare_pacienti_demo then
    insert into pacienti (cod_card, nume, prenume, telefon, discount_pct) values
      ('CC-A7K9-3M2P', 'Popescu',     'Maria',   '0721111111',  7.5),
      ('CC-B2X4-7N1Q', 'Ionescu',     'Ion',     '0722222222',  5.0),
      ('CC-D5F8-9L2W', 'Dumitrescu',  'Ana',     '0723333333', 10.0),
      ('CC-E1R3-6T4Y', 'Marinescu',   'George',  '0724444444',  2.5),
      ('CC-H9M2-1P8Z', 'Stoica',      'Elena',   '0725555555',  7.5)
    on conflict (cod_card) do nothing;
    raise notice 'Inserați 5 pacienți demo (discount-uri: 2.5, 5, 7.5, 10).';
  end if;

  raise notice '──── Seed data finalizat ────';
end $$;

-- ═══════════════════════════════════════════════════════════════
-- CONTURI DE TEST PENTRU PARTENERI
-- ═══════════════════════════════════════════════════════════════
--
-- ACEST SCRIPT NU CREEAZĂ CONTURILE AUTOMAT (Supabase nu permite).
--
-- Pentru fiecare partener, urmezi acești pași în Supabase Dashboard:
--
-- 1. Mergi la Authentication → Users → Add user → Create new user
-- 2. Completezi:
--      Email: binisan@test.com
--      Password: Test1234
--      ☑ Auto Confirm User
-- 3. Repeți pentru fiecare partener (vezi tabel mai jos)
-- 4. RULEZI scriptul SQL de mai jos pentru a lega userul de partener
--
-- ═══════════════════════════════════════════════════════════════
-- CREDENȚIALE TEST PENTRU PARTENERI
-- ═══════════════════════════════════════════════════════════════
--
--   ┌─────────────────────────┬───────────┬────────────────────┐
--   │ Email                   │ Parolă    │ Partener           │
--   ├─────────────────────────┼───────────┼────────────────────┤
--   │ binisan@test.com        │ Test1234  │ BINISAN_TEST       │
--   │ sante@test.com          │ Test1234  │ SANTE_TEST         │
--   │ medilab@test.com        │ Test1234  │ MEDILAB_TEST       │
--   │ derzelius@test.com      │ Test1234  │ DERZELIUS_TEST     │
--   │ poliana@test.com        │ Test1234  │ POLIANA_TEST       │
--   │ solomed@test.com        │ Test1234  │ SOLOMED_TEST       │
--   └─────────────────────────┴───────────┴────────────────────┘
--
-- DUPĂ ce ai creat userii în Authentication, RULEAZĂ scriptul de mai jos:
-- ═══════════════════════════════════════════════════════════════

-- ATENȚIE: Decomentează (șterge `--` din față) doar liniile pentru userii pe care i-ai creat efectiv în Authentication.

/*
-- BINISAN
insert into useri_partener (id, partener_id, email, nume_complet, activ)
select au.id, p.id, au.email, 'Recepție Binisan', true
from auth.users au, parteneri p
where au.email = 'binisan@test.com' and p.cod = 'BINISAN_TEST'
on conflict (id) do nothing;

-- SANTE
insert into useri_partener (id, partener_id, email, nume_complet, activ)
select au.id, p.id, au.email, 'Recepție Sante', true
from auth.users au, parteneri p
where au.email = 'sante@test.com' and p.cod = 'SANTE_TEST'
on conflict (id) do nothing;

-- MEDILAB
insert into useri_partener (id, partener_id, email, nume_complet, activ)
select au.id, p.id, au.email, 'Recepție Medilab', true
from auth.users au, parteneri p
where au.email = 'medilab@test.com' and p.cod = 'MEDILAB_TEST'
on conflict (id) do nothing;

-- DERZELIUS
insert into useri_partener (id, partener_id, email, nume_complet, activ)
select au.id, p.id, au.email, 'Recepție Derzelius', true
from auth.users au, parteneri p
where au.email = 'derzelius@test.com' and p.cod = 'DERZELIUS_TEST'
on conflict (id) do nothing;

-- POLIANA
insert into useri_partener (id, partener_id, email, nume_complet, activ)
select au.id, p.id, au.email, 'Recepție Poliana', true
from auth.users au, parteneri p
where au.email = 'poliana@test.com' and p.cod = 'POLIANA_TEST'
on conflict (id) do nothing;

-- SOLOMED
insert into useri_partener (id, partener_id, email, nume_complet, activ)
select au.id, p.id, au.email, 'Recepție Solomed', true
from auth.users au, parteneri p
where au.email = 'solomed@test.com' and p.cod = 'SOLOMED_TEST'
on conflict (id) do nothing;
*/

-- ═══════════════════════════════════════════════════════════════
-- VERIFICARE
-- ═══════════════════════════════════════════════════════════════

-- Vezi parteneri:
-- select cod, denumire, oras, comision_pct from parteneri order by oras, denumire;

-- Vezi pacienți:
-- select cod_card, nume, prenume, discount_pct from pacienti order by discount_pct desc;

-- Vezi conturile partenerilor configurate:
-- select up.email, p.denumire, up.activ
-- from useri_partener up
-- join parteneri p on p.id = up.partener_id;
