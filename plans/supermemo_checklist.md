# The 90% Checklist

Not a feature list — a list of **tests you run on your own app.** Each one you can perform yourself without reading code. Tick what passes, add up the weight, and you have an honest number.

**How to use this:** go through it with your app open. Actually run the tests. "I think I built that" is not a pass; watching the app behave correctly is a pass.

---

## Scoring

| Band | Score | What it means |
|---|---|---|
| A | Foundation | 30 |
| B | Load valve | 24 |
| C | Scheduler | 10 |
| D | Visibility | 8 |
| E | Priority integrity | 5 |
| F | Reading mechanics | 11 |
| G | Structure & retrieval | 8 |
| H | Input | 4 |
| | **Total** | **100** |

Based on what you've told me, you're likely sitting around **27–30**. That is not a criticism — you built the part that's visible and hard to fake. But it means "nearly at 90%" is not where you are, and the remaining work is mostly invisible plumbing.

**90 means you need essentially all of B through G.**

---

## A. Foundation — 30 points

*You have most of this. Verify anyway — especially A3.*

| # | Test | Passes if | Pts |
|---|---|---|---|
| A1 | Open an article, select a passage, extract it | A new element exists containing that passage | 6 |
| A2 | Turn an extract into both a Q&A card and a cloze card | Both work; both keep the extract as parent | 6 |
| A3 | Take an extract, open it, extract a smaller piece from *inside* it. Repeat 4 levels deep | Works at every level, no depth limit | 3 |
| A4 | Read a topic, finish the session, check when it returns | It has a future due date and the interval is longer than last time | 6 |
| A5 | Start a review session | Articles and cards appear mixed together in one stream, one keystroke to advance | 6 |
| A6 | Set two elements to very different priorities, both due today | The high-priority one appears earlier in the session | 3 |

> **A5 is the make-or-break.** If your app has a "Read" tab and a "Review" tab that you switch between manually, you don't have incremental reading — you have two apps sharing a database. The interleaving is the whole mechanism.

---

## B. Load valve — 24 points

*This is the band that decides whether you're still using your app in six months.*

| # | Test | Passes if | Pts |
|---|---|---|---|
| B1 | Do a review, then a postpone, then a dismiss. Look at your app's stored history | Three separate records exist, each labelled with a **different event type** | 5 |
| B2 | Find a card with a ~200-day interval. Press "Later" | It's gone for weeks, not one day | 3 |
| B3 | Find a card with a 3-day interval. Press "Later" | It's gone for ~1 day, not 30 | — |
| B4 | Dismiss an element, then look for it | Gone from the queue, still in your library, still has its history, can be restored | 2 |
| B5 | **The big one.** Set your daily cap to 20. Force 200 elements due. Open the app, do 20, close it. Open it the next day | Roughly 20–30 due. **Not 180.** **Not 380.** | 8 |
| B6 | After B5, check where the overflow went | Low-priority elements were pushed much further than high-priority ones | — |
| B7 | After B5, look at the due dates of everything postponed | They're spread across many future days, not stacked on one | — |
| B8 | Set something to your top 1% priority. Force a massive overload. Rebuild the queue | That element is **still due today** — never auto-postponed | 3 |
| B9 | Simulate 3 weeks away: force 1,500 things overdue. Run "Mercy" with a 60-day horizon | Top-priority backlog lands in the next 2–3 days; the tail lands months out; tomorrow is a normal-sized day | 3 |

> B5 is the single most important test in this document. If it fails, nothing else you build matters — you will abandon the app before the other features earn their keep.

---

## C. Scheduler — 10 points

| # | Test | Passes if | Pts |
|---|---|---|---|
| C1 | Find a card scheduled for ~10 days that you actually reviewed ~45+ days late. Grade it "Good" | Next interval is **substantially longer than 25 days** — 80, 100, more. If it's ~25, your scheduler is ignoring the delay | 7 |
| C2 | Take any card. Note its "last reviewed" date. Press "Later." Check again | **Unchanged.** If it now says today, you have a state-corruption bug that will poison everything | 3 |
| C3 | Same as C2 but with a manual reschedule, and with auto-postpone | Unchanged in all cases | — |

> No overdue card handy for C1? Move your system clock forward 45 days on a test copy. Worth the five minutes — this test catches the most consequential wrong default in the whole build.

---

## D. Visibility — 8 points

| # | Test | Passes if | Pts |
|---|---|---|---|
| D1 | Pick your largest imported source. Ask your app what it costs you per day | It gives you a **number** — e.g. "40 reviews/day" — not a card count | 5 |
| D2 | View your library tree | Every branch shows its own daily cost, so you can compare siblings | — |
| D3 | Open a workload view | A chart of reviews due per day for the next 30 days | 3 |

