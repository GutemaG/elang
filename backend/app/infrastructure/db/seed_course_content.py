"""Content for the three courses added by bolt `025-course-content-seed`
(intent `010-multi-language-courses`): English to Afaan Oromo, Amharic to
Afaan Oromo, and Afaan Oromo to Amharic.

Imported by `seed_lesson_content.py`, which appends these lists to its own
`COURSES`/`CATEGORIES`/`CURRICULUM`/`VOCABULARY` and seeds everything through
the one existing idempotent loop -- this module holds data and small builders
only.

**Content caveat (NFR-3)**: the Amharic and Afaan Oromo here were authored by
the agent and are NOT native-speaker reviewed. It is suitable for
demonstrating the product; a native-speaker proof-read is required before any
real release. The lowest-confidence items are listed in the bolt's
`implementation-plan.md`.

All three courses teach the same 16 words in the same 4 lessons (one shared
word list below); only the language of the prompts and answers differs, so the
three directions cannot drift apart. Each lesson is expanded into the
standard exercise shapes: two vocab-linked multiple-choice exercises, one
listening, one sentence-building, (second lesson of each skill) a
match-pairs, a gap-fill, and a spell-tiles. Ids are deterministic slugs that
include the course.
"""

from __future__ import annotations

from typing import Any

from app.infrastructure.db.seed_category_content import (
    _CHOICE_IDS,
    PLACEHOLDER_AUDIO_URL,
    _choice,
    _choices,
)

# (English, Amharic, Afaan Oromo), 4 words per lesson, in lesson order.
_WORDS: list[tuple[str, str, str]] = [
    # Lesson 1: Hello & Goodbye
    ("hello", "ሰላም", "Akkam"),
    ("goodbye", "ደህና ሁን", "Nagaatti"),
    ("thank you", "አመሰግናለሁ", "Galatoomi"),
    ("please", "እባክዎ", "Maaloo"),
    # Lesson 2: Yes, No & Friends
    ("yes", "አዎ", "Eeyyee"),
    ("no", "አይ", "Lakki"),
    ("good", "ጥሩ", "Gaarii"),
    ("friend", "ጓደኛ", "Hiriyaa"),
    # Lesson 3: Coffee, Tea & Water
    ("coffee", "ቡና", "Buna"),
    ("tea", "ሻይ", "Shaayii"),
    ("water", "ውሃ", "Bishaan"),
    ("milk", "ወተት", "Aannan"),
    # Lesson 4: Bread & Food
    ("bread", "ዳቦ", "Daabboo"),
    ("food", "ምግብ", "Nyaata"),
    ("meat", "ስጋ", "Foon"),
    ("egg", "እንቁላል", "Hanqaaquu"),
]
_LANG_COLUMN = {"en": 0, "am": 1, "om": 2}

# (skill slug part, skill title, [(lesson slug part, lesson title), ...])
_SKILLS: list[tuple[str, str, list[tuple[str, str]]]] = [
    (
        "greetings-and-basics",
        "Greetings & Basics",
        [("hello-and-goodbye", "Hello & Goodbye"), ("yes-no-and-friends", "Yes, No & Friends")],
    ),
    (
        "food-and-drink",
        "Food & Drink",
        [("coffee-tea-and-water", "Coffee, Tea & Water"), ("bread-and-food", "Bread & Food")],
    ),
]

