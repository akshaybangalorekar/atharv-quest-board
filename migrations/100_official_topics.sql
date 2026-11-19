-- ============================================================================
-- 100_official_topics.sql
-- The topic lists come from what each provider publishes, not from anything
-- uploaded here:
--   AMC      — amt.edu.au/amc: basic arithmetic; fractions and ratios; algebra
--              and pre-algebra; geometry; measurement; statistics and
--              probability; problem-solving (including enumeration)
--   ICAS     — icasassessments.com: number and arithmetic; algebra and patterns;
--              chance and data; measures and units; space and geometry
--   AAS      — academicassessment.com.au: numbers; measurements; space and
--              geometry; data; patterns and algebra; working mathematically
--   Edutest  — edutest.com.au: numerical reasoning is series, matrices,
--              arithmetical reasoning, deduction; mathematics is number,
--              measurement, algebra, space, data
--   APSMO    — apsmo.edu.au publishes no topic list: Division J is four contests
--              of five problems. Its strands are the four contests plus the
--              preparation kit, which is what it actually provides.
-- Run after 099. Safe to re-run.
-- ============================================================================

delete from problem_answers where chapter >= 100;
delete from problems where chapter >= 100;
delete from chapters where n >= 100;

select seed_topics('AAS numerical reasoning', array[
  'Numbers','Measurements','Space and geometry','Data','Patterns and algebra','Working mathematically']);

select seed_topics('Edutest numerical reasoning', array[
  'Series','Matrices','Arithmetical reasoning','Deduction']);

select seed_topics('ELMS', array[
  'Number','Measurement','Algebra','Space','Data']);

select seed_topics('ICAS Maths', array[
  'Number and arithmetic','Algebra and patterns','Chance and data','Measures and units','Space and geometry']);

select seed_topics('AMC Upper Primary', array[
  'Basic arithmetic','Fractions and ratios','Algebra and pre-algebra','Geometry',
  'Measurement','Statistics and probability','Problem-solving']);

-- APSMO publishes no topic list, and Olympiad shows only the study guide's chapters.
-- Nothing is seeded for it: its contests are sat, not taught.

update chapters set practice = (select count(*) from problems p where p.chapter = chapters.n);
