-- ============================================================================
-- 027_scholarship_banks.sql
-- Starter banks for AAS, Edutest and ICAS, written in the style those papers use,
-- so the coach has something to teach before real papers are uploaded.
-- Every answer here was computed, not guessed. Replace them with real papers
-- when you have them.
-- Run after 026. Safe to re-run.
-- ============================================================================

insert into chapters (n,title,pages,examples,practice,tier,source) values (101,'AAS numerical reasoning · Patterns and number',null,0,29,1,'aas') on conflict (n) do update set practice=excluded.practice;
insert into problems (chapter, idx, prompt, difficulty, technique_tags, source) values
  (101,1,$q$What comes next in this sequence? 8, 16, 24, 32, …$q$,2,array['Patterns and number']::text[],'aas'),
  (101,2,$q$What comes next in this sequence? 3, 6, 9, 12, …$q$,2,array['Patterns and number']::text[],'aas'),
  (101,3,$q$What comes next in this sequence? 14, 22, 30, 38, 46, …$q$,2,array['Patterns and number']::text[],'aas'),
  (101,4,$q$What comes next? 27, 32, 25, 30, 23, …$q$,2,array['Patterns and number']::text[],'aas'),
  (101,5,$q$What comes next? 10, 13, 6, 9, 2, …$q$,2,array['Patterns and number']::text[],'aas'),
  (101,6,$q$What comes next? 5, 8, 2, 5, -1, …$q$,2,array['Patterns and number']::text[],'aas'),
  (101,7,$q$In a code, DOG is written as EPH. How is DO written?$q$,2,array['Patterns and number']::text[],'aas'),
  (101,8,$q$In a code, CAT is written as DBU. How is CA written?$q$,2,array['Patterns and number']::text[],'aas'),
  (101,9,$q$In a code, DOG is written as GRJ. How is DO written?$q$,2,array['Patterns and number']::text[],'aas'),
  (101,10,$q$Each row of this grid follows the same rule: 0, 4, 8 | 2, 6, 10 | 4, 8, ?. What replaces the question mark?$q$,2,array['Patterns and number']::text[],'aas'),
  (101,11,$q$Each row of this grid follows the same rule: 0, 2, 4 | 6, 8, 10 | 12, 14, ?. What replaces the question mark?$q$,2,array['Patterns and number']::text[],'aas'),
  (101,12,$q$Each row of this grid follows the same rule: 0, 2, 4 | 5, 7, 9 | 10, 12, ?. What replaces the question mark?$q$,2,array['Patterns and number']::text[],'aas'),
  (101,13,$q$A jacket costs $60. It is reduced by 20%. What is the sale price?$q$,2,array['Patterns and number']::text[],'aas'),
  (101,14,$q$A jacket costs $40. It is reduced by 50%. What is the sale price?$q$,2,array['Patterns and number']::text[],'aas'),
  (101,15,$q$A jacket costs $120. It is reduced by 20%. What is the sale price?$q$,2,array['Patterns and number']::text[],'aas'),
  (101,16,$q$$55 is shared in the ratio 2 : 3. What is the larger share?$q$,2,array['Patterns and number']::text[],'aas'),
  (101,17,$q$$96 is shared in the ratio 3 : 5. What is the larger share?$q$,2,array['Patterns and number']::text[],'aas'),
  (101,18,$q$$54 is shared in the ratio 4 : 5. What is the larger share?$q$,2,array['Patterns and number']::text[],'aas'),
  (101,19,$q$A rectangle is 12 cm long and 9 cm wide. What is its area?$q$,2,array['Patterns and number']::text[],'aas'),
  (101,20,$q$A rectangle is 11 cm long and 3 cm wide. What is its area?$q$,2,array['Patterns and number']::text[],'aas'),
  (101,21,$q$Five scores are 6, 27, 13, 14, 23. What is the mean?$q$,2,array['Patterns and number']::text[],'aas'),
  (101,22,$q$Five scores are 25, 23, 16, 24, 25. What is the mean?$q$,2,array['Patterns and number']::text[],'aas'),
  (101,23,$q$Five scores are 8, 16, 27, 12, 25. What is the mean?$q$,2,array['Patterns and number']::text[],'aas'),
  (101,24,$q$A film lasts 3 hours 15 minutes. How many minutes is that in total?$q$,2,array['Patterns and number']::text[],'aas'),
  (101,25,$q$A film lasts 2 hours 30 minutes. How many minutes is that in total?$q$,2,array['Patterns and number']::text[],'aas'),
  (101,26,$q$A film lasts 4 hours 45 minutes. How many minutes is that in total?$q$,2,array['Patterns and number']::text[],'aas'),
  (101,27,$q$Laps swum on Monday: Ava 9; Ben 9; Chloe 7; Dev 12. Who swam the most, and how many?$q$,2,array['Patterns and number']::text[],'aas'),
  (101,28,$q$Laps swum on Monday: Ava 17; Ben 19; Chloe 18; Dev 5. Who swam the most, and how many?$q$,2,array['Patterns and number']::text[],'aas'),
  (101,29,$q$Laps swum on Monday: Ava 13; Ben 17; Chloe 7; Dev 11. Who swam the most, and how many?$q$,2,array['Patterns and number']::text[],'aas')
