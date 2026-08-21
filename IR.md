## User

im used to use anki so i understand how it works , i heared of incremental reading and supermemo , i have tried supermemo, but i can't understand anything , i want you to make me understand incremental reading fully , because i will build a tool for incremental reading , i have mentionned anki to get that i understand anki

## Assistant

Yes. The easiest way to understand **Incremental Reading (IR)** is to stop thinking of it as “a better Anki.” It is a different architecture for learning.

You already understand the core Anki model:

> **Information → make a card → schedule card → retrieve answer → repeat**

Incremental reading is closer to:

> **Sources → progressively process sources → extract pieces → turn pieces into questions/cards → schedule both reading and reviewing → repeat**

The crucial idea is that **the source itself becomes a scheduled learning object**.

---

# 1. What problem is Incremental Reading solving?

Suppose you want to learn from 500 articles/books/papers.

With Anki, you might do this:

1. Read an article.
2. Decide what is important.
3. Create 10 cards.
4. Put them in Anki.
5. Review those cards forever.

The problem is that **you have to completely process the article before Anki can help you**.

IR asks:

> What if I don't have to finish reading an article in one sitting?

Imagine you have 100 interesting articles.

Instead of:

```text
Article 1
████████████████████
Article 2
████████████████████
Article 3
████████████████████
...
```

you do:

```text
Article 1 → read 5% → stop
Article 2 → read 3% → stop
Article 3 → read 8% → stop
Article 1 → read another 4%
Article 4 → read 2%
Article 2 → extract important paragraph
...
```

Your attention is distributed across many sources.

That is the **incremental** part.

---

# 2. The fundamental distinction: "reading" is scheduled

This is the first thing you need to understand if you're building a tool.

Anki schedules **reviews**.

SuperMemo/IR schedules **many different kinds of work**.

For example:

| Object | What happens to it? |
|---|---|
| Article | Read a little |
| Article | Read another little part later |
| Paragraph | Extract |
| Extract | Read/analyze later |
| Important statement | Turn into a question |
| Question | Review |
| Concept | Connect to other concepts |

So an IR system has something resembling a **task scheduler for knowledge processing**.

That's why SuperMemo initially feels bizarre if you're coming from Anki.

Anki mostly asks:

> **"Do you remember this?"**

IR asks:

> **"What should you do with this piece of knowledge next?"**

---

# 3. The core object: an Incremental Item

Forget SuperMemo's UI for a moment.

Imagine your system has an object:

```text
Item
├── type: article
├── content: "..."
├── position: 37%
├── next_reading: tomorrow
└── priority: 80
```

Tomorrow, the system says:

> Here's 500 words from this article.

You read them.

You decide:

> This paragraph is important.

You select it.

The system creates another item:

```text
Item
├── type: extract
├── source: Article A
├── content: "important paragraph..."
└── next_reading: tomorrow
```

Now you have **two scheduled objects**:

```text
Article A
   ↓
Extract A1
```

Later, you might extract a sentence:

```text
Article A
   ↓
Extract A1
   ↓
Sentence A1.1
```

And eventually create a question:

```text
Sentence A1.1
   ↓
Question:
"Why does X cause Y?"
```

That question can behave much more like an Anki card.

---

# 4. Extraction is one of the most important IR operations

This is where IR becomes very different from normal reading.

Suppose you're reading:

> The hippocampus plays a critical role in the consolidation of declarative memories. Evidence from patients with hippocampal lesions suggests that the hippocampus is particularly important for forming new long-term memories, while previously consolidated memories can remain relatively intact.

You don't necessarily want to turn that entire thing into a card.

You might extract:

> The hippocampus is particularly important for forming new long-term memories.

Now you have a smaller unit.

Later you might transform it into:

> **What brain structure is particularly important for forming new long-term memories?**

Answer:

> Hippocampus.

That transformation is called **formulation** in the SuperMemo ecosystem.

So the pipeline can look like:

```text
SOURCE
  ↓
READ
  ↓
EXTRACT
  ↓
READ EXTRACT
  ↓
FORMULATE
  ↓
QUESTION
  ↓
REVIEW
```

And importantly, **not everything needs to reach the final stage**.

---

# 5. IR is a pipeline, not a card system

This is probably the most useful mental model for your tool.

Think of knowledge flowing through a pipeline:

```text
                  ┌───────────────┐
                  │    Sources    │
                  │ books/articles│
                  └───────┬───────┘
                          ↓
                    incremental
                      reading
                          ↓
                  ┌───────────────┐
                  │   extracts    │
                  └───────┬───────┘
                          ↓
                    incremental
                      reading
                          ↓
                  ┌───────────────┐
                  │ formulations  │
                  │  / questions  │
                  └───────┬───────┘
                          ↓
                     repetition
                          ↓
                  ┌───────────────┐
                  │   knowledge   │
                  └───────────────┘
```

But it's not strictly linear.

You can go backward and sideways:

```text
Article A
   ↓
Extract A
   ↓
Question A
   ↓
Article B
   ↓
Extract B
   ↓
Question B
   ↓
Question A revisited
```

This allows **knowledge to evolve**.

---

# 6. Why "incremental"?

Suppose you have a 30-page paper.

Traditional reading:

```text
Start ─────────────────────────────── Finish
```

IR:

```text
Start ────┐
          ↓
         stop

          ┌─────── continue
          ↓
       Start again
          ↓
         stop

                  ┌──── continue
                  ↓
             Start again
```

You don't need to consume the entire source immediately.

You process **small portions at a time**.

The scheduler decides when that source comes back.

For example:

```text
Monday:
Paper A → read 400 words

Tuesday:
Paper B → read 300 words
Paper A → read 500 words

Wednesday:
Article C → read 600 words
Paper A → extract paragraph
```

The source is therefore **not "done" or "not done."**

It has a **reading position**.

That is a fundamental data-model difference from Anki.

---

# 7. A source has state

For your tool, don't think:

```text
Article = text
```

Think:

```text
Article
├── content
├── current_position
├── reading history
├── priority
├── scheduled date
├── extracted items
└── status
```

Example:

```json
{
  "id": "article_123",
  "type": "source",
  "position": 4200,
  "priority": 0.8,
  "next_reading": "2026-08-21",
  "children": [
    "extract_91",
    "extract_92"
  ]
}
```

The article is effectively a **living learning object**.

---

# 8. Priority is another major difference

Anki is predominantly:

> **When is this card due?**

IR has another question:

> **How valuable is it to spend my limited attention on this right now?**

Imagine:

```text
Article A: priority 90
Article B: priority 40
Article C: priority 10
```

Even if Article C is technically scheduled, it might be pushed aside because Article A is much more valuable.

This is important because IR deals with **attention allocation**, not just memory scheduling.

You have finite time.

The system therefore needs to decide:

> Given 30 minutes of available cognitive bandwidth, what should I process?