# One sentence per lesson (index = lesson number - 1). `prompt` is the
# sentence in each from-language; `answer`/`distractors` are the tiles in each
# learning language (Afaan Oromo, Amharic), split on whitespace.
#
# `blank` is the index into `answer` that the gap-fill exercise removes
# (015-gap-fill-exercise-type). It is authored per language and never
# computed: the same sentence has different token counts in different
# languages -- "I want bread" is three tokens in Afaan Oromo
# (`Daabboo nan barbaada`) and two in Amharic (`ዳቦ እፈልጋለሁ`) -- so one
# shared index would blank the wrong word in one of them. Where possible
# the blanked token is one of the lesson's two tracked vocabulary words,
# so the exercise can carry a `vocab_item_id` and feed SRS/Practice.
_SENTENCES: list[dict[str, Any]] = [
    {
        "prompt": {
            "en": "Thank you, goodbye",
            "am": "አመሰግናለሁ፣ ደህና ሁን",
            "om": "Galatoomi, nagaatti",
        },
        "answer": {"om": ["Galatoomi", "nagaatti"], "am": ["አመሰግናለሁ", "ደህና", "ሁን"]},
        "distractors": {"om": ["Akkam", "Maaloo"], "am": ["ሰላም", "እባክዎ"]},
        "blank": {"om": 1, "am": 0},
    },
    {
        "prompt": {"en": "Hello, friend", "am": "ሰላም ጓደኛ", "om": "Akkam hiriyaa"},
        "answer": {"om": ["Akkam", "hiriyaa"], "am": ["ሰላም", "ጓደኛ"]},
        "distractors": {"om": ["Eeyyee", "Lakki"], "am": ["አዎ", "አይ"]},
        "blank": {"om": 1, "am": 1},
    },
    {
        "prompt": {"en": "Coffee, please", "am": "ቡና እባክዎ", "om": "Buna maaloo"},
        "answer": {"om": ["Buna", "maaloo"], "am": ["ቡና", "እባክዎ"]},
        "distractors": {"om": ["Shaayii", "Bishaan"], "am": ["ሻይ", "ውሃ"]},
        "blank": {"om": 0, "am": 0},
    },
    {
        "prompt": {"en": "I want bread", "am": "ዳቦ እፈልጋለሁ", "om": "Daabboo nan barbaada"},
        "answer": {"om": ["Daabboo", "nan", "barbaada"], "am": ["ዳቦ", "እፈልጋለሁ"]},
        "distractors": {"om": ["Nyaata", "Foon"], "am": ["ምግብ", "ስጋ"]},
        "blank": {"om": 0, "am": 0},
    },
]

# Question wording per from-language. "say" also depends on the language being
# learned, so it is keyed by (from, learning).
_SAY: dict[tuple[str, str], str] = {
    ("en", "om"): "How do you say '{w}' in Afaan Oromo?",
    ("am", "om"): "'{w}' በኦሮምኛ እንዴት ይባላል?",
    ("om", "am"): "Afaan Amaaraatiin '{w}' akkamitti jedhama?",
}
_TEXT: dict[str, dict[str, str]] = {
    "en": {
        "mean": "What does '{w}' mean?",
        "listen": "What does this word mean?",
        "translate": "Translate: '{s}'",
        "match": "Match each word to its meaning",
        "gap": "Complete the sentence: '{s}'",
        "spell": "Spell '{w}'",
    },
    "am": {
        "mean": "'{w}' ምን ማለት ነው?",
        "listen": "ይህ ቃል ምን ማለት ነው?",
        "translate": "ተርጉም፦ '{s}'",
        "match": "እያንዳንዱን ቃል ከትርጉሙ ጋር አዛምድ",
        "gap": "ዓረፍተ ነገሩን ሙላ፦ '{s}'",
        "spell": "'{w}'ን ፊደል በፊደል ጻፍ",
    },
    "om": {
        "mean": "'{w}' maal jechuudha?",
        "listen": "Jechi kun maal jechuudha?",
        "translate": "Hiiki: '{s}'",
        "match": "Jechoota hiikaa isaanii waliin wal simsiisi",
        "gap": "Hima kana guuti: '{s}'",
        "spell": "'{w}' qubeedhaan barreessi",
    },
}

# (course key, learning language, from-language, title, order, category subtitle)
_COURSES: list[tuple[str, str, str, str, int, str]] = [
    ("en-om", "om", "en", "English to Afaan Oromo", 2, "Nagaa fi jalqaba"),
    ("am-om", "om", "am", "Amharic to Afaan Oromo", 3, "Nagaa fi jalqaba"),
    ("om-am", "am", "om", "Afaan Oromo to Amharic", 4, "ሰላምታ እና መሠረታዊ ቃላት"),
]


def _word(index: int, language: str) -> str:
    return _WORDS[index][_LANG_COLUMN[language]]