on conflict (chapter, idx) do nothing;
insert into problem_answers (chapter, idx, answer, method, answer_key, mark_mode, solved_by, verified) values
  (101,1,$q$40 — Each term goes up by 8, so add 8 again.$q$,$q$Each term goes up by 8, so add 8 again.$q$,$q$40$q$,'auto','llm',false),
  (101,2,$q$15 — Each term goes up by 3, so add 3 again.$q$,$q$Each term goes up by 3, so add 3 again.$q$,$q$15$q$,'auto','llm',false),
  (101,3,$q$54 — Each term goes up by 8, so add 8 again.$q$,$q$Each term goes up by 8, so add 8 again.$q$,$q$54$q$,'auto','llm',false),
  (101,4,$q$28 — Two rules alternate: add 5, then subtract 7.$q$,$q$Two rules alternate: add 5, then subtract 7.$q$,$q$28$q$,'auto','llm',false),
  (101,5,$q$5 — Two rules alternate: add 3, then subtract 7.$q$,$q$Two rules alternate: add 3, then subtract 7.$q$,$q$5$q$,'auto','llm',false),
  (101,6,$q$2 — Two rules alternate: add 3, then subtract 6.$q$,$q$Two rules alternate: add 3, then subtract 6.$q$,$q$2$q$,'auto','llm',false),
  (101,7,$q$EP — Each letter moves 1 places forward in the alphabet.$q$,$q$Each letter moves 1 places forward in the alphabet.$q$,$q$EP$q$,'auto','llm',false),
  (101,8,$q$DB — Each letter moves 1 places forward in the alphabet.$q$,$q$Each letter moves 1 places forward in the alphabet.$q$,$q$DB$q$,'auto','llm',false),
  (101,9,$q$GR — Each letter moves 3 places forward in the alphabet.$q$,$q$Each letter moves 3 places forward in the alphabet.$q$,$q$GR$q$,'auto','llm',false),
  (101,10,$q$12 — Going across a row adds 4 each time; going down adds 2.$q$,$q$Going across a row adds 4 each time; going down adds 2.$q$,$q$12$q$,'auto','llm',false),
  (101,11,$q$16 — Going across a row adds 2 each time; going down adds 6.$q$,$q$Going across a row adds 2 each time; going down adds 6.$q$,$q$16$q$,'auto','llm',false),
  (101,12,$q$14 — Going across a row adds 2 each time; going down adds 5.$q$,$q$Going across a row adds 2 each time; going down adds 5.$q$,$q$14$q$,'auto','llm',false),
  (101,13,$q$48 — 20% of $60 is $12, so take that off.$q$,$q$20% of $60 is $12, so take that off.$q$,$q$48$q$,'auto','llm',false),
  (101,14,$q$20 — 50% of $40 is $20, so take that off.$q$,$q$50% of $40 is $20, so take that off.$q$,$q$20$q$,'auto','llm',false),
  (101,15,$q$96 — 20% of $120 is $24, so take that off.$q$,$q$20% of $120 is $24, so take that off.$q$,$q$96$q$,'auto','llm',false),
  (101,16,$q$33 — There are 5 parts, each worth $11; the larger share is 3 parts.$q$,$q$There are 5 parts, each worth $11; the larger share is 3 parts.$q$,$q$33$q$,'auto','llm',false),
  (101,17,$q$60 — There are 8 parts, each worth $12; the larger share is 5 parts.$q$,$q$There are 8 parts, each worth $12; the larger share is 5 parts.$q$,$q$60$q$,'auto','llm',false),
  (101,18,$q$30 — There are 9 parts, each worth $6; the larger share is 5 parts.$q$,$q$There are 9 parts, each worth $6; the larger share is 5 parts.$q$,$q$30$q$,'auto','llm',false),
  (101,19,$q$108 cm² — Area = length × width = 12 × 9.$q$,$q$Area = length × width = 12 × 9.$q$,$q$108 cm²$q$,'auto','llm',false),
  (101,20,$q$33 cm² — Area = length × width = 11 × 3.$q$,$q$Area = length × width = 11 × 3.$q$,$q$33 cm²$q$,'auto','llm',false),
  (101,21,$q$16.6 — Add them to get 83, then divide by 5.$q$,$q$Add them to get 83, then divide by 5.$q$,$q$16.6$q$,'auto','llm',false),
  (101,22,$q$22.6 — Add them to get 113, then divide by 5.$q$,$q$Add them to get 113, then divide by 5.$q$,$q$22.6$q$,'auto','llm',false),
  (101,23,$q$17.6 — Add them to get 88, then divide by 5.$q$,$q$Add them to get 88, then divide by 5.$q$,$q$17.6$q$,'auto','llm',false),
  (101,24,$q$195 — 3 × 60 = 180, plus 15.$q$,$q$3 × 60 = 180, plus 15.$q$,$q$195$q$,'auto','llm',false),
  (101,25,$q$150 — 2 × 60 = 120, plus 30.$q$,$q$2 × 60 = 120, plus 30.$q$,$q$150$q$,'auto','llm',false),
  (101,26,$q$285 — 4 × 60 = 240, plus 45.$q$,$q$4 × 60 = 240, plus 45.$q$,$q$285$q$,'auto','llm',false),
  (101,27,$q$Dev, 12 — Compare the four numbers; the largest is the answer.$q$,$q$Compare the four numbers; the largest is the answer.$q$,$q$Dev, 12$q$,'auto','llm',false),
  (101,28,$q$Ben, 19 — Compare the four numbers; the largest is the answer.$q$,$q$Compare the four numbers; the largest is the answer.$q$,$q$Ben, 19$q$,'auto','llm',false),
  (101,29,$q$Ben, 17 — Compare the four numbers; the largest is the answer.$q$,$q$Compare the four numbers; the largest is the answer.$q$,$q$Ben, 17$q$,'auto','llm',false)