That's a much more ambitious problem than Anki's scheduler.

---

# 9. There are actually multiple schedulers

This is where SuperMemo terminology can become confusing.

You can conceptually separate:

### A. Reading scheduling

> When should I encounter this source/extract again?

### B. Repetition scheduling

> When should I retrieve this knowledge again?

### C. Priority

> How important is this item relative to other items?

### D. Workload/time

> How much material should I process right now?

Your tool can initially simplify all of this.

For example:

```text
Item.next_due
Item.priority
Item.estimated_time
Item.type
```

Then your queue algorithm can calculate:

```text
score =
    priority
    × urgency
    × importance
    × ...
```

You don't need to reproduce SuperMemo's algorithms to understand IR.

---

# 10. What does a user actually do?

Imagine I give you this article:

> "Why neural networks generalize"

You import it.

Your system shows:

```text
WHY NEURAL NETWORKS GENERALIZE

[Read next 300 words]

The classical view of statistical learning theory...
...
...
```

You read.

You encounter:

> Double descent refers to a phenomenon in which test error first decreases, then increases, and finally decreases again as model complexity increases.

You think:

> That's useful.

You select it.

Your tool creates:

```text
EXTRACT

Double descent refers to a phenomenon in which test
error first decreases, then increases, and finally
decreases again as model complexity increases.
```

You continue reading.

Then perhaps you formulate:

```text
QUESTION

What is the double-descent phenomenon?

ANSWER

Test error decreases, then increases, then decreases
again as model complexity increases.
```

Now the system schedules both:

```text
Article
→ next reading: tomorrow

Question
→ next review: 3 days
```

That's IR.

---

# 11. The really important part: extraction doesn't have to become a card

This is one of the biggest conceptual differences.

In Anki, there's a strong bias toward:

> **Everything useful → card**

IR says:

> **Everything useful → potentially another learning object.**

You might extract something simply because you want to think about it later.

For example:

```text
Extract:

"Gradient descent can be interpreted as..."
```

You don't yet know how to formulate a good question.

Fine.

Leave it as an extract.

Later:

```text
Extract comes back
↓
You understand it better
↓
Formulate a question
```

This reduces the pressure to create perfect cards immediately.

---

# 12. This solves a major Anki problem

If you've used Anki seriously, you've probably encountered this:

> "I understand this concept, but I don't know how to make a good card for it."

So you either:

- make a bad card,
- spend 10 minutes writing the card,
- postpone it,
- or don't capture it.

IR introduces an intermediate state:

```text
Interesting information
        ↓
      capture
        ↓
     process later
        ↓
 formulate later
        ↓
 review later
```

This separation is extremely powerful.

**Capture and formulation don't have to happen at the same time.**

---

# 13. Incremental reading is also about forgetting

There is another subtle idea.

Suppose you read an interesting paragraph today.

If you simply mark it "read," your brain may forget it.

IR can bring the paragraph back later.

But when it returns, you may not simply reread it.

You might:

```text
Read
↓
Extract
↓
Reread
↓
Formulate
↓
Recall
```

Each pass can transform the information.

So the system isn't merely scheduling pages.

It's scheduling **successive encounters with information**.

---

# 14. Knowledge becomes progressively compressed

This is one of the deepest ideas behind IR.

Imagine:

### Stage 1 — source

5000 words

↓

### Stage 2 — extract

500 words

↓

### Stage 3 — important extract

100 words

↓

### Stage 4 — formulation

20 words

↓

### Stage 5 — question

8 words

↓

### Stage 6 — memory

Conceptual representation in your brain

So:

```text
5000 words
    ↓
500 words
    ↓
100 words
    ↓
20 words
    ↓
8-word question
    ↓
mental model
```

You are progressively **compressing information while preserving what matters**.

This is a much better way to think about incremental reading than "reading articles in chunks."

---

# 15. But IR isn't just compression

There's a second dimension:

## Connections

Suppose you're learning machine learning.

You read:

```text
Article A:
Gradient descent
```

Then another source:

```text
Article B:
Convex optimization
```

Then:

```text
Article C:
Learning rate schedules
```

Your extracted knowledge can link them:

```text
Gradient descent
      │
      ├── optimization
      │
      ├── learning rate
      │
      └── convexity
```

Eventually you're not just accumulating cards.

You're constructing a **network of concepts**.

This is why IR is often more appropriate for research-heavy learning than pure flashcard systems.

---

# 16. IR vs Anki

Here's the cleanest comparison:

| | Anki | Incremental Reading |
|---|---|---|
| Primary object | Card | Learning item/source |
| Input | Usually prepared knowledge | Raw sources |
| Reading | External to scheduler | Part of scheduler |
| Unit | Question/answer | Source, extract, question, etc. |
| Scheduling | Reviews | Reading + processing + reviews |
| Extraction | Manual/external | Native operation |
| Formulation | Usually immediate | Can be delayed |
| Priority | Secondary | Central |
| Goal | Retention | Processing + understanding + retention |
| Source completion | Usually before cards | Not necessary |
| Knowledge graph | Minimal | Natural |
| Workflow | Linear-ish | Highly iterative |

The key distinction:

> **Anki schedules your memory. IR schedules your interaction with information.**

---

# 17. What SuperMemo is actually doing

SuperMemo is not one feature called "Incremental Reading."

It's closer to an entire environment for managing learning.

You have concepts such as:

- collections
- elements
- incremental reading
- extracts
- repetitions
- forgetting
- priorities
- scheduling
- knowledge organization
- formulation
- learning algorithms

That's why opening SuperMemo and trying to understand it as an Anki alternative is painful.

You're looking at an **information-processing environment**, not just a flashcard application.

---

# 18. A much simpler IR system you could build

If you're building your own tool, I would **not** start by implementing SuperMemo.

Build this:

### Object types

```text
Source
Extract
Card
```

### Source

```text
Source
- title
- content
- position
- priority
- next_due
```

### Extract

```text
Extract
- content
- source_id
- priority
- next_due
```

### Card

```text
Card
- question
- answer
- source_id / extract_id
- next_due
- interval
- ease
```

Then give the user four operations:

```text
READ
EXTRACT
FORMULATE
REVIEW
```

That's already a real incremental-reading system.

---

# 19. Your daily screen could be extremely simple

Instead of SuperMemo's complexity:

```text
TODAY

1. Read Article A
   8 minutes

2. Review card
   30 seconds

3. Continue Article B
   5 minutes

4. Process extract
   2 minutes

5. Review card
   20 seconds
```

The user simply works through a **queue**.

The queue contains heterogeneous tasks:

```text
┌─────────────────────────┐
│ Read Article A          │
│ 5 minutes               │
└─────────────────────────┘

┌─────────────────────────┐
│ Review: What is X?      │
│ 20 seconds              │
└─────────────────────────┘

┌─────────────────────────┐
│ Process Extract B       │
│ 2 minutes               │
└─────────────────────────┘
```

