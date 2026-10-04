"""Sounds charts: every letter of a language's script with its recorded
sound, shown in the app's Sounds tab (the Fidel for Amharic, Qubee for
Afaan Oromo).

A chart is one per learning language. Its letters sit in groups (the 34
Fidel families and their labialised forms; Qubee's vowels, consonants and
letter pairs), in order. A group with `columns` is laid out as a grid of
that many columns, its letters filling it row by row, with
`column_labels` along the top: the Fidel's seven vowel orders.

This module holds the rules and the starting templates. The templates only
save typing: an admin adds the recordings and examples, and can change any
letter afterwards.
"""

from __future__ import annotations

from dataclasses import dataclass, field

# A letter's review state on the admin site. Learners never see it.
LETTER_STATUSES = ("draft", "needs_review", "ready")

# Templates an admin can start a chart from.
TEMPLATES = ("fidel", "qubee", "empty")

MAX_GLYPH = 16
MAX_ROMANIZATION = 32
MAX_HINT = 200
MAX_EXAMPLE = 64
MAX_MEANING = 120
MAX_RECORDED_BY = 120
MAX_GROUP_NAME = 40


@dataclass(frozen=True)
class GroupTemplate:
    key: str
    # Display names by app language (`en`, `am`, `om`); `en` is the
    # fallback.
    names: dict[str, str]
    columns: int | None = None
    column_labels: tuple[str, ...] = ()


@dataclass(frozen=True)
class LetterTemplate:
    group: str
    glyph: str
    romanization: str
    # The glyph of an earlier letter in the same chart it sounds the same
    # as, so it needs no recording of its own.
    same_as: str | None = None
    hint: dict[str, str] = field(default_factory=dict)


@dataclass(frozen=True)
class ChartTemplate:
    title: dict[str, str]
    groups: tuple[GroupTemplate, ...]
    letters: tuple[LetterTemplate, ...]


# --- Fidel ------------------------------------------------------------------

# The seven vowel orders as the lessons romanize them (ቡና = bunna,
# ሰላም = selam): the 6th is the consonant alone or with a short ə.
FIDEL_ORDERS = ("e", "u", "i", "a", "é", "ə", "o")

# Each family's first code point and its consonant. The vowel letters አ and
# ዐ have none. A third item names the family it sounds the same as in
# modern Amharic.
FIDEL_FAMILIES: tuple[tuple[int, str, str | None], ...] = (
    (0x1200, "h", None),  # ሀ
    (0x1208, "l", None),  # ለ
    (0x1210, "h", "ሀ"),  # ሐ
    (0x1218, "m", None),  # መ
    (0x1220, "s", "ሰ"),  # ሠ
    (0x1228, "r", None),  # ረ
    (0x1230, "s", None),  # ሰ
    (0x1238, "sh", None),  # ሸ
    (0x1240, "q", None),  # ቀ
    (0x1260, "b", None),  # በ
    (0x1268, "v", None),  # ቨ
    (0x1270, "t", None),  # ተ
    (0x1278, "ch", None),  # ቸ
    (0x1280, "h", "ሀ"),  # ኀ
    (0x1290, "n", None),  # ነ
    (0x1298, "ny", None),  # ኘ
    (0x12A0, "", None),  # አ
    (0x12A8, "k", None),  # ከ
    (0x12B8, "kh", None),  # ኸ
    (0x12C8, "w", None),  # ወ
    (0x12D0, "", "አ"),  # ዐ
    (0x12D8, "z", None),  # ዘ
    (0x12E0, "zh", None),  # ዠ
    (0x12E8, "y", None),  # የ
    (0x12F0, "d", None),  # ደ
    (0x1300, "j", None),  # ጀ
    (0x1308, "g", None),  # ገ
    (0x1320, "t'", None),  # ጠ
    (0x1328, "ch'", None),  # ጨ
    (0x1330, "p'", None),  # ጰ
    (0x1338, "ts'", None),  # ጸ
    (0x1340, "ts'", "ጸ"),  # ፀ
    (0x1348, "f", None),  # ፈ
    (0x1350, "p", None),  # ፐ
)

# The labialised letters ("-wa"), as (code point, consonant).
FIDEL_LABIALISED: tuple[tuple[int, str], ...] = (
    (0x120F, "l"),  # ሏ
    (0x121F, "m"),  # ሟ
    (0x122F, "r"),  # ሯ
    (0x1237, "s"),  # ሷ
    (0x123F, "sh"),  # ሿ
    (0x124B, "q"),  # ቋ
    (0x1267, "b"),  # ቧ
    (0x1277, "t"),  # ቷ
    (0x127F, "ch"),  # ቿ
    (0x128B, "h"),  # ኋ
    (0x1297, "n"),  # ኗ
    (0x129F, "ny"),  # ኟ
    (0x12B3, "k"),  # ኳ
    (0x12DF, "z"),  # ዟ
    (0x12E7, "zh"),  # ዧ
    (0x12F7, "d"),  # ዷ
    (0x1307, "j"),  # ጇ
    (0x1313, "g"),  # ጓ
    (0x1327, "t'"),  # ጧ
    (0x132F, "ch'"),  # ጯ
    (0x133F, "ts'"),  # ጿ
    (0x134F, "f"),  # ፏ
)


