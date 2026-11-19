-- ============================================================================
-- 081_storage_guardians.sql
-- The page images were being written into the child's folder by the parent's
-- login, and the storage rules only ever allowed a person their own folder. So
-- every page upload was refused, no page was stored, and the reader reported
-- "Object not found". A parent may now read and write their own child's folder.
-- Run after 080. Safe to re-run.
-- ============================================================================

drop policy if exists "own papers read" on storage.objects;
drop policy if exists "own papers upload" on storage.objects;
drop policy if exists "papers read own" on storage.objects;
drop policy if exists "papers write own" on storage.objects;
drop policy if exists "papers guardian read" on storage.objects;
drop policy if exists "papers guardian write" on storage.objects;

create policy "papers guardian read" on storage.objects for select to authenticated
  using (
    bucket_id = 'papers' and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or exists (select 1 from guardians g
                  where g.parent_id = (select auth.uid())
                    and g.student_id::text = (storage.foldername(name))[1])
    )
  );

create policy "papers guardian write" on storage.objects for insert to authenticated
  with check (
    bucket_id = 'papers' and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or exists (select 1 from guardians g
                  where g.parent_id = (select auth.uid())
                    and g.student_id::text = (storage.foldername(name))[1])
    )
  );

create policy "papers guardian update" on storage.objects for update to authenticated
  using (
    bucket_id = 'papers' and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or exists (select 1 from guardians g
                  where g.parent_id = (select auth.uid())
                    and g.student_id::text = (storage.foldername(name))[1])
    )
  );

create policy "papers guardian delete" on storage.objects for delete to authenticated
  using (
    bucket_id = 'papers' and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or exists (select 1 from guardians g
                  where g.parent_id = (select auth.uid())
                    and g.student_id::text = (storage.foldername(name))[1])
    )
  );
