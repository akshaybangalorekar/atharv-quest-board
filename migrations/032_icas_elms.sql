-- ============================================================================
-- 032_icas_elms.sql
-- Starter banks for ICAS Mathematics (Paper D, Year 6: 40 questions in 60
-- minutes, strands number and arithmetic, algebra and patterns, chance and
-- data, measures and units, space and geometry) and for the McKinnon ELMS
-- entrance test, which is mathematics only, set at Year 6 standard.
-- Every answer was computed, not guessed. Replace with real papers as they come.
-- Run after 031. Safe to re-run.
-- ============================================================================

insert into chapters (n,title,pages,examples,practice,tier,source) values (121,'ICAS Maths · Number and arithmetic',null,0,14,1,'icas') on conflict (n) do update set practice=excluded.practice;
insert into problems (chapter, idx, prompt, difficulty, technique_tags, source) values
  (121,1,$q$What is 249 × 22?$q$,2,array['Number and arithmetic']::text[],'icas'),
  (121,2,$q$What is 221 × 19?$q$,2,array['Number and arithmetic']::text[],'icas'),
  (121,3,$q$What is 218 × 15?$q$,2,array['Number and arithmetic']::text[],'icas'),
  (121,4,$q$What is 269 × 27?$q$,2,array['Number and arithmetic']::text[],'icas'),
  (121,5,$q$What is 405 × 19?$q$,2,array['Number and arithmetic']::text[],'icas'),
  (121,6,$q$What is 194 × 29?$q$,2,array['Number and arithmetic']::text[],'icas'),
  (121,7,$q$What is 442 × 28?$q$,2,array['Number and arithmetic']::text[],'icas'),
  (121,8,$q$What is 121 × 20?$q$,2,array['Number and arithmetic']::text[],'icas'),
  (121,9,$q$Write 2 and 3/8 as an improper fraction.$q$,2,array['Number and arithmetic']::text[],'icas'),
  (121,10,$q$Write 1 and 5/6 as an improper fraction.$q$,2,array['Number and arithmetic']::text[],'icas'),
  (121,11,$q$Write 1 and 9/10 as an improper fraction.$q$,2,array['Number and arithmetic']::text[],'icas'),
  (121,12,$q$Write 2 and 7/12 as an improper fraction.$q$,2,array['Number and arithmetic']::text[],'icas'),
  (121,13,$q$A bike costs $80. In a sale it is reduced by 15%. What is the new price?$q$,2,array['Number and arithmetic']::text[],'icas'),
  (121,14,$q$A bike costs $120. In a sale it is reduced by 40%. What is the new price?$q$,2,array['Number and arithmetic']::text[],'icas')
on conflict (chapter, idx) do nothing;
insert into problem_answers (chapter, idx, answer, method, answer_key, mark_mode, solved_by, verified) values
  (121,1,$q$5478 — 249 × 22 = 5478.$q$,$q$249 × 22 = 5478.$q$,$q$5478$q$,'auto','llm',false),
  (121,2,$q$4199 — 221 × 19 = 4199.$q$,$q$221 × 19 = 4199.$q$,$q$4199$q$,'auto','llm',false),
  (121,3,$q$3270 — 218 × 15 = 3270.$q$,$q$218 × 15 = 3270.$q$,$q$3270$q$,'auto','llm',false),
  (121,4,$q$7263 — 269 × 27 = 7263.$q$,$q$269 × 27 = 7263.$q$,$q$7263$q$,'auto','llm',false),
  (121,5,$q$7695 — 405 × 19 = 7695.$q$,$q$405 × 19 = 7695.$q$,$q$7695$q$,'auto','llm',false),
  (121,6,$q$5626 — 194 × 29 = 5626.$q$,$q$194 × 29 = 5626.$q$,$q$5626$q$,'auto','llm',false),
  (121,7,$q$12376 — 442 × 28 = 12376.$q$,$q$442 × 28 = 12376.$q$,$q$12376$q$,'auto','llm',false),
  (121,8,$q$2420 — 121 × 20 = 2420.$q$,$q$121 × 20 = 2420.$q$,$q$2420$q$,'auto','llm',false),
  (121,9,$q$19/8 — 2 = 16/8, add 3.$q$,$q$2 = 16/8, add 3.$q$,$q$19/8$q$,'auto','llm',false),
  (121,10,$q$11/6 — 1 = 6/6, add 5.$q$,$q$1 = 6/6, add 5.$q$,$q$11/6$q$,'auto','llm',false),
  (121,11,$q$19/10 — 1 = 10/10, add 9.$q$,$q$1 = 10/10, add 9.$q$,$q$19/10$q$,'auto','llm',false),
  (121,12,$q$31/12 — 2 = 24/12, add 7.$q$,$q$2 = 24/12, add 7.$q$,$q$31/12$q$,'auto','llm',false),
  (121,13,$q$68 — 15% of $80 = $12.$q$,$q$15% of $80 = $12.$q$,$q$68$q$,'auto','llm',false),
  (121,14,$q$72 — 40% of $120 = $48.$q$,$q$40% of $120 = $48.$q$,$q$72$q$,'auto','llm',false)