> D1's failure mode is subtle: showing "800 cards" instead of "40 reviews/day." Card count tells you nothing about ongoing cost — 800 cards at 200-day intervals is 4/day, 800 at 10-day intervals is 80/day. Same count, twentyfold difference.

---

## E. Priority integrity — 5 points

| # | Test | Passes if | Pts |
|---|---|---|---|
| E1 | Set the priority of something | You choose a **percentile** ("top 10%"), not a raw score | 5 |
| E2 | Look at a list of your elements sorted by priority | You see rank position ("above 87% of collection"), not a bare number | — |
| E3 | Check the distribution of priority across your whole collection | Roughly even across the range. If most of it clusters in the top third, inflation has already started | — |

---

## F. Reading mechanics — 11 points

| # | Test | Passes if | Pts |
|---|---|---|---|
| F1 | Read a long article to paragraph 40. Close it. Now edit a typo in paragraph 5 and delete an extract from paragraph 12. Reopen | Still at paragraph 40, not somewhere random | 4 |
| F2 | Close an article mid-session, come back a week later | Opens exactly where you left off, not at the top | — |
| F3 | Take a 12,000-word article. Split it | You get multiple child topics, each inheriting priority and source info | 4 |
| F4 | Immediately after F3, check the children's due dates | **Spread over coming weeks**, not all due today | — |
| F5 | Reopen an article you've extracted from heavily | Extracted text is greyed/dimmed, still readable for context — not deleted | 1 |
| F6 | Run a review session when you have 300 cards and 5 articles due | Articles still appear regularly — roughly one every 8 elements — not buried at the end | 2 |

> F6 catches a slow death. Cards outnumber articles 20:1 within months. Pure priority sorting buries reading, reading stops, no new cards are made, and the collection ossifies into something you only maintain.

---

## G. Structure & retrieval — 8 points

| # | Test | Passes if | Pts |
|---|---|---|---|
| G1 | Fail a card during review. Press one key | The original article opens with your extract highlighted in place | 3 |
| G2 | Look at a card made from an extract made from an article imported last year | It still shows the article's title, author, and link | 2 |
| G3 | Delete a source article that has 60 cards under it | It **asks** what to do — delete all / keep cards / just dismiss — and shows how many reviews of history are at stake | 1 |
| G4 | Pick a branch of your tree. Drill it right now, ignoring due dates | Works, and clearly tells you whether it counts as real review or just practice | 2 |

> G1 is the highest-value keystroke in the app. Cards you fail repeatedly usually aren't hard — they're badly written, and you can't see that without the original context in front of you.

---

## H. Input — 4 points

| # | Test | Passes if | Pts |
|---|---|---|---|
| H1 | Import a messy article-heavy web page | Clean text, headings and images preserved, no navigation junk | 2 |
| H2 | Import a PDF and an EPUB | Both become readable topics you can extract from | 1 |
| H3 | Import a YouTube video with a transcript | Transcript becomes extractable text | 1 |

> Starvation is a real failure mode. So is fighting bad HTML every session until you stop importing.

---

## Bonus — not counted, not SuperMemo

| Test | Passes if |
|---|---|
| Read an article and make 15 extracts. Read another and make zero. Compare their next due dates | The productive one comes back sooner |
| Skim past an article three sessions running with no extracts | App asks whether to drop it |

This is my suggestion, not SuperMemo's behaviour. Build it as an option, log what the old fixed-multiplier would have done, and compare before trusting it.

---

## Deliberately NOT on this list

The remaining 10% of SuperMemo, which you should skip:

- Incremental writing / composing extracts into new text
- Concept groups, concept links, neural review
- Separate machinery for incremental video, image, audio
- Plan, tasklists, sleep tracking, work-time analysis
- The templates and styles engine
- Registry / lexicon
- Any attempt to reimplement SM-17 or SM-18

That's thirty years of one person's accumulated preferences, much of it bad interface design. Chasing it is cargo cult.

---

## Fastest route from ~30 to ~90

| Order | Band | Points | Rough effort |
|---|---|---|---|
| 1 | B1 (review log) | 5 | Half a day. **Do this before anything else** — history can't be backfilled |
| 2 | B2–B9 (postpone machinery) | 19 | 2–3 days |
| 3 | C1–C3 (FSRS + state hygiene) | 10 | 1–2 days with a library |
| 4 | D1–D3 (burden) | 8 | 1 day |
| 5 | E1–E3 (percentile priority) | 5 | 1 day |
| 6 | G1–G4 (navigation, subset) | 8 | 1–2 days |
| 7 | F1–F6 (blocks, splitting) | 11 | The big rebuild — 3–5 days |
| 8 | H1–H3 (import) | 4 | Ongoing |

Steps 1 and 2 alone take you from ~30 to ~54 and are the difference between a system you use and one you abandon. Do them first even though burden and percentile priority are more fun to build.