-- ============================================================================
-- 045_papers.sql
-- The papers themselves, kept as papers. Until now an upload was turned into
-- questions and the file was thrown away, so there was nothing to look at — no
-- book to open. Now the file is stored, listed under its exam, and can be read
-- page by page in the app.
-- Run after 044. Safe to re-run.
-- ============================================================================

create table if not exists papers (
  id bigserial primary key,
  student_id uuid not null references auth.users(id) on delete cascade,
  exam text not null,
  title text not null,
  path text not null,            -- where it sits in the papers bucket
  pages int default 0,
  questions int default 0,       -- how many were taken out of it
  created_at timestamptz default now()
);
alter table papers enable row level security;
drop policy if exists "own papers" on papers;
create policy "own papers" on papers for all to authenticated
  using (student_id = (select auth.uid())) with check (student_id = (select auth.uid()));
drop policy if exists "guardian papers" on papers;
create policy "guardian papers" on papers for select to authenticated using (is_guardian(student_id));
drop policy if exists "guardian papers write" on papers;
create policy "guardian papers write" on papers for insert to authenticated with check (is_guardian(student_id));

create index if not exists papers_by_exam on papers (student_id, exam, created_at desc);

-- the storage bucket, private to the account
insert into storage.buckets (id, name, public)
values ('papers', 'papers', false)
on conflict (id) do nothing;

drop policy if exists "papers read own" on storage.objects;
create policy "papers read own" on storage.objects for select to authenticated
  using (bucket_id = 'papers' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "papers write own" on storage.objects;
create policy "papers write own" on storage.objects for insert to authenticated
  with check (bucket_id = 'papers' and (storage.foldername(name))[1] = auth.uid()::text);
