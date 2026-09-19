"""Content for the four categories added by bolt `022-category-content-seed`
(intent `009-course-categories`): Family & People, Numbers & Time, Travel &
Places, and Colors/Body & Health.

Imported by `seed_lesson_content.py`, which appends these lists to its own
`CATEGORIES`/`CURRICULUM`/`VOCABULARY` and seeds everything through the one
existing idempotent loop -- this module holds data and small builders only.

**Content caveat (NFR-3)**: the Amharic here was authored by the agent and is
NOT native-speaker reviewed. It is suitable for demonstrating the product; a
native-speaker proof-read is required before any real release.

Each lesson is written once in compact form (its words, which words the two
multiple-choice exercises and the listening exercise test, one sentence to
build, and optionally a match-pairs) and expanded here into the standard
exercise shapes, so the shapes cannot drift between lessons. Ids are
deterministic slugs, same as the rest of the seed.
"""

from __future__ import annotations

from typing import Any

# Same documented placeholder as the original seed (see that module's
# "Known limitation"): no per-exercise real audio exists yet.
PLACEHOLDER_AUDIO_URL = "https://www.kozco.com/tech/piano2-CoolEdit.mp3"

_CHOICE_IDS = ("a", "b", "c", "d")


def _choice(choice_id: str, text: str) -> dict[str, str]:
    return {"id": choice_id, "text": text}


def _choices(correct: str, others: list[str], position: int) -> tuple[list[dict[str, str]], str]:
    """Four choices: `correct` plus the first three of `others`, with the
    correct one at `position` (varied per exercise so it is not always
    "a"). Returns the choices and the correct choice's id.
    """
    texts = list(others[:3])
    texts.insert(position % 4, correct)
    choices = [_choice(_CHOICE_IDS[i], text) for i, text in enumerate(texts)]
    return choices, _CHOICE_IDS[position % 4]


def _lesson(
    *,
    key: str,
    skill_key: str,
    title: str,
    order: int,
    words: list[tuple[str, str]],
    mc: tuple[int, int],
    listening: int,
    sentence: tuple[str, list[str], list[str]],
    match: list[int] | None = None,
) -> tuple[dict[str, Any], list[dict[str, str]]]:
    """Expand one compact lesson into (lesson dict, its vocab entries).

    `words` are (Amharic, English) pairs. `mc` are the two word indexes
    tested by multiple choice (both vocab-linked); `listening` is the word
    tested by the listening exercise; `sentence` is (English prompt, answer
    tokens in order, the full shuffled word bank); `match` optionally lists
    the four word indexes for a match-pairs exercise.
    """
    exercises: list[dict[str, Any]] = []
    vocab: list[dict[str, str]] = []

    def slug(n: int) -> str:
        return f"exercise:{key}:{n}"

    # 1. Multiple choice, English -> Amharic (vocab-linked).
    amharic, english = words[mc[0]]
    others = [w[0] for i, w in enumerate(words) if i != mc[0]]
    choices, correct_id = _choices(amharic, others, order)
    exercises.append(
        {
            "slug": slug(1),
            "order_index": 1,
            "type": "multiple_choice",
            "vocab_slug": f"vocab:{key}:{mc[0]}",
            "prompt": f"How do you say '{english}' in Amharic?",
            "content": {"choices": choices},
            "answer_key": {"correct_choice_id": correct_id},
        }
    )
    vocab.append({"slug": f"vocab:{key}:{mc[0]}", "word": amharic, "translation": english})

    # 2. Multiple choice, Amharic -> English (vocab-linked).
    amharic, english = words[mc[1]]
    others = [w[1] for i, w in enumerate(words) if i != mc[1]]
    choices, correct_id = _choices(english, others, order + 1)
    exercises.append(
        {
            "slug": slug(2),
            "order_index": 2,
            "type": "multiple_choice",
            "vocab_slug": f"vocab:{key}:{mc[1]}",
            "prompt": f"What does '{amharic}' mean?",
            "content": {"choices": choices},
            "answer_key": {"correct_choice_id": correct_id},
        }
    )
    vocab.append({"slug": f"vocab:{key}:{mc[1]}", "word": amharic, "translation": english})

    # 3. Listening (not vocab-linked, same convention as the original seed).
    _, english = words[listening]
    others = [w[1] for i, w in enumerate(words) if i != listening]
    choices, correct_id = _choices(english, others, order + 2)
    exercises.append(
        {
            "slug": slug(3),
            "order_index": 3,
            "type": "listening",
            "prompt": "What does this word mean?",
            "content": {"audio_url": PLACEHOLDER_AUDIO_URL, "choices": choices},
            "answer_key": {"correct_choice_id": correct_id},
        }
    )

    # 4. Sentence construction.
    prompt_english, answer_tokens, bank_tokens = sentence
    bank = [_choice(f"w{i + 1}", token) for i, token in enumerate(bank_tokens)]
    id_by_token = {tile["text"]: tile["id"] for tile in bank}
    exercises.append(
        {
            "slug": slug(4),
            "order_index": 4,
            "type": "sentence_construction",
            "prompt": f"Translate: '{prompt_english}'",
            "content": {"word_bank": bank},
            "answer_key": {"correct_sequence": [id_by_token[t] for t in answer_tokens]},
        }
    )

    # 5. Match pairs (optional): Amharic on the left, English (rotated by
    # one so the columns are not in matching order) on the right.
    if match is not None:
        chosen = [words[i] for i in match]
        rotated = chosen[1:] + chosen[:1]
        left = [_choice(f"l{i + 1}", w[0]) for i, w in enumerate(chosen)]
        right = [_choice(f"r{i + 1}", w[1]) for i, w in enumerate(rotated)]
        right_id_by_english = {tile["text"]: tile["id"] for tile in right}
        exercises.append(
            {
                "slug": slug(5),
                "order_index": 5,
                "type": "match_pairs",
                "prompt": "Match each word to its meaning",
                "content": {"left_tiles": left, "right_tiles": right},
                "answer_key": {
                    "correct_pairs": [
                        [left[i]["id"], right_id_by_english[chosen[i][1]]]
                        for i in range(len(chosen))
                    ]
                },
            }
        )

    lesson = {
        "slug": f"lesson:{skill_key}:{key.split(':', 1)[-1]}",
        "title": title,
        "order_index": order,
        "exercises": exercises,
    }
    return lesson, vocab