on conflict (chapter, idx) do update set answer_key=excluded.answer_key, method=excluded.method;
insert into chapters (n,title,pages,examples,practice,tier,source) values (122,'ICAS Maths · Algebra and patterns',null,0,11,1,'icas') on conflict (n) do update set practice=excluded.practice;
insert into problems (chapter, idx, prompt, difficulty, technique_tags, source) values
  (122,1,$q$What is the next term? 5, 8, 11, 14, …$q$,2,array['Algebra and patterns']::text[],'icas'),
  (122,2,$q$What is the next term? 3, 12, 21, 30, …$q$,2,array['Algebra and patterns']::text[],'icas'),
  (122,3,$q$What is the next term? 5, 13, 21, 29, …$q$,2,array['Algebra and patterns']::text[],'icas'),
  (122,4,$q$What is the next term? 9, 16, 23, 30, …$q$,2,array['Algebra and patterns']::text[],'icas'),
  (122,5,$q$What is the next term? 3, 6, 9, 12, …$q$,2,array['Algebra and patterns']::text[],'icas'),
  (122,6,$q$A rule says: multiply by 3, then add 3. What comes out if you put 5 in?$q$,2,array['Algebra and patterns']::text[],'icas'),
  (122,7,$q$A rule says: multiply by 3, then add 4. What comes out if you put 5 in?$q$,2,array['Algebra and patterns']::text[],'icas'),
  (122,8,$q$A rule says: multiply by 3, then add 2. What comes out if you put 5 in?$q$,2,array['Algebra and patterns']::text[],'icas'),
  (122,9,$q$If □ + 7 = 18, what is □?$q$,2,array['Algebra and patterns']::text[],'icas'),
  (122,10,$q$If □ + 7 = 12, what is □?$q$,2,array['Algebra and patterns']::text[],'icas'),
  (122,11,$q$If □ + 7 = 19, what is □?$q$,2,array['Algebra and patterns']::text[],'icas')
