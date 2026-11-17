-- ============================================================================
-- 013_chapter_tricks.sql
-- The chapter notes, rewritten for an eleven-year-old: each technique is a short
-- name, one plain sentence, and a tiny example. The dense prose stays in
-- chapter_notes.summary for reference; this is what the app shows.
-- Run after 012. Safe to re-run.
-- ============================================================================

alter table chapter_notes add column if not exists tricks jsonb default '[]'::jsonb;

update chapter_notes set tricks = jsonb_build_array(
      jsonb_build_object('t', $t$Digits have places$t$, 'p', $t$Each digit is worth its place. A 4 in the hundreds is 400.$t$, 'e', $t$734 = 700 + 30 + 4$t$),
      jsonb_build_object('t', $t$Swap and subtract$t$, 'p', $t$Swapping two digits changes the number by 9, 99 or 900.$t$, 'e', $t$83 − 38 = 45 = 9 × 5$t$),
      jsonb_build_object('t', $t$Nines are easy$t$, 'p', $t$A row of nines is a round number minus one.$t$, 'e', $t$999 = 1000 − 1$t$),
      jsonb_build_object('t', $t$Find what both share$t$, 'p', $t$In a sum of two big products, pull out the shared factor.$t$, 'e', $t$6×4 + 6×9 = 6×13$t$)
    ) where chapter = 1;
update chapter_notes set tricks = jsonb_build_array(
      jsonb_build_object('t', $t$Write it as arrows$t$, 'p', $t$Two things worth the same get an arrow between them.$t$, 'e', $t$5 tables + 18 chairs = $594$t$),
      jsonb_build_object('t', $t$Swap one for the other$t$, 'p', $t$Replace a shape with what it equals, then count again.$t$, 'e', $t$□ = △△△, so □+□ = 6△$t$),
      jsonb_build_object('t', $t$Compare to cancel$t$, 'p', $t$Put two statements together and the shared part disappears.$t$, 'e', $t$A+B=10, A+C=12 → C−B=2$t$),
      jsonb_build_object('t', $t$Add both lines$t$, 'p', $t$Adding the two statements can wipe out a letter.$t$, 'e', $t$(A+B)+(A−B) = 2A$t$)
    ) where chapter = 2;
update chapter_notes set tricks = jsonb_build_array(
      jsonb_build_object('t', $t$Same letter, same digit$t$, 'p', $t$One letter is one digit, everywhere it appears.$t$, 'e', $t$AB + AB = CCC$t$),
      jsonb_build_object('t', $t$Start on the right$t$, 'p', $t$Begin at the last column, where the carrying happens.$t$, 'e', $t$add the ones first$t$),
      jsonb_build_object('t', $t$Try the digits$t$, 'p', $t$Test 0 to 9 in order and cross out what breaks.$t$, 'e', $t$work down the list$t$)
    ) where chapter = 3;
update chapter_notes set tricks = jsonb_build_array(
      jsonb_build_object('t', $t$Two circles$t$, 'p', $t$The overlap means both. Outside both means neither.$t$, 'e', $t$30 maths, 25 English, 12 both$t$),
      jsonb_build_object('t', $t$Fill the middle first$t$, 'p', $t$Put the 'both' number in the overlap, then subtract.$t$, 'e', $t$maths only = 30 − 12$t$),
      jsonb_build_object('t', $t$Three circles$t$, 'p', $t$Add all three, take away the pairs, add the middle back.$t$, 'e', $t$A+B+C − pairs + middle$t$),
      jsonb_build_object('t', $t$Counting multiples$t$, 'p', $t$Count with division first, then place them in the circles.$t$, 'e', $t$multiples of 3 up to 50 = 16$t$)
    ) where chapter = 4;
