-- ============================================================================
-- 085_delete_everything.sql
-- Deleting a file used to leave traces behind: the answers were removed, but an
-- attempt made against a question could stay, and the next question to take that
-- chapter-and-index slot would inherit it. Deleting a file now removes every
-- trace of it — answers, questions, attempts, weak-queue entries, test items,
-- reading jobs, page rows — and reports what it removed. It also hands back the
-- storage paths so the files themselves can go.
-- Run after 084. Safe to re-run.
-- ============================================================================

create or replace function paper_objects(p_id bigint)
returns text[]
language sql security definer set search_path = public as $$
  select coalesce(array_agg(path), '{}')
  from paper_pages where paper_id = p_id;
$$;

grant execute on function paper_objects(bigint) to authenticated;

create or replace function delete_paper(p_id bigint)
returns json
language plpgsql security definer set search_path = public as $$
declare
  v_child uuid := coalesce(viewing_student(), auth.uid());
  v_paths text[];
  v_q int := 0; v_a int := 0; v_att int := 0; v_weak int := 0; v_items int := 0;
begin
  if not exists (select 1 from papers where id = p_id and student_id = v_child) then
    raise exception 'no such paper' using errcode = '22023';
  end if;

  select coalesce(array_agg(path), '{}') into v_paths from paper_pages where paper_id = p_id;

  -- the questions this file produced
  create temp table if not exists _gone (chapter int, idx int) on commit drop;
  delete from _gone;
  insert into _gone (chapter, idx)
  select chapter, idx from problems where paper_id = p_id;

  select count(*) into v_q from _gone;

  -- everything that pointed at them
  delete from attempts a using _gone g where a.chapter = g.chapter and a.idx = g.idx;
  get diagnostics v_att = row_count;

  delete from weak_queue w using _gone g where w.chapter = g.chapter and w.idx = g.idx;
  get diagnostics v_weak = row_count;

  delete from exam_items e using _gone g where e.chapter = g.chapter and e.idx = g.idx;
  get diagnostics v_items = row_count;

  delete from problem_answers a using _gone g where a.chapter = g.chapter and a.idx = g.idx;
  get diagnostics v_a = row_count;

  delete from problems where paper_id = p_id;

  delete from parse_jobs where paper_id = p_id;
  delete from papers where id = p_id;        -- page rows cascade

  update chapters set practice = (select count(*) from problems p where p.chapter = chapters.n);

  return json_build_object('ok', true,
    'questions_removed', v_q, 'answers_removed', v_a,
    'attempts_removed', v_att, 'weak_entries_removed', v_weak, 'test_items_removed', v_items,
    'paths', v_paths);
end $$;

grant execute on function delete_paper(bigint) to authenticated;