on conflict (chapter, idx) do nothing;
insert into problem_answers (chapter, idx, answer, method, answer_key, mark_mode, solved_by, verified) values
  (122,1,$q$17 — Add 3 each time.$q$,$q$Add 3 each time.$q$,$q$17$q$,'auto','llm',false),
  (122,2,$q$39 — Add 9 each time.$q$,$q$Add 9 each time.$q$,$q$39$q$,'auto','llm',false),
  (122,3,$q$37 — Add 8 each time.$q$,$q$Add 8 each time.$q$,$q$37$q$,'auto','llm',false),
  (122,4,$q$37 — Add 7 each time.$q$,$q$Add 7 each time.$q$,$q$37$q$,'auto','llm',false),
  (122,5,$q$15 — Add 3 each time.$q$,$q$Add 3 each time.$q$,$q$15$q$,'auto','llm',false),
  (122,6,$q$18 — 3 × 5 = 15, then add 3.$q$,$q$3 × 5 = 15, then add 3.$q$,$q$18$q$,'auto','llm',false),
  (122,7,$q$19 — 3 × 5 = 15, then add 4.$q$,$q$3 × 5 = 15, then add 4.$q$,$q$19$q$,'auto','llm',false),
  (122,8,$q$17 — 3 × 5 = 15, then add 2.$q$,$q$3 × 5 = 15, then add 2.$q$,$q$17$q$,'auto','llm',false),
  (122,9,$q$11 — Subtract 7 from 18.$q$,$q$Subtract 7 from 18.$q$,$q$11$q$,'auto','llm',false),
  (122,10,$q$5 — Subtract 7 from 12.$q$,$q$Subtract 7 from 12.$q$,$q$5$q$,'auto','llm',false),
  (122,11,$q$12 — Subtract 7 from 19.$q$,$q$Subtract 7 from 19.$q$,$q$12$q$,'auto','llm',false)
on conflict (chapter, idx) do update set answer_key=excluded.answer_key, method=excluded.method;
insert into chapters (n,title,pages,examples,practice,tier,source) values (123,'ICAS Maths · Chance and data',null,0,11,1,'icas') on conflict (n) do update set practice=excluded.practice;
insert into problems (chapter, idx, prompt, difficulty, technique_tags, source) values
  (123,1,$q$A bag has 2 red and 5 blue counters. What is the chance of a blue one? Give a fraction.$q$,2,array['Chance and data']::text[],'icas'),
  (123,2,$q$A bag has 5 red and 7 blue counters. What is the chance of a blue one? Give a fraction.$q$,2,array['Chance and data']::text[],'icas'),
  (123,3,$q$A bag has 2 red and 6 blue counters. What is the chance of a blue one? Give a fraction.$q$,2,array['Chance and data']::text[],'icas'),
  (123,4,$q$A bag has 3 red and 4 blue counters. What is the chance of a blue one? Give a fraction.$q$,2,array['Chance and data']::text[],'icas'),
  (123,5,$q$Find the range of: 18, 15, 7, 15, 3$q$,2,array['Chance and data']::text[],'icas'),
  (123,6,$q$Find the range of: 4, 4, 18, 4, 14$q$,2,array['Chance and data']::text[],'icas'),
  (123,7,$q$Find the range of: 16, 6, 11, 19, 18$q$,2,array['Chance and data']::text[],'icas'),
  (123,8,$q$Find the range of: 4, 18, 6, 7, 12$q$,2,array['Chance and data']::text[],'icas'),
  (123,9,$q$What is the median of: 20, 6, 4, 30?$q$,2,array['Chance and data']::text[],'icas'),
  (123,10,$q$What is the median of: 19, 15, 30, 28?$q$,2,array['Chance and data']::text[],'icas'),
  (123,11,$q$What is the median of: 17, 22, 4, 5?$q$,2,array['Chance and data']::text[],'icas')
