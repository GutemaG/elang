---
stage: plan
bolt: 032-spell-tiles-service
created: '2026-09-20T18:40:00Z'
---

## Implementation Plan: 001-spell-tiles-service

### Objective

Serve `spell_tiles` exercises from the existing lesson-content endpoint and seed them into
all four courses, adding no answer-key shape and no response envelope.

---

### Decisions resolved at this stage

The stories left two questions open for Plan, to be answered against real code rather than
on paper. Both are now answered, and reading the code turned up a third that nobody had
asked.

#### D1 — Which word is spelled: `indexes[3]`, the fourth word of each lesson

Traced through `_lesson()` in `seed_course_content.py`:

| Word | Where it is already the answer |
|------|-------------------------------|
| `indexes[0]` | multiple-choice #1 (vocab-linked) |
| `indexes[1]` | multiple-choice #2 (vocab-linked) |
| `indexes[2]` | listening |
| `indexes[3]` | **nothing** — it appears only as a distractor, and in match-pairs |

So `indexes[3]` is the one word a lesson never drills directly. Spelling it adds coverage
instead of a fourth pass over an already-drilled word.

It also avoids the only landmine in `_WORDS`. `goodbye` is `ደህና ሁን` in Amharic — **two
tokens**, which cannot be spelled from character tiles in v1. It sits at `indexes[1]`, so
the `indexes[3]` rule never selects it. Checked all four lessons: `please` / `friend` /
`milk` / `egg` are single-token in both Amharic and Afaan Oromo.

A pleasing side effect, verified rather than hoped for:

| Lesson | Afaan Oromo | Repeats | Amharic | Repeats |
|--------|-------------|---------|---------|---------|
| 1 | `Maaloo` | `a`×2, `o`×2 | `እባክዎ` | none |
| 2 | `Hiriyaa` | `i`×2, `a`×2 | `ጓደኛ` | none |
| 3 | `Aannan` | `n`×3, `a`×2 | `ወተት` | none |
| 4 | `Hanqaaquu` | `a`×3, `q`×2, `u`×2 | `እንቁላል` | none |

**Every Afaan Oromo word repeats characters; no Amharic one does.** The duplicate-tile risk
is therefore exercised by real seeded content in two of the four courses, not only by a
contrived test fixture. `Hanqaaquu` is the worst case at 9 characters + 2 distractors = 11
tiles, inside the 12-tile budget FR-2 set.

#### D2 — Distractors are drawn from the non-initial characters of the lesson's other words

Two constraints, both from looking at the data:

- **Not the initial character.** Afaan Oromo words are capitalised (`Maaloo`, `Hanqaaquu`),
  so only the first tile of a word is ever uppercase. A distractor taken from another word's
  first letter would be uppercase too, and would announce itself as a distractor.
- **Prefer a character not already in the target word.** Not required for correctness once D3
  is settled, but it keeps the tile bank legible.

#### D3 — ⚠️ Grading must compare the spelled **text**, not the id sequence

This was not in the requirements and is a correctness bug if missed.

`Maaloo` has two `a` tiles. Say `correct_sequence` is `[t3(M), t1(a), t7(a), t2(l), t5(o),
t8(o)]`. A learner who taps the *other* `a` first builds `[t3, t7, t1, t2, t5, t8]` — which
spells `Maaloo` exactly, and which a straight `listEquals` on ids **grades as wrong**.

Resolution: `correct_sequence` keeps holding **tile ids** on the wire (unchanged
`SequenceAnswerKey`, unchanged convention with `sentence_construction`), but its meaning for
this type is "*a* correct ordering", not "the only one". The client resolves both the built
sequence and `correct_sequence` to text and compares the strings.

Nothing changes in this bolt's code — the backend stores and serves ids either way. What
changes is a docstring here, and an acceptance criterion in bolt `033`. Raised at this
checkpoint because it belongs to the contract's meaning, not to the widget.

---

### Deliverables

**Domain**
- [ ] `ExerciseType.SPELL_TILES = "spell_tiles"` in `value_objects.py`, and the docstring's
      "half the change" note extended to name this type's migration
- [ ] `SpellTilesContent` value object: `tiles: tuple[Choice, ...]`, validating at least 2
      tiles. Added to the `ExerciseContent` union
- [ ] **No** change to the `AnswerKey` union — and its "deliberately three members for six
      exercise types" comment updated to say six

**Persistence**
- [ ] `ExerciseModel.__table_args__`'s `ck_exercises_type` widened to six values, and its
      class docstring extended
- [ ] New Alembic revision, `down_revision = "d1b7e4f2a903"`, copying that revision's
      batch-mode shape verbatim including the downgrade caveat
- [ ] `_content_from_json` gains an explicit `SPELL_TILES` branch **above** the guarded
      `raise`. `_answer_key_from_json` expected to need **no** edit — its `correct_sequence`
      branch already returns a `SequenceAnswerKey`; confirm, do not assume