def _gap_choices(
    correct: str, distractors: list[str], position: int
) -> tuple[list[dict[str, str]], str]:
    """Three choices for a gap-fill -- the missing word plus two
    distractors -- with the correct one at `position` so it is not always
    first. Returns the choices and the correct choice's id.

    Deliberately not `_choices`: that helper assumes four options and
    derives the correct id from `position % 4`, which with only two
    distractors would name a tile that does not exist.
    """
    texts = list(distractors[:2])
    index = position % (len(texts) + 1)
    texts.insert(index, correct)
    return [_choice(_CHOICE_IDS[i], text) for i, text in enumerate(texts)], _CHOICE_IDS[index]


def _scatter(items: list[Any], seed: int) -> list[Any]:
    """Deterministically reorder `items`. No `random`: the seed loop must
    be idempotent, so tile order has to be a pure function of its inputs.
    """
    out: list[Any] = []
    pool = list(items)
    index = seed
    while pool:
        index = (index + seed + 3) % len(pool)
        out.append(pool.pop(index))
    return out


def _spell_tiles(
    word: str, other_words: list[str], position: int
) -> tuple[list[dict[str, str]], list[str]]:
    """Character tiles for a spell-tiles exercise: every character of
    `word` plus two distractors, scattered. Returns the tiles and the ids
    that spell `word` in order.

    Deliberately neither `_choices` nor `_gap_choices`. Both identify a
    tile by its text, which is safe for words in a sentence and wrong
    here: `Maaloo` needs two `a` tiles and two `o` tiles that stay
    distinguishable. The id -> position mapping below is keyed by the
    character's index in the word, never by the character itself, so
    duplicates keep distinct ids by construction.

    Distractors skip each other word's first character: Afaan Oromo words
    are capitalised, so an uppercase tile anywhere but position one would
    announce itself as a distractor.
    """
    chars = list(word)
    pool = sorted({c for other in other_words for c in other[1:]} - set(chars))
    start = position % len(pool)
    distractors = [pool[(start + offset) % len(pool)] for offset in range(2)]

    # `None` marks a distractor; an int is the character's index in `word`.
    entries: list[tuple[int | None, str]] = [(i, c) for i, c in enumerate(chars)]
    entries += [(None, d) for d in distractors]
    scattered = _scatter(entries, position)

    tiles = [_choice(f"t{n + 1}", text) for n, (_, text) in enumerate(scattered)]
    id_by_word_index = {
        origin: f"t{n + 1}" for n, (origin, _) in enumerate(scattered) if origin is not None
    }
    return tiles, [id_by_word_index[i] for i in range(len(chars))]