on conflict (chapter, idx) do nothing;
insert into problem_answers (chapter, idx, answer, method, answer_key, mark_mode, solved_by, verified) values
  (123,1,$q$5/7 — 5 of 7 are blue.$q$,$q$5 of 7 are blue.$q$,$q$5/7$q$,'auto','llm',false),
  (123,2,$q$7/12 — 7 of 12 are blue.$q$,$q$7 of 12 are blue.$q$,$q$7/12$q$,'auto','llm',false),
  (123,3,$q$3/4 — 6 of 8 are blue.$q$,$q$6 of 8 are blue.$q$,$q$3/4$q$,'auto','llm',false),
  (123,4,$q$4/7 — 4 of 7 are blue.$q$,$q$4 of 7 are blue.$q$,$q$4/7$q$,'auto','llm',false),
  (123,5,$q$15 — Largest 18 minus smallest 3.$q$,$q$Largest 18 minus smallest 3.$q$,$q$15$q$,'auto','llm',false),
  (123,6,$q$14 — Largest 18 minus smallest 4.$q$,$q$Largest 18 minus smallest 4.$q$,$q$14$q$,'auto','llm',false),
  (123,7,$q$13 — Largest 19 minus smallest 6.$q$,$q$Largest 19 minus smallest 6.$q$,$q$13$q$,'auto','llm',false),
  (123,8,$q$14 — Largest 18 minus smallest 4.$q$,$q$Largest 18 minus smallest 4.$q$,$q$14$q$,'auto','llm',false),
  (123,9,$q$13 — Order them, then average the middle two.$q$,$q$Order them, then average the middle two.$q$,$q$13$q$,'auto','llm',false),
  (123,10,$q$23.5 — Order them, then average the middle two.$q$,$q$Order them, then average the middle two.$q$,$q$23.5$q$,'auto','llm',false),
  (123,11,$q$11 — Order them, then average the middle two.$q$,$q$Order them, then average the middle two.$q$,$q$11$q$,'auto','llm',false)
on conflict (chapter, idx) do update set answer_key=excluded.answer_key, method=excluded.method;
insert into chapters (n,title,pages,examples,practice,tier,source) values (124,'ICAS Maths · Measures and units',null,0,10,1,'icas') on conflict (n) do update set practice=excluded.practice;
insert into problems (chapter, idx, prompt, difficulty, technique_tags, source) values
  (124,1,$q$How many centimetres are in 0.75 metres?$q$,2,array['Measures and units']::text[],'icas'),
  (124,2,$q$How many centimetres are in 2.25 metres?$q$,2,array['Measures and units']::text[],'icas'),
  (124,3,$q$How many centimetres are in 1.5 metres?$q$,2,array['Measures and units']::text[],'icas'),
  (124,4,$q$A lesson runs for 1 hours 40 minutes. How many minutes is that?$q$,2,array['Measures and units']::text[],'icas'),
  (124,5,$q$A lesson runs for 2 hours 15 minutes. How many minutes is that?$q$,2,array['Measures and units']::text[],'icas'),
  (124,6,$q$A lesson runs for 2 hours 25 minutes. How many minutes is that?$q$,2,array['Measures and units']::text[],'icas'),
  (124,7,$q$A lesson runs for 1 hours 15 minutes. How many minutes is that?$q$,2,array['Measures and units']::text[],'icas'),
  (124,8,$q$A rectangle is 8 cm by 5 cm. What is its perimeter?$q$,2,array['Measures and units']::text[],'icas'),
  (124,9,$q$A rectangle is 8 cm by 9 cm. What is its perimeter?$q$,2,array['Measures and units']::text[],'icas'),
  (124,10,$q$A rectangle is 6 cm by 4 cm. What is its perimeter?$q$,2,array['Measures and units']::text[],'icas')
on conflict (chapter, idx) do nothing;
insert into problem_answers (chapter, idx, answer, method, answer_key, mark_mode, solved_by, verified) values
  (124,1,$q$75 — Multiply by 100.$q$,$q$Multiply by 100.$q$,$q$75$q$,'auto','llm',false),
  (124,2,$q$225 — Multiply by 100.$q$,$q$Multiply by 100.$q$,$q$225$q$,'auto','llm',false),
  (124,3,$q$150 — Multiply by 100.$q$,$q$Multiply by 100.$q$,$q$150$q$,'auto','llm',false),
  (124,4,$q$100 — 1×60 = 60, add 40.$q$,$q$1×60 = 60, add 40.$q$,$q$100$q$,'auto','llm',false),
  (124,5,$q$135 — 2×60 = 120, add 15.$q$,$q$2×60 = 120, add 15.$q$,$q$135$q$,'auto','llm',false),
  (124,6,$q$145 — 2×60 = 120, add 25.$q$,$q$2×60 = 120, add 25.$q$,$q$145$q$,'auto','llm',false),
  (124,7,$q$75 — 1×60 = 60, add 15.$q$,$q$1×60 = 60, add 15.$q$,$q$75$q$,'auto','llm',false),
  (124,8,$q$26 — 2 × (8 + 5).$q$,$q$2 × (8 + 5).$q$,$q$26$q$,'auto','llm',false),
  (124,9,$q$34 — 2 × (8 + 9).$q$,$q$2 × (8 + 9).$q$,$q$34$q$,'auto','llm',false),
  (124,10,$q$20 — 2 × (6 + 4).$q$,$q$2 × (6 + 4).$q$,$q$20$q$,'auto','llm',false)
