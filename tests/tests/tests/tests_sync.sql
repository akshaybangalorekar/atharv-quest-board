-- tests/tests_sync.sql — the parent and the child must see the same database.
--
-- Run this after any change to truth(), coach_context() or the screens' data calls.
-- Every line must read "same". Anything else is an out-of-sync bug, and the failing
-- key names which part of the app disagrees.

begin;

select set_config('request.jwt.claims',
  json_build_object('sub', (select student_id::text from profiles where name is not null limit 1),
                    'role', 'authenticated')::text, true);

-- the child's own view
create temp table as_child on commit drop as
select truth() as t, coach_context() as c;

-- the parent's view of the same child
select set_config('request.jwt.claims',
  json_build_object('sub', (select parent_id::text from guardians limit 1),
                    'role', 'authenticated')::text, true);

create temp table as_parent on commit drop as
select truth() as t, coach_context() as c;

-- one row per thing that must agree, with the two values side by side
select k.name,
       (a.t #>> k.path::text[]) as child_sees,
       (b.t #>> k.path::text[]) as parent_sees,
       case when (a.t #>> k.path::text[]) is not distinct from (b.t #>> k.path::text[]) then 'same' else 'DIFFERENT' end as verdict
from as_child a, as_parent b,
     (values ('questions', '{content,total}'),
             ('attempts',  '{attempts,total}'),
             ('sessions',  '{sessions,last_7}'),
             ('exams',     '{journey,exams}'),
             ('topics',    '{journey,topics_total}'),
             ('tests',     '{tests,count}')) as k(name, path)
order by k.name;

-- the library and the bank, which the coach answers from
select 'library' as name,
       (a.c->>'library') = (b.c->>'library') as same,
       left(a.c->>'library', 90) as what_she_sees
from as_child a, as_parent b
union all
select 'bank',
       (a.c->>'bank') = (b.c->>'bank'),
       left(a.c->>'bank', 90)
from as_child a, as_parent b
union all
select 'material',
       json_array_length(a.c->'material') = json_array_length(b.c->'material'),
       (json_array_length(a.c->'material'))::text || ' passages'
from as_child a, as_parent b;

-- the dates the timetable prints, exam by exam
select x->>'label' as exam,
       x->>'exam_on' as date,
       case when (select count(*) from json_array_elements(b.t->'families') y
                  where y->>'label' = x->>'label' and y->>'exam_on' is not distinct from x->>'exam_on') = 1
            then 'same' else 'DIFFERENT' end as verdict
from as_child a, as_parent b, json_array_elements(a.t->'families') x
order by exam;

rollback;
