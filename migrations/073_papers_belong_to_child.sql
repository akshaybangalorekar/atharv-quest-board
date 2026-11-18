-- ============================================================================
-- 073_papers_belong_to_child.sql
-- A paper uploaded by a parent was being filed under the parent's own account,
-- so the child's screens could not see it — and the retry list, which looks at
-- the child's papers, came back empty. Papers belong to the child now; the
-- parent is recorded as the uploader.
-- Run after 072. Safe to re-run.
-- ============================================================================

alter table papers add column if not exists uploaded_by uuid references auth.users(id) on delete set null;

-- move the papers already stored under a parent's account to the child
update papers p
   set uploaded_by = coalesce(p.uploaded_by, p.student_id),
       student_id = g.student_id
  from guardians g
 where g.parent_id = p.student_id
   and p.uploaded_by is null;

-- and the same for their page images and jobs
update parse_jobs j
   set student_id = p.student_id
  from papers p
 where p.id = j.paper_id and j.student_id <> p.student_id;

create or replace function save_upload(
  p_exam text, p_name text, p_mime text, p_b64 text, p_path text default null
) returns bigint
language plpgsql security definer set search_path = public as $$
declare
  v_child uuid := coalesce(viewing_student(), auth.uid());
  v_id bigint;
  v_bytes bytea;
begin
  if auth.uid() is null then raise exception 'not signed in' using errcode = '28000'; end if;
  if coalesce(p_b64,'') = '' then raise exception 'nothing to save' using errcode = '22023'; end if;

  v_bytes := decode(p_b64, 'base64');

  insert into papers (student_id, uploaded_by, exam, title, path, pages, questions, mime, size_bytes, data, sha)
  values (v_child, auth.uid(), coalesce(nullif(p_exam,''), 'Unfiled'), coalesce(nullif(p_name,''), 'upload'),
          coalesce(p_path, ''), 0, 0, p_mime, length(v_bytes), v_bytes, md5(v_bytes::text))
  returning id into v_id;

  return v_id;
end $$;

grant execute on function save_upload(text, text, text, text, text) to authenticated;

-- the app needs to know which folder to put page images in
create or replace function my_student_id()
returns uuid
language sql security definer set search_path = public as $$
  select coalesce(viewing_student(), auth.uid());
$$;

grant execute on function my_student_id() to authenticated;
