// Zugangsdaten zur Supabase-Datenbank. Der „anon“-Schlüssel ist öffentlich gedacht:
// Er erlaubt nur, was die Sicherheitsregeln in supabase/schema.sql zulassen
// (jeder angemeldete Nutzer sieht ausschließlich seine eigenen Daten).
export const SUPABASE_URL = "__SUPABASE_URL__";
export const SUPABASE_ANON_KEY = "__SUPABASE_ANON_KEY__";
