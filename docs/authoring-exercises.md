# Authoring exercises

How to add exercise content to Buna, for all six exercise types, with a
worked example of each.

This is about **content**, not schema: everything below writes rows into the
existing `exercises` table. Adding a *seventh type* is a different job — see
[Appendix B](#appendix-b-adding-a-seventh-exercise-type).

---

## Where content lives

All seeded content is Python data, not SQL and not an Alembic data migration.
Three modules hold it, and one loop writes all of it:

| File | What it holds | Style |
|---|---|---|
| [`seed_lesson_content.py`](../backend/app/infrastructure/db/seed_lesson_content.py) | The English→Amharic course's first two skills, plus `seed()` — the single idempotent write loop for everything | Hand-authored, one dict per exercise |
| [`seed_category_content.py`](../backend/app/infrastructure/db/seed_category_content.py) | 16 further English→Amharic lessons across four categories | Compact per-lesson input expanded by `_lesson(...)` |
| [`seed_course_content.py`](../backend/app/infrastructure/db/seed_course_content.py) | The other three courses (en→om, am→om, om→am) | Fully generated from one 16-word table |

The latter two build lists that `seed_lesson_content.py` appends to its own
(`seed_lesson_content.py:731-742`), so there is exactly one place rows are
written — `seed()` at `seed_lesson_content.py:745`.

### Running the seed

```powershell
cd backend
uv run python -m app.infrastructure.db.seed_lesson_content
```

It prints a count of what it wrote. It is **idempotent**: every row's id is
`uuid5(CONTENT_NAMESPACE, slug)`, so a re-run fetches each row by that id and
updates it in place. Nothing is ever duplicated and nothing is ever deleted.

Two consequences worth internalising:

- **Editing an exercise's text is free.** Change the dict, re-run, done.
- **Changing a `slug` is not an edit — it is a new row.** The old row keeps
  its old id and stays in the database forever, orphaned but served. If you
  need to rename, change the slug *and* delete the old row by hand.

Back up `dev.db` before running anything that isn't a plain re-seed.

---

## The shape of one exercise

Every exercise — hand-authored or generated — is a dict with these keys. They
are consumed verbatim at `seed_lesson_content.py:807-820`.

| Key | Required | Notes |
|---|---|---|
| `slug` | yes | Unique across the whole seed. Becomes the row id via `uuid5`. Convention: `exercise:<lesson-slug>:<n>` |
| `order_index` | yes | Unique within the lesson (`uq_exercises_lesson_order`). The order the learner sees |
| `type` | yes | One of the six below. Must also be in the `ck_exercises_type` CHECK constraint |
| `prompt` | yes | The instruction line, written in the learner's *from*-language |
| `content` | yes | JSON. The renderable half — what the client draws |
| `answer_key` | yes | JSON. The correct-answer half |
| `vocab_slug` | no | Links this exercise to a vocab item for SRS/Practice. Omit for most types — see rule 5 |

### Five rules that hold for every type

**1. `content` must never reveal its own answer.**
This is the load-bearing split. `content` holds tiles, choices, a sentence
with a hole in it; `answer_key` holds which tile, which choice, which order.
A gap-fill's missing word appears *only* in the answer key. A spell-tiles'
word never appears anywhere — only its scattered characters do.

**2. Ids are local to one exercise, and referenced only by id.**
The conventions across the existing seed:

| Type | Tile ids |
|---|---|
| `multiple_choice`, `listening`, `gap_fill` | `a`, `b`, `c`, `d` |
| `sentence_construction` | `w1`, `w2`, … |
| `match_pairs` | `l1`, `l2`, … / `r1`, `r2`, … |
| `spell_tiles` | `t1`, `t2`, … |

These are convention, not enforcement — but follow them, because the tests
and helpers assume them.

**3. Every id in `answer_key` must exist in `content`. Nothing checks this.**
Not the seed, not the ORM, not the domain entity. A dangling id is written
happily and fails on the learner's device:

- a bad `correct_choice_id` → the client's `choices.indexWhere(...)` returns
  `-1`, and no answer is ever correct;
- a bad id in `correct_sequence` → `textById[tileId]!` throws, and the whole
  lesson fails to load.

This is the single most common authoring mistake. [Check your work](#checking-your-work).

**4. Append; never renumber.**
`uq_exercises_lesson_order` is a unique constraint on `(lesson_id,
order_index)`. Shuffling existing exercises means updating two rows inside
one flush, which can collide transiently. Every type added after the first
four (`gap_fill`, then `spell_tiles`, then the extra `match_pairs`) was
appended at the end for exactly this reason — which is why slugs and
`order_index` drift apart: `hello-and-goodbye:6` sits at `order_index` 5.
**The slug number is stable history; the `order_index` is presentation
order.** They are not meant to match.

**5. Link at most one exercise per vocab item.**
`list_exercises_by_vocab_item_ids` keeps the first row per `vocab_item_id`,
so a second exercise sharing a word either never surfaces in Practice or
displaces the first, decided by a UUID comparison. In practice only the
`multiple_choice` exercises carry `vocab_slug`. A null `vocab_item_id` means
"no SRS tracking", not "not yet linked".

---

## The six types

Each section gives the `content`/`answer_key` shape, a real hand-authored
example, the generator that produces it in bulk, and what tends to go wrong.

### 1. `multiple_choice`

One prompt, four options, one right.

```python
{
    "slug": "exercise:hello-and-goodbye:1",
    "order_index": 1,
    "type": "multiple_choice",
    "vocab_slug": "vocab:hello",
    "prompt": "How do you say 'Hello' in Amharic?",
    "content": {
        "choices": [
            _choice("a", "ሰላም"),
            _choice("b", "ደህና ሁን"),
            _choice("c", "አመሰግናለሁ"),
            _choice("d", "አይ"),
        ]
    },
    "answer_key": {"correct_choice_id": "a"},
}
```

**Generated form** — `_choices(correct, others, position)` in
`seed_category_content.py:35`. It inserts `correct` at `position % 4` so the
answer is not always `a`, and returns the choices plus the correct id:

```python
choices, correct_id = _choices(target, others, order)
```

Pass `others` with at least three entries; it takes the first three.

**Rules**: at least 2 choices (`MultipleChoiceContent`). The distractors
should be words the learner has met — the existing seed draws them from the
same lesson's four words.

**Client**: converts `correct_choice_id` to an *index* into `choices` at
parse time, so choice order is fixed by the time it renders. Rendered and
graded.

### 2. `listening`

Identical to multiple choice, plus an audio file.

```python
{
    "slug": "exercise:hello-and-goodbye:3",
    "order_index": 3,
    "type": "listening",
    "prompt": "What does this word mean?",
    "content": {
        "audio_url": _audio_url("greetings-hello"),
        "choices": [
            _choice("a", "Hello"),
            _choice("b", "Goodbye"),
            _choice("c", "Thank you"),
            _choice("d", "Please"),
        ],
    },
    "answer_key": {"correct_choice_id": "a"},
}
```

**Note the direction flips.** The options are in the *from*-language here,
because the audio supplies the learning-language word.

**`audio_url` is a placeholder.** Every listening exercise in the seed points
at the same MP3 (`PLACEHOLDER_AUDIO_URL`, `seed_category_content.py:26`);
there is no R2 bucket in this environment. Swapping in real per-exercise URLs
later is a pure data update — re-run the seed — not a contract change. Use
`_audio_url(slug)` rather than the constant directly, so the day it becomes
per-exercise there is one function to change.

**Client**: rendered and graded. Also downloaded for offline packs, so the URL
must actually resolve.

### 3. `sentence_construction`

Build a sentence by tapping word tiles in order.

```python
{
    "slug": "exercise:hello-and-goodbye:4",
    "order_index": 4,
    "type": "sentence_construction",
    "prompt": "Translate: 'I am fine'",
    "content": {
        "word_bank": [
            _choice("w1", "ደህና"),
            _choice("w2", "ነኝ"),
            _choice("w3", "ጥሩ"),
            _choice("w4", "እንደምን"),
        ]
    },
    "answer_key": {"correct_sequence": ["w1", "w2"]},
}
```

**`correct_sequence` is deliberately a subset.** `w3`/`w4` are distractors
that are never used — this tests picking the right words, not just ordering
the given ones. Two distractors is the house style.

**Generated form** — the bank is interleaved so the answer is not the first
run of tiles (`seed_course_content.py:324-334`):

```python
bank_tokens = [answer[-1], distractors[0], *answer[:-1], distractors[1]]
bank = [_choice(f"w{i + 1}", token) for i, token in enumerate(bank_tokens)]
id_by_token = {tile["text"]: tile["id"] for tile in bank}
"answer_key": {"correct_sequence": [id_by_token[t] for t in answer]},
```

**Watch the `id_by_token` idiom.** It maps *text* → id, so it silently
collapses a sentence that uses the same word twice. Safe for sentences today
because none of them repeat a token; it is exactly wrong for `spell_tiles`
(see below).

**Client**: rendered and graded by comparing the spelled-out word list.

### 4. `match_pairs`

Two columns, drag each left tile to its meaning.

```python
{
    "slug": "exercise:hello-and-goodbye:8",
    "order_index": 7,
    "type": "match_pairs",
    "prompt": "Match each word to its meaning",
    "content": {
        "left_tiles": [
            _choice("l1", "ሰላም"),
            _choice("l2", "ደህና ሁን"),
            _choice("l3", "አመሰግናለሁ"),
            _choice("l4", "እባክዎ"),
        ],
        "right_tiles": [
            _choice("r1", "Thank you"),
            _choice("r2", "Hello"),
            _choice("r3", "Please"),
            _choice("r4", "Goodbye"),
        ],
    },
    "answer_key": {
        "correct_pairs": [["l1", "r2"], ["l2", "r4"], ["l3", "r1"], ["l4", "r3"]]
    },
}
```

**The two columns must be the same length** (`MatchPairsContent` enforces it)
and must be **independently ordered** — if `l1`↔`r1`, `l2`↔`r2` and so on,
the exercise solves itself. Above, the right column is the left column
rotated by one; the generator does this literally:

```python
rotated = chosen[1:] + chosen[:1]
```

Minimum 2 pairs; 4 is the house style.

**Client**: rendered and graded.

### 5. `gap_fill`

A sentence with one word removed, and three words to choose from.

```python
{
    "slug": "exercise:hello-and-goodbye:6",
    "order_index": 5,
    "type": "gap_fill",
    "prompt": "Complete the sentence: 'I am fine'",
    "content": {
        "sentence_before": "",
        "sentence_after": "ነኝ",
        "choices": [
            _choice("a", "ደህና"),
            _choice("b", "ጥሩ"),
            _choice("c", "እንደምን"),
        ],
    },
    "answer_key": {"correct_choice_id": "a"},
}
```

**The sentence is stored as the text on either side of the gap** — not as a
string with a `___` marker, and not as tokens plus a blank index. A gap at
the very start or end is just an empty string on that side, as above. That is
the normal representation, not a special case. At least one side must be
non-empty.

**Store both sides already trimmed.** The space around the gap is the
client's layout problem, not the data's.

**Three choices, not four.** Use `_gap_choices(correct, distractors,
position)` (`seed_course_content.py:164`), *not* `_choices` — the latter
assumes four options and derives the correct id from `position % 4`, which
with two distractors names a tile that does not exist.

**Generated form** — the blank index is authored per language, never
computed, because the same sentence has different token counts in different
languages (`seed_course_content.py:87-116`). "I want bread" is three tokens
in Afaan Oromo and two in Amharic; one shared index would blank the wrong
word in one of them.

```python
blank_index = sentence["blank"][learning]
missing = answer[blank_index]
"sentence_before": " ".join(answer[:blank_index]),
"sentence_after": " ".join(answer[blank_index + 1:]),
```

**No `vocab_slug`** — rule 5. It does test one word, but the word is already
tracked by that lesson's multiple-choice exercise.

**Client**: rendered and graded. Same answer key as multiple choice, so the
client treats it as one index with no partial credit.

### 6. `spell_tiles`

Spell a word from scattered character tiles.

```python
{
    "slug": "exercise:hello-and-goodbye:7",
    "order_index": 6,
    "type": "spell_tiles",
    "prompt": "Spell 'Hello'",
    "content": {
        "tiles": [
            _choice("t1", "ላ"),
            _choice("t2", "ደ"),
            _choice("t3", "ም"),
            _choice("t4", "ሰ"),
            _choice("t5", "ና"),
        ]
    },
    "answer_key": {"correct_sequence": ["t4", "t1", "t3"]},
}
```

`t4 t1 t3` = ሰ ላ ም = ሰላም. `t2` and `t5` are distractors.

This type has **two properties no other type has**, and both are easy to get
wrong.

**(a) Duplicate `text` across tiles is normal and must be preserved.**
`Maaloo` needs two `a` tiles and two `o` tiles. Any helper that keys a tile
by its text — the `id_by_token` idiom from sentence construction — collapses
them and produces an answer key naming the same id twice. Use
`_spell_tiles(word, other_words, position)` (`seed_course_content.py:194`),
which keys by the character's **index in the word**:

```python
entries = [(i, c) for i, c in enumerate(chars)]      # int = position in word
entries += [(None, d) for d in distractors]           # None = distractor
scattered = _scatter(entries, position)
tiles = [_choice(f"t{n + 1}", text) for n, (_, text) in enumerate(scattered)]
id_by_word_index = {
    origin: f"t{n + 1}" for n, (origin, _) in enumerate(scattered) if origin is not None
}
return tiles, [id_by_word_index[i] for i in range(len(chars))]
```

**(b) `correct_sequence` names *a* correct ordering, not the only one.**
Because repeated characters have interchangeable tiles, several id sequences
spell the same word. The client therefore grades by comparing the spelled
**text**, never the id list. (Bolt 032 decision D3.)

**Choosing the word.** Pick a **single token**. `goodbye` is two words in
Amharic (`ደህና ሁን`) and is not something to spell from character tiles. The
generator sidesteps this structurally: it always spells `indexes[3]`, the one
word the lesson never drills directly, which is also never the two-token
entry.

**Distractors skip each word's first character** — Afaan Oromo words are
capitalised, so an uppercase tile anywhere but position one would announce
itself as a distractor:

```python
pool = sorted({c for other in other_words for c in other[1:]} - set(chars))
```

**No `vocab_slug`** — rule 5, same as gap-fill.

> **Not yet on the phone.** The client cannot render `spell_tiles` until bolt
> `033-spell-tiles-ui` ships. Until then `http_lesson_api.dart` drops it from
> the lesson and carries the count in `LessonContent.unrenderableCount`, so
> completion still reports a `total_count` the server accepts. Seeding it is
> safe; it is simply invisible.

---

## Adding a whole lesson

Two generators exist, and they do **not** produce the same thing.

### `seed_category_content.py:46` — English→Amharic, compact

Takes four words and expands them into **four exercises** (two
`multiple_choice`, one `listening`, one `sentence_construction`), plus a fifth
`match_pairs` if you pass `match`:

```python
_lesson(
    key="numbers:one-to-five",          # `<group>:<lesson>`; the lesson slug drops the prefix
    skill_key="numbers",
    title="One to Five",
    order=1,
    words=[("አንድ", "one"), ("ሁለት", "two"), ("ሦስት", "three"), ("አራት", "four")],
    mc=(0, 1),          # which two words the multiple-choice exercises test (both vocab-linked)
    listening=2,        # which word the listening exercise plays
    sentence=("I have two", ["ሁለት", "አለኝ"], ["አለኝ", "አንድ", "ሁለት", "ነው"]),
    match=[0, 1, 2, 3], # omit for no match-pairs
)
```

`sentence` is `(English prompt, answer tokens in order, the full shuffled word
bank)`. It returns `(lesson_dict, vocab_entries)` — feed the tuple straight
into `_skill(..., lessons=[...])`.

> **Known gap**: this generator produces no `gap_fill` and no `spell_tiles`,
> so the 16 lessons it builds carry four types, not six. Extending it is
> worthwhile but not yet done.

### `seed_course_content.py:229` — any language pair, all seven

Produces the full seven-exercise shape (2 MC, listening, sentence, optional
match, gap-fill, spell-tiles) for any (from-language, learning-language) pair,
driven entirely by the shared `_WORDS` table and `_SENTENCES`. It is why the
three non-default courses cannot drift apart: adding a word there adds it to
all three at once, in all three directions.

Its inputs are the tables at the top of the module, not call-site arguments —
to add content, extend `_WORDS` (and `_SENTENCES`, with a per-language
`blank` index), not the function.

---

## Checking your work

Run these after any content change. In order of how much they catch:

```powershell
cd backend
uv run pytest tests/integration/test_seed_course_content.py tests/integration/test_seed_lesson_content.py
uv run pytest tests/unit/test_exercise_type_dispatch.py
uv run pytest            # the whole suite; several tests assert exact counts
```

**Expect count assertions to fail when you add exercises.** Several tests
hard-code totals (the lesson exercise count, the whole-seed total). That is
deliberate — it forces you to notice what you changed. Update each one and
say in a comment what moved it.

Then verify the actual database, which the test suite does not touch (tests
build their schema with `create_all` and never run migrations):

```powershell
cd backend
$env:PYTHONIOENCODING="utf-8"   # required, or Fidel output dies on cp1252
uv run python -m app.infrastructure.db.seed_lesson_content
```

The strongest single check for a tile-bearing type is a **round-trip
assertion**: map `correct_sequence` back through the tiles and confirm it
spells the word you meant. That is what caught a hand-authored `Maaloo` whose
sequence spelled `Malaoo`.

---

## Appendix A: seeding for a device test

To reseed without losing your sign-in: content ids are deterministic, so
wiping content and re-seeding recreates **identical ids** — including the one
`users.active_course_id` points at. Keep `users` and `auth_sessions`, delete
the content tables, re-run the seed, and the session still resolves.

Back up `dev.db` first.

---

## Appendix B: adding a seventh exercise type

Content authoring stops here; this is the code change. Every seam below must
be touched, and the list is not derivable from the compiler — several of
these fail only at runtime.

**Backend**

1. `ExerciseType` enum — `value_objects.py`
2. A `…Content` value object, plus the `ExerciseContent` union
3. An answer key — reuse `ChoiceAnswerKey`/`SequenceAnswerKey`/`PairAnswerKey`
   if the question is genuinely the same one. Three keys currently serve six
   types
4. `ck_exercises_type` CHECK — **in both places**: `ExerciseModel.__table_args__`
   *and* a new migration. Use `op.batch_alter_table` (SQLite cannot alter a
   CHECK in place)
5. `_content_from_json` — add a branch **before** the terminal `raise`
6. `_answer_key_from_json` — ⚠️ **the one fall-through in the codebase.** Its
   last branch returns `ChoiceAnswerKey` unconditionally. A sequence-answering
   type that is not named explicitly falls in and dies on a missing
   `correct_choice_id`. This trap has fired once already
7. `…ExerciseResponse` schema + the discriminated union — `lesson_schemas.py`
8. `to_exercise_response` — add a branch before the terminal `raise`
9. Seed content in at least one lesson
10. `database-schema.md`

**Client**

11. A sealed subclass of `Exercise` + a case in `isAnswerCorrect`
12. `_toExercise` in `http_lesson_api.dart`, **and** the `known` set in
    `_toExerciseOrNull` — a type missing from that set is silently dropped
13. `packExerciseToJson` **and** `packExerciseFromJson` in
    `lesson_pack_store.dart`. ⚠️ Only the first is compiler-checked; the
    second is a string switch that throws at runtime, inside a downloaded
    pack, offline
14. The fake API
15. Two switches in `lesson_screen.dart`
16. The exercise widget

The runtime-only seams — 6, 12, 13 — are where every escaped bug in this area
has come from. `tests/unit/test_exercise_type_dispatch.py` exists to cover the
backend half.
