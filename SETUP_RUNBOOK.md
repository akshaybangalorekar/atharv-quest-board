# Setup — the exact steps, in order

Everything below is clicking and pasting. Nothing needs a terminal except one
optional command, and it is marked.

---

## 1. Two keys (10 minutes)

**Sarvam key.** Go to `dashboard.sarvam.ai`, sign in, API keys, create one. Copy it.
This is the key that reads photos of his working. Treat it like a password.

**Put it in Supabase.** Supabase dashboard → your project → Edge Functions →
Secrets (older dashboards: Settings → Edge Functions → Secrets) → add a secret
named exactly `SARVAM_API_KEY`, value = the key you just copied. Save.

Optional, if you prefer the CLI:

```bash
supabase secrets set SARVAM_API_KEY=<key> --project-ref qjynqcbhyctisptciblp
```

**Publishable key.** Supabase → Settings → API keys → copy the key that starts
`sb_publishable_`. This one is meant to be public; it goes in the page.

**Put it in the page.** GitHub → `akshaybangalorekar/atharv-quest-board` →
switch branch to `gh-pages` → open `index.html` → pencil icon → line 2,
replace `PASTE_PUBLISHABLE_KEY_HERE` with the key → Commit changes. The site
rebuilds itself in about a minute.

Do the same edit in `quest_board.html` on `main` if you want the copy on your
laptop to work as well.

---

## 2. Three accounts (5 minutes)

Supabase → Authentication → Users → **Add user** → **Create new user**.

- Email: Atharv's address (any address he can receive at; it does not need to be
  a school one)
- Password: something he can type
- **Tick "Auto Confirm User"** — otherwise he cannot sign in until he clicks a
  confirmation email

Do it three times: Atharv, Pooja, Akshay. Each gets their own login, and the
parents' logins can read his data without being able to change his marks.

Then open `010_people.sql`, replace the three placeholder addresses with the
real ones, and run it in the SQL editor. It creates his profile row and links
both parents to it.

Then run `008_plan_seed.sql` again — now that his profile exists, the plan
lands on his calendar, 171 rows covering 17 November to 14 February.

Tell me when the three accounts exist and I'll do both of those runs for you.

---

## 3. First login

Open **https://akshaybangalorekar.github.io/atharv-quest-board/**

Sign in as Atharv. What you should see:

- **Today**: the lane for today, with the chapter and question count
- **Level 1 · Apprentice, 0 XP**, streak 0
- **Chapter map**: 24 squares, all grey — nothing started
- **Is the content enough?**: "0 of 288 practised so far. Too early to say — keep going."
- **Work on these next**: empty

Sign out, sign in as Pooja or Akshay. The Parent tab should show the same
chapter map, the readiness table with "Olympiad book — 288 questions, Too early",
and no tests yet.

If the board shows "No plan yet", the plan seed has not run. If it shows
"Readiness view not available", the migrations have not all been applied.

---

## 4. Running a session

1. Open the board, see the lane.
2. Open the book at the chapter's page, and the board in the next tab.
3. He works on paper. You mark each answer by calling `submit_answer()` with the
   chapter, the question number and what he wrote.
4. Where it comes back `needs_manual_mark` — thirteen of those, all constructions,
   proofs and tables — mark it by eye with `mark_attempt()`.
5. Photo of his working: upload it to the `working` bucket under his own folder,
   then call `coach-work` with the chapter, the question and the file path.
6. Saturday: the quiz. From 22 January: the AMC paper.

---

## 5. Adding another exam — AAS, Edutest, ICAS, ELMS

The book owns chapters 1 to 24. Every other exam gets its own block of chapter
numbers starting at 101, one chapter per strand. Marking, the weak queue, the
plan and the readiness panel all keep working, because they only ever see a
chapter number and a question number.

Five steps, once you have the questions:

1. **Pick a block.** AAS 101–110, Edutest 111–120, ICAS 121–130, ELMS 131–140.
2. **One `chapters` row per strand**, with `source` set to the exam:

   ```sql
   insert into chapters (n, title, pages, examples, practice, tier, source)
   values (101, 'AAS · Numerical reasoning — sequences', null, 0, 0, 1, 'aas');
   ```

3. **The questions**, `idx` counting 1, 2, 3… inside each chapter:

   ```sql
   insert into problems (chapter, idx, prompt, difficulty, technique_tags, source)
   values (101, 1, 'Next in the sequence: 3, 7, 15, 31, …', 2,
           array['Sequences'], 'aas');

   insert into problem_answers (chapter, idx, answer, method, answer_key, mark_mode)
   values (101, 1, '63 — double and add one', 'Double, then add 1.', '63', 'auto');
   ```

   `mark_mode` is `auto` when a short answer key can decide it, and `manual` when
   it cannot — a diagram, a proof, a table, "give five solutions".

4. **Link them to the exam** so the readiness panel sees them:

   ```sql
   insert into exam_map (exam, chapter, idx)
   select 'AAS numerical reasoning', chapter, idx from problems where source = 'aas';
   ```

5. **Register the bank**:

   ```sql
   insert into exam_banks (exam, kind, chapter_from, chapter_to)
   values ('AAS numerical reasoning', 'aas', 101, 110);
   ```

The readiness panel then shows that exam with its own verdict. Below 30 questions
it says **"Need more data"** on purpose — a handful of items cannot tell you
whether he is ready, and a green tick on twenty questions would be a lie. Sixty
to a hundred items per exam is the range where the verdict starts to mean
something.

**The fastest route:** send me the file you have — PDF, Word, a scan, whatever —
and tell me which exam it belongs to. I'll do the conversion, write the SQL, run
it, and show you the readiness panel with the new exam on it.

---

## 6. What is not built yet

- The board is read-only. Marking happens through the database, not on screen.
- No email or push. The nightly job updates the data; nobody is told.
- Photos are uploaded by hand to Storage, not from the page.
- `plan_days` is seeded once. If the plan slips, it needs re-seeding.