on conflict (chapter, idx) do update set answer_key=excluded.answer_key, method=excluded.method;
insert into chapters (n,title,pages,examples,practice,tier,source) values (125,'ICAS Maths · Space and geometry',null,0,7,1,'icas') on conflict (n) do update set practice=excluded.practice;
insert into problems (chapter, idx, prompt, difficulty, technique_tags, source) values
  (125,1,$q$Two angles on a straight line are 48° and x°. What is x?$q$,2,array['Space and geometry']::text[],'icas'),
  (125,2,$q$Two angles on a straight line are 35° and x°. What is x?$q$,2,array['Space and geometry']::text[],'icas'),
  (125,3,$q$How many faces does a hexagonal prism have?$q$,2,array['Space and geometry']::text[],'icas'),
  (125,4,$q$How many faces does a square pyramid have?$q$,2,array['Space and geometry']::text[],'icas'),
  (125,5,$q$A cube has edges of 7 cm. What is its volume?$q$,2,array['Space and geometry']::text[],'icas'),
  (125,6,$q$A cube has edges of 9 cm. What is its volume?$q$,2,array['Space and geometry']::text[],'icas'),
  (125,7,$q$A cube has edges of 3 cm. What is its volume?$q$,2,array['Space and geometry']::text[],'icas')
on conflict (chapter, idx) do nothing;
insert into problem_answers (chapter, idx, answer, method, answer_key, mark_mode, solved_by, verified) values
  (125,1,$q$132 — Angles on a straight line add to 180°.$q$,$q$Angles on a straight line add to 180°.$q$,$q$132$q$,'auto','llm',false),
  (125,2,$q$145 — Angles on a straight line add to 180°.$q$,$q$Angles on a straight line add to 180°.$q$,$q$145$q$,'auto','llm',false),
  (125,3,$q$8 — Count the flat faces.$q$,$q$Count the flat faces.$q$,$q$8$q$,'auto','llm',false),
  (125,4,$q$5 — Count the flat faces.$q$,$q$Count the flat faces.$q$,$q$5$q$,'auto','llm',false),
  (125,5,$q$343 — 7 × 7 × 7.$q$,$q$7 × 7 × 7.$q$,$q$343$q$,'auto','llm',false),
  (125,6,$q$729 — 9 × 9 × 9.$q$,$q$9 × 9 × 9.$q$,$q$729$q$,'auto','llm',false),
  (125,7,$q$27 — 3 × 3 × 3.$q$,$q$3 × 3 × 3.$q$,$q$27$q$,'auto','llm',false)
on conflict (chapter, idx) do update set answer_key=excluded.answer_key, method=excluded.method;
insert into exam_map (exam, chapter, idx) select 'ICAS Maths', chapter, idx from problems where source='icas' on conflict do nothing;
insert into chapters (n,title,pages,examples,practice,tier,source) values (131,'ELMS · Number',null,0,7,1,'elms') on conflict (n) do update set practice=excluded.practice;
insert into problems (chapter, idx, prompt, difficulty, technique_tags, source) values
  (131,1,$q$Work out 18 × 20 without a calculator.$q$,2,array['Number']::text[],'elms'),
  (131,2,$q$Work out 17 × 15 without a calculator.$q$,2,array['Number']::text[],'elms'),
  (131,3,$q$Work out 19 × 15 without a calculator.$q$,2,array['Number']::text[],'elms'),
  (131,4,$q$Work out 15 × 18 without a calculator.$q$,2,array['Number']::text[],'elms'),
  (131,5,$q$Work out 24 × 14 without a calculator.$q$,2,array['Number']::text[],'elms'),
  (131,6,$q$Work out 11 × 20 without a calculator.$q$,2,array['Number']::text[],'elms'),
  (131,7,$q$Work out 18 × 12 without a calculator.$q$,2,array['Number']::text[],'elms')
