-- ============================================================================
-- 103_exam_specs.sql — the real shape of each paper, from the provider.
-- ============================================================================
create or replace function exam_specs()
returns json
language sql security definer set search_path = public as $$
  select json_agg(row_to_json(t) order by t.sort)
  from (values
    (1, 'AAS', 'Camberwell Grammar', 45, 40,
     'Each paper is 40 to 50 minutes, sat as two separately timed papers with a break between them. The mathematics paper is the part we can test.',
     json_build_array(json_build_object('part','Mathematics','minutes',45)),
     'two papers, each separately timed', 'a 20-minute break between the two papers'),

    (2, 'Edutest', 'Kilvington Grammar', 135, 60,
     'Five tests: verbal reasoning 30, numerical reasoning 30, reading comprehension 30, mathematics 30, written expression 15. We have questions for two of the five.',
     json_build_array(json_build_object('part','Verbal reasoning','minutes',30),json_build_object('part','Numerical reasoning','minutes',30),json_build_object('part','Reading comprehension','minutes',30),json_build_object('part','Mathematics','minutes',30),json_build_object('part','Written expression','minutes',15)),
     'five separately timed tests', 'a short break between each test'),

    (3, 'Edutest', 'McKinnon Secondary (ELMS)', 30, 30,
     'McKinnon sits the mathematics test only: one 30-minute test.',
     json_build_array(json_build_object('part','Mathematics','minutes',30)),
     'one test, timed on its own', 'no break — it is a single 30-minute test'),

    (4, 'Olympiad', 'Division J', 30, 30,
     'Five questions in 30 minutes. Four contests across the year, each one its own paper.',
     json_build_array(json_build_object('part','Each contest','minutes',30)),
     'four contests, each separately timed', 'months apart — one contest in each of four rounds'),

    (5, 'AMC', 'Upper Primary', 60, 60,
     'Thirty questions in 60 minutes: twenty-five multiple choice, five integer answers. 135 marks, no penalty for a wrong answer.',
     json_build_array(json_build_object('part','Whole paper','minutes',60)),
     'one paper, timed as a whole', 'no break — it is a single 60-minute paper'),

    (6, 'ICAS', 'Mathematics Paper D', 60, 60,
     'Forty questions in 60 minutes. The last five are typed answers rather than multiple choice.',
     json_build_array(json_build_object('part','Whole paper','minutes',60)),
     'one paper, timed as a whole', 'no break — it is a single 60-minute paper'),

    (99, 'unused', 'unused', 0, 0, 'unused', '[]'::json, 'unused', 'unused')
  ) as t(sort, family, sits, minutes, questions, note, sections, timing, breaks)
  where t.sort <> 99;
$$;

grant execute on function exam_specs() to authenticated;