This is probably the right conceptual starting point for your product.

---

# 20. The most important architectural insight

Don't model your application as:

```text
Deck
 └── Cards
```

That's the Anki mental model.

Model it more like:

```text
Library
│
├── Sources
│   ├── Article A
│   ├── Book B
│   └── Paper C
│
├── Extracts
│   ├── Extract A1
│   ├── Extract A2
│   └── Extract C1
│
├── Cards
│   ├── Card A1
│   └── Card C1
│
└── Queue
    ├── Read A
    ├── Review Card A1
    ├── Process Extract A2
    └── Read C
```

**The queue is the heart of the application.**

Not the deck.

---

# 21. One more concept: "incremental" doesn't mean arbitrary tiny chunks

Don't make the mistake of thinking:

> "I'll split every article into 100-word chunks and show one per day."

That's not really the interesting part.

The chunk size should depend on the **cognitive operation**.

For example:

```text
Reading:
500 words

Extract:
one paragraph

Formulation:
one idea

Review:
one question
```

These are different granularities.

Your system should therefore treat **reading position** separately from **knowledge units**.

---

# 22. The complete mental model

If you remember only one diagram, make it this:

```text
                         ┌──────────────┐
                         │    SOURCE    │
                         │ article/book │
                         └──────┬───────┘
                                │
                         incremental read
                                │
                                ▼
                         ┌──────────────┐
                         │   EXTRACT    │
                         │ useful idea  │
                         └──────┬───────┘
                                │
                         revisit / process
                                │
                                ▼
                         ┌──────────────┐
                         │ FORMULATION  │
                         │   question   │
                         └──────┬───────┘
                                │
                           spaced recall
                                │
                                ▼
                         ┌──────────────┐
                         │    MEMORY    │
                         └──────────────┘


Every stage has:

        ┌───────────────┐
        │ next_due      │
        │ priority      │
        │ scheduling    │
        └───────────────┘
```

So the fundamental abstraction is:

> **An item is something that needs cognitive work, and the scheduler decides when that work should happen.**

That is the conceptual leap from Anki to Incremental Reading.

---

## Where I would go next

Since you're building a tool, the next thing you need isn't more SuperMemo terminology. You need to understand **exactly how an IR session works from the user's perspective**, including:

1. **How items are scheduled**
2. **How reading position works**
3. **How extraction works**
4. **How prioritization works**
5. **How incremental reading differs from normal spaced repetition**
6. **What happens when you forget something**
7. **How to turn extracts into good cards**
8. **What data model you need**
9. **What the daily algorithm/queue should actually do**
10. **Which SuperMemo features are essential vs unnecessary complexity**

I can walk you through those as if we're reverse-engineering SuperMemo and designing a **much simpler IR system from scratch**.

**Which should we tackle next: scheduling, the user workflow, or the data model?**

## User

the user workflow

## Assistant

# Incremental Reading: the actual user workflow

If you're building the tool, start here. Ignore SuperMemo's terminology and algorithms for now.

The user's experience should be understandable as:

> **Collect → read a little → extract what matters → come back later → process → formulate → review → repeat**

But there are important details hidden inside each step.

---

# 1. The user starts with a source

The user imports something:

- article
- PDF
- book
- web page
- lecture notes
- research paper
- YouTube transcript, etc.

Example:

> **Paper: Attention Is All You Need**

The system creates a **Source**.

```text
Source
────────────────────────
Attention Is All You Need

Progress: 0%
Priority: High

Next: Read
```

At this point, there are **no cards**.

That's important.

The user doesn't need to decide in advance what should become a card.

---

# 2. The system gives them a small portion

The user clicks:

> **Continue reading**

Instead of opening the entire paper and expecting them to finish it, the system gives them a manageable portion.

For example:

```text
────────────────────────────────

The dominant sequence transduction
models are based on complex recurrent
or convolutional neural networks...

[... 500 words ...]

────────────────────────────────

        Continue reading
```

The system remembers:

```text
Source position = 8%
```

The user stops when they've reached a natural stopping point.

Then:

> **Done**

The source gets scheduled again.

```text
Attention Is All You Need
Position: 8%
Next: tomorrow
```

This is the first major difference from Anki:

**The user's unfinished reading is itself scheduled.**

---

# 3. While reading, the user notices something valuable

Suppose they encounter:

> "The Transformer is based solely on attention mechanisms, dispensing with recurrence and convolutions entirely."

They think:

> I want to remember this.

They select the sentence.

The UI offers:

```text
Extract
```

They click it.

Now the system creates:

```text
EXTRACT
────────────────────────
The Transformer is based solely on
attention mechanisms, dispensing with
recurrence and convolutions entirely.

Source:
Attention Is All You Need

Next: tomorrow
```

And the user continues reading.

---

# 4. The important distinction: the source and extract are now separate

This is fundamental.

You now have:

```text
SOURCE
Attention Is All You Need
Position: 12%
Next: tomorrow

        │
        └──────> EXTRACT
                 "The Transformer is based
                  solely on attention..."

                 Next: tomorrow
```

They have **different schedules**.

Tomorrow, the user might:

- continue reading the source
- process the extract
- do both

The extract is no longer dependent on the user's reading position.

---

# 5. The user eventually encounters the extract again

The next day:

```text
TODAY
────────────────────────

1. Continue reading
   Attention Is All You Need

2. Process extract
   "The Transformer is based solely
    on attention mechanisms..."

3. Review card
   What is self-attention?

────────────────────────
```

The user opens the extract.

Now they can decide:

### A. Keep it as an extract

Maybe they don't yet understand it.

### B. Edit it

Maybe they want to shorten it.

### C. Formulate it into a card

Maybe they now understand it well enough.

This is why **extraction and formulation are separate operations**.

---

# 6. Formulation

Suppose the extract is:

> The Transformer is based solely on attention mechanisms, dispensing with recurrence and convolutions entirely.

The user turns it into:

**Question**

> What are Transformers based on instead of recurrence and convolution?

**Answer**

> Attention mechanisms.

Now it becomes a review item.

```text
EXTRACT
     ↓
FORMULATE
     ↓
CARD
```

The card gets its own repetition schedule.

For example:

```text
Card
────────────────────
Q: What are Transformers
based on instead of recurrence
and convolution?

A: Attention mechanisms.

Next review: Aug 23
```

---

# 7. But the user does NOT have to formulate everything

This is critical.

Imagine the user reads 30 pages and extracts 15 things.

They might have:

```text
15 extracts
```

They shouldn't be forced to create:

```text
15 cards
```

Instead:

```text
15 extracts
│
├── 4 → formulate into cards
├── 6 → keep as extracts
├── 3 → delete
└── 2 → merge
```

This is one of the main reasons IR can feel less labor-intensive than manually converting everything into Anki cards.

---

