-- ============================================================================
-- 079_save_upload_fast.sql
-- A 7 MB PDF timed out while being saved: the function decoded the whole file,
-- hashed the whole file, and wrote it, all inside the default statement limit.
-- It now gives itself room, and stops hashing the entire thing.
-- Run after 078. Safe to re-run.
-- ============================================================================

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

  -- a big file needs longer than the default eight seconds
  perform set_config('statement_timeout', '120000', true);

  v_bytes := decode(p_b64, 'base64');

  insert into papers (student_id, uploaded_by, exam, title, path, pages, questions, mime, size_bytes, data, sha)
  values (v_child, auth.uid(), coalesce(nullif(p_exam,''), 'Unfiled'), coalesce(nullif(p_name,''), 'upload'),
          coalesce(p_path, ''), 0, 0, p_mime, length(v_bytes), v_bytes,
          substr(md5(encode(substr(v_bytes, 1, 4096), 'base64')), 1, 16))   -- a cheap fingerprint, not the whole file
  returning id into v_id;

  return v_id;
end $$;

grant execute on function save_upload(text, text, text, text, text) to authenticated;

-- the same for reading a big original back out
create or replace function upload_bytes(p_id bigint)
returns text
language plpgsql security definer set search_path = public as $$
declare v uuid := auth.uid(); v_out text;
begin
  perform set_config('statement_timeout', '120000', true);
  select encode(data, 'base64') into v_out
  from papers
  where id = p_id and (student_id = v or is_guardian(student_id));
  return v_out;
end $$;

grant execute on function upload_bytes(bigint) to authenticated;