def _skill(
    *,
    slug: str,
    category_slug: str,
    title: str,
    order: int,
    lessons: list[tuple[dict[str, Any], list[dict[str, str]]]],
) -> tuple[dict[str, Any], list[dict[str, str]]]:
    skill = {
        "slug": slug,
        "category_slug": category_slug,
        "title": title,
        "order_index": order,
        "lessons": [lesson for lesson, _ in lessons],
    }
    return skill, [v for _, vocab in lessons for v in vocab]


def _build() -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[dict[str, str]]]:
    categories: list[dict[str, Any]] = []
    curriculum: list[dict[str, Any]] = []
    vocabulary: list[dict[str, str]] = []

    def add_category(slug: str, title: str, subtitle: str, order: int) -> str:
        categories.append(
            {"slug": slug, "title": title, "subtitle": subtitle, "order_index": order}
        )
        return slug

    def add_skill(built: tuple[dict[str, Any], list[dict[str, str]]]) -> None:
        skill, vocab = built
        curriculum.append(skill)
        vocabulary.extend(vocab)

    # ---- Category 2: Family & People --------------------------------------
    cat = add_category("category:family-and-people", "Family & People", "ቤተሰብ እና ሰዎች", 2)
    add_skill(
        _skill(
            slug="skill:my-family",
            category_slug=cat,
            title="My Family",
            order=1,
            lessons=[
                _lesson(
                    key="family:mother-and-father",
                    skill_key="my-family",
                    title="Mother & Father",
                    order=1,
                    words=[
                        ("እናት", "mother"),
                        ("አባት", "father"),
                        ("ወንድም", "brother"),
                        ("እህት", "sister"),
                    ],
                    mc=(0, 1),
                    listening=2,
                    sentence=("I have a brother", ["ወንድም", "አለኝ"], ["እህት", "ወንድም", "ነኝ", "አለኝ"]),
                ),
                _lesson(
                    key="family:husband-wife-child",
                    skill_key="my-family",
                    title="Husband, Wife & Child",
                    order=2,
                    words=[
                        ("ባል", "husband"),
                        ("ሚስት", "wife"),
                        ("ልጅ", "child"),
                        ("አያት", "grandparent"),
                    ],
                    mc=(0, 1),
                    listening=2,
                    sentence=("I have a child", ["ልጅ", "አለኝ"], ["አለኝ", "ባል", "ልጅ", "ነኝ"]),
                    match=[0, 1, 2, 3],
                ),
            ],
        )
    )
    add_skill(
        _skill(
            slug="skill:people",
            category_slug=cat,
            title="People",
            order=2,
            lessons=[
                _lesson(
                    key="family:friends-and-teachers",
                    skill_key="people",
                    title="Friends & Teachers",
                    order=1,
                    words=[
                        ("ጓደኛ", "friend"),
                        ("ጎረቤት", "neighbor"),
                        ("መምህር", "teacher"),
                        ("ሰው", "person"),
                    ],
                    mc=(0, 2),
                    listening=1,
                    sentence=("He is a teacher", ["እሱ", "መምህር", "ነው"], ["ጓደኛ", "መምህር", "ነው", "እሱ"]),
                ),
                _lesson(
                    key="family:i-you-he-she",
                    skill_key="people",
                    title="I, You, He, She",
                    order=2,
                    words=[("እኔ", "I"), ("አንተ", "you (m.)"), ("እሱ", "he"), ("እሷ", "she")],
                    mc=(0, 3),
                    listening=2,
                    sentence=("I am a teacher", ["እኔ", "መምህር", "ነኝ"], ["ነው", "መምህር", "እኔ", "ነኝ"]),
                    match=[0, 1, 2, 3],
                ),
            ],
        )
    )

    # ---- Category 3: Numbers & Time ---------------------------------------
    cat = add_category("category:numbers-and-time", "Numbers & Time", "ቁጥሮች እና ጊዜ", 3)
    add_skill(
        _skill(
            slug="skill:numbers",
            category_slug=cat,
            title="Numbers",
            order=1,
            lessons=[
                _lesson(
                    key="numbers:one-to-five",
                    skill_key="numbers",
                    title="One to Five",
                    order=1,
                    words=[
                        ("አንድ", "one"),
                        ("ሁለት", "two"),
                        ("ሦስት", "three"),
                        ("አራት", "four"),
                        ("አምስት", "five"),
                    ],
                    mc=(0, 2),
                    listening=3,
                    sentence=(
                        "Two teas, please",
                        ["ሁለት", "ሻይ", "እባክዎ"],
                        ["አንድ", "እባክዎ", "ሻይ", "ሁለት"],
                    ),
                ),
                _lesson(
                    key="numbers:six-to-ten",
                    skill_key="numbers",
                    title="Six to Ten",
                    order=2,
                    words=[
                        ("ስድስት", "six"),
                        ("ሰባት", "seven"),
                        ("ስምንት", "eight"),
                        ("ዘጠኝ", "nine"),
                        ("አሥር", "ten"),
                    ],
                    mc=(0, 2),
                    listening=4,
                    sentence=(
                        "Five breads, please",
                        ["አምስት", "ዳቦ", "እባክዎ"],
                        ["እባክዎ", "አሥር", "ዳቦ", "አምስት"],
                    ),
                    match=[0, 1, 3, 4],
                ),
            ],
        )
    )
    add_skill(
        _skill(
            slug="skill:time",
            category_slug=cat,
            title="Time",
            order=2,
            lessons=[
                _lesson(
                    key="numbers:today-and-tomorrow",
                    skill_key="time",
                    title="Today & Tomorrow",
                    order=1,
                    words=[
                        ("ዛሬ", "today"),
                        ("ነገ", "tomorrow"),
                        ("ትናንት", "yesterday"),
                        ("ጠዋት", "morning"),
                        ("ማታ", "evening"),
                    ],
                    mc=(0, 1),
                    listening=2,
                    sentence=(
                        "See you tomorrow",
                        ["ነገ", "እንገናኛለን"],
                        ["ዛሬ", "እንገናኛለን", "ትናንት", "ነገ"],
                    ),
                ),
                _lesson(
                    key="numbers:days-of-the-week",
                    skill_key="time",
                    title="Days of the Week",
                    order=2,
                    words=[
                        ("ሰኞ", "Monday"),
                        ("ማክሰኞ", "Tuesday"),
                        ("ረቡዕ", "Wednesday"),
                        ("ሐሙስ", "Thursday"),
                        ("አርብ", "Friday"),
                        ("ቅዳሜ", "Saturday"),
                        ("እሑድ", "Sunday"),
                    ],
                    mc=(0, 4),
                    listening=6,
                    sentence=("Today is Monday", ["ዛሬ", "ሰኞ", "ነው"], ["ነገ", "ሰኞ", "ነው", "ዛሬ"]),
                    match=[0, 2, 5, 6],
                ),
            ],
        )
    )

    # ---- Category 4: Travel & Places --------------------------------------
    cat = add_category("category:travel-and-places", "Travel & Places", "ጉዞ እና ቦታዎች", 4)
    add_skill(
        _skill(
            slug="skill:around-town",
            category_slug=cat,
            title="Around Town",
            order=1,
            lessons=[
                _lesson(
                    key="travel:places",
                    skill_key="around-town",
                    title="Places",
                    order=1,
                    words=[
                        ("ቤት", "home"),
                        ("ገበያ", "market"),
                        ("ሆቴል", "hotel"),
                        ("ትምህርት ቤት", "school"),
                    ],
                    mc=(1, 2),
                    listening=3,
                    sentence=("I want a hotel", ["ሆቴል", "እፈልጋለሁ"], ["ገበያ", "እፈልጋለሁ", "ሆቴል", "ነኝ"]),
                ),
                _lesson(
                    key="travel:directions",
                    skill_key="around-town",
                    title="Directions",
                    order=2,
                    words=[("ቀኝ", "right"), ("ግራ", "left"), ("ቀጥታ", "straight"), ("እዚህ", "here")],
                    mc=(0, 1),
                    listening=2,
                    sentence=("Go straight", ["ቀጥታ", "ሂድ"], ["ቀኝ", "ሂድ", "ግራ", "ቀጥታ"]),
                    match=[0, 1, 2, 3],
                ),
            ],
        )
    )
    add_skill(
        _skill(
            slug="skill:getting-there",
            category_slug=cat,
            title="Getting There",
            order=2,
            lessons=[
                _lesson(
                    key="travel:asking-questions",
                    skill_key="getting-there",
                    title="Asking Questions",
                    order=1,
                    words=[("የት", "where"), ("ምን", "what"), ("መቼ", "when"), ("ስንት", "how much")],
                    mc=(0, 3),
                    listening=2,
                    sentence=("How much is it?", ["ስንት", "ነው"], ["የት", "ነው", "ስንት", "ምን"]),
                ),
                _lesson(
                    key="travel:transport",
                    skill_key="getting-there",
                    title="Transport",
                    order=2,
                    words=[
                        ("መኪና", "car"),
                        ("አውቶቡስ", "bus"),
                        ("ታክሲ", "taxi"),
                        ("አውሮፕላን", "airplane"),
                    ],
                    mc=(1, 2),
                    listening=3,
                    sentence=(
                        "Where is the bus?",
                        ["አውቶቡስ", "የት", "ነው"],
                        ["ስንት", "የት", "ነው", "አውቶቡስ"],
                    ),
                    match=[0, 1, 2, 3],
                ),
            ],
        )
    )

    # ---- Category 5: Colors, Body & Health --------------------------------
    cat = add_category(
        "category:colors-body-and-health", "Colors, Body & Health", "ቀለሞች፣ አካል እና ጤና", 5
    )
    add_skill(
        _skill(
            slug="skill:colors",
            category_slug=cat,
            title="Colors",
            order=1,
            lessons=[
                _lesson(
                    key="colors:basic-colors",
                    skill_key="colors",
                    title="Basic Colors",
                    order=1,
                    words=[("ቀይ", "red"), ("ሰማያዊ", "blue"), ("አረንጓዴ", "green"), ("ቢጫ", "yellow")],
                    mc=(0, 1),
                    listening=2,
                    sentence=("It is red", ["ቀይ", "ነው"], ["ነው", "ሰማያዊ", "ቀይ", "ነኝ"]),
                ),
                _lesson(
                    key="colors:more-colors",
                    skill_key="colors",
                    title="More Colors",
                    order=2,
                    words=[
                        ("ነጭ", "white"),
                        ("ጥቁር", "black"),
                        ("ብርቱካናማ", "orange"),
                        ("ሐምራዊ", "purple"),
                    ],
                    mc=(0, 1),
                    listening=2,
                    sentence=(
                        "The bread is white",
                        ["ዳቦው", "ነጭ", "ነው"],
                        ["ነጭ", "ጥቁር", "ዳቦው", "ነው"],
                    ),
                    match=[0, 1, 2, 3],
                ),
            ],
        )
    )
    add_skill(
        _skill(
            slug="skill:body-and-health",
            category_slug=cat,
            title="Body & Health",
            order=2,
            lessons=[
                _lesson(
                    key="colors:body",
                    skill_key="body-and-health",
                    title="Body",
                    order=1,
                    words=[
                        ("ራስ", "head"),
                        ("እጅ", "hand"),
                        ("እግር", "foot"),
                        ("ዓይን", "eye"),
                        ("ጆሮ", "ear"),
                    ],
                    mc=(0, 1),
                    listening=3,
                    sentence=("My head hurts", ["ራሴን", "ያመኛል"], ["እጄን", "ያመኛል", "ራሴን", "ነው"]),
                ),
                _lesson(
                    key="colors:health",
                    skill_key="body-and-health",
                    title="Health",
                    order=2,
                    words=[
                        ("ሐኪም", "doctor"),
                        ("መድኃኒት", "medicine"),
                        ("ህመም", "pain"),
                        ("ውሃ", "water"),
                    ],
                    mc=(0, 1),
                    listening=2,
                    sentence=(
                        "I need a doctor",
                        ["ሐኪም", "እፈልጋለሁ"],
                        ["መድኃኒት", "እፈልጋለሁ", "ሐኪም", "ነኝ"],
                    ),
                    match=[0, 1, 2, 3],
                ),
            ],
        )
    )

    return categories, curriculum, vocabulary


NEW_CATEGORIES, NEW_CURRICULUM, NEW_VOCABULARY = _build()