# 8. Extracts can themselves be processed incrementally

This is where things become recursive.

Suppose you extract a difficult paragraph:

> Modern neural networks exhibit double descent...

You don't understand it completely.

You don't need to formulate a card.

You schedule the extract.

Later:

```text
Extract appears
↓
Read it again
↓
Understand more
↓
Extract one sentence
↓
Delete irrelevant part
↓
Formulate question
```

So an extract can evolve.

```text
Source
  ↓
Extract
  ↓
Smaller Extract
  ↓
Card
```

This is the **incremental processing** aspect.

---

# 9. The user's queue is heterogeneous

This is probably the most important UX concept for your application.

Don't show the user:

> "Your cards are due."

Show:

> **"Here's what you should work on."**

For example:

```text
TODAY
════════════════════════════════

READ
Attention Is All You Need
~5 min

REVIEW
What is self-attention?
~20 sec

PROCESS
Double descent extract
~2 min

READ
Deep Learning textbook
~5 min

REVIEW
What does gradient descent minimize?
~20 sec

PROCESS
Bayesian inference extract
~3 min
```

The queue combines different cognitive activities.

---

# 10. Why this is different from an Anki deck

In Anki:

```text
              DECK
                │
                ▼
        ┌───────────────┐
        │ cards due     │
        └───────┬───────┘
                │
          review cards
```

In IR:

```text
                  LIBRARY
                     │
          ┌──────────┼──────────┐
          ↓          ↓          ↓
       Sources    Extracts    Cards
          │          │          │
          └──────────┼──────────┘
                     ↓
                  SCHEDULER
                     ↓
                    QUEUE
                     ↓
              user's next task
```

The scheduler is sitting **above** all the different object types.

---

# 11. What happens when the user opens a source?

This is where I'd recommend a very simple UX.

Show:

```text
┌─────────────────────────────────────┐
│ Attention Is All You Need            │
│                                     │
│ Progress: 18%                       │
│                                     │
│ "The dominant sequence transduction │
│ models are based on complex..."     │
│                                     │
│ ...                                 │
│                                     │
│              [Done]                 │
└─────────────────────────────────────┘
```

And allow:

- **Extract**
- **Highlight**
- **Ignore**
- **Done**

You don't need to expose scheduling complexity.

The system handles it.

---

# 12. What happens when the user clicks "Extract"?

I'd make this almost frictionless.

User selects:

> "Attention mechanisms provide a way to..."

Then:

```text
[Extract]
```

Immediately:

```text
✓ Extracted
```

Don't interrupt the reading flow with:

> Set priority  
> Choose repetition interval  
> Choose item type  
> Choose destination  
> Choose scheduling algorithm

That's SuperMemo's complexity leaking into the user's workflow.

The user should primarily be thinking about **the material**, not your database.

---

# 13. What happens when the user finishes reading?

This is an important design decision.

Don't force:

> "Choose when to read this again."

Instead, your scheduler decides.

You might show:

```text
Finished this session.

Progress: 18% → 23%

Next reading:
Tomorrow
```

Advanced users could override it.

But default behavior should be automatic.

---

# 14. The user can interrupt themselves

Suppose they're reading:

```text
Article A
```

and encounter a concept they don't understand:

> "Bayesian hierarchical model..."

They can create a new source:

```text
Search / Add source:
"What is a Bayesian hierarchical model?"
```

Now you have:

```text
Article A
   │
   └── concept: Bayesian hierarchical model
                       │
                       ↓
                  New Source B
```

Later the queue can surface Source B.

This creates a **research loop**:

```text
Read
 ↓
Encounter unknown concept
 ↓
Capture it
 ↓
Research it
 ↓
Return to original source
```

This is much closer to how serious research actually works.

---

# 15. The user should be able to postpone

Suppose the queue says:

```text
Process:
Bayesian inference extract
```

But the user doesn't feel like doing it.

They should be able to say:

> Later

And the item gets rescheduled.

This is different from "again" in Anki.

Anki's Again generally means:

> I failed retrieval.

IR's postponement means:

> This is not the right task for me right now.

Those are different signals and should be modeled separately.

---

# 16. There are therefore several user actions

Your initial tool could have only these:

| Action | Meaning |
|---|---|
| **Continue** | Continue processing the item |
| **Extract** | Create a smaller learning item |
| **Formulate** | Turn an extract into a question |
| **Review** | Test memory |
| **Done** | Finish this session |
| **Later** | Reschedule without processing |
| **Delete** | This isn't worth keeping |
| **Edit** | Improve the content |

That's enough for an MVP.

---

# 17. A complete example

Let's follow one article over several days.

## Day 1

User imports:

> "Introduction to Bayesian Inference"

System:

```text
Read 500 words.
```

User reads.

Finds an important paragraph.

```text
Extract paragraph.
```

User stops.

State:

```text
Article
position: 9%
next: tomorrow

Extract
next: tomorrow
```

---

## Day 2

Queue:

```text
1. Article → continue reading
2. Extract → process
```

User processes the extract.

They don't understand it fully.

They click:

> Keep

System schedules it again.

Then they continue the article.

They find another useful statement.

```text
Extract #2
```

---

## Day 3

Queue:

```text
1. Extract #1
2. Article
3. Extract #2
```

Extract #1 now makes sense.

User formulates:

```text
Q: What does Bayesian inference
update when new evidence arrives?

A: The posterior distribution.
```

Now:

```text
Extract #1 → Card #1
```

---

## Day 5

Queue:

```text
Review Card #1
```

User answers:

> Posterior distribution.

Correct.

Card gets a longer interval.

Meanwhile:

```text
Article → continue
Extract #2 → process
```

The article may eventually reach:

```text
100%
```

But the cards extracted from it continue existing independently.

---

# 18. Notice what happened

The original source:

```text
5000 words
```

produced:

```text
Source
│
├── Extract 1
│    └── Card 1
│
├── Extract 2
│
├── Extract 3
│    └── Card 2
│
└── Extract 4
     └── Extract 4a
          └── Card 3
```

And each object has its own lifecycle.

That's the essence of IR.

---

# 19. The lifecycle you should implement

For your tool, I'd model it explicitly:

```text
SOURCE

  ↓ read

SOURCE
  ├── continue
  ├── extract
  └── finish

EXTRACT

  ↓ process

EXTRACT
  ├── keep
  ├── edit
  ├── extract again
  ├── formulate
  └── delete

CARD

  ↓ review

CARD
  ├── remembered
  ├── forgotten
  └── postpone
```

And **every node can be scheduled**.

---

# 20. The biggest mistake to avoid

Don't design the application around:

> **"How do I make Incremental Reading work like Anki?"**

That will produce something awkward.

Instead:

> **"How do I build a scheduler for progressively processing information?"**

Then Anki-style spaced repetition becomes **one component inside it**.

The conceptual hierarchy is:

