-- My Bloom Journal - Supabase setup
-- Run this ONCE in Supabase Dashboard -> SQL Editor -> New query -> Run.

create table if not exists public.journal_records (
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  id text not null,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);

create index if not exists journal_records_user_id_idx on public.journal_records (user_id);

alter table public.journal_records enable row level security;

revoke all on table public.journal_records from anon, authenticated;
grant select, insert, update, delete on table public.journal_records to authenticated;

drop policy if exists "journal_records_select_own" on public.journal_records;
create policy "journal_records_select_own" on public.journal_records
for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "journal_records_insert_own" on public.journal_records;
create policy "journal_records_insert_own" on public.journal_records
for insert to authenticated with check ((select auth.uid()) = user_id);

drop policy if exists "journal_records_update_own" on public.journal_records;
create policy "journal_records_update_own" on public.journal_records
for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "journal_records_delete_own" on public.journal_records;
create policy "journal_records_delete_own" on public.journal_records
for delete to authenticated using ((select auth.uid()) = user_id);

create or replace function public.set_journal_records_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists journal_records_set_updated_at on public.journal_records;
create trigger journal_records_set_updated_at
before update on public.journal_records
for each row execute function public.set_journal_records_updated_at();

alter table public.journal_records replica identity full;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'journal_records'
  ) then
    alter publication supabase_realtime add table public.journal_records;
  end if;
end $$;
