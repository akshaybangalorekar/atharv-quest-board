-- ============================================================================
-- 015_exam_registry.sql
-- Reserves a block of chapter numbers for each exam, so questions can be added
-- before any exist. The app's four cards point at these names.
-- Run after 014. Safe to re-run.
-- ============================================================================

insert into exam_banks (exam, kind, chapter_from, chapter_to, note) values
  ('AAS numerical reasoning', 'aas',     101, 110, 'Camberwell Grammar · AAS. Numerical reasoning strands.'),
  ('Edutest numerical reasoning', 'edutest', 111, 120, 'Kilvington Grammar · Edutest. Numerical reasoning strands.'),
  ('ICAS Maths', 'icas',                 121, 130, 'ICAS Mathematics, Paper D.'),
  ('ELMS', 'elms',                       131, 140, 'McKinnon ELMS proxy.')
on conflict (exam) do nothing;

-- the olympiad bank is the book itself
update exam_banks set kind = 'olympiad' where exam = 'Olympiad book';

-- check
-- select exam, kind, chapter_from, chapter_to from exam_banks order by chapter_from;