def _lesson(
    *,
    course_key: str,
    learning: str,
    from_language: str,
    skill_slug: str,
    lesson_slug: str,
    title: str,
    lesson_number: int,
    order: int,
    with_match: bool,
) -> tuple[dict[str, Any], list[dict[str, str]]]:
    """Expand one lesson into (lesson dict, its two vocab entries). The
    lesson's four words are `_WORDS[4 * (lesson_number - 1):][:4]`.
    """
    base = 4 * (lesson_number - 1)
    indexes = [base, base + 1, base + 2, base + 3]
    text = _TEXT[from_language]
    key = f"{course_key}:{lesson_slug}"
    exercises: list[dict[str, Any]] = []
    vocab: list[dict[str, str]] = []

    def slug(n: int) -> str:
        return f"exercise:{key}:{n}"

    # 1. Multiple choice, from-language -> learning language (vocab-linked).
    first = indexes[0]
    target = _word(first, learning)
    others = [_word(i, learning) for i in indexes if i != first]
    choices, correct_id = _choices(target, others, order)
    exercises.append(
        {
            "slug": slug(1),
            "order_index": 1,
            "type": "multiple_choice",
            "vocab_slug": f"vocab:{key}:1",
            "prompt": _SAY[(from_language, learning)].format(w=_word(first, from_language)),
            "content": {"choices": choices},
            "answer_key": {"correct_choice_id": correct_id},
        }
    )
    vocab.append(
        {
            "slug": f"vocab:{key}:1",
            "course_slug": f"course:{course_key}",
            "word": target,
            "translation": _word(first, from_language),
        }
    )

    # 2. Multiple choice, learning language -> from-language (vocab-linked).
    second = indexes[1]
    target = _word(second, learning)
    others = [_word(i, from_language) for i in indexes if i != second]
    choices, correct_id = _choices(_word(second, from_language), others, order + 1)
    exercises.append(
        {
            "slug": slug(2),
            "order_index": 2,
            "type": "multiple_choice",
            "vocab_slug": f"vocab:{key}:2",
            "prompt": text["mean"].format(w=target),
            "content": {"choices": choices},
            "answer_key": {"correct_choice_id": correct_id},
        }
    )
    vocab.append(
        {
            "slug": f"vocab:{key}:2",
            "course_slug": f"course:{course_key}",
            "word": target,
            "translation": _word(second, from_language),
        }
    )

    # 3. Listening (not vocab-linked, same convention as the rest of the seed).
    third = indexes[2]
    others = [_word(i, from_language) for i in indexes if i != third]
    choices, correct_id = _choices(_word(third, from_language), others, order + 2)
    exercises.append(
        {
            "slug": slug(3),
            "order_index": 3,
            "type": "listening",
            "prompt": text["listen"],
            "content": {"audio_url": PLACEHOLDER_AUDIO_URL, "choices": choices},
            "answer_key": {"correct_choice_id": correct_id},
        }
    )

    # 4. Sentence construction: answer tokens in the learning language, in
    # a shuffled bank with two distractors.
    sentence = _SENTENCES[lesson_number - 1]
    answer: list[str] = sentence["answer"][learning]
    distractors: list[str] = sentence["distractors"][learning]
    bank_tokens = [answer[-1], distractors[0], *answer[:-1], distractors[1]]
    bank = [_choice(f"w{i + 1}", token) for i, token in enumerate(bank_tokens)]
    id_by_token = {tile["text"]: tile["id"] for tile in bank}
    exercises.append(
        {
            "slug": slug(4),
            "order_index": 4,
            "type": "sentence_construction",
            "prompt": text["translate"].format(s=sentence["prompt"][from_language]),
            "content": {"word_bank": bank},
            "answer_key": {"correct_sequence": [id_by_token[t] for t in answer]},
        }
    )

    # 5. Match pairs (second lesson of each skill): learning-language words on
    # the left, from-language meanings (rotated by one) on the right.
    if with_match:
        chosen = [(_word(i, learning), _word(i, from_language)) for i in indexes]
        rotated = chosen[1:] + chosen[:1]
        left = [_choice(f"l{i + 1}", w[0]) for i, w in enumerate(chosen)]
        right = [_choice(f"r{i + 1}", w[1]) for i, w in enumerate(rotated)]
        right_id_by_meaning = {tile["text"]: tile["id"] for tile in right}
        exercises.append(
            {
                "slug": slug(5),
                "order_index": 5,
                "type": "match_pairs",
                "prompt": text["match"],
                "content": {"left_tiles": left, "right_tiles": right},
                "answer_key": {
                    "correct_pairs": [
                        [left[i]["id"], right_id_by_meaning[chosen[i][1]]]
                        for i in range(len(chosen))
                    ]
                },
            }
        )

    # 6. Gap fill (015-gap-fill-exercise-type, bolt 030): the same sentence
    # as exercise 4 with one word taken out. Appended last so no existing
    # exercise's `order_index` moves; the slug is always `:6` so it stays
    # stable whether or not this lesson has a match-pairs at 5.
    blank_index: int = sentence["blank"][learning]
    missing = answer[blank_index]
    gap_choices, gap_correct_id = _gap_choices(missing, distractors, order)
    # Deliberately NOT vocab-linked, though it does test one word. A vocab
    # item maps to exactly one exercise: `list_exercises_by_vocab_item_ids`
    # keeps the first row per `vocab_item_id`, so a second exercise sharing
    # a word would either never be served in Practice or would displace the
    # multiple-choice one, decided by a UUID comparison. The intent asked
    # for a link; reading the code showed it would add no SRS coverage.
    # See bolt 030's `implementation-walkthrough.md`.
    exercises.append(
        {
            "slug": slug(6),
            "order_index": 6 if with_match else 5,
            "type": "gap_fill",
            "prompt": text["gap"].format(s=sentence["prompt"][from_language]),
            "content": {
                # Stored trimmed, either side of the gap. An empty string
                # means the gap is at that end of the sentence.
                "sentence_before": " ".join(answer[:blank_index]),
                "sentence_after": " ".join(answer[blank_index + 1 :]),
                "choices": gap_choices,
            },
            "answer_key": {"correct_choice_id": gap_correct_id},
        }
    )

    # 7. Spell tiles (016-spell-from-tiles-exercise-type, bolt 032): the
    # lesson's fourth word, spelled from character tiles. `indexes[3]` is
    # chosen because it is the one word the lesson never drills directly --
    # exercises 1, 2 and 3 answer with `indexes[0..2]` and this word appears
    # only as a distractor. It also side-steps the only unspellable entry in
    # `_WORDS`: `goodbye` is two tokens in Amharic (`ደህና ሁን`), and it sits
    # at `indexes[1]`, which this rule never selects.
    #
    # Not vocab-linked, for the same reason the gap-fill above is not.
    fourth = indexes[3]
    spell_word = _word(fourth, learning)
    spell_tiles, spell_sequence = _spell_tiles(
        spell_word, [_word(i, learning) for i in indexes if i != fourth], order
    )
    exercises.append(
        {
            "slug": slug(7),
            "order_index": 7 if with_match else 6,
            "type": "spell_tiles",
            "prompt": text["spell"].format(w=_word(fourth, from_language)),
            "content": {"tiles": spell_tiles},
            "answer_key": {"correct_sequence": spell_sequence},
        }
    )

    lesson = {
        "slug": f"lesson:{course_key}:{skill_slug}:{lesson_slug}",
        "title": title,
        "order_index": order,
        "exercises": exercises,
    }
    return lesson, vocab


