# Clinica Carduri Fidelitate

Sistem intern pentru gestionarea cardurilor QR de fidelitate ale pacienților. Permite înregistrarea tranzacțiilor la parteneri (laboratoare/clinici partenere) și calculul automat al comisioanelor.

## Structura proiectului

```
clinica-carduri/
├── index.html           ← Landing page (staff entry point)
├── card.html            ← Pagina scanată din QR-ul pacientului
├── login.html           ← Autentificare staff (Supabase Auth)
├── dashboard.html       ← Rapoarte tranzacții
├── admin.html           ← Gestionare pacienți + generare QR
├── shared/
│   ├── config.js        ← Editezi cu credențialele Supabase
│   ├── styles.css       ← Stiluri partajate
│   └── supabase-client.js
├── supabase/
│   ├── 01_schema.sql    ← Schema bazei de date
│   └── 02_seed_data.sql ← Date inițiale (parteneri test + pacienți demo)
└── docs/
    └── SETUP.md         ← Ghid setup pas cu pas
```

## URL-uri

| Pagină | URL pe GitHub Pages | Cine accesează |
|--------|---------------------|----------------|
| Landing | `username.github.io/clinica-carduri/` | Staff (entry point) |
| Login | `.../login.html` | Staff |
| Dashboard | `.../dashboard.html` | Staff (necesită auth) |
| Admin | `.../admin.html` | Admin (necesită rol admin) |
| **Scan card** | `.../card.html?id=CC-XXXX` | **Pacienți (prin QR)** |

## Cum se accesează cardul de către pacient

Pacientul **nu** trece niciodată prin landing page. Cardul fizic conține un QR cu URL direct către `card.html?id=CODUL_LUI`. Browser-ul îl deschide direct pe pagina cardului propriu, unde:

- **Vede** datele cardului (nume, nivel, discount activ) — fără login
- **Recepționera scanează** și se loghează (un singur login per zi/sesiune)
- **Înregistrează tranzacția** (preț de listă, preț plătit cu discount, serviciu)
- Sistemul calculează automat comisionul tău

## Securitate

- **Row Level Security (RLS)** în Supabase pentru toate tabelele
- **View public** (`pacient_card_public`) cu doar nume + nivel + discount — fără date sensibile
- **Audit log** automat: cine a modificat ce, când
- **GDPR**: bază de date hosted în EU (Frankfurt)
- **Auth obligatoriu** pentru înregistrare tranzacții, dashboard, admin

## Stack

- Frontend: HTML/CSS/JS vanilla — fără framework, deploy simplu
- Backend: Supabase (PostgreSQL + Auth + REST API)
- Hosting: GitHub Pages → Cloudflare Pages când ai domeniu propriu
- QR: qrcode.js (generare în browser pe pagina admin)
- GPS: Browser Geolocation API

## Setup

Vezi `docs/SETUP.md` pentru ghidul complet (60-90 min).

Rapid:
1. Creezi proiect Supabase, rulezi cele 2 SQL-uri din `supabase/`
2. Editezi `shared/config.js` cu credențialele Supabase
3. Push pe GitHub, activezi Pages
4. Inviți staff și setezi rolurile

## Independent de alte proiecte

Acest repo e **complet independent** de alte aplicații. Folosește propriul Supabase (deși poate partaja baza de date cu alte aplicații dacă schemele sunt compatibile — de văzut documentația de arhitectură).

## Roadmap

- [x] Sistem QR carduri funcțional
- [x] Auth staff cu Supabase
- [x] Dashboard tranzacții cu rapoarte
- [x] Admin pentru gestionare pacienți
- [x] Generare QR-uri în browser
- [x] GPS auto-detect partener
- [ ] Notificări SMS la fiecare tranzacție
- [ ] Generare facturi PDF lunare către parteneri
- [ ] Mobile app (PWA)
- [ ] Multi-clinică (white-label)

## Licență

Proiect intern.
