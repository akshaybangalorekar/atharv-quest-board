-- ============================================================================
-- 090_reset_all.sql
-- One button that puts the whole thing back to the day it was set up: the
-- child's work, the parent's uploaded files, every question from either side,
-- the journal, the formula board, the tests, the streaks.
-- What survives: the accounts, the logins, the chapters, the exam banks, the
-- exam calendar and the timetable. Nothing else.
-- Run after 089. Safe to re-run.
-- ============================================================================

create or replace function reset_all()
returns json
language plpgsql security definer set search_path = public as $$
declare
  v_counts json;
begin
  if not is_parent() then
    raise exception 'only a parent can do this' using errcode = '42501';
  end if;

  delete from exam_items;
  delete from exam_mocks;
  delete from attempts;
  delete from weak_queue;
  delete from problems;
  delete from problem_answers;
  delete from paper_pages;
  delete from parse_jobs;
  delete from papers;
  delete from question_topups;
  delete from session_notes;
  delete from formula_board;
  delete from chapter_progress;
  delete from sessions;
  delete from coach_brief;
  delete from chapter_visits;
  delete from chat_messages;
  delete from self_reports;
  delete from working_reviews;
  delete from weekly_reports;
  delete from badges;
  delete from content_changes;

  update chapters set practice = 0, examples = 0;

  update profiles
     set xp = 0, level = 1, streak_days = 0,
         start_date = (now() at time zone 'Australia/Melbourne')::date;

  v_counts := json_build_object(
    'questions', (select count(*) from problems),
    'answers', (select count(*) from problem_answers),
    'attempts', (select count(*) from attempts),
    'files', (select count(*) from papers),
    'pages', (select count(*) from paper_pages),
    'journal', (select count(*) from session_notes),
    'tests', (select count(*) from exam_mocks)
  );

  return v_counts;
end $$;

grant execute on function reset_all() to authenticated;

-- where each exam's questions came from
create or replace function exam_question_sources()
returns json
language sql security definer set search_path = public as $$
  select coalesce(json_agg(row_to_json(t) order by t.exam), '[]'::json)
  from (
    select b.exam,
           (select count(*) from problems p where p.source = b.kind and p.paper_id is not null) as uploaded,
           (select count(*) from problems p where p.source = b.kind and p.paper_id is null) as by_coach,
           (select count(*) from problems p where p.source = b.kind) as total,
           (select string_agg(distinct pa.title, ', ')
              from problems p join papers pa on pa.id = p.paper_id
             where p.source = b.kind) as from_files
    from exam_banks b
  ) t;
$$;

grant execute on function exam_question_sources() to authenticated;