update chapter_notes set tricks = jsonb_build_array(
      jsonb_build_object('t', $t$Add the last two$t$, 'p', $t$Each term is the two before it, added.$t$, 'e', $t$3, 6, 9, 15, 24$t$),
      jsonb_build_object('t', $t$Fill the gap$t$, 'p', $t$Two terms with a gap? Subtract to step backwards.$t$, 'e', $t$?, ?, 12, 20 → 4, 8, 12, 20$t$),
      jsonb_build_object('t', $t$Staircase counting$t$, 'p', $t$Ways of climbing 1 or 2 steps follow the same numbers.$t$, 'e', $t$1, 2, 3, 5, 8 ways$t$)
    ) where chapter = 5;
update chapter_notes set tricks = jsonb_build_array(
      jsonb_build_object('t', $t$Order matters? Multiply$t$, 'p', $t$Choosing and arranging means multiplying downwards.$t$, 'e', $t$5×4×3 ways to place 3 of 5$t$),
      jsonb_build_object('t', $t$Order doesn't? Divide$t$, 'p', $t$Then divide by the ways the chosen ones can be shuffled.$t$, 'e', $t$÷ 3×2×1$t$),
      jsonb_build_object('t', $t$AND multiply, OR add$t$, 'p', $t$Two things together multiply. Either-or adds.$t$, 'e', $t$2 shirts × 3 ties = 6 outfits$t$)
    ) where chapter = 6;
update chapter_notes set tricks = jsonb_build_array(
      jsonb_build_object('t', $t$Look at the gaps$t$, 'p', $t$Write the differences between terms. Is there a pattern?$t$, 'e', $t$2, 6, 12, 20 → gaps 4, 6, 8$t$),
      jsonb_build_object('t', $t$Count the rows$t$, 'p', $t$Work out how many numbers sit in each row before yours.$t$, 'e', $t$row k holds k numbers$t$)
    ) where chapter = 7;
update chapter_notes set tricks = jsonb_build_array(
      jsonb_build_object('t', $t$Distance = speed × time$t$, 'p', $t$Any two of these give you the third.$t$, 'e', $t$60 km/h for 2 h = 120 km$t$),
      jsonb_build_object('t', $t$Trains and bridges$t$, 'p', $t$Add the train's own length to the bridge.$t$, 'e', $t$length + 1200 m$t$),
      jsonb_build_object('t', $t$Average speed$t$, 'p', $t$Total distance ÷ total time. Never average the speeds.$t$, 'e', $t$240 km in 3 h = 80 km/h$t$),
      jsonb_build_object('t', $t$Faster means less time$t$, 'p', $t$Double the speed and the time halves.$t$, 'e', $t$same trip, half the time$t$)
    ) where chapter = 8;
update chapter_notes set tricks = jsonb_build_array(
      jsonb_build_object('t', $t$Quick tests$t$, 'p', $t$3 and 9: add the digits. 4: last two digits. 11: alternating sum.$t$, 'e', $t$173a ÷ 9 → 1+7+3+a$t$),
      jsonb_build_object('t', $t$What squares end in$t$, 'p', $t$0, 1, 4, 5, 6, 9 — never 2, 3, 7 or 8.$t$, 'e', $t$no square ends in 7$t$)
    ) where chapter = 9;
update chapter_notes set tricks = jsonb_build_array(
      jsonb_build_object('t', $t$Make a table$t$, 'p', $t$One thing down the side, another across the top.$t$, 'e', $t$people × days$t$),
      jsonb_build_object('t', $t$Draw it$t$, 'p', $t$A picture often shows the answer before the sums do.$t$, 'e', $t$sketch the field$t$),
      jsonb_build_object('t', $t$Work backwards$t$, 'p', $t$Start at the answer and undo each step.$t$, 'e', $t$half, then add 3 → reverse$t$)
    ) where chapter = 10;
update chapter_notes set tricks = jsonb_build_array(
      jsonb_build_object('t', $t$Try small cases$t$, 'p', $t$Do n = 1, 2, 3 and look for the rule.$t$, 'e', $t$1, 4, 9, 16 → squares$t$),
      jsonb_build_object('t', $t$Guess, then prove$t$, 'p', $t$A pattern is a guess until you show why it keeps going.$t$, 'e', $t$say why step n+1 follows$t$)
    ) where chapter = 11;
update chapter_notes set tricks = jsonb_build_array(
      jsonb_build_object('t', $t$Clock angles$t$, 'p', $t$Each hour is 30°, each minute 6°. Take one from the other.$t$, 'e', $t$7:10 → 30×7 + 0.5×10$t$),
      jsonb_build_object('t', $t$When hands meet$t$, 'p', $t$The minute hand gains 5.5° every minute.$t$, 'e', $t$catch-up at 5.5° a minute$t$)
    ) where chapter = 12;
update chapter_notes set tricks = jsonb_build_array(
      jsonb_build_object('t', $t$Give it a letter$t$, 'p', $t$Name what you are looking for, then write what you know.$t$, 'e', $t$let the number be x$t$),
      jsonb_build_object('t', $t$Two unknowns, two facts$t$, 'p', $t$Each sentence becomes one equation.$t$, 'e', $t$x + y = 60, x − y = 10$t$),
      jsonb_build_object('t', $t$Add or subtract the lines$t$, 'p', $t$That removes one letter at a time.$t$, 'e', $t$add them → 2x = 70$t$)
    ) where chapter = 13;
update chapter_notes set tricks = jsonb_build_array(
      jsonb_build_object('t', $t$Equal areas$t$, 'p', $t$Same base, same height: same area, whatever the shape.$t$, 'e', $t$triangle = half the rectangle$t$),
      jsonb_build_object('t', $t$Cut and move$t$, 'p', $t$Slide a piece across to turn an odd shape into a rectangle.$t$, 'e', $t$lopsided → rectangle$t$),
      jsonb_build_object('t', $t$Angle chase$t$, 'p', $t$Straight line 180°, triangle 180°, full turn 360°.$t$, 'e', $t$fill the missing angle$t$)
    ) where chapter = 14;
update chapter_notes set tricks = jsonb_build_array(
      jsonb_build_object('t', $t$Assume and test$t$, 'p', $t$Pretend someone is telling the truth and see if it breaks.$t$, 'e', $t$if Alan is lying…$t$),
      jsonb_build_object('t', $t$Make a list$t$, 'p', $t$Write every possibility, then cross out the impossible.$t$, 'e', $t$six boxes, six names$t$),
      jsonb_build_object('t', $t$Draw a table$t$, 'p', $t$People down the side, clues across the top.$t$, 'e', $t$ticks and crosses$t$)
    ) where chapter = 15;
update chapter_notes set tricks = jsonb_build_array(
      jsonb_build_object('t', $t$Cost, sell, profit$t$, 'p', $t$Profit is selling price minus cost. Loss is the other way.$t$, 'e', $t$$8000 → $4800 is a loss$t$),
      jsonb_build_object('t', $t$Simple interest$t$, 'p', $t$Interest = principal × rate × years.$t$, 'e', $t$$500 at 6% for 2 y = $60$t$),
      jsonb_build_object('t', $t$Compound interest$t$, 'p', $t$Each year's interest joins the money and earns too.$t$, 'e', $t$(4/3)³ ≈ 2.37$t$)
    ) where chapter = 16;
update chapter_notes set tricks = jsonb_build_array(
      jsonb_build_object('t', $t$Find what stays the same$t$, 'p', $t$Make the unchanged part the same in both ratios.$t$, 'e', $t$yellow : total = 5 : 7$t$),
      jsonb_build_object('t', $t$One part first$t$, 'p', $t$Find the value of one part, then multiply up.$t$, 'e', $t$1 part = 18 ÷ 3$t$),
      jsonb_build_object('t', $t$Work backwards$t$, 'p', $t$Start from the end and undo each step.$t$, 'e', $t$reverse the changes$t$)
    ) where chapter = 17;
update chapter_notes set tricks = jsonb_build_array(
      jsonb_build_object('t', $t$Work problems$t$, 'p', $t$Together: add the rates. Against: subtract them.$t$, 'e', $t$12 h alone → 1/12 a day$t$),
      jsonb_build_object('t', $t$Candles$t$, 'p', $t$Same candle, different burn times — compare fractions.$t$, 'e', $t$1/4 and 1/6 a minute$t$),
      jsonb_build_object('t', $t$Newton's cows$t$, 'p', $t$The grass grows while they eat, so use two equations.$t$, 'e', $t$two fields, two equations$t$)
    ) where chapter = 18;
update chapter_notes set tricks = jsonb_build_array(
      jsonb_build_object('t', $t$Telescoping$t$, 'p', $t$Write each fraction as a difference so most terms cancel.$t$, 'e', $t$1/(1+2) + 1/(1+2+3) + …$t$),
      jsonb_build_object('t', $t$Difference of squares$t$, 'p', $t$a² − b² = (a − b)(a + b).$t$, 'e', $t$79½ − 49⅔ trick$t$),
      jsonb_build_object('t', $t$Continued fractions$t$, 'p', $t$Work from the bottom upwards.$t$, 'e', $t$innermost first$t$)
    ) where chapter = 19;
update chapter_notes set tricks = jsonb_build_array(
      jsonb_build_object('t', $t$Two meetings$t$, 'p', $t$Between two meetings they cover the whole distance once.$t$, 'e', $t$A and B meet twice$t$),
      jsonb_build_object('t', $t$Catching up$t$, 'p', $t$The gap shrinks by the difference in their speeds.$t$, 'e', $t$3 : 2 speeds$t$),
      jsonb_build_object('t', $t$Echo$t$, 'p', $t$Sound goes there and back, so halve the distance.$t$, 'e', $t$echo in 2 s → 340 m$t$)
    ) where chapter = 20;
update chapter_notes set tricks = jsonb_build_array(
      jsonb_build_object('t', $t$Whole numbers either side$t$, 'p', $t$Trap the answer between two easy numbers.$t$, 'e', $t$2 < sum < 3$t$),
      jsonb_build_object('t', $t$Cross-multiply to compare$t$, 'p', $t$For a/b and c/d, compare ad with bc.$t$, 'e', $t$41245×234567 vs 78282×123456$t$),
      jsonb_build_object('t', $t$Bound it both ways$t$, 'p', $t$Show it is under something easy, and over something easy.$t$, 'e', $t$< 0.1 by pairing$t$)
    ) where chapter = 21;
update chapter_notes set tricks = jsonb_build_array(
      jsonb_build_object('t', $t$Other base to ten$t$, 'p', $t$Multiply each digit by its place value in that base.$t$, 'e', $t$(1202)₃ = 1×27 + 2×9 + 2$t$),
      jsonb_build_object('t', $t$Ten to another base$t$, 'p', $t$Divide by the base again and again; read the remainders backwards.$t$, 'e', $t$47 → (1202)₃$t$)
    ) where chapter = 22;
update chapter_notes set tricks = jsonb_build_array(
      jsonb_build_object('t', $t$Think of the worst case$t$, 'p', $t$Ask how bad it can get before it must happen.$t$, 'e', $t$draw one of each colour first$t$),
      jsonb_build_object('t', $t$One more than the holes$t$, 'p', $t$More pigeons than holes means a hole holds two.$t$, 'e', $t$11 marbles, 10 colours$t$)
    ) where chapter = 23;
update chapter_notes set tricks = jsonb_build_array(
      jsonb_build_object('t', $t$Pick a friendly radius$t$, 'p', $t$If only a ratio matters, choose r = 7 so π = 22/7 fits.$t$, 'e', $t$r = 7, π = 22/7$t$),
      jsonb_build_object('t', $t$Square in a circle$t$, 'p', $t$A square inside a circle of radius r has area 2r².$t$, 'e', $t$r² /2 = 8 → r = 4$t$),
      jsonb_build_object('t', $t$Rolling around$t$, 'p', $t$Round the outside: (R + r)/r turns. Inside: (R − r)/r.$t$, 'e', $t$inside 4× smaller → 3 turns$t$)
    ) where chapter = 24;

-- check: every chapter should have at least one trick
-- select chapter, jsonb_array_length(tricks) from chapter_notes order by chapter;