def _fidel() -> ChartTemplate:
    letters: list[LetterTemplate] = []
    for base, consonant, same_family in FIDEL_FAMILIES:
        for order, vowel in enumerate(FIDEL_ORDERS):
            same = None
            if same_family is not None:
                same = chr(ord(same_family) + order)
            letters.append(
                LetterTemplate(
                    group="fidel",
                    glyph=chr(base + order),
                    romanization=consonant + vowel,
                    same_as=same,
                )
            )
    for code, consonant in FIDEL_LABIALISED:
        letters.append(
            LetterTemplate(group="labialised", glyph=chr(code), romanization=consonant + "wa")
        )
    return ChartTemplate(
        title={"en": "Fidel", "am": "ፊደል", "om": "Fidel"},
        groups=(
            GroupTemplate(
                key="fidel",
                names={"en": "Fidel", "am": "ፊደል", "om": "Fidel"},
                columns=len(FIDEL_ORDERS),
                column_labels=FIDEL_ORDERS,
            ),
            GroupTemplate(
                key="labialised",
                names={"en": "Labialised", "am": "ዲቃላ", "om": "Labialised"},
            ),
        ),
        letters=tuple(letters),
    )


# --- Qubee ------------------------------------------------------------------

# (glyph, romanization, hint) for one Qubee letter.
_Item = tuple[str, str, dict[str, str]]

_EJECTIVE = {"en": "Pushed out from the throat"}
_LONG = {"en": "Held twice as long; the length changes the word"}


def _qubee() -> ChartTemplate:
    def group(key: str, items: list[_Item]) -> list[LetterTemplate]:
        return [LetterTemplate(group=key, glyph=g, romanization=r, hint=h) for g, r, h in items]

    vowels: list[_Item] = [(f"{v.upper()} {v}", v, {}) for v in "aeiou"]
    long_vowels: list[_Item] = [(v * 2, v * 2, _LONG) for v in "aeiou"]
    consonant_sounds = {"c": "ch'", "q": "k'", "x": "t'"}
    consonants: list[_Item] = [
        (
            f"{c.upper()} {c}",
            consonant_sounds.get(c, c),
            _EJECTIVE if c in consonant_sounds else {},
        )
        for c in "bcdfghjklmnqrstwxy"
    ]
    consonants.append(("'", "'", {"en": "Hudhaa: a short catch in the throat, as in uh-oh"}))
    pairs: list[_Item] = [
        ("Ch ch", "ch", {}),
        ("Dh dh", "dh", {"en": "A d made with the tongue drawn back"}),
        ("Ny ny", "ny", {"en": "As in canyon"}),
        ("Ph ph", "p'", _EJECTIVE),
        ("Sh sh", "sh", {}),
    ]
    borrowed: list[_Item] = [(f"{c.upper()} {c}", c, {}) for c in "pvz"]
    return ChartTemplate(
        title={"en": "Qubee", "am": "ቁቤ", "om": "Qubee"},
        groups=(
            GroupTemplate(
                key="vowels", names={"en": "Vowels", "am": "አናባቢዎች", "om": "Dubbachiiftuu"}
            ),
            GroupTemplate(
                key="long_vowels",
                names={"en": "Long vowels", "am": "ረጃጅም አናባቢዎች", "om": "Dubbachiiftuu dheeraa"},
            ),
            GroupTemplate(
                key="consonants",
                names={"en": "Consonants", "am": "ተነባቢዎች", "om": "Dubbifamaa"},
            ),
            GroupTemplate(
                key="pairs",
                names={"en": "Letter pairs", "am": "ጥምር ፊደላት", "om": "Qubee dachaa"},
            ),
            GroupTemplate(
                key="borrowed",
                names={"en": "In borrowed words", "am": "በውሰት ቃላት", "om": "Jechoota liqii"},
            ),
        ),
        letters=tuple(
            group("vowels", vowels)
            + group("long_vowels", long_vowels)
            + group("consonants", consonants)
            + group("pairs", pairs)
            + group("borrowed", borrowed)
        ),
    )


def _empty() -> ChartTemplate:
    return ChartTemplate(
        title={"en": "Letters"},
        groups=(GroupTemplate(key="letters", names={"en": "Letters"}),),
        letters=(),
    )


def chart_template(name: str) -> ChartTemplate:
    """The chart a new one starts as. Raises `KeyError` for an unknown
    template; `TEMPLATES` lists the known ones."""
    return {"fidel": _fidel, "qubee": _qubee, "empty": _empty}[name]()


# --- what a chart needs before learners see it --------------------------------


@dataclass(frozen=True)
class LetterFacts:
    """What `missing_for_learners` needs to know about one letter."""

    id: str
    romanization: str
    has_audio: bool
    same_as_id: str | None


@dataclass(frozen=True)
class Gaps:
    """Why a chart cannot be shown yet, as counts the admin site shows."""

    no_letters: bool
    no_romanization: int
    no_audio: int

    @property
    def any(self) -> bool:
        return self.no_letters or self.no_romanization > 0 or self.no_audio > 0


def missing_for_learners(letters: list[LetterFacts]) -> Gaps:
    """A chart may be shown once it has a letter, every letter has its
    romanization, and every sound can play: a letter's own recording, or
    the recording of the letter it sounds the same as."""
    by_id = {letter.id: letter for letter in letters}
    no_audio = 0
    for letter in letters:
        source = by_id.get(letter.same_as_id) if letter.same_as_id else letter
        if source is None or not source.has_audio:
            no_audio += 1
    return Gaps(
        no_letters=not letters,
        no_romanization=sum(1 for letter in letters if not letter.romanization.strip()),
        no_audio=no_audio,
    )