on conflict (chapter, idx) do nothing;
insert into problem_answers (chapter, idx, answer, method, answer_key, mark_mode, solved_by, verified) values
  (131,1,$q$360 — 18×20 = 360.$q$,$q$18×20 = 360.$q$,$q$360$q$,'auto','llm',false),
  (131,2,$q$255 — 17×15 = 255.$q$,$q$17×15 = 255.$q$,$q$255$q$,'auto','llm',false),
  (131,3,$q$285 — 19×15 = 285.$q$,$q$19×15 = 285.$q$,$q$285$q$,'auto','llm',false),
  (131,4,$q$270 — 15×18 = 270.$q$,$q$15×18 = 270.$q$,$q$270$q$,'auto','llm',false),
  (131,5,$q$336 — 24×14 = 336.$q$,$q$24×14 = 336.$q$,$q$336$q$,'auto','llm',false),
  (131,6,$q$220 — 11×20 = 220.$q$,$q$11×20 = 220.$q$,$q$220$q$,'auto','llm',false),
  (131,7,$q$216 — 18×12 = 216.$q$,$q$18×12 = 216.$q$,$q$216$q$,'auto','llm',false)
on conflict (chapter, idx) do update set answer_key=excluded.answer_key, method=excluded.method;
insert into chapters (n,title,pages,examples,practice,tier,source) values (132,'ELMS · Fractions and decimals',null,0,2,1,'elms') on conflict (n) do update set practice=excluded.practice;
insert into problems (chapter, idx, prompt, difficulty, technique_tags, source) values
  (132,1,$q$What is 2/3 + 1/6? Give the answer as a fraction in simplest form.$q$,2,array['Fractions and decimals']::text[],'elms'),
  (132,2,$q$What is 5/8 + 1/6? Give the answer as a fraction in simplest form.$q$,2,array['Fractions and decimals']::text[],'elms')
on conflict (chapter, idx) do nothing;
insert into problem_answers (chapter, idx, answer, method, answer_key, mark_mode, solved_by, verified) values
  (132,1,$q$5/6 — Common denominator, add, simplify.$q$,$q$Common denominator, add, simplify.$q$,$q$5/6$q$,'auto','llm',false),
  (132,2,$q$19/24 — Common denominator, add, simplify.$q$,$q$Common denominator, add, simplify.$q$,$q$19/24$q$,'auto','llm',false)
on conflict (chapter, idx) do update set answer_key=excluded.answer_key, method=excluded.method;
insert into chapters (n,title,pages,examples,practice,tier,source) values (133,'ELMS · Ratio and proportion',null,0,4,1,'elms') on conflict (n) do update set practice=excluded.practice;
insert into problems (chapter, idx, prompt, difficulty, technique_tags, source) values
  (133,1,$q$$72 is shared in the ratio 3:5. What is the smaller share?$q$,2,array['Ratio and proportion']::text[],'elms'),
  (133,2,$q$$60 is shared in the ratio 3:5. What is the smaller share?$q$,2,array['Ratio and proportion']::text[],'elms'),
  (133,3,$q$$48 is shared in the ratio 2:4. What is the smaller share?$q$,2,array['Ratio and proportion']::text[],'elms'),
  (133,4,$q$$60 is shared in the ratio 5:7. What is the smaller share?$q$,2,array['Ratio and proportion']::text[],'elms')