**API**
- [ ] `SpellTilesExerciseResponse` in `lesson_schemas.py` with
      `type: Literal["spell_tiles"]`, `prompt`, `tiles`, `correct_sequence`, added to the
      discriminated union
- [ ] `to_exercise_response` branch in `exercise_mapping.py`, above its guarded fall-through

**Seed**
- [ ] A `_spell_tiles` helper in `seed_course_content.py` that splits a word into characters,
      appends two distractors, shuffles deterministically, assigns ids and returns the
      correct id order. Its docstring must say why it is not `_choices` and not
      `_gap_choices`
- [ ] Generated `spell_tiles` exercise appended per lesson in `seed_course_content.py`
      (3 courses × 4 lessons), slug `:7`, `order_index` after the gap-fill, no `vocab_slug`
- [ ] Four hand-authored `spell_tiles` entries in `seed_lesson_content.py` (the en→am
      course), slug `:7`, mirroring how its `gap_fill` entries are written
- [ ] New `"spell"` key in `_TEXT` for `en` / `am` / `om`

**Docs**
- [ ] `database-schema.md`'s exercise-type list and its `content`/`answer_key` shape table

---

### Dependencies

- None. Extends existing `001-lesson-service` code in place.
- Enables `033-spell-tiles-ui`, which needs the real serialized shape.

---

### Technical Approach

**Order of work.** Enum first. `test_exercise_type_dispatch.py` is parametrized over
`ExerciseType`, so adding the value immediately turns every unfilled seam into a named test
failure. That list *is* the worklist — follow it rather than a checklist from memory. It is
the alarm working; satisfying it by weakening the test would be the one unacceptable outcome.

**Character splitting.** Python iterates `str` by code point. Both scripts here are
unaccented: Fidel characters are single code points, and the Afaan Oromo words use plain
ASCII letters. Verify with an explicit assertion over `_WORDS` rather than trusting it —
one combining mark anywhere would silently produce a broken tile.

**The two text-keyed traps.** `_choices` assumes four options and derives the correct id from
`position % 4`. The `id_by_token = {tile["text"]: tile["id"]}` idiom at
`seed_course_content.py:275` collapses duplicate text — with `Maaloo` it would produce four
tiles from six characters. Neither may be reused. Build the id→position mapping by
enumerating the shuffled list, so duplicates keep distinct ids by construction.

**Shuffle determinism.** The seed must be idempotent, so the tile order has to be a pure
function of the lesson's inputs — rotate by `order`, as `_choices` and `_gap_choices` already
do. No `random`.

**Migration.** Copy `d1b7e4f2a903`. The test DB uses `Base.metadata.create_all` and never
runs migrations, so a green suite proves nothing here — verify by hand on a scratch SQLite
file: upgrade to head (six types), downgrade one (five), upgrade again (six).

**Expect test-count churn.** Bolt `030` broke 13 count assertions by adding one exercise per
lesson; this does the same. Each updated assertion gets a comment naming the old value, as
`030`'s did. If a failure is *not* a count, treat it as a real finding — that is exactly how
the `vocab_item_id` defect surfaced last time.

---

### Acceptance Criteria

- [ ] `ExerciseType.SPELL_TILES` exists; the `AnswerKey` union is byte-for-byte unchanged
- [ ] `test_exercise_type_dispatch.py` passes for six types, extended and not weakened
- [ ] Migration on `d1b7e4f2a903` widens `ck_exercises_type`; verified by hand up, down and up
- [ ] `ExerciseModel.__table_args__` widened in the same change
- [ ] `_answer_key_from_json` is unchanged (or, if it could not be, the reason is recorded)
- [ ] `_content_from_json` and `to_exercise_response` keep their guarded `raise`
- [ ] Every one of the four courses contains `spell_tiles` exercises after seeding; re-seeding
      changes nothing
- [ ] `Maaloo`, `Hiriyaa`, `Aannan` and `Hanqaaquu` each keep every repeated character as its
      own tile with its own id — asserted from real seed output, not a fixture
- [ ] No seeded `spell_tiles` exercise is the multi-token `ደህና ሁን`
- [ ] Every seeded `spell_tiles` exercise has `vocab_item_id` null, asserted by a test
- [ ] No seeded exercise exceeds 12 tiles
- [ ] Tile order does not reveal the answer: `correct_sequence` is not `t1..tN` in order
- [ ] Full backend suite green; ruff clean on touched files; mypy no worse than the two
      pre-existing errors
- [ ] No client file touched

---

### Risks

1. **Writing a text-keyed helper by reflex.** Every neighbour in this file keys by text. The
   mitigation is the explicit prohibition above plus a test over real seed output.
2. **Assuming the migration is covered by the suite.** It is not. Bolt `011` made this
   mistake; `030` did not. Hand verification is an acceptance criterion.
3. **A real defect hiding among the count churn.** 13 assertions broke last time. Do not
   batch-update; read each failure.
4. **D3 arriving too late.** The grading semantics are written down here so bolt `033` starts
   from them rather than rediscovering them from a failing test — or worse, shipping the bug.
