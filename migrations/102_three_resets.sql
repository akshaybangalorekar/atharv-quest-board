-- ============================================================================
-- 102_three_resets.sql
-- Three separate wipes, so one kind of content can go without the other:
--   reset_all()       — everything: work, files, questions, timetable, day one
--   clear_uploaded()  — the files and the questions that came from them
--   clear_generated() — the questions the coach wrote
-- Each removes the traces too: answers, attempts, weak queue, test items.
-- Run after 101. Safe to re-run.
-- ============================================================================

create or replace function _wipe_questions(p_where text)
returns int
language plpgsql security definer set search_path = public as $$
declare v_n int := 0;
begin
  create temp table if not exists _gone on commit drop as select chapter, idx from problems where false;
  delete from _gone;

  execute format('insert into _gone (chapter, idx) select chapter, idx from problems where %s', p_where);
  select count(*) into v_n from _gone;

  delete from attempts a using _gone g where a.chapter = g.chapter and a.idx = g.idx;
  delete from weak_queue w using _gone g where w.chapter = g.chapter and w.idx = g.idx;
  delete from exam_items e using _gone g where e.chapter = g.chapter and e.idx = g.idx;
  delete from problem_answers a using _gone g where a.chapter = g.chapter and a.idx = g.idx;
  execute format('delete from problems where %s', p_where);

  update chapters set practice = (select count(*) from problems p where p.chapter = chapters.n);
  return v_n;
end $$;

create or replace function clear_uploaded()
returns json
language plpgsql security definer set search_path = public as $$
declare v_q int; v_files int; v_pages int;
begin
  if not is_parent() then raise exception 'only a parent can do this' using errcode = '42501'; end if;

  v_q := _wipe_questions('paper_id is not null');

  select count(*) into v_pages from paper_pages;
  select count(*) into v_files from papers;

  delete from paper_pages;
  delete from parse_jobs;
  delete from papers;

  return json_build_object('questions_removed', v_q, 'files_removed', v_files, 'pages_removed', v_pages);
end $$;

create or replace function clear_generated()
returns json
language plpgsql security definer set search_path = public as $$
declare v_q int;
begin
  if not is_parent() then raise exception 'only a parent can do this' using errcode = '42501'; end if;
  v_q := _wipe_questions('paper_id is null');
  delete from question_topups;
  return json_build_object('questions_removed', v_q);
end $$;

grant execute on function clear_uploaded() to authenticated;
grant execute on function clear_generated() to authenticated;