on conflict (chapter, idx) do nothing;
insert into problem_answers (chapter, idx, answer, method, answer_key, mark_mode, solved_by, verified) values
  (133,1,$q$27 — 8 parts of $9 each.$q$,$q$8 parts of $9 each.$q$,$q$27$q$,'auto','llm',false),
  (133,2,$q$22 — 8 parts of $7 each.$q$,$q$8 parts of $7 each.$q$,$q$22$q$,'auto','llm',false),
  (133,3,$q$16 — 6 parts of $8 each.$q$,$q$6 parts of $8 each.$q$,$q$16$q$,'auto','llm',false),
  (133,4,$q$25 — 12 parts of $5 each.$q$,$q$12 parts of $5 each.$q$,$q$25$q$,'auto','llm',false)
on conflict (chapter, idx) do update set answer_key=excluded.answer_key, method=excluded.method;
insert into chapters (n,title,pages,examples,practice,tier,source) values (134,'ELMS · Percentage',null,0,5,1,'elms') on conflict (n) do update set practice=excluded.practice;
insert into problems (chapter, idx, prompt, difficulty, technique_tags, source) values
  (134,1,$q$Find 20% of $90.$q$,2,array['Percentage']::text[],'elms'),
  (134,2,$q$Find 15% of $40.$q$,2,array['Percentage']::text[],'elms'),
  (134,3,$q$Find 20% of $60.$q$,2,array['Percentage']::text[],'elms'),
  (134,4,$q$Find 15% of $60.$q$,2,array['Percentage']::text[],'elms'),
  (134,5,$q$Find 12% of $90.$q$,2,array['Percentage']::text[],'elms')
on conflict (chapter, idx) do nothing;
insert into problem_answers (chapter, idx, answer, method, answer_key, mark_mode, solved_by, verified) values
  (134,1,$q$18 — 20/100 × 90.$q$,$q$20/100 × 90.$q$,$q$18$q$,'auto','llm',false),
  (134,2,$q$6 — 15/100 × 40.$q$,$q$15/100 × 40.$q$,$q$6$q$,'auto','llm',false),
  (134,3,$q$12 — 20/100 × 60.$q$,$q$20/100 × 60.$q$,$q$12$q$,'auto','llm',false),
  (134,4,$q$9 — 15/100 × 60.$q$,$q$15/100 × 60.$q$,$q$9$q$,'auto','llm',false),
  (134,5,$q$10 — 12/100 × 90.$q$,$q$12/100 × 90.$q$,$q$10$q$,'auto','llm',false)
on conflict (chapter, idx) do update set answer_key=excluded.answer_key, method=excluded.method;
insert into chapters (n,title,pages,examples,practice,tier,source) values (135,'ELMS · Measurement and geometry',null,0,7,1,'elms') on conflict (n) do update set practice=excluded.practice;
insert into problems (chapter, idx, prompt, difficulty, technique_tags, source) values
  (135,1,$q$A rectangle is 11 m by 6 m. A path 1 m wide runs inside its edge. What is the area of the path?$q$,2,array['Measurement and geometry']::text[],'elms'),
  (135,2,$q$A rectangle is 9 m by 6 m. A path 1 m wide runs inside its edge. What is the area of the path?$q$,2,array['Measurement and geometry']::text[],'elms'),
  (135,3,$q$A rectangle is 11 m by 9 m. A path 1 m wide runs inside its edge. What is the area of the path?$q$,2,array['Measurement and geometry']::text[],'elms'),
  (135,4,$q$A rectangle is 13 m by 9 m. A path 1 m wide runs inside its edge. What is the area of the path?$q$,2,array['Measurement and geometry']::text[],'elms'),
  (135,5,$q$A rectangle is 14 m by 7 m. A path 1 m wide runs inside its edge. What is the area of the path?$q$,2,array['Measurement and geometry']::text[],'elms'),
  (135,6,$q$A square has perimeter 44 cm. What is its area?$q$,2,array['Measurement and geometry']::text[],'elms'),
  (135,7,$q$A square has perimeter 36 cm. What is its area?$q$,2,array['Measurement and geometry']::text[],'elms')
