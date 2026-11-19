-- ============================================================================
-- 084_progress_stale.sql
-- A reading job whose paper has since been deleted was still being reported as
-- the current one, so the app could show "Reading" for a file that no longer
-- exists. Progress only ever reports a job that belongs to a real paper.
-- Run after 083. Safe to re-run.
-- ============================================================================

delete from parse_jobs j
 where not exists (select 1 from papers p where p.id = j.paper_id);

create or replace function parse_progress()
returns json
language sql security definer set search_path = public as $$
  with who as (select coalesce(viewing_student(), auth.uid()) as sid),
  job as (
    select j.*
    from parse_jobs j
    join papers p on p.id = j.paper_id
    join who on true
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
