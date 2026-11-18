-- ============================================================================
-- 072_retry_visible.sql
-- Two reasons the retry was impossible to find: the Papers card hid itself when
-- a paper had no page images yet, and the note that said "try again" carried no
-- way to do it. Both fixed here.
-- Run after 071. Safe to re-run.
-- ============================================================================

create or replace function papers_to_read()
returns json
language sql security definer set search_path = public as $$
  with who as (select coalesce(viewing_student(), auth.uid()) as sid)
  select coalesce(json_agg(row_to_json(t) order by t.created_at desc), '[]'::json)
  from (
    select p.id, p.exam, p.title, p.created_at,
           (select count(*) from paper_pages pp where pp.paper_id = p.id) as pages_total,
           (select count(*) from paper_pages pp where pp.paper_id = p.id and pp.done) as pages_done,
           (select count(*) from problems q where q.paper_id = p.id) as questions,
           (select j.status from parse_jobs j where j.paper_id = p.id order by j.created_at desc limit 1) as status
    from papers p, who
    where p.student_id = who.sid
  ) t;
$$;

grant execute on function papers_to_read() to authenticated;

-- the note now says which paper it is about, so it can offer the retry itself
create or replace function parse_note()
returns json
language sql security definer set search_path = public as $$
  select row_to_json(t) from (
    select id, note, status, added, unanswered, strand, paper_id
    from parse_jobs
    where student_id = coalesce(viewing_student(), auth.uid())
      and status in ('done','failed') and coalesce(note,'') <> '' and not seen
    order by updated_at desc limit 1
  ) t;
$$;

grant execute on function parse_note() to authenticated;
