-- ============================================================================
-- 098_timetable.sql
-- What the plan actually is, per exam and per topic, and whether he is ahead of
-- it, level with it, or behind. A topic's target date is spread evenly between
-- today and the exam, so the answer moves on its own as the days pass.
-- A topic counts as done when his preparedness for it reaches 60 per cent.
-- Run after 097. Safe to re-run.
-- ============================================================================

create or replace function timetable()
returns json
language sql security definer set search_path = public as $$
  with who as (select coalesce(viewing_student(), auth.uid()) as sid),
  today as (select (now() at time zone 'Australia/Melbourne')::date as d),
  fams as (
    select b.family,
           case b.family when 'olympiad' then 'Olympiad' when 'aas' then 'AAS'
                         when 'edutest' then 'Edutest' when 'amc' then 'AMC'
                         when 'icas' then 'ICAS' else initcap(b.family) end as label,
           array_agg(distinct case when b.kind = 'olympiad' then 'book' else b.kind end) as kinds
    from exam_banks b where b.family is not null group by b.family
  ),
  dates as (
    select f.family, f.label, f.kinds,
           (select min(c.sits_on) from exam_calendar c, who
             where c.student_id = who.sid and c.sits_on >= (select d from today)
               and (lower(c.exam) like '%' || lower(f.label) || '%'
                    or (f.family = 'edutest' and lower(c.exam) like '%elms%')
                    or (f.family = 'edutest' and lower(c.exam) like '%edutest%')
                    or (f.family = 'olympiad' and lower(c.exam) like '%apsmo%'))) as exam_on
    from fams f
  ),
  topics as (
    select d.family, d.label, d.exam_on, c.n, c.title,
           coalesce(t.questions, 0) as questions,
           coalesce(t.preparedness, 0) as preparedness
    from dates d
    join chapters c on c.source = any(d.kinds)
    left join lateral (
      select (x->>'questions')::int as questions, (x->>'preparedness')::int as preparedness
      from json_array_elements(topic_readiness(d.family)) x
      where (x->>'n')::int = c.n
    ) t on true
  ),
  planned as (
    select family, label, exam_on, n, title, questions, preparedness,
           row_number() over (partition by family order by n) as seq,
           count(*) over (partition by family) as of_n
    from topics
  ),
  targeted as (
    select p.*,
           (select d from today) as today,
           case when exam_on is null or exam_on <= (select d from today) then null
                else (select d from today)
                     + round((exam_on - (select d from today)) * p.seq::numeric / p.of_n)::int
           end as target_on
    from planned p
  )
  select coalesce(json_agg(row_to_json(g) order by g.exam_on nulls last, g.label), '[]'::json)
  from (
    select family, label, exam_on,
           case when exam_on is null then null else exam_on - today end as days_left,
           of_n as topics_all,
           count(*) filter (where preparedness >= 60) as topics_done,
           count(*) filter (where preparedness > 0) as topics_started,
           count(*) filter (where target_on is not null and target_on <= today) as due_by_now,
           count(*) filter (where target_on is not null and target_on < today and preparedness < 60) as behind,
           json_agg(json_build_object(
             'n', n, 'title', title, 'questions', questions, 'preparedness', preparedness,
             'target_on', target_on,
             'state', case
               when preparedness >= 60 then 'done'
               when target_on is null then 'no_date'
               when target_on < today then 'behind'
               when target_on = today then 'due'
               else 'ahead' end
           ) order by seq) as rows
    from targeted
    group by family, label, exam_on, today, of_n
  ) g;
$$;

grant execute on function timetable() to authenticated;
