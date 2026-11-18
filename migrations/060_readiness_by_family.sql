-- ============================================================================
-- 060_readiness_by_family.sql
-- The parent table listed seven banks as if they were seven exams. Three of
-- them are families: Edutest is Kilvington and McKinnon together, Olympiad is
-- the book and Division J together. This view reports one row per family, with
-- the schools it covers, and the same wording for every verdict.
-- Run after 059. Safe to re-run.
-- ============================================================================

drop view if exists v_exam_readiness;
create view v_exam_readiness as
with fams as (
  select family, string_agg(school, ' + ' order by school) as schools,
         array_agg(case when kind = 'olympiad' then 'book' else kind end) as kinds
  from exam_banks
  where family is not null
  group by family
),
counts as (
  select f.family, f.schools, f.kinds,
         (select count(*) from problems p where p.source = any(f.kinds)) as items,
         (select count(*) from attempts a join problems p
            on p.chapter = a.chapter and p.idx = a.idx
          where p.source = any(f.kinds) and a.student_id = auth.uid()) as practised,
         (select count(distinct a.chapter) from attempts a join problems p
            on p.chapter = a.chapter and p.idx = a.idx
          where p.source = any(f.kinds) and a.student_id = auth.uid() and a.ok) as chapters_with_marks
  from fams f
)
select
  family,
  case family when 'olympiad' then 'Olympiad' when 'aas' then 'AAS' when 'edutest' then 'Edutest'
              when 'amc' then 'AMC' when 'icas' then 'ICAS' else initcap(family) end as exam,
  schools,
  items,
  practised,
  case when items = 0 then 0 else round(100.0 * practised / items) end as pct_practised,
  case
    when items = 0 then 'no_content'
    when items < 30 then 'thin'
    when practised < 20 then 'too_early'
    when practised < 60 then 'in_progress'
    when practised >= 60 and chapters_with_marks >= greatest(3, (items / 60)) then 'ready'
    else 'in_progress'
  end as verdict,
  case
    when items = 0 then 'Nothing loaded for this exam yet.'
    when items < 30 then 'Only ' || items || ' questions loaded. About 30 is the minimum to judge anything.'
    when practised = 0 then items || ' questions ready, none tried yet.'
    when practised < 20 then practised || ' of ' || items || ' tried. Too early to say.'
    else practised || ' of ' || items || ' tried.'
  end as message
from counts;
