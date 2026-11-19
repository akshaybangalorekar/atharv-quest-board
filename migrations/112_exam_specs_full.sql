-- ============================================================================
-- 103_exam_specs.sql — every section each paper has, as the provider lists it,
-- with the topics to prepare under each section. Nothing filtered out.
-- ============================================================================
create or replace function exam_specs()
returns json
language sql security definer set search_path = public as $$
  select json_agg(row_to_json(t) order by t.sort)
  from (values
    (1, 'AAS', 'Camberwell Grammar', 45, '',
     'Four papers, each 40 to 50 minutes, in two sessions with a 20-minute recess. Written expression is 25 to 30 minutes and is one long piece.',
     json_build_array(json_build_object('part','General reasoning','minutes',45,'topics',json_build_array('Verbal reasoning','Mathematical reasoning','Figural reasoning','Spatial reasoning')),
       json_build_object('part','Reading comprehension','minutes',45,'topics',json_build_array('Main idea','Locating detail','Inference','Vocabulary in context','Author purpose')),
       json_build_object('part','Mathematics','minutes',45,'topics',json_build_array('Number and algebra','Measurement and geometry','Statistics and probability','Problem solving')),
       json_build_object('part','Written expression','minutes',30,'topics',json_build_array('Persuasive writing','Narrative writing','Structure and paragraphs','Vocabulary','Sentence structure','Punctuation and spelling'))),
     'four papers, in two sessions', 'a 20-minute recess between the two sessions'),

    (2, 'Edutest', 'Kilvington Grammar', 135, '',
     'Five tests, 30 minutes each except written expression at 15. Two ability tests and three achievement tests.',
     json_build_array(json_build_object('part','Verbal reasoning','minutes',30,'topics',json_build_array('Vocabulary','Analogies','Word relationships','Logic and deduction')),
       json_build_object('part','Numerical reasoning','minutes',30,'topics',json_build_array('Number series','Patterns','Tables and graphs','Problem solving')),
       json_build_object('part','Reading comprehension','minutes',30,'topics',json_build_array('Main idea','Locating detail','Inference','Vocabulary in context')),
       json_build_object('part','Mathematics','minutes',30,'topics',json_build_array('Number and algebra','Measurement and geometry','Statistics and probability','Problem solving')),
       json_build_object('part','Written expression','minutes',15,'topics',json_build_array('Persuasive writing','Narrative writing','Structure','Vocabulary','Punctuation and spelling'))),
     'five separately timed tests', 'a short break between each test'),

    (3, 'Edutest', 'McKinnon Secondary (ELMS)', 30, '',
     'McKinnon sits the mathematics test only. The full Edutest has five tests; this sitting uses one.',
     json_build_array(json_build_object('part','Mathematics','minutes',30,'topics',json_build_array('Number and algebra','Measurement and geometry','Statistics and probability','Problem solving'))),
     'one test, timed on its own', 'no break — it is a single 30-minute test'),

    (4, 'Olympiad', 'Division J', 30, '',
     'Five questions in 30 minutes. Four contests across the year, each its own paper.',
     json_build_array(json_build_object('part','Each contest','minutes',30,'topics',json_build_array('Arithmetic','Number patterns','Geometry','Counting and logic','Working backwards'))),
     'four contests, each separately timed', 'months apart — one contest in each of four rounds'),

    (5, 'AMC', 'Upper Primary', 60, '',
     'Thirty questions in 60 minutes: twenty-five multiple choice, five integer answers. 135 marks, no penalty.',
     json_build_array(json_build_object('part','Whole paper','minutes',60,'topics',json_build_array('Number','Measurement','Geometry','Space','Chance and data','Pattern and algebra','Problem solving'))),
     'one paper, timed as a whole', 'no break — it is a single 60-minute paper'),

    (6, 'ICAS', 'Mathematics Paper D', 60, '',
     'Forty questions in 60 minutes. The last five are typed answers rather than multiple choice.',
     json_build_array(json_build_object('part','Whole paper','minutes',60,'topics',json_build_array('Number and algebra','Measurement and geometry','Statistics and probability','Problem solving'))),
     'one paper, timed as a whole', 'no break — it is a single 60-minute paper'),

    (99, 'unused', 'unused', 0, '', 'unused', '[]'::json, 'unused', 'unused')
  ) as t(sort, family, sits, minutes, questions, note, sections, timing, breaks)
  where t.sort <> 99;
$$;

grant execute on function exam_specs() to authenticated;
