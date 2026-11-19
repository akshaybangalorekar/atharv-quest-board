-- ============================================================================
-- 093_quiz_rule.sql
-- The chapter quiz used to come after four right answers in a row. It now comes
-- when he has done most of the chapter AND is getting them right AND is quick
-- AND is coping with the harder ones — a chapter is finished when it is
-- finished, not when a streak happens to line up.
-- Run after 092. Safe to re-run.
-- ============================================================================

create or replace function chapter_ready_for_quiz(p_chapter int)
returns json
language sql security definer set search_path = public as $$
  with who as (select coalesce(viewing_student(), auth.uid()) as sid),
  totals as (
    select (select count(*) from problems where chapter = p_chapter) as in_chapter
  ),
  done as (
    select count(*) as tried,
           count(*) filter (where a.ok) as right,
           coalesce(round(avg(a.seconds) filter (where a.seconds > 0)), 0) as avg_seconds,
           coalesce(round(avg(p.difficulty)), 2) as avg_difficulty
    from attempts a
    join problems p on p.chapter = a.chapter and p.idx = a.idx
    join who on true
    where a.student_id = who.sid and a.chapter = p_chapter
  )
  select json_build_object(
    'ready', (
      totals.in_chapter > 0
      and done.tried >= greatest(4, ceil(totals.in_chapter * 0.8))
      and (done.right::numeric / greatest(done.tried,1)) >= 0.90
      and (done.avg_seconds = 0 or done.avg_seconds <= 120)
      and done.avg_difficulty >= 2
    ),
    'tried', done.tried,
    'needed', greatest(4, ceil(totals.in_chapter * 0.8)),
    'accuracy', case when done.tried = 0 then 0 else round(100.0 * done.right / done.tried) end,
    'average_seconds', done.avg_seconds,
    'average_difficulty', done.avg_difficulty,
    'why', case
      when totals.in_chapter = 0 then 'this chapter has no questions yet'
      when done.tried < greatest(4, ceil(totals.in_chapter * 0.8)) then 'more of the chapter to go'
      when (done.right::numeric / greatest(done.tried,1)) < 0.90 then 'accuracy under 90 per cent'
      when done.avg_seconds > 120 then 'taking longer than two minutes a question'
      when done.avg_difficulty < 2 then 'the harder questions are still to come'
      else 'ready' end
  )
  from totals, done;
$$;

grant execute on function chapter_ready_for_quiz(int) to authenticated;
