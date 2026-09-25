---
intent: 019-image-choice-exercise-types
phase: inception
status: units-decomposed
updated: '2026-09-25T06:15:00Z'
---

# Image Choice Exercise Types - Unit Decomposition

## Units Overview

Three units, split at the same seams as `017-content-admin-web` and the
earlier exercise-type intents. The backend contract comes first. The admin
site and the app both build against it and do not depend on each other.

### Unit 1: 001-image-choice-service

**Description:** The two content types, their validation and migration, the
picture upload link and local picture storage, and the sample content with
its pictures and credits.

**Requirements:** FR-1, FR-2, FR-3 (server), FR-8 (pictures, credits and
seed)

**Deliverables:**
- `ExerciseType.IMAGE_CHOICE` and `AUDIO_IMAGE_CHOICE`, their content value
  objects, field checks, migration, repository, schema and mapping
- `POST /admin/images/uploads`, with local storage under `/media/images`
- Sample pictures committed with a credits file, and a local-only seed of
  at least 3 + 2 questions, each linked to its own vocabulary word
- **No** new `AnswerKey` member: `ChoiceAnswerKey`

**Dependencies:** none. Depended on by units 2 and 3.

**Estimated complexity:** M

### Unit 2: 002-image-choice-admin

**Description:** The admin site's picture field (shrink in the browser,
then upload), the two editors, and the preview.

**Requirements:** FR-3 (client), FR-4

**Deliverables:**
- A picture module: accept JPEG, PNG or WebP up to 10 MB, shrink to 512 px,
  encode WebP or JPEG at 300 KB or less, upload through the link
- An editor for 2 to 4 picture slots with alt text and a correct marker,
  used by both types; the audio field reused for `audio_image_choice`
- Both types in "add exercise" and in the preview

**Dependencies:** `001-image-choice-service`

**Estimated complexity:** M

### Unit 3: 003-image-choice-ui

**Description:** The picture tile in the question kit, both types in
lessons and practice, offline packs with pictures, early loading, and the
picture credits in the app.

**Requirements:** FR-5, FR-6, FR-7, FR-8 (credits in the app), FR-9, FR-10

**Deliverables:**
- `PictureTile` and its grid in `lib/shared/widgets/exercise/`, in the
  gallery
- Models, parsing, fake API and lesson-screen arms for both types
- Offline pack save, load, delete and size handling for pictures
- Early loading of a lesson's pictures
- A "Licences" entry listing the picture credits

**Dependencies:** `001-image-choice-service` (the real shape). The credits
story also needs the credits file from the samples bolt.

**Estimated complexity:** L

## Requirement-to-Unit Mapping

- **FR-1** Image choice content type → `001-image-choice-service`
- **FR-2** Audio image choice content type → `001-image-choice-service`
- **FR-3** Picture storage → `001-image-choice-service` (link and storage);
  the admin upload call is in `002-image-choice-admin`
- **FR-4** Admin editors → `002-image-choice-admin`
- **FR-5** Picture tile and lesson screens → `003-image-choice-ui`
- **FR-6** Offline lessons → `003-image-choice-ui`
- **FR-7** Practice sessions → `003-image-choice-ui`; the backend's due-item
  test is a criterion of the service's content story
- **FR-8** Sample content → `001-image-choice-service` (pictures, credits,
  seed); the credits in the app are in `003-image-choice-ui`
- **FR-9** Older app versions → `003-image-choice-ui`
- **FR-10** Pictures ready early → `003-image-choice-ui`

## Unit Dependency Graph

```text
                        ┌──> [002-image-choice-admin]
[001-image-choice-service]
                        └──> [003-image-choice-ui]
```

## Execution Order

1. `001-image-choice-service`: content types and upload link (bolt 050),
   then samples (bolt 051)
2. `002-image-choice-admin` (bolt 052)
3. `003-image-choice-ui`: the tile and lesson screens (bolt 053), then
   offline, early loading and credits (bolt 054)

Units 2 and 3 can run in either order after bolt 050.

## Note on Grading

There is no grading story. Both types grade on the device with the
existing `ChoiceAnswerKey`, as multiple choice does (ADR-5), so grading is a
criterion of the lesson screen story.