def _build() -> tuple[
    list[dict[str, Any]],
    list[dict[str, Any]],
    list[dict[str, Any]],
    list[dict[str, str]],
]:
    courses: list[dict[str, Any]] = []
    categories: list[dict[str, Any]] = []
    curriculum: list[dict[str, Any]] = []
    vocabulary: list[dict[str, str]] = []

    for course_key, learning, from_language, title, order, subtitle in _COURSES:
        courses.append(
            {
                "slug": f"course:{course_key}",
                "learning_language": learning,
                "from_language": from_language,
                "title": title,
                "status": "available",
                "order_index": order,
            }
        )
        category_slug = f"category:{course_key}:foundations-and-greetings"
        categories.append(
            {
                "slug": category_slug,
                "course_slug": f"course:{course_key}",
                "title": "Foundations & Greetings",
                "subtitle": subtitle,
                "order_index": 1,
            }
        )
        lesson_number = 0
        for skill_order, (skill_slug, skill_title, lessons) in enumerate(_SKILLS, start=1):
            built_lessons = []
            for lesson_order, (lesson_slug, lesson_title) in enumerate(lessons, start=1):
                lesson_number += 1
                lesson, lesson_vocab = _lesson(
                    course_key=course_key,
                    learning=learning,
                    from_language=from_language,
                    skill_slug=skill_slug,
                    lesson_slug=lesson_slug,
                    title=lesson_title,
                    lesson_number=lesson_number,
                    order=lesson_order,
                    with_match=lesson_order == 2,
                )
                built_lessons.append(lesson)
                vocabulary.extend(lesson_vocab)
            curriculum.append(
                {
                    "slug": f"skill:{course_key}:{skill_slug}",
                    "category_slug": category_slug,
                    "title": skill_title,
                    "order_index": skill_order,
                    "lessons": built_lessons,
                }
            )

    return courses, categories, curriculum, vocabulary


NEW_COURSES, NEW_COURSE_CATEGORIES, NEW_COURSE_CURRICULUM, NEW_COURSE_VOCABULARY = _build()
