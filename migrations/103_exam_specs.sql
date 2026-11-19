-- ============================================================================
-- 103_exam_specs.sql
-- The real length of each paper, from the provider, with its sections — so the
-- app can say plainly "30 minutes in the exam" and never leave a bare number
-- that could be mistaken for practice time.
-- Run after 102. Safe to re-run.
-- ============================================================================

create or replace function exam_specs()
returns json
language sql security definer set search_path = public as $$
  select json_agg(row_to_json(t) order by t.sort)
  from (values
    (1, 'AAS', 'Camberwell Grammar', 45, 40,
     'Each paper is 40 to 50 minutes, sat in two sessions with a 20-minute break. The maths section is the part we can test.',
     json_build_array(json_build_object('part','Mathematics','minutes',45))),

    (2, 'Edutest', 'Kilvington Grammar', 135, 60,
     'Five sections: verbal reasoning 30, numerical reasoning 30, reading comprehension 30, mathematics 30, written expression 15. We have questions for two of the five.',
     json_build_array(
       json_build_object('part','Verbal reasoning','minutes',30),
       json_build_object('part','Numerical reasoning','minutes',30),
       json_build_object('part','Reading comprehension','minutes',30),
       json_build_object('part','Mathematics','minutes',30),
       json_build_object('part','Written expression','minutes',15))),

    (3, 'Edutest', 'McKinnon Secondary (ELMS)', 30, 30,
     'McKinnon sits the mathematics section only: 30 minutes.',
     json_build_array(json_build_object('part','Mathematics','minutes',30))),

    (4, 'Olympiad', 'Division J', 30, 30,
     'Five questions in 30 minutes, four contests across the year. That is the contest time, not practice time.',
     json_build_array(json_build_object('part','Each contest','minutes',30))),

    (5, 'AMC', 'Upper Primary', 60, 60,
     'Thirty questions in 60 minutes: twenty-five multiple choice, five integer answers, 135 marks, no penalty for a wrong answer.',
     json_build_array(json_build_object('part','Whole paper','minutes',60))),

    (6, 'ICAS', 'Mathematics Paper D', 60, 60,
     'Forty questions in 60 minutes. The last five are typed answers rather than multiple choice.',
     json_build_array(json_build_object('part','Whole paper','minutes',60)))
  ) as t(sort, family, sits, minutes, questions, note, sections);
$$;

grant execute on function exam_specs() to authenticated;
