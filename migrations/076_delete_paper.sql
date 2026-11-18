-- ============================================================================
-- 076_delete_paper.sql
-- A paper can be removed: the file, its page images, its reading jobs and the
-- questions that came out of it. Nothing else is touched.
-- Run after 075. Safe to re-run.
-- ============================================================================

create or replace function delete_paper(p_id bigint)
returns json
language plpgsql security definer set search_path = public as $$
declare
  v_child uuid := coalesce(viewing_student(), auth.uid());
  v_paths text[];
  v_questions int;
begin
  if not exists (select 1 from papers where id = p_id and student_id = v_child) then
    raise exception 'no such paper' using errcode = '22023';
  end if;

  select coalesce(array_agg(path), '{}') into v_paths from paper_pages where paper_id = p_id;

  select count(*) into v_questions from problems where paper_id = p_id;

  -- the questions it produced, and their answers
  delete from problem_answers a
   using problems p
   where p.paper_id = p_id and a.chapter = p.chapter and a.idx = p.idx;
  delete from problems where paper_id = p_id;

  delete from parse_jobs where paper_id = p_id;
  delete from papers where id = p_id;      -- page rows cascade

  return json_build_object('ok', true, 'questions_removed', v_questions, 'paths', v_paths);
end $$;

grant execute on function delete_paper(bigint) to authenticated;
