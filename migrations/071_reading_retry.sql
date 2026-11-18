-- ============================================================================
-- 071_reading_retry.sql
-- A reading can fail — a model call drops, the app is closed mid-paper — and
-- until now there was no way to start it again. Now the parent view lists the
-- papers, says how far each one got, and offers to read the rest or read it all
-- again.
-- Run after 070. Safe to re-run.
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
      and exists (select 1 from paper_pages pp where pp.paper_id = p.id)
  ) t;
$$;

grant execute on function papers_to_read() to authenticated;

create or replace function restart_reading(p_paper bigint, p_all boolean default false)
returns json
language plpgsql security definer set search_path = public as $$
declare
  v uuid := coalesce(viewing_student(), auth.uid());
  v_job bigint;
  v_exam text;
begin
  if not (is_parent() or v = auth.uid()) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  select exam into v_exam from papers where id = p_paper and student_id = v;
  if v_exam is null then raise exception 'no such paper' using errcode = '22023'; end if;

  update paper_pages set done = false
   where paper_id = p_paper and (p_all or not done);

  select id into v_job from parse_jobs
   where paper_id = p_paper and status = 'running'
   order by created_at desc limit 1;

  if v_job is null then
    insert into parse_jobs (student_id, paper_id, exam, status)
    values (v, p_paper, v_exam, 'running') returning id into v_job;
  end if;

  return json_build_object('job', v_job, 'exam', v_exam);
end $$;

grant execute on function restart_reading(bigint, boolean) to authenticated;
