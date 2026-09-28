-- crestra Kundenboard – Datenbank (Supabase / Postgres)
-- Ein Dokumentenspeicher wie im alten claude.ai-Board: Sammlung + ID + JSON-Daten.
-- Jede Zeile gehört einem angemeldeten Nutzer; nur er sieht und ändert sie (Row Level Security).

create table if not exists public.docs (
  owner      uuid        not null default auth.uid() references auth.users(id) on delete cascade,
  collection text        not null,
  id         text        not null,
  data       jsonb       not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (owner, collection, id)
);

alter table public.docs enable row level security;
alter table public.docs replica identity full;  -- Live-Updates liefern bei Löschungen die ganze Zeile

drop policy if exists "docs lesen" on public.docs;
drop policy if exists "docs anlegen" on public.docs;
drop policy if exists "docs aendern" on public.docs;
drop policy if exists "docs loeschen" on public.docs;
create policy "docs lesen"   on public.docs for select to authenticated using (owner = auth.uid());
create policy "docs anlegen" on public.docs for insert to authenticated with check (owner = auth.uid());
create policy "docs aendern" on public.docs for update to authenticated using (owner = auth.uid()) with check (owner = auth.uid());
create policy "docs loeschen" on public.docs for delete to authenticated using (owner = auth.uid());

-- Felder zusammenführen statt ersetzen (wie doc.update im alten Board)
create or replace function public.doc_merge(p_collection text, p_id text, p_patch jsonb)
returns void language sql security invoker set search_path = public as $$
  insert into public.docs (owner, collection, id, data)
  values (auth.uid(), p_collection, p_id, p_patch)
  on conflict (owner, collection, id)
  do update set data = public.docs.data || excluded.data, updated_at = now();
$$;
grant execute on function public.doc_merge(text, text, jsonb) to authenticated;

-- Änderungen live an alle offenen Geräte schicken
do $$ begin
  alter publication supabase_realtime add table public.docs;
exception when duplicate_object then null; end $$;