```text
                    LEARNING SYSTEM
                          │
              ┌───────────┴───────────┐
              │                       │
        INFORMATION               MEMORY
        PROCESSING               RETENTION
              │                       │
       ┌──────┼──────┐                │
       ↓      ↓      ↓                ↓
     Read  Extract  Formulate       Review
       │      │      │                │
       └──────┴──────┴────────────────┘
                       │
                   SCHEDULER
                       │
                     QUEUE
                       │
                     USER
```

**That's the user workflow you want to reproduce.**

The next thing I'd tackle is the **scheduler**, because this is where IR becomes technically interesting: *given 100 sources, 200 extracts, and 300 cards, how does the system decide what the user sees next?* That's the part that determines whether your tool is actually incremental reading or merely an article reader with flashcards.

## User

1. **How reading position works** 
2. **How extraction works** 
3. **How prioritization works**

## Assistant

Yes. These three are the parts you need to get right in the data model and UX. I'll explain them from the perspective of **"what should my tool actually do?"**, not from SuperMemo terminology.

---

# 1. How reading position works

This sounds trivial:

> "Store the character offset."

But there are actually two separate concepts:

1. **Where the user is in the source**
2. **What portion the system should show next**

## 1.1 The basic model

Suppose a source contains 10,000 words.

The user has read the first 2,000.

You can represent:

```text
source.total = 10,000 words
source.position = 2,000
```

So:

```text
Progress = 20%
```

Next time, you start around word 2,001.

Simple.

But don't actually build your system around a raw character offset if you can avoid it.

---

## 1.2 Why character offsets are fragile

Imagine the source contains:

```text
The Transformer uses attention...
```

The user is at character 14,283.

Then you clean the HTML, fix a typo, or change formatting.

Now character 14,283 might point to a completely different place.

For a robust implementation, represent the source as **stable blocks**.

For example:

```text
Source
│
├── paragraph_001
├── paragraph_002
├── paragraph_003
├── paragraph_004
├── ...
└── paragraph_200
```

Then the reading position can be:

```text
current_block = paragraph_37
offset_in_block = 0.4
```

Or, even better, give every block a stable ID.

```text
reading_position:
    block_id = paragraph_37
```

Now you can reconstruct the reading position even if the UI changes.

---

# 1.3 Don't think "read/unread"

This is important.

Don't model:

```text
paragraph_1 = read
paragraph_2 = read
paragraph_3 = unread
```

IR doesn't really care about a binary read/unread state.

The important state is:

> **Where did the user's processing frontier reach?**

Think of it as a cursor:

```text
SOURCE

[processed] [processed] [processed] [cursor] [unprocessed]
                         ↑
                      position
```

The user moves the cursor forward.

---

# 1.4 What happens when the user stops?

Suppose today's session shows:

```text
Paragraph 35
Paragraph 36
Paragraph 37
Paragraph 38
```

They stop halfway through paragraph 38.

You save:

```text
position = paragraph_38 + offset
```

Next time:

```text
Continue from here
```

The user should not have to manually remember where they were.

---

# 1.5 But here's a subtle problem

What if the user extracts something?

Suppose:

```text
Paragraph 38
```

contains:

> Attention allows the model to...

They extract that sentence.

Now you have:

```text
Source
│
├── reading position → paragraph 38
│
└── Extract
      └── references paragraph 38
```

The extract is **not the reading position**.

It is a separate object referencing a location in the source.

That's why your database should separate:

```text
Source.position
```

from:

```text
Extract.source_location
```

---

# 1.6 Reading position and scheduling are separate

This distinction is crucial.

Imagine:

```text
Article A
position = 40%
next_reading = tomorrow
```

Tomorrow arrives.

The system gives the user another chunk.

After reading it:

```text
position = 47%
next_reading = 3 days later
```

The position says:

> **How far have I processed the source?**

The schedule says:

> **When should I process more?**

Never combine those concepts.

---

# 1.7 What if the user doesn't want to continue?

They might encounter an article and decide:

> "This isn't worth reading anymore."

Then:

```text
Source.status = abandoned
```

Or:

```text
Source.status = suspended
```

This is important because IR systems can otherwise accumulate enormous amounts of unfinished material.

Your tool needs an easy **"I'm done with this source"** operation.

---

# 2. How extraction works

Extraction is much more interesting than simply copying text.

The user's thought is:

> "This part is worth preserving separately."

So extraction creates a **new learning object derived from a source**.

---

# 2.1 Example

Source:

> The Transformer architecture dispenses with recurrence and convolutions and instead relies entirely on attention mechanisms. This allows significantly greater parallelization during training.

User selects:

> This allows significantly greater parallelization during training.

Clicks:

> **Extract**

You create:

```text
Extract
────────────────────────────
This allows significantly greater
parallelization during training.

source_id:
    transformer-paper

source_location:
    paragraph_12
```

Now the extract can have its own schedule:

```text
next_due = tomorrow
```

---

# 2.2 The source remains unchanged

This is important.

Extraction shouldn't mean:

> Cut this text out of the article.

It means:

> Create a reference to this piece of the article.

So conceptually:

```text
SOURCE
  │
  │ contains
  ↓
PASSAGE
  │
  │ extracted into
  ↓
EXTRACT
```

The extract should ideally remember:

```text
extract.source_id
extract.start
extract.end
```

or:

```text
extract.source_block_ids
```

This gives you provenance.

The user should always be able to click:

> **View in source**

and jump back to the original context.

---

# 2.3 Extraction should preserve context

Here's a common mistake.

User selects:

> "This allows significantly greater parallelization..."

But six months later they see:

> "This allows significantly greater parallelization..."

and think:

> "This what?"

The tool should be able to show:

```text
Extract
────────────────────
This allows significantly greater
parallelization during training.

[Show context]

...the Transformer architecture dispenses
with recurrence and convolutions...

THIS ALLOWS SIGNIFICANTLY GREATER
PARALLELIZATION DURING TRAINING.

...while maintaining...
```

This is one of the advantages of keeping a source reference.

---

# 2.4 Extraction is a branching operation

A source can generate many extracts:

```text
                    SOURCE
                      │
          ┌───────────┼───────────┐
          ↓           ↓           ↓
       Extract A   Extract B   Extract C
          │                       │
          ↓                       ↓
       Card A                  Extract C2
                                  │
                                  ↓
                               Card C2
```

This forms a tree/graph.

You should model the relationship explicitly.

Something like:

```text
extract.source_id
extract.parent_id
```

where `parent_id` is useful if an extract comes from another extract.

---

# 2.5 Extracts can be nested

This is an important IR behavior.

Suppose the user extracts an entire paragraph:

```text
Extract A
```

Later they realize only one sentence matters.

They can extract from the extract:

```text
Extract A
   ↓
Extract A.1
```

Or you can simply create a new extract linked to the same source.

Both designs are possible.

For an MVP, I'd recommend:

