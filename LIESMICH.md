# crestra Kundenboard – App (PWA)

Live: https://nilsc2308.github.io/crestra-board/ · Code: github.com/nilsc2308/crestra-board
Seit 28.09.2026 Nachfolger des claude.ai-Boards (gleiches Design, gleiche Funktionen).

## Aufbau
- `index.html` – das Board (aus dem claude.ai-Board übernommen, Quelle `_quelle-claude-board.html`)
- `db.js` – Supabase-Anbindung mit derselben Schnittstelle wie früher + Anmeldung
- `config.js` – Supabase-Adresse + öffentlicher anon-Schlüssel (darf öffentlich sein)
- `manifest.webmanifest`, `sw.js`, `icons/` – App-Einstellungen fürs Installieren
- `supabase/schema.sql` – Tabelle `docs` (Sammlung/ID/JSON), nur eigene Daten sichtbar (RLS)

## Supabase
- Projekt „claude“, Ref `mvcwhvntbvnldqimjiki`, Region eu-west-1 (Irland), Organisation „studiq“
  (Studiq-Projekt daneben NICHT anfassen)
- Registrierung gesperrt; einziges Konto: nilscre.ac@gmail.com
- Kostenloser Tarif: E-Mails nur an Team-Mitglieder, max. ~2 pro Stunde, Vorlagen nicht änderbar
- Zugangsdaten nur auf dem Mac in `~/.config/crestra/` (Token, service-key, DB-Passwort) – nie ins Repo

## Chat mit Claude
Nachrichten landen in `docs` (collection `chat`). Claude liest/antwortet mit
`node _claude-chat.js neu` bzw. `node _claude-chat.js antwort "Text"` (nicht im Repo).

## Offen
- [ ] Nils: Passwort festlegen („Passwort festlegen oder vergessen?“ → Link in der E-Mail)
- [ ] Nils: Supabase-Zugangsschlüssel löschen, die im Chat standen (supabase.com/dashboard/account/tokens)
- [ ] Altes claude.ai-Board nicht mehr benutzen (Hinweis im alten Chat steht drin)
