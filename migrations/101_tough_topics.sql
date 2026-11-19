-- ============================================================================
-- 101_tough_topics.sql
-- Which official topics he is finding hard, in plain words, for the coach and
-- for the parent: accuracy and pace per topic, worst first. The coach is told to
-- work on the top ones; the parent sees the same list.
-- Run after 100. Safe to re-run.
-- ============================================================================

create or replace function tough_topics(p_limit int default 5)
returns json
language sql security definer set search_path = public as $$
  with who as (select coalesce(viewing_student(), auth.uid()) as sid),
  rows as (
    select c.n, c.title, c.source,
           count(*) as tries,
           count(*) filter (where a.ok) as correct,
           coalesce(round(avg(a.seconds) filter (where a.seconds > 0)), 0) as avg_seconds,
           max(a.created_at) as last_tried
    from chapters c
    join attempts a on a.chapter = c.n
    cross join who
    where a.student_id = who.sid
    group by c.n, c.title, c.source
  )
  select coalesce(json_agg(row_to_json(t) order by t.accuracy asc, t.tries desc), '[]'::json)
  from (
    select n, title,
           tries, correct,
           case when tries = 0 then 0 else round(100.0 * correct / tries) end as accuracy,
           avg_seconds,
           last_tried::date as last_tried,
           case
             when tries < 3 then 'too few to judge'
             when (100.0 * correct / tries) < 50 then 'struggling'
             when (100.0 * correct / tries) < 75 then 'shaky'
             when avg_seconds > 150 then 'slow'
             else 'coping' end as verdict
    from rows
    where tries >= 1
  ) t
  limit greatest(1, coalesce(p_limit, 5));
$$;

grant execute on function tough_topics(int) to authenticated;