on conflict (chapter, idx) do nothing;
insert into problem_answers (chapter, idx, answer, method, answer_key, mark_mode, solved_by, verified) values
  (135,1,$q$30 — Whole 66, inner 36.$q$,$q$Whole 66, inner 36.$q$,$q$30$q$,'auto','llm',false),
  (135,2,$q$26 — Whole 54, inner 28.$q$,$q$Whole 54, inner 28.$q$,$q$26$q$,'auto','llm',false),
  (135,3,$q$36 — Whole 99, inner 63.$q$,$q$Whole 99, inner 63.$q$,$q$36$q$,'auto','llm',false),
  (135,4,$q$40 — Whole 117, inner 77.$q$,$q$Whole 117, inner 77.$q$,$q$40$q$,'auto','llm',false),
  (135,5,$q$38 — Whole 98, inner 60.$q$,$q$Whole 98, inner 60.$q$,$q$38$q$,'auto','llm',false),
  (135,6,$q$121 — Side 11 cm, so area 11².$q$,$q$Side 11 cm, so area 11².$q$,$q$121$q$,'auto','llm',false),
  (135,7,$q$81 — Side 9 cm, so area 9².$q$,$q$Side 9 cm, so area 9².$q$,$q$81$q$,'auto','llm',false)
on conflict (chapter, idx) do update set answer_key=excluded.answer_key, method=excluded.method;
insert into chapters (n,title,pages,examples,practice,tier,source) values (136,'ELMS · Data',null,0,4,1,'elms') on conflict (n) do update set practice=excluded.practice;
insert into problems (chapter, idx, prompt, difficulty, technique_tags, source) values
  (136,1,$q$Five scores are 39, 12, 18, 31, 13. What is the mean?$q$,2,array['Data']::text[],'elms'),
  (136,2,$q$Five scores are 14, 14, 21, 39, 35. What is the mean?$q$,2,array['Data']::text[],'elms'),
  (136,3,$q$Five scores are 32, 11, 16, 39, 36. What is the mean?$q$,2,array['Data']::text[],'elms'),
  (136,4,$q$Five scores are 28, 29, 27, 29, 31. What is the mean?$q$,2,array['Data']::text[],'elms')
on conflict (chapter, idx) do nothing;
insert into problem_answers (chapter, idx, answer, method, answer_key, mark_mode, solved_by, verified) values
  (136,1,$q$22.6 — Total 113 ÷ 5.$q$,$q$Total 113 ÷ 5.$q$,$q$22.6$q$,'auto','llm',false),
  (136,2,$q$24.6 — Total 123 ÷ 5.$q$,$q$Total 123 ÷ 5.$q$,$q$24.6$q$,'auto','llm',false),
  (136,3,$q$26.8 — Total 134 ÷ 5.$q$,$q$Total 134 ÷ 5.$q$,$q$26.8$q$,'auto','llm',false),
  (136,4,$q$28.8 — Total 144 ÷ 5.$q$,$q$Total 144 ÷ 5.$q$,$q$28.8$q$,'auto','llm',false)
on conflict (chapter, idx) do update set answer_key=excluded.answer_key, method=excluded.method;
insert into exam_map (exam, chapter, idx) select 'ELMS', chapter, idx from problems where source='elms' on conflict do nothing;

-- the dates we actually know, from the published calendars
delete from exam_calendar where exam in ('ICAS Maths', 'ELMS');
insert into exam_calendar (student_id, exam, sits_on, date_status, target, note)
select p.student_id, v.exam, v.sits_on, v.date_status, v.target, v.note
from profiles p,
     (values
       ('ICAS Maths', date '2027-08-23', 'confirmed', '40 questions in 60 minutes',
        'ICAS Mathematics window 23-27 August 2027. Paper D for Year 6.'),
       ('ELMS', date '2027-09-06', 'expected', 'Mathematics only, Year 6 standard',
        'McKinnon Secondary College, Enhanced Learning in Maths and Science. Held early September; the exact day is set by the school in Term 3.')
     ) as v(exam, sits_on, date_status, target, note);

