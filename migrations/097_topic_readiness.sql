-- ============================================================================
-- 097_topic_readiness.sql
-- One number per topic, used by the child's screen and the parent's table alike,
-- so the two can never disagree.
--   confidence  — how much of this topic's content can be trusted: has an answer,
--                 has a figure where one is needed, and was not written blind.
--   preparedness — how far HE is through it: questions answered correctly, out of
--                 the questions that exist.
-- Run after 096. Safe to re-run.
-- ============================================================================

create or replace function topic_readiness(p_family text)
returns json
language sql security definer set search_path = public as $$
  with who as (select coalesce(viewing_student(), auth.uid()) as sid),
  fams as (
    select b.kind,
           case when b.kind = 'olympiad' then 'book' else b.kind end as src
    from exam_banks b
    where lower(b.family) = lower(p_family) or lower(b.kind) = lower(p_family)
  ),
  kinds as (
    select array_agg(distinct src) as ks from fams
    union all select array_agg(distinct kind) from fams
  ),
  allkinds as (select array_agg(distinct k) as ks from (select unnest(ks) as k from kinds) z)
  select coalesce(json_agg(row_to_json(t) order by t.n), '[]'::json)
  from (
    select c.n, c.title,
           (select count(*) from problems p where p.chapter = c.n) as questions,
           (select count(*) from problems p
              join problem_answers a on a.chapter = p.chapter and a.idx = p.idx
             where p.chapter = c.n and coalesce(btrim(a.answer), '') <> '') as answered,
           (select count(*) from problems p
             where p.chapter = c.n
               and (p.diagram_box is not null or p.diagram_svg is not null or p.diagram_url is not null)) as with_figure,
           (select count(*) from problems p where p.chapter = c.n and p.paper_id is not null) as from_files,
           (select count(*) from problems p where p.chapter = c.n and p.paper_id is null) as by_coach,
           (select count(*) from attempts a, who
             where a.student_id = who.sid and a.chapter = c.n) as tried,
           (select count(*) from attempts a, who
             where a.student_id = who.sid and a.chapter = c.n and a.ok) as right,
           case
             when (select count(*) from problems p where p.chapter = c.n) = 0 then 0
             else round(100.0 *
               (select count(*) from problems p
                  join problem_answers a on a.chapter = p.chapter and a.idx = p.idx
                 where p.chapter = c.n and coalesce(btrim(a.answer), '') <> '')
               / (select count(*) from problems p where p.chapter = c.n))
           end as confidence,
           case
             when (select count(*) from problems p where p.chapter = c.n) = 0 then 0
             else least(100, round(100.0 *
               (select count(*) from attempts a, who where a.student_id = who.sid and a.chapter = c.n and a.ok)
               / (select count(*) from problems p where p.chapter = c.n)))
           end as preparedness
    from chapters c, allkinds ak
    where c.source = any(ak.ks)
  ) t;
$$;

grant execute on function topic_readiness(text) to authenticated;
