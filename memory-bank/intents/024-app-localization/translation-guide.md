# Translation guide: Buna's own words

For the native-speaker reviewers of Amharic and Afaan Oromo. You do not need
to read Dart.

## Where the words are

- `lib/l10n/app_en.arb`: English, the master copy. Every entry has a
  description saying where the words appear.
- `lib/l10n/app_am.arb`: Amharic.
- `lib/l10n/app_om.arb`: Afaan Oromo.

Each file is a list of `"key": "text"` lines. Change only the text on the
right, never the key on the left. Keep the quotes and the comma at the end
of the line.

```json
"continueButton": "ቀጥል",
```

Lesson content (words, sentences, audio) is not in these files: it comes
from the course, written in the admin site.

## Blanks: `{name}`

A word in curly brackets is filled in by the app. Keep it exactly as it is
(same spelling, same brackets) and move it to wherever it belongs in your
sentence.

```json
"finishedSkill": "{skill}ን ጨርሰዋል!",
```

Here `{skill}` becomes the skill's name, e.g. "Greetings".

## Counts: `{count, plural, ...}`

Some texts change with a number. They look like this:

```json
"daysLeft": "{count, plural, =1{1 ቀን ቀርቷል} other{{count} ቀናት ቀርተዋል}}"
```

- `=1{...}` is the text for exactly one.
- `other{...}` is the text for every other number; `{count}` is the number.

Translate only the text inside the inner `{...}`; keep `{count, plural,`,
`=1`, `other` and every bracket as they are.

## Lists separated by commas

`monthNames`, `monthShortNames` and `weekdayInitials` are lists: twelve
months (January first) or seven days (Monday first), separated by commas
with no spaces. Keep the same number of items.

## Terms to keep the same everywhere

| English | Amharic | Afaan Oromo | Notes |
|---|---|---|---|
| XP | XP | XP | Points; not translated |
| Amole | Amole | Amole | The app's coins; a name |
| Buna | Buna | Buna | The app's name |
| streak | ተከታታይ ቀናት | walitti fufiinsa | Days in a row with a lesson |
| beans | ፍሬ / ፍሬዎች | ija bunaa | Lives spent on wrong answers |
| lesson | ትምህርት | barnoota | |
| practice | ልምምድ | shaakala | |
| skill | ክህሎት | dandeettii | A group of lessons on the path |
| course | ኮርስ | koorsii | |
| league | ሊግ | liigii | The weekly ranking |
| Green Bean | አረንጓዴ ፍሬ | Ija Magariisa | League tier 1 |
| Light Roast | ቀላል ቁሌት | Akaawwii Salphaa | League tier 2 |
| Medium Roast | መካከለኛ ቁሌት | Akaawwii Giddugaleessaa | League tier 3 |
| Dark Roast | ጥቁር ቁሌት | Akaawwii Gurraacha | League tier 4 |
| Golden Cup | ወርቃማ ስኒ | Siinii Warqee | League tier 5 |

## Length

Buttons and badges have little room. If a translation is much longer than
the English, prefer a shorter wording. Texts in CAPITALS in English
("XP EARNED") are short labels on cards.

## After editing

Send the edited files back (or commit them). A developer runs the app's
tests, which check that every key is still there in every file and that
every `{blank}` matches the English.

## Status

All texts were drafted by Claude on 2026-10-02 and have not yet been
reviewed by a native speaker. The Afaan Oromo drafts most need checking.
