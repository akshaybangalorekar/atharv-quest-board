-- ============================================================================
-- 070_progress_remaining.sql
-- The bar kept vanishing because a job was being marked finished whether or not
-- its pages were read. Progress now reports how many pages are left, so the app
-- can tell "done" from "paused with work still to do".
-- Run after 069. Safe to re-run.
-- ============================================================================

create or replace function parse_progress()
returns json
language sql security definer set search_path = public as $$
  with who as (select coalesce(viewing_student(), auth.uid()) as sid),
  job as (
    select j.* from parse_jobs j, who
    where j.student_id = who.sid
    order by j.created_at desc limit 1
  )
  select row_to_json(t) from (
    select j.id, j.status, j.paper_id, j.exam, j.strand,
           (select count(*) from paper_pages pp where pp.paper_id = j.paper_id and pp.done) as pages_done,
           (select count(*) from paper_pages pp where pp.paper_id = j.paper_id) as pages_total,
           (select count(*) from paper_pages pp where pp.paper_id = j.paper_id and not pp.done) as remaining,
           j.added, j.unanswered, j.note
    from job j
  ) t;
$$;

grant execute on function parse_progress() to authenticated;