> **Keep source provenance as the primary relationship and treat parent/child relationships as optional metadata.**

It avoids unnecessary complexity.

---

# 2.6 Extraction should be fast

The interaction should be something like:

```text
Select text
     ↓
E
     ↓
Extract created
     ↓
Continue reading
```

Not:

```text
Select text
↓
Modal
↓
Title
↓
Tags
↓
Priority
↓
Schedule
↓
Folder
↓
Source
↓
Save
```

That destroys the reading flow.

The system can infer most metadata.

---

# 2.7 Extraction is not highlighting

You should distinguish:

### Highlight

> "This is interesting in this reading session."

### Extract

> "I want this to become an independent learning object."

They can coexist.

For example:

```text
Highlight → temporary/local annotation

Extract → scheduled object
```

If you only implement one for your MVP, implement **extract**.

---

# 2.8 What makes something worth extracting?

This is where the user is doing intellectual work.

Good extraction candidates:

- surprising facts
- important definitions
- causal relationships
- useful examples
- arguments
- principles
- things you don't fully understand
- things likely to be useful later

Bad extraction candidates:

- every sentence
- obvious information
- redundant statements
- things you already know extremely well
- entire pages

If your tool automatically extracts everything, you've basically built a clipping application.

The **human decides what deserves another encounter**.

---

# 3. How prioritization works

This is the part most likely to confuse an Anki user.

Anki primarily asks:

> Is this due?

IR asks:

> **How valuable is this item relative to everything else competing for the user's attention?**

Those are different questions.

---

# 3.1 Imagine 500 items

Your library might contain:

```text
100 sources
250 extracts
150 cards
```

Tomorrow, potentially 100 things could deserve attention.

But the user has:

> 30 minutes.

You need to select the best work.

That's prioritization.

---

# 3.2 Priority is not urgency

Suppose:

```text
Item A
Priority: 90
Due: today

Item B
Priority: 20
Due: today
```

A should probably come first.

But suppose:

```text
Item A
Priority: 90
Due: next week

Item B
Priority: 20
Due: today
```

Now B might deserve attention because it is overdue.

So you need at least two concepts:

```text
importance
+
urgency
```

---

# 3.3 A useful conceptual model

For your implementation, think:

```text
score =
    importance
    × urgency
    × relevance
    × maybe other factors
```

Don't take that formula literally yet. It's a conceptual model.

For example:

```text
                    Priority score

Importance ─────────────┐
                        │
Urgency ────────────────┼──→ Queue ranking
                        │
User goal ──────────────┤
                        │
Overdue ────────────────┘
```

Then the queue shows the highest-scoring tasks.

---

# 3.4 What determines importance?

Potential inputs:

### User explicitly sets priority

```text
High
Normal
Low
```

### Source priority

A paper you're actively researching might be high priority.

### Extract priority

An extremely important passage can inherit or exceed source priority.

### User goals

If the user has a current project:

> "Learn reinforcement learning"

then RL-related material gets a boost.

### Recency/context

If the user is currently working on a topic, related items might be temporarily promoted.

You don't need all of these initially.

---

# 3.5 SuperMemo's priority concept is more sophisticated

SuperMemo has historically used priority to influence how much attention an item receives.

This is related to a deeper idea:

> **You cannot learn everything.**

Therefore the system needs to decide which knowledge deserves more investment.

That's a very different philosophy from:

> "Put everything into Anki and review it forever."

IR accepts that your information collection may be much larger than your available learning capacity.

---

# 3.6 Priority can propagate

Suppose:

```text
Source:
"Deep Learning"
Priority = 80
```

You extract:

```text
"Backpropagation computes gradients..."
```

That extract could inherit:

```text
priority = 80
```

But perhaps the user says:

> This is extremely important.

Then:

```text
extract priority = 100
```

Later you formulate a card.

The card can inherit the extract's priority.

So:

```text
Source 80
   ↓
Extract 100
   ↓
Card 100
```

But don't make inheritance mandatory. Users should be able to override it.

---

# 3.7 Priority should influence scheduling, not replace it

This is a subtle but important design rule.

Don't do:

```text
highest priority = show constantly
```

Otherwise the system becomes:

> "Here is the same important article again."

Instead:

```text
Priority
   ↓
influences when it gets selected
```

while:

```text
Scheduling state
   ↓
determines whether it is eligible
```

Think of it as two stages:

```text
                 ALL ITEMS
                     │
                     ↓
              Eligibility filter
                     │
           ┌─────────┴─────────┐
           ↓                   ↓
         eligible           not eligible
           │
           ↓
       prioritization
           │
           ↓
          QUEUE
```

This architecture will save you trouble later.

---

# 3.8 Example

Suppose your system has:

| Item | Type | Due | Priority |
|---|---|---:|---:|
| Paper A | Source | Today | 90 |
| Card B | Card | Today | 70 |
| Extract C | Extract | Today | 40 |
| Article D | Source | Tomorrow | 100 |
| Card E | Card | 3 days ago | 50 |

First, determine eligibility.

```text
Paper A   ✓
Card B    ✓
Extract C ✓
Article D maybe
Card E    ✓ overdue
```

Then rank them.

Potential queue:

```text
1. Paper A
2. Card E
3. Card B
4. Extract C
```

The exact algorithm is your product decision.

The important architectural point is:

> **Due-ness and priority are separate dimensions.**

---

# 4. How these three concepts connect

Now put everything together.

## Reading position

Answers:

> **Where am I in this source?**

```text
Source A
position = 37%
```

## Extraction

Answers:

> **Which parts deserve independent attention?**

```text
Source A
 ├── Extract 1
 ├── Extract 2
 └── Extract 3
```

## Prioritization

Answers:

> **Which of all these things deserves my attention now?**

```text
Sources
Extracts
Cards
   ↓
priority + scheduling
   ↓
queue
```

Together:

```text
                         LIBRARY
                            │
             ┌──────────────┼──────────────┐
             ↓              ↓              ↓
          SOURCE         EXTRACT          CARD
             │              │              │
        position        own schedule   own schedule
             │              │              │
             └──────────────┼──────────────┘
                            ↓
                       PRIORITIZATION
                            ↓
                          QUEUE
                            ↓
                           USER
                            │
             ┌──────────────┼──────────────┐
             ↓              ↓              ↓
           READ          EXTRACT         REVIEW
             │              │              │
             └──────────────┼──────────────┘
                            ↓
                         updates
```

---

# 5. The data model I'd use for an MVP

You can already derive a reasonable schema.

### Source

```text
Source
- id
- title
- content
- blocks
- reading_position
- priority
- next_due
- status
```

### Extract

```text
Extract
- id
- source_id
- start_block
- end_block
- content
- priority
- next_due
- status
```

### Card

```text
Card
- id
- extract_id
- question
- answer
- priority
- due
- interval
- ease
- state
```

And later:

```text
Session
- id
- item_id
- action
- timestamp
- duration
```

That last table becomes useful because eventually you will want to know:

> How long does this user actually spend reading?

> How much text do they process per session?

> How often do they extract?

> Which sources are constantly postponed?

Those signals can improve scheduling.

---

# 6. One architectural decision I'd make early

Don't make `Source`, `Extract`, and `Card` completely unrelated entities.

Create a common abstraction:

```text
LearningItem
├── id
├── type
├── priority
├── next_due
├── created_at
├── updated_at
└── state
```

Then:

```text
Source extends LearningItem
Extract extends LearningItem
Card extends LearningItem
```

Conceptually:

```text
LearningItem
      │
 ┌────┼────┐
 ↓    ↓    ↓
Source Extract Card
```

Because your scheduler doesn't fundamentally care whether something is a source or a card.

It cares:

> **What is this item? Is it eligible? How important is it? What action should the user perform?**

That's the abstraction I'd build the rest of the system around.

---

## The key insight

Anki teaches you to think:

> **Card → due date → review**

IR requires you to think:

> **Information → item → state → schedule → cognitive action → new state**

That difference is the foundation of the entire product.

The next thing to understand is **the scheduling/state machine**: exactly what happens to a Source after a reading session, what happens to an Extract after processing, and how a Card's Anki-like repetition scheduler fits into the same queue. That's where the three concepts above become an actual implementable system.

## User

i want to make it work on android and windows, which language i should use for it

## User

so based on what we have discussed, if i implement what we have discussed this should be a complete IR

## Assistant

Yes — **if by “what we discussed” you mean the full workflow plus the three mechanisms we covered, you would have a legitimate Incremental Reading system**, not just an Anki clone with an article reader.

But there is an important distinction:

> You would have a **complete core IR system**, not necessarily a complete implementation of everything SuperMemo calls Incremental Reading.

### Your core system

You need these pieces:

| Component | Required? | What it does |
|---|---:|---|
| Sources | ✅ | Articles/books/PDFs/etc. |
| Incremental reading | ✅ | Read a source progressively |
| Reading position | ✅ | Remember exactly where to continue |
| Scheduling | ✅ | Decide when an item returns |
| Extraction | ✅ | Promote useful passages into independent items |
| Extract scheduling | ✅ | Revisit extracts independently |
| Formulation | ✅ | Convert extracts into questions/cards |
| Spaced repetition | ✅ | Schedule formulated cards |
| Priorities | ✅ | Decide which work deserves attention |
| Unified queue | ✅ | Mix reading, processing and reviewing |
| Suspend/delete | ✅ | Prevent the library becoming unmanageable |
| Source provenance | ✅ | Know where an extract/card came from |

The resulting architecture is:

```text
                     LIBRARY
                        │
       ┌────────────────┼────────────────┐
       │                │                │
     SOURCE           EXTRACT           CARD
       │                │                │
   position         schedule          SRS state
   schedule         priority          priority
   priority
       │                │                │
       └────────────────┼────────────────┘
                        ↓
                  QUEUE / SCHEDULER
                        ↓
                       USER
                        │
              ┌─────────┼─────────┐
              ↓         ↓         ↓
             READ    EXTRACT    REVIEW
              │         │         │
              └─────────┼─────────┘
                        ↓
                   STATE CHANGES
```

That is the core IR loop.

---

## But I would change one thing from our earlier discussion

Don't think of **"Card" as the final destination of every Extract**.

The real pipeline should be:

```text
Source
  ↓
Read
  ↓
Extract
  ↓
Process
  ├── discard
  ├── keep as extract
  ├── extract further
  └── formulate into card
                    ↓
                  Review
```

That distinction is essential.

If your application forces:

```text
Interesting passage → Card
```

you've basically recreated an Anki workflow.

If it allows:

```text
Interesting passage → Extract → revisit → understand → maybe card
```

then you're implementing the important IR idea.

---

# What would make it "SuperMemo-level"?

That's a different question.

SuperMemo has a much larger ecosystem around IR: sophisticated scheduling, priority calculations, forgetting models, workload management, knowledge organization, formulation techniques, etc.

You **do not need all of that** for your application to be a complete IR implementation.

I'd divide it into three levels:

### Level 1 — IR MVP

```text
Sources
+
incremental reading
+
position
+
extracts
+
scheduling
+
formulation
+
SRS cards
```

This is already IR.

### Level 2 — Good IR application

Add:

```text
priority
unified queue
automatic workload management
source provenance
suspension
search
editing
cross-links
statistics
```

This is what I'd recommend building.

### Level 3 — SuperMemo-like system

Add much more sophisticated:

```text
priority algorithms
forgetting models
automatic scheduling optimization
knowledge graphs
advanced repetition algorithms
advanced formulation
learning metrics
complex workload balancing
```

You don't need this initially.

---

# The bigger issue: your scheduler

There is one thing we haven't fully designed yet, and it is arguably the **heart of the application**.

You can have:

```text
100 Sources
300 Extracts
500 Cards
```

and correctly store:

```text
position
next_due
priority
interval
```

but you still need to answer:

> **What should the user do right now?**

For example:

```text
08:00

Review card A
Read source B
Process extract C
Review card D
Continue source E
```

You need an algorithm that turns those into:

```text
1. Review card D
2. Continue source B
3. Process extract C
4. Review card A
5. Continue source E
```

That **queue-generation algorithm** is where your implementation becomes an actual IR system rather than a database containing IR objects.

---

# And there's another thing I'd strongly recommend

Since you're targeting **Android + Windows**, don't start by trying to reproduce SuperMemo's UI or algorithms.

Build your own simpler conceptual model:

```text
LearningItem
├── Source
├── Extract
└── Card
```

Every item has roughly:

```text
id
type
priority
state
next_due
created_at
updated_at
```

Then each type adds its own state:

```text
Source:
    reading_position

Extract:
    source_reference

Card:
    stability
    difficulty
    interval
    ...
```

Then have one scheduler:

```text
Scheduler
    ↓
eligible items
    ↓
rank
    ↓
generate session
    ↓
user action
    ↓
update item
```

That architecture will work very well for a cross-platform application.

---

## So, short answer

**Yes.**

If you implement:

> **incremental source reading + persistent reading position + extraction + independently scheduled extracts + delayed formulation + spaced repetition + priority + unified task queue**

you have the **core of a complete Incremental Reading system**.

You don't need to implement every obscure SuperMemo feature to legitimately call it IR.

The next thing I'd design before writing code is the **scheduler/state machine**. Once we define exactly what happens to a Source, Extract, and Card after every possible user action, you can turn that directly into your database schema and application logic.

## User

what scheduler you recommend

## Assistant

For your project, I would **not copy SuperMemo's scheduler**. I would use a **hybrid scheduler**:

1. **FSRS for cards**
2. **A simpler custom scheduler for Sources and Extracts**
3. **A unified priority queue above both**

