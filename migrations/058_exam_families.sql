-- ============================================================================
-- 058_exam_families.sql
-- Three of these exams are families, not single papers:
--   Edutest — Kilvington, and McKinnon's ELMS. Same paper family, same year
--             level; each school sets its own cut-off.
--   AAS     — Camberwell.
--   Olympiad— the book, and APSMO Division J, which is olympiad work too.
-- The app shows one card per family, with the schools listed under it.
-- Run after 057. Safe to re-run.
-- ============================================================================

alter table exam_banks add column if not exists family text;
alter table exam_banks add column if not exists school text;

update exam_banks set family = 'olympiad', school = 'The book'                    where kind = 'olympiad';
update exam_banks set family = 'olympiad', school = 'APSMO Division J'            where kind = 'apsmo';
update exam_banks set family = 'aas',      school = 'Camberwell Grammar'          where kind = 'aas';
update exam_banks set family = 'edutest',  school = 'Kilvington Grammar'          where kind = 'edutest';
update exam_banks set family = 'edutest',  school = 'McKinnon Secondary (ELMS)'   where kind = 'elms';
update exam_banks set family = 'amc',      school = 'Australian Maths Competition' where kind = 'amc';
update exam_banks set family = 'icas',     school = 'ICAS Mathematics'            where kind = 'icas';

update exam_banks set family = coalesce(family, kind), school = coalesce(school, exam) where family is null;
