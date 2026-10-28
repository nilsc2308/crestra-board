-- crestra Kundenboard – Lead-Liste und Vertriebler (Supabase / Postgres)
-- Leads liegen in einer eigenen Tabelle. Nils (admin) sieht alle, ein Vertriebler nur die Leads,
-- die ihm zugeteilt wurden. Neue Leads bekommt ein Vertriebler nur über leads_anfordern():
-- Die Funktion vergibt die nächsten freien Leads aus der Liste (beste zuerst), nie doppelt.

-- Rollen
create table if not exists public.profiles (
  id         uuid        primary key references auth.users(id) on delete cascade,
  name       text        not null default '',
  role       text        not null default 'vertrieb' check (role in ('admin', 'vertrieb')),
  created_at timestamptz not null default now()
);
alter table public.profiles enable row level security;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;
grant execute on function public.is_admin() to authenticated;

drop policy if exists "profil lesen" on public.profiles;
create policy "profil lesen" on public.profiles for select to authenticated using (id = auth.uid() or public.is_admin());

-- Leads
create table if not exists public.leads (
  id          bigint      primary key,          -- Rang in der Liste: kleiner = besser
  gruppe      text        not null,
  branche     text        not null default '',
  firma       text        not null,
  inhaber     text        not null default '',
  strasse     text        not null default '',
  plz         text        not null default '',
  ort         text        not null default '',
  bundesland  text        not null default '',
  telefon     text        not null default '',
  email       text        not null default '',
  website     text        not null default '',
  art         text        not null check (art in ('alt', 'social', 'keine', 'tot', 'fehler')),
  punkte      int         not null default 0,
  maengel     jsonb       not null default '[]'::jsonb,
  status      text        not null default 'frei'
              check (status in ('frei', 'vergeben', 'angeschrieben', 'termin', 'kunde', 'kein_interesse', 'ungueltig')),
  assigned_to uuid        references auth.users(id) on delete set null,
  assigned_at timestamptz,
  notiz       text        not null default '',
  updated_at  timestamptz not null default now()
);
create index if not exists leads_frei_idx on public.leads (gruppe, bundesland, id) where status = 'frei';
create index if not exists leads_assigned_idx on public.leads (assigned_to, status);

alter table public.leads enable row level security;
drop policy if exists "leads lesen" on public.leads;
drop policy if exists "leads admin aendern" on public.leads;
create policy "leads lesen" on public.leads for select to authenticated
  using (public.is_admin() or assigned_to = auth.uid());
create policy "leads admin aendern" on public.leads for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Neue Leads anfordern: höchstens 50 auf einmal, höchstens 100 unbearbeitete gleichzeitig.
create or replace function public.leads_anfordern(p_anzahl int default 25, p_gruppe text default null, p_bundesland text default null)
returns setof public.leads language plpgsql security definer set search_path = public as $$
declare
  v_offen int;
  v_n int := least(greatest(coalesce(p_anzahl, 25), 1), 50);
begin
  if not exists (select 1 from profiles where id = auth.uid()) then
    raise exception 'Kein Vertriebler-Konto' using errcode = '42501';
  end if;
  select count(*) into v_offen from leads where assigned_to = auth.uid() and status = 'vergeben';
  if not public.is_admin() and v_offen >= 100 then
    raise exception 'Du hast noch % unbearbeitete Leads. Bitte erst diese bearbeiten.', v_offen using errcode = 'P0001';
  end if;
  return query
    with pick as (
      select l.id from leads l
      where l.status = 'frei'
        and (p_gruppe is null or l.gruppe = p_gruppe)
        and (p_bundesland is null or l.bundesland = p_bundesland)
      order by l.id
      limit v_n
      for update skip locked
    )
    update leads l set status = 'vergeben', assigned_to = auth.uid(), assigned_at = now(), updated_at = now()
    from pick where l.id = pick.id
    returning l.*;
end $$;
grant execute on function public.leads_anfordern(int, text, text) to authenticated;

-- Stand eines eigenen Leads ändern. 'frei' gibt den Lead an die Liste zurück.
create or replace function public.lead_stand(p_id bigint, p_status text, p_notiz text default null)
returns public.leads language plpgsql security definer set search_path = public as $$
declare v public.leads;
begin
  if p_status not in ('frei', 'vergeben', 'angeschrieben', 'termin', 'kunde', 'kein_interesse', 'ungueltig') then
    raise exception 'Unbekannter Stand %', p_status;
  end if;
  update leads set
    status = p_status,
    notiz = coalesce(p_notiz, notiz),
    assigned_to = case when p_status = 'frei' then null else assigned_to end,
    assigned_at = case when p_status = 'frei' then null else assigned_at end,
    updated_at = now()
  where id = p_id and (assigned_to = auth.uid() or public.is_admin())
  returning * into v;
  if v.id is null then raise exception 'Lead nicht gefunden' using errcode = 'P0002'; end if;
  return v;
end $$;
grant execute on function public.lead_stand(bigint, text, text) to authenticated;

-- Übersicht für Nils: wie viele Leads je Gruppe frei / vergeben sind
create or replace function public.leads_uebersicht()
returns table (gruppe text, status text, anzahl bigint) language sql stable security definer set search_path = public as $$
  select gruppe, status, count(*) from leads where public.is_admin() group by 1, 2;
$$;
grant execute on function public.leads_uebersicht() to authenticated;

-- Nils ist admin
insert into public.profiles (id, name, role)
select id, 'Nils', 'admin' from auth.users where email = 'nilscre.ac@gmail.com'
on conflict (id) do update set role = 'admin';
