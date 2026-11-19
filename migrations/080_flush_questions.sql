-- ============================================================================
-- 080_flush_questions.sql
-- A clean slate, as asked. Everything that is a question goes: the problems,
-- their answers, every attempt against them, the weak queue built from those
-- attempts, and the tests that were assembled from them. The chapters, the
-- timetable, the logins, the uploaded files and the papers stay.
--
-- Before anything is deleted, a copy is kept, so this is recoverable:
--   problems_backup_20261119, problem_answers_backup_20261119
-- Run after 079. Safe to re-run (the backup is only taken once).
-- ============================================================================

do $$
begin
  if not exists (select 1 from information_schema.tables
                 where table_schema = 'public' and table_name = 'problems_backup_20261119') then
    create table problems_backup_20261119 as select * from problems;
    create table problem_answers_backup_20261119 as select * from problem_answers;
  end if;
end $$;

-- tests were built out of the questions that are going
delete from exam_items;
delete from exam_mocks;

-- everything that pointed at a question
delete from attempts;
delete from weak_queue;
delete from problems;
delete from problem_answers;

-- chapter counters follow the questions
update chapters set practice = 0;
update chapter_progress set quiz_best = null, weak = false, examples_reviewed = false;

select 'flushed' as done;
