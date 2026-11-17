-- ============================================================================
-- 005_answer_keys.sql
-- Resolves the 25 questions that had no auto-markable key.
--   * 12 get a key, set by hand from the study guide.
--   * 13 are marked manual on purpose: constructions, proofs, multi-part
--     fill-ins and "give five solutions" cannot be judged by string match, and
--     a fake key would mark a correct boy wrong.
-- Run after 002/003. Safe to re-run.
-- ============================================================================

alter table problem_answers add column if not exists mark_mode text default 'auto';
alter table problem_answers add column if not exists mark_note text;

-- ---- keys set by hand ------------------------------------------------------
update problem_answers set answer_key = $k$1,1,2,3,5,8,13$k$, mark_mode='auto',
  mark_note = 'Fibonacci from the shallow diagonals of Pascal triangle'
 where chapter = 5 and idx = 13;

update problem_answers set answer_key = $k$120,4896,210,56,34,525$k$, mark_mode='auto',
  mark_note = 'six parts in order (a)-(f); all six required'
 where chapter = 6 and idx = 1;

update problem_answers set answer_key = $k$63,9$k$, mark_mode='auto',
  mark_note = 'row 63, column 9; the word form is accepted'
 where chapter = 7 and idx = 6;

update problem_answers set answer_key = $k$4,8,12,16$k$, mark_mode='auto',
  mark_note = 'the four areas in order'
 where chapter = 14 and idx = 7;

update problem_answers set answer_key = $k$6,6,16,217$k$, mark_mode='auto',
  mark_note = 'parts (a)-(d) in order'
 where chapter = 15 and idx = 7;

update problem_answers set answer_key = $k$64/27$k$, mark_mode='auto',
  mark_note = 'the ratio (4/3)^3; 2.37 accepted'
 where chapter = 16 and idx = 10;

update problem_answers set answer_key = $k$1/512$k$, mark_mode='auto',
  mark_note = 'the exact value of the sum; 0.00195 accepted'
 where chapter = 21 and idx = 8;

update problem_answers set answer_key = $k$11010,101110,1011010,1100$k$, mark_mode='auto',
  mark_note = 'parts (a)-(d) in base 2'
 where chapter = 22 and idx = 1;

update problem_answers set answer_key = $k$103111,22665$k$, mark_mode='auto',
  mark_note = '(a) in base 4 then (b) in base 8'
 where chapter = 22 and idx = 2;

update problem_answers set answer_key = $k$23,36,1755,15462$k$, mark_mode='auto',
  mark_note = 'the four values in base 10, in order'
 where chapter = 22 and idx = 4;

update problem_answers set answer_key = $k$2,11,20,22,101$k$, mark_mode='auto',
  mark_note = 'the base-3 column for 2,4,6,8,10'
 where chapter = 22 and idx = 5;

update problem_answers set answer_key = $k$47,586$k$, mark_mode='auto',
  mark_note = '(1202) base 3 then (4321) base 5'
 where chapter = 22 and idx = 6;

-- ---- manual on purpose ----------------------------------------------------
update problem_answers set mark_mode='manual', answer_key=null,
  mark_note='Four separate patterns; he must show all four. Mark by eye.'
 where chapter = 1 and idx = 1;
update problem_answers set mark_mode='manual', answer_key=null,
  mark_note='Any five valid solutions count. Mark by eye.'
 where chapter = 3 and idx = 1;
update problem_answers set mark_mode='manual', answer_key=null,
  mark_note='Fill-in-the-blanks; the order he writes them is his own.'
 where chapter = 5 and idx = 1;
update problem_answers set mark_mode='manual', answer_key=null,
  mark_note='Fill-in-the-blanks in four rows.'
 where chapter = 5 and idx = 2;
update problem_answers set mark_mode='manual', answer_key=null,
  mark_note='A drawing. Mark by eye against the book figure.'
 where chapter = 5 and idx = 3;
update problem_answers set mark_mode='manual', answer_key=null,
  mark_note='A construction. Mark by eye against the book figure.'
 where chapter = 14 and idx = 1;
update problem_answers set mark_mode='manual', answer_key=null,
  mark_note='A whole grid of entries; mark row by row.'
 where chapter = 15 and idx = 6;
update problem_answers set mark_mode='manual', answer_key=null,
  mark_note='A proof by comparison. Mark the reasoning, not a number.'
 where chapter = 21 and idx = 9;
update problem_answers set mark_mode='manual', answer_key=null,
  mark_note='A disproof of two claims. Mark the reasoning.'
 where chapter = 21 and idx = 11;
update problem_answers set mark_mode='manual', answer_key=null,
  mark_note='A bound proved by pairing. Mark the reasoning.'
 where chapter = 21 and idx = 12;
update problem_answers set mark_mode='manual', answer_key=null,
  mark_note='Six expanded forms. Mark by eye.'
 where chapter = 22 and idx = 3;
update problem_answers set mark_mode='manual', answer_key=null,
  mark_note='A multiplication table in base 6. Mark by eye.'
 where chapter = 22 and idx = 7;
update problem_answers set mark_mode='manual', answer_key=null,
  mark_note='A multiplication table in base 8. Mark by eye.'
 where chapter = 22 and idx = 9;

-- ---- anything still unkeyed is manual -------------------------------------
update problem_answers set mark_mode='manual'
 where answer_key is null and coalesce(mark_mode,'auto') <> 'manual';

-- ---- check ----------------------------------------------------------------
-- select mark_mode, count(*) from problem_answers group by 1;
-- expect: auto 275, manual 13
