# Ghid complet de setup — Clinica Carduri Fidelitate

**Timp total:** ~75 minute, pe pași clari.
**Necesar:** cont GitHub, cont Supabase. Nimic altceva.

---

## OVERVIEW — Cum funcționează

```
┌────────────────────────────────────────────────────────────────┐
│  ADMIN (tu)                                                    │
│  → login admin → dashboard cu rapoarte + admin pacienți        │
│  → generezi QR-uri pentru pacienți                             │
└────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│  PARTENER (Binisan, Sante, etc.)                               │
│  → login partener → vede tranzacțiile lui                      │
│  → când scanează QR pacient → completează tranzacția           │
└────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│  PACIENT (Maria, Ion, etc.)                                    │
│  → primește card cu QR de la tine                              │
│  → recepționera la partener scanează → completează             │
└────────────────────────────────────────────────────────────────┘
```

---

# 🗄 PARTEA 1 — Supabase (~30 min)

## 1.1 Creezi proiectul

1. [supabase.com](https://supabase.com) → **Start your project**
2. Login cu **GitHub**
3. **New Project**:
   - **Name**: `clinica-carduri`
   - **Database Password**: parolă puternică, **salvează-o**
   - **Region**: **Central EU (Frankfurt)** — pentru GDPR
   - **Pricing Plan**: **Free**
4. **Create new project** — așteaptă ~2 min

## 1.2 Rulezi schema bazei de date

1. Meniul stâng → **SQL Editor**
2. **+ New query**
3. Deschizi `supabase/01_schema.sql` din ZIP, copiezi tot
4. Lipești în SQL Editor → **Run** (Ctrl+Enter)
5. Vezi: "Success. No rows returned"

**Verificare:** Table Editor → ar trebui să vezi 6 tabele:
- `useri_admin`
- `useri_partener`
- `pacienti`
- `parteneri`
- `tranzactii`
- `audit_log`

## 1.3 Rulezi datele inițiale

1. **+ New query**
2. Lipești conținutul din `supabase/02_seed_data.sql`
3. **Run**

Mesaje de succes:
- `NOTICE: Inserați 6 parteneri test`
- `NOTICE: Inserați 5 pacienți demo`

## 1.4 Iei credențialele

1. ⚙️ **Project Settings** (jos stânga) → **API**
2. Copiază:
   - **Project URL** (ex. `https://abcdefghij.supabase.co`)
   - **anon public** key (jwt lung)
3. Le ții la îndemână pentru pasul 2.4

## 1.5 Configurezi Authentication

1. **Authentication** → **Sign In / Providers** → Email e activat
2. **Configuration** → **"Confirm email"** → **dezactivează**

## 1.6 Creezi contul tău de ADMIN

1. **Authentication** → **Users** → **Add user** → **Create new user**
2. **Email**: emailul tău real
3. **Password**: o parolă pe care o ții minte
4. ☑ **Auto Confirm User**
5. **Create user**

## 1.7 Te setezi admin în baza de date

În SQL Editor → New query:
```sql
insert into useri_admin (id, email, nume_complet, activ)
select id, email, 'Numele Tău', true
from auth.users
where email = 'EMAILUL_TĂU@example.com';
```
Înlocuiește emailul cu cel real → **Run** → "1 row affected".

## 1.8 ⭐ Creezi cele 6 conturi de PARTENER (TEST)

**Repetă pașii pentru fiecare partener:**

1. **Authentication** → **Users** → **Add user** → **Create new user**
2. Completezi:

| Email | Parolă | ☑ Auto Confirm |
|---|---|---|
| `binisan@test.com` | `Test1234` | bifat |
| `sante@test.com` | `Test1234` | bifat |
| `medilab@test.com` | `Test1234` | bifat |
| `derzelius@test.com` | `Test1234` | bifat |
| `poliana@test.com` | `Test1234` | bifat |
| `solomed@test.com` | `Test1234` | bifat |

3. **Create user** după fiecare

✅ După aceasta ar trebui să vezi 7 useri în lista (1 admin + 6 parteneri).

## 1.9 ⭐ Legi conturile de partener cu partenerii din DB

În `supabase/02_seed_data.sql` ai un bloc cu instrucțiuni la final, înconjurat de `/* ... */`. Trebuie să-l rulezi separat după ce ai creat userii.

În SQL Editor → New query → lipește **EXACT acest cod** (atenție, fără `/*` și `*/`):

```sql
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
```

**Run** → ar trebui să fie "6 rows affected".

**Verificare:**
```sql
select up.email, p.denumire, up.activ
from useri_partener up
join parteneri p on p.id = up.partener_id;
```
Ar trebui să vezi 6 linii.

✅ **Backend-ul Supabase e gata complet!**

---

# 🐙 PARTEA 2 — GitHub (~20 min)

## 2.1 Creezi repo-ul

1. [github.com](https://github.com) → **+** → **New repository**
2. **Name**: `clinica-carduri`
3. **Public**
4. **NU bifa** "Add README"
5. **Create repository**

## 2.2 Upload fișiere prin browser

1. Pe pagina repo gol → click **"uploading an existing file"**
2. Drag & drop **conținutul** folderului `clinica-carduri` (NU folderul în sine):
   - `README.md`, `index.html`, `card.html`, `login.html`
   - `dashboard.html`, `admin.html`, `partener.html`
   - folderele `shared/`, `supabase/`, `docs/`
3. Commit message: `feat: structură inițială`
4. **Commit changes**

## 2.3 Creezi `.gitignore` direct pe GitHub

1. **Add file** → **Create new file**
2. Name: **`.gitignore`** (cu punct la început)
3. Conținut:
```
.DS_Store
Thumbs.db
.vscode/
.idea/
*.swp
.env
*.log
node_modules/
*.bak
```
4. Commit message: `add gitignore` → **Commit new file**

## 2.4 Editezi `shared/config.js` cu credențialele

1. Click pe folderul `shared/` → `config.js`
2. Click pe creion (✏️ Edit)
3. Înlocuiește placeholder-urile:
```javascript
window.CLINICA_CONFIG = {
  SUPABASE_URL: "https://abcdefghij.supabase.co",   // ← din 1.4
  SUPABASE_ANON_KEY: "eyJhbGc...",                   // ← din 1.4
  CLINICA_NUME: "Clinica Mea"
};
```
4. Commit message: `config: credențiale Supabase` → **Commit changes**

## 2.5 Activezi GitHub Pages

1. Repo → **Settings** → **Pages**
2. Source: `Deploy from a branch`
3. Branch: `main`, folder: `/ (root)` → **Save**
4. Așteaptă 1-2 min → URL: `https://USERNAME.github.io/clinica-carduri/`

---

# 🧪 PARTEA 3 — Test end-to-end (~25 min)

## 3.1 Test landing page

Deschide `https://USERNAME.github.io/clinica-carduri/`

Vezi pagina principală cu **2 carduri**:
- 🔴 **Login admin** (cu border roșu sus)
- 🟡 **Login partener** (cu border auriu sus)

## 3.2 Test login ADMIN

1. Click pe **Login admin**
2. Email: cel din 1.6
3. Parolă: cea setată
4. **Intră în cont →**
5. Te duce la `/dashboard.html`

✅ Dacă vezi dashboard-ul → admin login OK.

## 3.3 Test admin → adaugă pacient

1. În topbar, click pe **Admin**
2. Vezi 5 pacienți demo
3. Click **+ Adaugă pacient**
4. Completezi un test rapid:
   - Prenume: `Test`
   - Nume: `Pacient`
   - Discount: `7.5%`
5. **Salvează**
6. Apare modalul cu 2 secțiuni:
   - URL pentru qr.io (cu Copiază)
   - QR generat instant (Download / Tipărește)

✅ Admin funcționează.

## 3.4 Test login PARTENER (în alt browser/incognito)

⚠️ **Important:** trebuie alt browser sau incognito pentru a nu fi confundat cu sesiunea de admin!

1. Browser nou / incognito → deschide URL-ul GitHub Pages
2. Click pe **Login partener**
3. Email: `binisan@test.com`
4. Parolă: `Test1234`
5. **Intră în cont →**
6. Te duce la `/partener.html`

Vezi:
- Topbar cu border auriu, scrie "Partener: Binisan (TEST)"
- Welcome card mare cu "Bun venit, Binisan (TEST)"
- KPI-uri (toate 0 deocamdată)
- Tabelă goală cu mesaj "Fără tranzacții"

## 3.5 Test scanare card (ca recepționera la Binisan)

1. Încă logat ca Binisan, copiază în URL bar:
   ```
   https://USERNAME.github.io/clinica-carduri/card.html?id=CC-A7K9-3M2P
   ```
   (Maria Popescu, 7.5% discount)

2. Vezi:
   - Topbar: "Logat ca: Binisan (TEST)"
   - Card-ul mare negru cu Maria Popescu, 7.5%
   - Form cu badge auriu: "Tranzacția va fi înregistrată la: Binisan (TEST)"

3. Completezi:
   - Servicii: `Hemoleucogramă completă`
   - Sumă inițială: `100`
   - Sumă plătită cu discount: `92.50`
4. Vezi automat: "Economie: 7,50 RON · 7.5% reducere aplicată"
5. Click **Înregistrează tranzacția →**

✅ Card verde mare: "✓ Tranzacție înregistrată"

## 3.6 Verificare în partener.html

1. Click "Vezi tranzacții" (sau navighează la `partener.html`)
2. KPI-uri actualizate:
   - Tranzacții: 1
   - Total încasat: 92,50 RON
   - Discount aplicat: 7,50 RON
3. Tabelă cu 1 rând: Maria Popescu

✅ Partenerul vede doar tranzacțiile **lui** (RLS).

## 3.7 Test izolare parteneri

1. Logout (buton Logout din topbar)
2. Login ca **alt partener**: `sante@test.com / Test1234`
3. Vezi pagina partenerului Sante
4. Tabela e goală — pentru că Sante nu are tranzacții, doar Binisan are.

✅ Izolarea între parteneri funcționează.

## 3.8 Test admin vede tot

1. Browser-ul cu admin (sesiunea inițială)
2. Reîmprospătează `/dashboard.html`
3. Vezi tranzacția Binisan-Maria în lista globală
4. Comision auto-calculat (15% din 92.50 = 13.88 RON)
5. **⬇ Export CSV** funcționează

🎉 **Sistemul e complet funcțional!**

---

# 📋 CONTURI DE TEST — SUMARY

| Cont | Email | Parolă | Acces |
|---|---|---|---|
| **Tu (Admin)** | emailul tău | parola ta | dashboard, admin, gestionare |
| **Binisan** | `binisan@test.com` | `Test1234` | partener.html, card.html |
| **Sante** | `sante@test.com` | `Test1234` | partener.html, card.html |
| **Medilab** | `medilab@test.com` | `Test1234` | partener.html, card.html |
| **Derzelius** | `derzelius@test.com` | `Test1234` | partener.html, card.html |
| **Poliana** | `poliana@test.com` | `Test1234` | partener.html, card.html |
| **Solomed** | `solomed@test.com` | `Test1234` | partener.html, card.html |

---

# 🆘 TROUBLESHOOTING

| Problemă | Soluție |
|---|---|
| Pagină 404 după Pages | Așteaptă 5 min, hard refresh (`Ctrl+Shift+R`) |
| Login admin nu merge | Verifică în Authentication → Users + în `useri_admin` (1.7) |
| Login partener nu merge | Verifică în `useri_partener` (1.9) |
| "Acest cont e de tip X. Folosește login-ul Y" | Contul e configurat ca alt tip — folosește login-ul corect |
| `card.html` cere login | Da, e normal acum — partenerul TREBUIE să fie logat |
| "Card neidentificat" | Pacientul nu există / nu e activ în baza de date |
| Partenerul vede 0 tranzacții deși există | RLS: vede doar tranzacțiile propriului `partener_id` — corect |

---

# 🚀 URMĂTORII PAȘI

## Activare parteneri reali (Pitești)

În `02_seed_data.sql`:
```sql
v_inserare_pitesti boolean := true;
v_inserare_tenerife boolean := false;
```
Re-rulezi scriptul. Apoi:
1. Creezi conturi reale în Authentication
2. Modifici INSERT-urile în `useri_partener` cu emailurile reale și codurile reale (BINISAN_CENTRAL în loc de BINISAN_TEST)

## Schimbare parolă partener

Authentication → Users → click pe userul partener → "Send password recovery" sau "Send magic link"

## Adăugare admin nou (max 3 total)

Repeți 1.6 + 1.7 cu emailul nou.

## Reset parolă admin

Authentication → Users → "Send password recovery" → primești email cu link de reset.

---

Mult succes! Începe cu Partea 1 și spune-mi când ești la pasul 1.8 — acolo e magia.