That gives you the benefits of Anki-style SRS without forcing reading and memory into the same algorithm.

## 1. Cards: FSRS

For formulated cards, use **FSRS** rather than inventing your own SRS algorithm.

Your card scheduler answers:

> "When should I test this memory again?"

The card has:

```text
due
stability
difficulty
retrievability
```

And user outcomes such as:

```text
Again
Hard
Good
Easy
```

FSRS handles the interval calculation.

This part can essentially behave like Anki.

---

# 2. Sources: use a reading scheduler

A source is different.

The question isn't:

> "Will I remember this article?"

It's:

> "When should I continue processing this article?"

I would start with a **simple interval schedule**.

For example:

```text
New source
    ↓
read
    ↓
tomorrow
    ↓
read
    ↓
3 days
    ↓
read
    ↓
7 days
    ↓
read
    ↓
14 days
```

But don't blindly increase the interval forever.

A source that's only 30% processed shouldn't disappear for six months.

I'd cap the interval based on progress.

For example:

```text
progress 0–25%     max interval 3 days
progress 25–50%    max interval 7 days
progress 50–75%    max interval 14 days
progress 75–99%    max interval 30 days
```

These numbers are starting heuristics, not scientific constants.

The important thing is:

> **Reading scheduling should primarily control how quickly you process a source, not how well you remember it.**

---

# 3. Extracts: schedule them differently

Extracts are in between sources and cards.

They represent:

> "This piece of information deserves another encounter."

I'd give them a simple revisit schedule.

For example:

```text
New extract
   ↓
tomorrow
   ↓
3 days
   ↓
7 days
   ↓
14 days
   ↓
30 days
```

But unlike a card, the user isn't necessarily tested.

When an extract appears, they can:

```text
KEEP
FORMULATE
EXTRACT MORE
DELETE
POSTPONE
```

So an extract is essentially a **scheduled processing task**.

---

# 4. Then put everything into one queue

This is the interesting part.

Suppose the system has:

```text
Card A
due today
priority 60

Card B
due today
priority 30

Source C
due today
priority 90

Extract D
due today
priority 80

Source E
due tomorrow
priority 100
```

Don't simply sort by due date.

First determine:

### Eligibility

```text
Is this available to work on?
```

Then calculate a ranking.

Something like:

```text
score =
    urgency
    × priority
    × relevance
    × workload_factor
```

Then:

```text
eligible items
      ↓
calculate score
      ↓
sort
      ↓
generate today's queue
```

---

# 5. But I would NOT make priority × urgency literally

That's only a conceptual model.

For the first implementation, I'd use something more understandable:

```text
score =
    base_priority
    + overdue_bonus
    + goal_relevance_bonus
    + age_bonus
```

For example:

```text
base priority:       0–100

overdue bonus:       up to +50

goal relevance:      0–30

neglect bonus:       up to +20
```

Then:

```text
Source A
priority = 80
overdue = +20
relevance = +10

score = 110
```

This is easier to debug than a complicated formula.

---

# 6. Very important: don't let reading starve reviews

Imagine:

```text
50 articles
500 extracts
100 cards
```

If your priority algorithm simply picks the most interesting things, the user could spend all day reading and never review their cards.

That's bad.

You need **category quotas**.

For example:

```text
Today's 30 minutes

Reviews:
    ~10 minutes

Reading:
    ~15 minutes

Processing:
    ~5 minutes
```

The queue can therefore reserve some capacity for each activity.

Conceptually:

```text
              TODAY'S CAPACITY
                     │
       ┌─────────────┼─────────────┐
       ↓             ↓             ↓
     CARDS         SOURCES       EXTRACTS
      30%            50%           20%
```

The percentages should eventually be user-configurable.

---

# 7. I'd make the scheduler time-based

This is particularly important for your application.

Don't say:

> "You have 47 items today."

Say:

> **"You have approximately 28 minutes of scheduled work."**

Each item gets an estimated duration:

```text
Card:       20–30 sec
Extract:    1–3 min
Reading:    5–10 min
```

Then the user chooses:

```text
10 min
20 min
30 min
60 min
```

Your scheduler generates a session that fits.

This is much closer to the actual problem IR is solving:

> **How should I spend my limited attention?**

---

# 8. The scheduler I would actually build

Architecture:

```text
                    SCHEDULER
                        │
             ┌──────────┴──────────┐
             │                     │
        Eligibility             Capacity
             │                     │
             └──────────┬──────────┘
                        ↓
                  Candidate pool
                        ↓
                  Priority ranking
                        ↓
                 Category balancing
                        ↓
                  Time estimation
                        ↓
                   Daily queue
```

And the specialized schedulers:

```text
             ┌──────────────────┐
             │ Unified Scheduler│
             └────────┬─────────┘
                      │
        ┌─────────────┼─────────────┐
        ↓             ↓             ↓
   Card scheduler  Source scheduler Extract scheduler
       FSRS           custom            custom
```

This is the architecture I'd recommend.

---

# 9. What happens after each action?

This is more important than the exact formula.

### Card

```text
Review
 ↓
Again / Hard / Good / Easy
 ↓
FSRS calculates next due
```

### Source

```text
Read 5 minutes
 ↓
position advances
 ↓
calculate next reading date
```

### Extract

```text
Process
 ↓
Keep → reschedule
Formulate → becomes card
Delete → done
Extract further → create another item
```

This gives you a clean state machine.

---

# 10. One thing I would NOT implement initially

Don't attempt to reproduce SuperMemo's **priority inheritance and complex priority formulas** immediately.

Start with explicit priority:

```text
Low     = 30
Normal  = 50
High    = 70
Critical = 90
```

Then later add automatic adjustments.

Similarly, don't invent a sophisticated reading-memory model.

You don't have enough user data initially to justify it.

---

# My recommendation

If I were building this:

**Cards**
→ **FSRS**

**Sources**
→ simple progressive reading scheduler

**Extracts**
→ simple spaced processing scheduler

**Queue**
→ priority + urgency + relevance + time budget

**Session**
→ time-based, with category balancing

So:

```text
                  ┌───────────────┐
                  │     USER      │
                  └───────┬───────┘
                          │
                     "30 minutes"
                          ↓
                  ┌───────────────┐
                  │ QUEUE BUILDER │
                  └───────┬───────┘
                          │
             ┌────────────┼────────────┐
             ↓            ↓            ↓
           Cards        Sources      Extracts
             ↓            ↓            ↓
           FSRS       Read schedule  Processing
             └────────────┼────────────┘
                          ↓
                    Ranked tasks
                          ↓
                    30-min session
```

**This is the scheduler I'd recommend for your first serious version.**

The next thing worth designing is the **exact state machine**—all states and transitions for `Source`, `Extract`, and `Card`. Once that is defined, the scheduler becomes much easier to implement correctly.