-- ============================================================================
-- 026_amc_bank.sql
-- AMC gets its own block of chapters, so nothing from the book or Division J
-- can drift into it. Empty until AMC papers are uploaded.
-- Run after 025. Safe to re-run.
-- ============================================================================

insert into exam_banks (exam, kind, chapter_from, chapter_to, note) values
  ('AMC Upper Primary', 'amc', 151, 165, 'Australian Maths Competition, Upper Primary. 30 questions, 60 minutes, 135 marks.')
on conflict (exam) do nothing;
