-- ============================================================================
-- 017_papers.sql
-- Somewhere to put the paper you are uploading from: jpeg, png or pdf.
-- Run after 016. Safe to re-run.
-- ============================================================================

insert into storage.buckets (id, name, public)
values ('papers', 'papers', false)
on conflict (id) do nothing;

drop policy if exists "own papers upload" on storage.objects;
create policy "own papers upload" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'papers' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "own papers read" on storage.objects;
create policy "own papers read" on storage.objects
  for select to authenticated
  using (bucket_id = 'papers' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- every question carries where it came from, so a bad extraction can be found later
alter table problems add column if not exists source_file text;
