-- ============================================================================
-- 077_file_status.sql
-- Each sample carries its own tally: how many questions came out of it, how many
-- of those have a figure, and how many have an answer. Kept in the database, so
-- it survives a reload and reads the same on every device.
-- Run after 076. Safe to re-run.
-- ============================================================================

create or replace function papers_to_read()
returns json
language sql security definer set search_path = public as $$
  with who as (select coalesce(viewing_student(), auth.uid()) as sid)
  select coalesce(json_agg(row_to_json(t) order by t.created_at desc), '[]'::json)
  from (
    select p.id, p.exam, p.title, p.created_at, p.pages as claimed_pages,
           (select count(*) from paper_pages pp where pp.paper_id = p.id) as pages_total,
           (select count(*) from paper_pages pp where pp.paper_id = p.id and pp.done) as pages_done,
           (select count(*) from problems q where q.paper_id = p.id) as questions,
           (select count(*) from problems q where q.paper_id = p.id
              and (q.diagram_url is not null or q.diagram_svg is not null or q.diagram_box is not null)) as diagrams,
           (select count(*) from problems q
              join problem_answers a on a.chapter = q.chapter and a.idx = q.idx
             where q.paper_id = p.id and coalesce(btrim(a.answer_key), '') <> '') as answers,
           (select j.status from parse_jobs j where j.paper_id = p.id order by j.created_at desc limit 1) as status
    from papers p, who
    where p.student_id = who.sid
  ) t;
$$;

grant execute on function papers_to_read() to authenticated;
