-- Jalankan sekali di Supabase SQL Editor untuk proyek database baru.
-- Sesuai pilihan aplikasi: pengunjung anonim boleh membaca dan mengubah semua data.

create table if not exists public.members (
  id text primary key default gen_random_uuid()::text,
  nama text not null check (btrim(nama) <> ''),
  divisi text not null default '',
  tel text not null default ''
);

create table if not exists public.attendance (
  attendance_date date not null,
  member_id text not null references public.members(id) on delete cascade,
  status text not null check (status in ('H', 'I', 'S', 'A')),
  primary key (attendance_date, member_id)
);

create table if not exists public.app_settings (
  id smallint primary key default 1 check (id = 1),
  kegiatan text not null default '',
  waktu text not null default '15:30',
  tpl text not null default E'Nama-nama di bawah ini tidak berangkat dan tanpa keterangan, {kegiatan} tanggal {tanggal} pukul {waktu}:\n{daftar}\nMohon konfirmasi. Terima kasih.'
);

insert into public.app_settings (id) values (1) on conflict (id) do nothing;

alter table public.members enable row level security;
alter table public.attendance enable row level security;
alter table public.app_settings enable row level security;

grant usage on schema public to anon;
grant select, insert, update, delete on public.members, public.attendance, public.app_settings to anon;

drop policy if exists "Public can read members" on public.members;
drop policy if exists "Public can add members" on public.members;
drop policy if exists "Public can update members" on public.members;
drop policy if exists "Public can delete members" on public.members;
create policy "Public can read members" on public.members for select to anon using (true);
create policy "Public can add members" on public.members for insert to anon with check (true);
create policy "Public can update members" on public.members for update to anon using (true) with check (true);
create policy "Public can delete members" on public.members for delete to anon using (true);

drop policy if exists "Public can read attendance" on public.attendance;
drop policy if exists "Public can add attendance" on public.attendance;
drop policy if exists "Public can update attendance" on public.attendance;
drop policy if exists "Public can delete attendance" on public.attendance;
create policy "Public can read attendance" on public.attendance for select to anon using (true);
create policy "Public can add attendance" on public.attendance for insert to anon with check (true);
create policy "Public can update attendance" on public.attendance for update to anon using (true) with check (true);
create policy "Public can delete attendance" on public.attendance for delete to anon using (true);

drop policy if exists "Public can read app settings" on public.app_settings;
drop policy if exists "Public can add app settings" on public.app_settings;
drop policy if exists "Public can update app settings" on public.app_settings;
drop policy if exists "Public can delete app settings" on public.app_settings;
create policy "Public can read app settings" on public.app_settings for select to anon using (true);
create policy "Public can add app settings" on public.app_settings for insert to anon with check (true);
create policy "Public can update app settings" on public.app_settings for update to anon using (true) with check (true);
create policy "Public can delete app settings" on public.app_settings for delete to anon using (true);

create or replace function public.restore_osis_backup(p_backup jsonb)
returns void
language plpgsql
security invoker
set search_path = pg_catalog, public
as $function$
declare
  v_member record;
  v_day record;
  v_entry record;
  v_settings jsonb;
begin
  if p_backup is null or jsonb_typeof(p_backup) is distinct from 'object' then
    raise exception 'Backup harus berupa objek JSON';
  end if;
  if jsonb_typeof(p_backup -> 'members') is distinct from 'array' then
    raise exception 'Backup tidak memiliki daftar members yang valid';
  end if;
  if p_backup ? 'records' and jsonb_typeof(p_backup -> 'records') is distinct from 'object' then
    raise exception 'Bagian records harus berupa objek';
  end if;
  v_settings := coalesce(p_backup -> 'settings', '{}'::jsonb);
  if jsonb_typeof(v_settings) is distinct from 'object' then
    raise exception 'Bagian settings harus berupa objek';
  end if;

  delete from public.members;

  for v_member in
    select * from jsonb_to_recordset(p_backup -> 'members') as x(id text, nama text, divisi text, tel text)
  loop
    if nullif(btrim(v_member.nama), '') is null then
      raise exception 'Nama anggota tidak boleh kosong';
    end if;
    insert into public.members (id, nama, divisi, tel)
    values (
      coalesce(nullif(v_member.id, ''), gen_random_uuid()::text),
      btrim(v_member.nama), coalesce(v_member.divisi, ''), coalesce(v_member.tel, '')
    );
  end loop;

  for v_day in
    select key, value from jsonb_each(coalesce(p_backup -> 'records', '{}'::jsonb))
  loop
    if jsonb_typeof(v_day.value) is distinct from 'object' then
      raise exception 'Data absensi per tanggal harus berupa objek';
    end if;
    for v_entry in select key, value from jsonb_each(v_day.value)
    loop
      if jsonb_typeof(v_entry.value) is distinct from 'string'
         or (v_entry.value #>> '{}') not in ('H', 'I', 'S', 'A') then
        raise exception 'Status absensi tidak valid';
      end if;
      insert into public.attendance (attendance_date, member_id, status)
      values (v_day.key::date, v_entry.key, v_entry.value #>> '{}');
    end loop;
  end loop;

  insert into public.app_settings (id, kegiatan, waktu, tpl)
  values (
    1,
    coalesce(v_settings ->> 'kegiatan', ''),
    coalesce(v_settings ->> 'waktu', '15:30'),
    coalesce(v_settings ->> 'tpl', E'Nama-nama di bawah ini tidak berangkat dan tanpa keterangan, {kegiatan} tanggal {tanggal} pukul {waktu}:\n{daftar}\nMohon konfirmasi. Terima kasih.')
  )
  on conflict (id) do update set
    kegiatan = excluded.kegiatan,
    waktu = excluded.waktu,
    tpl = excluded.tpl;
end;
$function$;

revoke all on function public.restore_osis_backup(jsonb) from public, anon, authenticated;
grant execute on function public.restore_osis_backup(jsonb) to anon;

-- Aktifkan event PostgreSQL Changes untuk sinkronisasi langsung antar browser.
do $realtime$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    raise exception 'Publication supabase_realtime tidak ditemukan';
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'members'
  ) then
    alter publication supabase_realtime add table public.members;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'attendance'
  ) then
    alter publication supabase_realtime add table public.attendance;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'app_settings'
  ) then
    alter publication supabase_realtime add table public.app_settings;
  end if;
end;
$realtime$;