on conflict (chapter, idx) do update set answer_key=excluded.answer_key, method=excluded.method, answer=excluded.answer;
insert into chapters (n,title,pages,examples,practice,tier,source) values (102,'AAS numerical reasoning · Mathematics',null,0,21,1,'aas') on conflict (n) do update set practice=excluded.practice;
insert into problems (chapter, idx, prompt, difficulty, technique_tags, source) values
  (102,1,$q$A jacket costs $40. It is reduced by 25%. What is the sale price?$q$,2,array['Mathematics']::text[],'aas'),
  (102,2,$q$A jacket costs $40. It is reduced by 10%. What is the sale price?$q$,2,array['Mathematics']::text[],'aas'),
  (102,3,$q$A jacket costs $120. It is reduced by 25%. What is the sale price?$q$,2,array['Mathematics']::text[],'aas'),
  (102,4,$q$$50 is shared in the ratio 1 : 4. What is the larger share?$q$,2,array['Mathematics']::text[],'aas'),
  (102,5,$q$$40 is shared in the ratio 3 : 5. What is the larger share?$q$,2,array['Mathematics']::text[],'aas'),
  (102,6,$q$$30 is shared in the ratio 1 : 4. What is the larger share?$q$,2,array['Mathematics']::text[],'aas'),
  (102,7,$q$Pack A has 6 for $4.20. Pack B has 12 for $8.80. Which is better value?$q$,2,array['Mathematics']::text[],'aas'),
  (102,8,$q$Pack A has 6 for $4.20. Pack B has 5 for $3.40. Which is better value?$q$,2,array['Mathematics']::text[],'aas'),
  (102,9,$q$Pack A has 6 for $4.20. Pack B has 4 for $2.90. Which is better value?$q$,2,array['Mathematics']::text[],'aas'),
  (102,10,$q$A rectangle is 8 cm long and 4 cm wide. What is its area?$q$,2,array['Mathematics']::text[],'aas'),
  (102,11,$q$A rectangle is 13 cm long and 7 cm wide. What is its area?$q$,2,array['Mathematics']::text[],'aas'),
  (102,12,$q$A rectangle is 8 cm long and 5 cm wide. What is its area?$q$,2,array['Mathematics']::text[],'aas'),
  (102,13,$q$A garden is 15 m by 9 m. A path 1 m wide runs around the inside edge. What is the area of the path?$q$,2,array['Mathematics']::text[],'aas'),
  (102,14,$q$A garden is 12 m by 8 m. A path 1 m wide runs around the inside edge. What is the area of the path?$q$,2,array['Mathematics']::text[],'aas'),
  (102,15,$q$A garden is 11 m by 8 m. A path 1 m wide runs around the inside edge. What is the area of the path?$q$,2,array['Mathematics']::text[],'aas'),
  (102,16,$q$A bag holds 5 red and 6 blue counters. What is the probability of drawing a red one? Give a fraction.$q$,2,array['Mathematics']::text[],'aas'),
  (102,17,$q$A bag holds 2 red and 4 blue counters. What is the probability of drawing a red one? Give a fraction.$q$,2,array['Mathematics']::text[],'aas'),
  (102,18,$q$A bag holds 6 red and 6 blue counters. What is the probability of drawing a red one? Give a fraction.$q$,2,array['Mathematics']::text[],'aas'),
  (102,19,$q$In 4 years' time a child will be 16. How old were they 3 years ago?$q$,2,array['Mathematics']::text[],'aas'),
  (102,20,$q$In 4 years' time a child will be 14. How old were they 3 years ago?$q$,2,array['Mathematics']::text[],'aas'),
  (102,21,$q$In 4 years' time a child will be 15. How old were they 3 years ago?$q$,2,array['Mathematics']::text[],'aas')
on conflict (chapter, idx) do nothing;
insert into problem_answers (chapter, idx, answer, method, answer_key, mark_mode, solved_by, verified) values
  (102,1,$q$30 — 25% of $40 is $10, so take that off.$q$,$q$25% of $40 is $10, so take that off.$q$,$q$30$q$,'auto','llm',false),
  (102,2,$q$36 — 10% of $40 is $4, so take that off.$q$,$q$10% of $40 is $4, so take that off.$q$,$q$36$q$,'auto','llm',false),
  (102,3,$q$90 — 25% of $120 is $30, so take that off.$q$,$q$25% of $120 is $30, so take that off.$q$,$q$90$q$,'auto','llm',false),
  (102,4,$q$40 — There are 5 parts, each worth $10; the larger share is 4 parts.$q$,$q$There are 5 parts, each worth $10; the larger share is 4 parts.$q$,$q$40$q$,'auto','llm',false),
  (102,5,$q$25 — There are 8 parts, each worth $5; the larger share is 5 parts.$q$,$q$There are 8 parts, each worth $5; the larger share is 5 parts.$q$,$q$25$q$,'auto','llm',false),
  (102,6,$q$24 — There are 5 parts, each worth $6; the larger share is 4 parts.$q$,$q$There are 5 parts, each worth $6; the larger share is 4 parts.$q$,$q$24$q$,'auto','llm',false),
  (102,7,$q$the first — A costs $0.700 each, B costs $0.733 each.$q$,$q$A costs $0.700 each, B costs $0.733 each.$q$,$q$the first$q$,'auto','llm',false),
  (102,8,$q$the second — A costs $0.700 each, B costs $0.680 each.$q$,$q$A costs $0.700 each, B costs $0.680 each.$q$,$q$the second$q$,'auto','llm',false),
  (102,9,$q$the first — A costs $0.700 each, B costs $0.725 each.$q$,$q$A costs $0.700 each, B costs $0.725 each.$q$,$q$the first$q$,'auto','llm',false),
  (102,10,$q$32 cm² — Area = length × width = 8 × 4.$q$,$q$Area = length × width = 8 × 4.$q$,$q$32 cm²$q$,'auto','llm',false),
  (102,11,$q$91 cm² — Area = length × width = 13 × 7.$q$,$q$Area = length × width = 13 × 7.$q$,$q$91 cm²$q$,'auto','llm',false),
  (102,12,$q$40 cm² — Area = length × width = 8 × 5.$q$,$q$Area = length × width = 8 × 5.$q$,$q$40 cm²$q$,'auto','llm',false),
  (102,13,$q$44 — Whole garden 135 m², inner rectangle 91 m²; subtract.$q$,$q$Whole garden 135 m², inner rectangle 91 m²; subtract.$q$,$q$44$q$,'auto','llm',false),
  (102,14,$q$36 — Whole garden 96 m², inner rectangle 60 m²; subtract.$q$,$q$Whole garden 96 m², inner rectangle 60 m²; subtract.$q$,$q$36$q$,'auto','llm',false),
  (102,15,$q$34 — Whole garden 88 m², inner rectangle 54 m²; subtract.$q$,$q$Whole garden 88 m², inner rectangle 54 m²; subtract.$q$,$q$34$q$,'auto','llm',false),
  (102,16,$q$5/11 — 5 favourable out of 11 in total.$q$,$q$5 favourable out of 11 in total.$q$,$q$5/11$q$,'auto','llm',false),
  (102,17,$q$1/3 — 2 favourable out of 6 in total.$q$,$q$2 favourable out of 6 in total.$q$,$q$1/3$q$,'auto','llm',false),
  (102,18,$q$1/2 — 6 favourable out of 12 in total.$q$,$q$6 favourable out of 12 in total.$q$,$q$1/2$q$,'auto','llm',false),
  (102,19,$q$9 — They are 12 now, so three years ago they were 9.$q$,$q$They are 12 now, so three years ago they were 9.$q$,$q$9$q$,'auto','llm',false),
  (102,20,$q$7 — They are 10 now, so three years ago they were 7.$q$,$q$They are 10 now, so three years ago they were 7.$q$,$q$7$q$,'auto','llm',false),
  (102,21,$q$8 — They are 11 now, so three years ago they were 8.$q$,$q$They are 11 now, so three years ago they were 8.$q$,$q$8$q$,'auto','llm',false)
on conflict (chapter, idx) do update set answer_key=excluded.answer_key, method=excluded.method, answer=excluded.answer;
insert into exam_map (exam, chapter, idx) select 'AAS numerical reasoning', chapter, idx from problems where source='aas' on conflict do nothing;
insert into chapters (n,title,pages,examples,practice,tier,source) values (111,'Edutest numerical reasoning · Series and matrices',null,0,14,1,'edutest') on conflict (n) do update set practice=excluded.practice;
insert into problems (chapter, idx, prompt, difficulty, technique_tags, source) values
  (111,1,$q$What comes next in this sequence? 6, 12, 18, 24, …$q$,2,array['Series and matrices']::text[],'edutest'),
  (111,2,$q$What comes next in this sequence? 6, 15, 24, 33, 42, …$q$,2,array['Series and matrices']::text[],'edutest'),
  (111,3,$q$What comes next in this sequence? 18, 27, 36, 45, 54, 63, …$q$,2,array['Series and matrices']::text[],'edutest'),
  (111,4,$q$What comes next? 3, 9, 27, 81, …$q$,2,array['Series and matrices']::text[],'edutest'),
  (111,5,$q$What comes next? 1, 2, 4, 8, …$q$,2,array['Series and matrices']::text[],'edutest'),
  (111,6,$q$What comes next? 2, 4, 8, 16, …$q$,2,array['Series and matrices']::text[],'edutest'),
  (111,7,$q$What comes next? 18, 22, 18, 22, 18, …$q$,2,array['Series and matrices']::text[],'edutest'),
  (111,8,$q$What comes next? 28, 34, 31, 37, 34, …$q$,2,array['Series and matrices']::text[],'edutest'),
  (111,9,$q$What comes next? 17, 21, 15, 19, 13, …$q$,2,array['Series and matrices']::text[],'edutest'),
  (111,10,$q$What comes next? 36, 49, 64, 81, …$q$,2,array['Series and matrices']::text[],'edutest'),
  (111,11,$q$What comes next? 9, 16, 25, 36, …$q$,2,array['Series and matrices']::text[],'edutest'),
  (111,12,$q$Each row of this grid follows the same rule: 0, 2, 4 | 2, 4, 6 | 4, 6, ?. What replaces the question mark?$q$,2,array['Series and matrices']::text[],'edutest'),
  (111,13,$q$Each row of this grid follows the same rule: 0, 4, 8 | 5, 9, 13 | 10, 14, ?. What replaces the question mark?$q$,2,array['Series and matrices']::text[],'edutest'),
  (111,14,$q$Each row of this grid follows the same rule: 0, 4, 8 | 3, 7, 11 | 6, 10, ?. What replaces the question mark?$q$,2,array['Series and matrices']::text[],'edutest')
on conflict (chapter, idx) do nothing;
insert into problem_answers (chapter, idx, answer, method, answer_key, mark_mode, solved_by, verified) values
  (111,1,$q$30 — Each term goes up by 6, so add 6 again.$q$,$q$Each term goes up by 6, so add 6 again.$q$,$q$30$q$,'auto','llm',false),
  (111,2,$q$51 — Each term goes up by 9, so add 9 again.$q$,$q$Each term goes up by 9, so add 9 again.$q$,$q$51$q$,'auto','llm',false),
  (111,3,$q$72 — Each term goes up by 9, so add 9 again.$q$,$q$Each term goes up by 9, so add 9 again.$q$,$q$72$q$,'auto','llm',false),
  (111,4,$q$243 — Each term is multiplied by 3.$q$,$q$Each term is multiplied by 3.$q$,$q$243$q$,'auto','llm',false),
  (111,5,$q$16 — Each term is multiplied by 2.$q$,$q$Each term is multiplied by 2.$q$,$q$16$q$,'auto','llm',false),
  (111,6,$q$32 — Each term is multiplied by 2.$q$,$q$Each term is multiplied by 2.$q$,$q$32$q$,'auto','llm',false),
  (111,7,$q$22 — Two rules alternate: add 4, then subtract 4.$q$,$q$Two rules alternate: add 4, then subtract 4.$q$,$q$22$q$,'auto','llm',false),
  (111,8,$q$40 — Two rules alternate: add 6, then subtract 3.$q$,$q$Two rules alternate: add 6, then subtract 3.$q$,$q$40$q$,'auto','llm',false),
  (111,9,$q$17 — Two rules alternate: add 4, then subtract 6.$q$,$q$Two rules alternate: add 4, then subtract 6.$q$,$q$17$q$,'auto','llm',false),
  (111,10,$q$100 — These are the squares of 6, 7, 8, … so the next is 10².$q$,$q$These are the squares of 6, 7, 8, … so the next is 10².$q$,$q$100$q$,'auto','llm',false),
  (111,11,$q$49 — These are the squares of 3, 4, 5, … so the next is 7².$q$,$q$These are the squares of 3, 4, 5, … so the next is 7².$q$,$q$49$q$,'auto','llm',false),
  (111,12,$q$8 — Going across a row adds 2 each time; going down adds 2.$q$,$q$Going across a row adds 2 each time; going down adds 2.$q$,$q$8$q$,'auto','llm',false),
  (111,13,$q$18 — Going across a row adds 4 each time; going down adds 5.$q$,$q$Going across a row adds 4 each time; going down adds 5.$q$,$q$18$q$,'auto','llm',false),
  (111,14,$q$14 — Going across a row adds 4 each time; going down adds 3.$q$,$q$Going across a row adds 4 each time; going down adds 3.$q$,$q$14$q$,'auto','llm',false)
on conflict (chapter, idx) do update set answer_key=excluded.answer_key, method=excluded.method, answer=excluded.answer;
insert into chapters (n,title,pages,examples,practice,tier,source) values (112,'Edutest numerical reasoning · Arithmetic reasoning',null,0,14,1,'edutest') on conflict (n) do update set practice=excluded.practice;
insert into problems (chapter, idx, prompt, difficulty, technique_tags, source) values
  (112,1,$q$A jacket costs $60. It is reduced by 50%. What is the sale price?$q$,2,array['Arithmetic reasoning']::text[],'edutest'),
  (112,2,$q$A jacket costs $60. It is reduced by 20%. What is the sale price?$q$,2,array['Arithmetic reasoning']::text[],'edutest'),
  (112,3,$q$A jacket costs $150. It is reduced by 20%. What is the sale price?$q$,2,array['Arithmetic reasoning']::text[],'edutest'),
  (112,4,$q$$50 is shared in the ratio 2 : 3. What is the larger share?$q$,2,array['Arithmetic reasoning']::text[],'edutest'),
  (112,5,$q$$50 is shared in the ratio 1 : 4. What is the larger share?$q$,2,array['Arithmetic reasoning']::text[],'edutest'),
  (112,6,$q$$88 is shared in the ratio 3 : 5. What is the larger share?$q$,2,array['Arithmetic reasoning']::text[],'edutest'),
  (112,7,$q$Five scores are 19, 13, 20, 11, 9. What is the mean?$q$,2,array['Arithmetic reasoning']::text[],'edutest'),
  (112,8,$q$Five scores are 13, 9, 16, 21, 23. What is the mean?$q$,2,array['Arithmetic reasoning']::text[],'edutest'),
  (112,9,$q$Five scores are 14, 23, 27, 28, 22. What is the mean?$q$,2,array['Arithmetic reasoning']::text[],'edutest'),
  (112,10,$q$In 4 years' time a child will be 15. How old were they 3 years ago?$q$,2,array['Arithmetic reasoning']::text[],'edutest'),
  (112,11,$q$In 4 years' time a child will be 13. How old were they 3 years ago?$q$,2,array['Arithmetic reasoning']::text[],'edutest'),
  (112,12,$q$Pack A has 8 for $5.60. Pack B has 4 for $2.90. Which is better value?$q$,2,array['Arithmetic reasoning']::text[],'edutest'),
  (112,13,$q$Pack A has 10 for $7.00. Pack B has 5 for $3.40. Which is better value?$q$,2,array['Arithmetic reasoning']::text[],'edutest'),
  (112,14,$q$Pack A has 6 for $4.20. Pack B has 12 for $8.80. Which is better value?$q$,2,array['Arithmetic reasoning']::text[],'edutest')
on conflict (chapter, idx) do nothing;
insert into problem_answers (chapter, idx, answer, method, answer_key, mark_mode, solved_by, verified) values
  (112,1,$q$30 — 50% of $60 is $30, so take that off.$q$,$q$50% of $60 is $30, so take that off.$q$,$q$30$q$,'auto','llm',false),
  (112,2,$q$48 — 20% of $60 is $12, so take that off.$q$,$q$20% of $60 is $12, so take that off.$q$,$q$48$q$,'auto','llm',false),
  (112,3,$q$120 — 20% of $150 is $30, so take that off.$q$,$q$20% of $150 is $30, so take that off.$q$,$q$120$q$,'auto','llm',false),
  (112,4,$q$30 — There are 5 parts, each worth $10; the larger share is 3 parts.$q$,$q$There are 5 parts, each worth $10; the larger share is 3 parts.$q$,$q$30$q$,'auto','llm',false),
  (112,5,$q$40 — There are 5 parts, each worth $10; the larger share is 4 parts.$q$,$q$There are 5 parts, each worth $10; the larger share is 4 parts.$q$,$q$40$q$,'auto','llm',false),
  (112,6,$q$55 — There are 8 parts, each worth $11; the larger share is 5 parts.$q$,$q$There are 8 parts, each worth $11; the larger share is 5 parts.$q$,$q$55$q$,'auto','llm',false),
  (112,7,$q$14.4 — Add them to get 72, then divide by 5.$q$,$q$Add them to get 72, then divide by 5.$q$,$q$14.4$q$,'auto','llm',false),
  (112,8,$q$16.4 — Add them to get 82, then divide by 5.$q$,$q$Add them to get 82, then divide by 5.$q$,$q$16.4$q$,'auto','llm',false),
  (112,9,$q$22.8 — Add them to get 114, then divide by 5.$q$,$q$Add them to get 114, then divide by 5.$q$,$q$22.8$q$,'auto','llm',false),
  (112,10,$q$8 — They are 11 now, so three years ago they were 8.$q$,$q$They are 11 now, so three years ago they were 8.$q$,$q$8$q$,'auto','llm',false),
  (112,11,$q$6 — They are 9 now, so three years ago they were 6.$q$,$q$They are 9 now, so three years ago they were 6.$q$,$q$6$q$,'auto','llm',false),
  (112,12,$q$the first — A costs $0.700 each, B costs $0.725 each.$q$,$q$A costs $0.700 each, B costs $0.725 each.$q$,$q$the first$q$,'auto','llm',false),
  (112,13,$q$the second — A costs $0.700 each, B costs $0.680 each.$q$,$q$A costs $0.700 each, B costs $0.680 each.$q$,$q$the second$q$,'auto','llm',false),
  (112,14,$q$the first — A costs $0.700 each, B costs $0.733 each.$q$,$q$A costs $0.700 each, B costs $0.733 each.$q$,$q$the first$q$,'auto','llm',false)
on conflict (chapter, idx) do update set answer_key=excluded.answer_key, method=excluded.method, answer=excluded.answer;
insert into exam_map (exam, chapter, idx) select 'Edutest numerical reasoning', chapter, idx from problems where source='edutest' on conflict do nothing;
insert into chapters (n,title,pages,examples,practice,tier,source) values (121,'ICAS Maths · Number and algebra',null,0,13,1,'icas') on conflict (n) do update set practice=excluded.practice;
insert into problems (chapter, idx, prompt, difficulty, technique_tags, source) values
  (121,1,$q$A jacket costs $120. It is reduced by 20%. What is the sale price?$q$,2,array['Number and algebra']::text[],'icas'),
  (121,2,$q$A jacket costs $40. It is reduced by 25%. What is the sale price?$q$,2,array['Number and algebra']::text[],'icas'),
  (121,3,$q$A jacket costs $120. It is reduced by 10%. What is the sale price?$q$,2,array['Number and algebra']::text[],'icas'),
  (121,4,$q$$56 is shared in the ratio 3 : 5. What is the larger share?$q$,2,array['Number and algebra']::text[],'icas'),
  (121,5,$q$$55 is shared in the ratio 2 : 3. What is the larger share?$q$,2,array['Number and algebra']::text[],'icas'),
  (121,6,$q$$50 is shared in the ratio 1 : 4. What is the larger share?$q$,2,array['Number and algebra']::text[],'icas'),
  (121,7,$q$Five scores are 11, 6, 4, 4, 26. What is the mean?$q$,2,array['Number and algebra']::text[],'icas'),
  (121,8,$q$Five scores are 21, 24, 9, 5, 6. What is the mean?$q$,2,array['Number and algebra']::text[],'icas'),
  (121,9,$q$Five scores are 21, 30, 15, 4, 5. What is the mean?$q$,2,array['Number and algebra']::text[],'icas'),
  (121,10,$q$A film lasts 2 hours 45 minutes. How many minutes is that in total?$q$,2,array['Number and algebra']::text[],'icas'),
  (121,11,$q$A film lasts 1 hours 15 minutes. How many minutes is that in total?$q$,2,array['Number and algebra']::text[],'icas'),
  (121,12,$q$Pack A has 10 for $7.00. Pack B has 5 for $3.40. Which is better value?$q$,2,array['Number and algebra']::text[],'icas'),
  (121,13,$q$Pack A has 6 for $4.20. Pack B has 12 for $8.80. Which is better value?$q$,2,array['Number and algebra']::text[],'icas')
on conflict (chapter, idx) do nothing;
insert into problem_answers (chapter, idx, answer, method, answer_key, mark_mode, solved_by, verified) values
  (121,1,$q$96 — 20% of $120 is $24, so take that off.$q$,$q$20% of $120 is $24, so take that off.$q$,$q$96$q$,'auto','llm',false),
  (121,2,$q$30 — 25% of $40 is $10, so take that off.$q$,$q$25% of $40 is $10, so take that off.$q$,$q$30$q$,'auto','llm',false),
  (121,3,$q$108 — 10% of $120 is $12, so take that off.$q$,$q$10% of $120 is $12, so take that off.$q$,$q$108$q$,'auto','llm',false),
  (121,4,$q$35 — There are 8 parts, each worth $7; the larger share is 5 parts.$q$,$q$There are 8 parts, each worth $7; the larger share is 5 parts.$q$,$q$35$q$,'auto','llm',false),
  (121,5,$q$33 — There are 5 parts, each worth $11; the larger share is 3 parts.$q$,$q$There are 5 parts, each worth $11; the larger share is 3 parts.$q$,$q$33$q$,'auto','llm',false),
  (121,6,$q$40 — There are 5 parts, each worth $10; the larger share is 4 parts.$q$,$q$There are 5 parts, each worth $10; the larger share is 4 parts.$q$,$q$40$q$,'auto','llm',false),
  (121,7,$q$10.2 — Add them to get 51, then divide by 5.$q$,$q$Add them to get 51, then divide by 5.$q$,$q$10.2$q$,'auto','llm',false),
  (121,8,$q$13 — Add them to get 65, then divide by 5.$q$,$q$Add them to get 65, then divide by 5.$q$,$q$13$q$,'auto','llm',false),
  (121,9,$q$15 — Add them to get 75, then divide by 5.$q$,$q$Add them to get 75, then divide by 5.$q$,$q$15$q$,'auto','llm',false),
  (121,10,$q$165 — 2 × 60 = 120, plus 45.$q$,$q$2 × 60 = 120, plus 45.$q$,$q$165$q$,'auto','llm',false),
  (121,11,$q$75 — 1 × 60 = 60, plus 15.$q$,$q$1 × 60 = 60, plus 15.$q$,$q$75$q$,'auto','llm',false),
  (121,12,$q$the second — A costs $0.700 each, B costs $0.680 each.$q$,$q$A costs $0.700 each, B costs $0.680 each.$q$,$q$the second$q$,'auto','llm',false),
  (121,13,$q$the first — A costs $0.700 each, B costs $0.733 each.$q$,$q$A costs $0.700 each, B costs $0.733 each.$q$,$q$the first$q$,'auto','llm',false)
on conflict (chapter, idx) do update set answer_key=excluded.answer_key, method=excluded.method, answer=excluded.answer;
insert into chapters (n,title,pages,examples,practice,tier,source) values (122,'ICAS Maths · Measurement and geometry',null,0,6,1,'icas') on conflict (n) do update set practice=excluded.practice;
insert into problems (chapter, idx, prompt, difficulty, technique_tags, source) values
  (122,1,$q$A rectangle is 8 cm long and 7 cm wide. What is its area?$q$,2,array['Measurement and geometry']::text[],'icas'),
  (122,2,$q$A rectangle is 9 cm long and 4 cm wide. What is its area?$q$,2,array['Measurement and geometry']::text[],'icas'),
  (122,3,$q$A rectangle is 11 cm long and 7 cm wide. What is its area?$q$,2,array['Measurement and geometry']::text[],'icas'),
  (122,4,$q$A garden is 15 m by 8 m. A path 1 m wide runs around the inside edge. What is the area of the path?$q$,2,array['Measurement and geometry']::text[],'icas'),
  (122,5,$q$A garden is 13 m by 6 m. A path 1 m wide runs around the inside edge. What is the area of the path?$q$,2,array['Measurement and geometry']::text[],'icas'),
  (122,6,$q$A garden is 11 m by 6 m. A path 1 m wide runs around the inside edge. What is the area of the path?$q$,2,array['Measurement and geometry']::text[],'icas')
on conflict (chapter, idx) do nothing;
insert into problem_answers (chapter, idx, answer, method, answer_key, mark_mode, solved_by, verified) values
  (122,1,$q$56 cm² — Area = length × width = 8 × 7.$q$,$q$Area = length × width = 8 × 7.$q$,$q$56 cm²$q$,'auto','llm',false),
  (122,2,$q$36 cm² — Area = length × width = 9 × 4.$q$,$q$Area = length × width = 9 × 4.$q$,$q$36 cm²$q$,'auto','llm',false),
  (122,3,$q$77 cm² — Area = length × width = 11 × 7.$q$,$q$Area = length × width = 11 × 7.$q$,$q$77 cm²$q$,'auto','llm',false),
  (122,4,$q$42 — Whole garden 120 m², inner rectangle 78 m²; subtract.$q$,$q$Whole garden 120 m², inner rectangle 78 m²; subtract.$q$,$q$42$q$,'auto','llm',false),
  (122,5,$q$34 — Whole garden 78 m², inner rectangle 44 m²; subtract.$q$,$q$Whole garden 78 m², inner rectangle 44 m²; subtract.$q$,$q$34$q$,'auto','llm',false),
  (122,6,$q$30 — Whole garden 66 m², inner rectangle 36 m²; subtract.$q$,$q$Whole garden 66 m², inner rectangle 36 m²; subtract.$q$,$q$30$q$,'auto','llm',false)
on conflict (chapter, idx) do update set answer_key=excluded.answer_key, method=excluded.method, answer=excluded.answer;
insert into chapters (n,title,pages,examples,practice,tier,source) values (123,'ICAS Maths · Statistics and probability',null,0,6,1,'icas') on conflict (n) do update set practice=excluded.practice;
insert into problems (chapter, idx, prompt, difficulty, technique_tags, source) values
  (123,1,$q$A bag holds 6 red and 4 blue counters. What is the probability of drawing a red one? Give a fraction.$q$,2,array['Statistics and probability']::text[],'icas'),
  (123,2,$q$A bag holds 2 red and 3 blue counters. What is the probability of drawing a red one? Give a fraction.$q$,2,array['Statistics and probability']::text[],'icas'),
  (123,3,$q$A bag holds 2 red and 5 blue counters. What is the probability of drawing a red one? Give a fraction.$q$,2,array['Statistics and probability']::text[],'icas'),
  (123,4,$q$Laps swum on Monday: Ava 14; Ben 13; Chloe 5; Dev 12. Who swam the most, and how many?$q$,2,array['Statistics and probability']::text[],'icas'),
  (123,5,$q$Laps swum on Monday: Ava 13; Ben 8; Chloe 7; Dev 19. Who swam the most, and how many?$q$,2,array['Statistics and probability']::text[],'icas'),
  (123,6,$q$Laps swum on Monday: Ava 10; Ben 17; Chloe 6; Dev 7. Who swam the most, and how many?$q$,2,array['Statistics and probability']::text[],'icas')
on conflict (chapter, idx) do nothing;
insert into problem_answers (chapter, idx, answer, method, answer_key, mark_mode, solved_by, verified) values
  (123,1,$q$3/5 — 6 favourable out of 10 in total.$q$,$q$6 favourable out of 10 in total.$q$,$q$3/5$q$,'auto','llm',false),
  (123,2,$q$2/5 — 2 favourable out of 5 in total.$q$,$q$2 favourable out of 5 in total.$q$,$q$2/5$q$,'auto','llm',false),
  (123,3,$q$2/7 — 2 favourable out of 7 in total.$q$,$q$2 favourable out of 7 in total.$q$,$q$2/7$q$,'auto','llm',false),
  (123,4,$q$Ava, 14 — Compare the four numbers; the largest is the answer.$q$,$q$Compare the four numbers; the largest is the answer.$q$,$q$Ava, 14$q$,'auto','llm',false),
  (123,5,$q$Dev, 19 — Compare the four numbers; the largest is the answer.$q$,$q$Compare the four numbers; the largest is the answer.$q$,$q$Dev, 19$q$,'auto','llm',false),
  (123,6,$q$Ben, 17 — Compare the four numbers; the largest is the answer.$q$,$q$Compare the four numbers; the largest is the answer.$q$,$q$Ben, 17$q$,'auto','llm',false)
on conflict (chapter, idx) do update set answer_key=excluded.answer_key, method=excluded.method, answer=excluded.answer;
insert into exam_map (exam, chapter, idx) select 'ICAS Maths', chapter, idx from problems where source='icas' on conflict do nothing;

-- check: 103 starter questions across the three banks
-- select source, count(*) from problems where source in ('aas','edutest','icas') group by 1;

