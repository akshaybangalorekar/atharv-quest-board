-- ============================================================================
-- 053_save_uploads_in_db.sql
-- Every upload is kept exactly as it arrived, inside the database, before
-- anything is parsed. Storage keeps a copy for showing pages quickly; this is
-- the original, byte for byte, so the parser can always be re-run on the real
-- file and nothing depends on a browser tab staying open.
-- Run after 052. Safe to re-run.
-- ============================================================================

alter table papers add column if not exists mime text;
alter table papers add column if not exists size_bytes bigint;
alter table papers add column if not exists data bytea;
alter table papers add column if not exists sha text;

create or replace function save_upload(
  p_exam text, p_name text, p_mime text, p_b64 text, p_path text default null
) returns bigint
language plpgsql security definer set search_path = public as $$
declare
  v uuid := auth.uid();
  v_id bigint;
  v_bytes bytea;
begin
  if v is null then raise exception 'not signed in' using errcode = '28000'; end if;
  if coalesce(p_b64,'') = '' then raise exception 'nothing to save' using errcode = '22023'; end if;

  v_bytes := decode(p_b64, 'base64');

  insert into papers (student_id, exam, title, path, pages, questions, mime, size_bytes, data, sha)
  values (v, coalesce(nullif(p_exam,''), 'Unfiled'), coalesce(nullif(p_name,''), 'upload'),
          coalesce(p_path, ''), 0, 0, p_mime, length(v_bytes), v_bytes, md5(v_bytes::text))
  returning id into v_id;

  return v_id;
end $$;

grant execute on function save_upload(text, text, text, text, text) to authenticated;

-- the original back out again, for a re-parse or a look at the file
create or replace function upload_bytes(p_id bigint)
returns text
language plpgsql security definer set search_path = public as $$
declare v uuid := auth.uid(); v_out text;
begin
  select encode(data, 'base64') into v_out
  from papers
  where id = p_id and (student_id = v or is_guardian(student_id));
  return v_out;
end $$;

grant execute on function upload_bytes(bigint) to authenticated;
