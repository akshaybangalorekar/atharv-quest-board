-- ============================================================================
-- 007_working.sql
-- Photos of rough work, and the reviews the coach writes about them.
-- Run after 006. Safe to re-run.
-- ============================================================================

-- private bucket: one folder per student
insert into storage.buckets (id, name, public)
values ('working', 'working', false)
on conflict (id) do nothing;

drop policy if exists "own working uploads" on storage.objects;
create policy "own working uploads" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'working' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "own working reads" on storage.objects;
create policy "own working reads" on storage.objects
  for select to authenticated
  using (bucket_id = 'working' and (storage.foldername(name))[1] = (select auth.uid())::text);

create table if not exists working_reviews (
  id bigserial primary key,
  student_id uuid not null references auth.users(id) on delete cascade,
  chapter int not null,
  idx int not null,
  image_path text,
  stage text not null default 'work',     -- work | check | teachback
  feedback jsonb,
  model text,
  created_at timestamptz default now()
);
alter table working_reviews enable row level security;

drop policy if exists "own rows" on working_reviews;
create policy "own rows" on working_reviews for all to authenticated
  using (student_id = (select auth.uid())) with check (student_id = (select auth.uid()));
drop policy if exists "guardian read" on working_reviews;
create policy "guardian read" on working_reviews for select to authenticated
  using (is_guardian(student_id));

create index if not exists working_reviews_student_idx
  on working_reviews(student_id, created_at desc);
