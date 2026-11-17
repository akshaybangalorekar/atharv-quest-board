-- ============================================================================
-- 039_calendar_full.sql
-- The whole season on the calendar, so the flight chart shows every exam he is
-- actually preparing for — Camberwell and Kilvington included.
--
-- Where a date is published, it says confirmed. Where the school has not yet
-- announced it, the row says expected and carries the reasoning in the note, so
-- nobody mistakes a guess for a fact.
-- Run after 038. Safe to re-run.
-- ============================================================================

delete from exam_calendar
 where exam in ('AAS numerical reasoning', 'Edutest numerical reasoning',
                'AMC Upper Primary', 'APSMO Division J', 'ICAS Maths', 'ELMS');

insert into exam_calendar (student_id, exam, sits_on, date_status, target, note)
select p.student_id, v.exam, v.sits_on, v.date_status, v.target, v.note
from profiles p,
     (values
       ('AAS numerical reasoning',   date '2027-02-06', 'expected',  'Numerical reasoning and maths',
        'Camberwell Grammar scholarship test. The school has not published 2027; this is the first Saturday of February, where it has fallen in recent years.'),
       ('Edutest numerical reasoning', date '2027-02-20', 'expected', 'Numerical reasoning',
        'Kilvington Grammar, sat through Edutest. Expected about a fortnight after Camberwell; confirm when the school publishes.'),
       ('APSMO Division J',          date '2027-05-05', 'expected',  'Five questions in thirty minutes',
        'Contest 1 of 4, held at school in early May. Later contests run through to September.'),
       ('AMC Upper Primary',         date '2027-08-03', 'confirmed', '30 questions in 60 minutes, 135 marks',
        'Australian Maths Competition, 3 to 5 August 2027.'),
       ('ICAS Maths',                date '2027-08-23', 'confirmed', '40 questions in 60 minutes',
        'ICAS Mathematics window, 23 to 27 August 2027. Paper D for Year 6.'),
       ('ELMS',                      date '2027-09-06', 'expected',  'Mathematics only, Year 6 standard',
        'McKinnon Secondary College enhanced learning entry. Held early September; the exact day is set by the school in Term 3.')
     ) as v(exam, sits_on, date_status, target, note);
