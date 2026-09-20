---
stage: plan
bolt: 027-course-offline-and-verification
created: '2026-09-21T00:00:00Z'
---

## Implementation Plan: course-offline-and-verification

### Objective

Switching courses is correct online and offline, downloaded lessons and queued completions stay attached to their own course, and the whole multi-course flow is proven end to end without regressing English to Amharic.

### Real-Source Findings (read at Plan stage)

- **There is no skill-tree cache today.** `SkillTreeDashboardScreen._load` calls `getSkillTree`, `getBeansStatus` and `getDueCount` and shows an error state with Retry if any fails. So the dashboard is already blank offline, with or without courses. Story 003's "opens from cache" and "A's tree is not shown for B" need a cache to be built, not just re-keyed.
- **Lesson packs are already separate per course by construction.** `lesson_packs` is keyed by `lesson_id` (a globally unique id), and a lesson belongs to one course, so two courses' packs never collide and deleting one never touches another. What is missing is only the *label*: a pack row has no course, so Manage Downloads cannot show which course a pack belongs to.
- **The sync queue is already correct across a switch.** Entries hold `lesson_id` and the backend (bolt 024) gates a completion by the lesson's OWN course, not the active one. No client change needed; it needs a test proving it.
- **Switching is a server call** (`PUT /users/me/active-course`). Offline it cannot happen, so an offline switch must be local, then reconciled.
- Existing packs (before this bolt) have no course; per the story they are treated as English to Amharic.

### Decisions for your approval

1. **Build a per-course skill-tree cache (recommended).** After every successful dashboard load, save that course's tree (with beans, XP, streak) keyed by course id. If the network fails, show the cached tree of the active course with a small "Offline, showing saved progress" note instead of the error state. Practice stays online-only (existing rule). Alternative: skip the cache and make offline switching unavailable, which fails two of story 003's acceptance criteria.
2. **Offline switch rule (recommended):**
   - The last course list is cached too, so the picker opens offline.
   - Offline, a course can be chosen only if its tree is cached. It becomes the active course **locally** and the dashboard opens from cache.
   - Offline and not cached: the message "Connect to the internet to open this course for the first time." and the current course stays active.
   - On the next successful online load, if the local active course differs from the server's, the app sends the switch to the server, then reloads. The server stays the source of truth otherwise.
3. **Label packs with their course (recommended).** Add nullable `course_id` and `course_title` columns to `lesson_packs` (database v2, existing rows stay and read as English to Amharic). The dashboard passes the active course when a pack is downloaded. Manage Downloads shows the course under each pack title. Alternative: derive the course from a cached tree, which breaks when the cache is empty.
4. **Verification (story 004):** audit the backend tests written in bolts 024 and 025 and add only the missing integration tests per new pair (en to om, am to om, om to am): completing a lesson updates XP, Amole and streak and creates vocab in that course; due words show in Practice only for their course; prompts and answers read in the right languages, including Amharic to Afaan Oromo with no English anywhere. Then run the full suites. The manual on-device check stays with you.

### Deliverables

- **Models**: `SkillTreeResponse` and `CourseList` gain JSON round-trip (to and from a stored map).
- **Services**: a `CourseCacheStore` interface with a file-backed implementation and an in-memory fake, holding per-course trees, the last course list, and the locally active course id. `HttpCourseApi`/`HttpLessonApi` stay network-only. A small `OfflineCourseGate` (or logic in the picker helper) decides the offline switch rule. `LessonPackStore` gains the two columns and `DownloadedPackSummary` gains `courseTitle`.
- **UI**: the dashboard falls back to the cached tree offline with the note; the picker works offline per decision 2; Manage Downloads shows each pack's course; reconciliation on the next online load.
- **Backend**: only missing integration tests from decision 4, plus any small fix they expose.
- **Docs**: update the ADR index only if the offline-switch rule is worth an ADR (I would record it as ADR-14, short).

### Dependencies

- Bolts 024 to 026 (complete). No new packages: the cache uses the app documents directory and JSON, as the pack store does.

### Acceptance Criteria Mapping

| Story 003 criterion | How it is met |
|---|---|
| A's tree not shown for B | tree cache keyed by course id |
| Packs in two courses both kept and labelled | pack rows unchanged by course, new label columns |
| Offline, target cached: opens from cache | decision 2 |
| Offline, target never cached: message, stays | decision 2 |
| Completion queued in A, switched to B, syncs to A | queue keyed by lesson id, backend gates by lesson's course; test on both sides |
| Pre-existing cached data kept as English to Amharic | null `course_id` reads as English to Amharic; nothing is deleted |

### Test Plan

- Cache store: round-trip a tree and a course list, separate courses do not mix, corrupt or missing file returns nothing, not a crash.
- Dashboard: online load writes the cache; offline load shows the cached tree and note; offline with no cache shows the existing error state; reconciliation sends the switch once.
- Picker offline: cached course switches locally, uncached one shows the message, current course unchanged.
- Pack store: v1 to v2 upgrade keeps rows; new packs carry the course; Manage Downloads shows the label; deleting one course's pack leaves the other.
- Sync engine: an entry queued for a lesson in another course still syncs after the active course changed.
- Backend: per-pair completion, Practice scoping and language-direction tests as in decision 4.
- Overflow tests at 360dp and 320dp with 1.3x text for the new note and the pack label.
- Full Flutter and backend suites and `flutter analyze`.

### Risks

- The offline switch changes what "active course" means for a short time (device and server can differ). Mitigated by reconciling first on the next online load, and by lesson completion being gated by the lesson's own course.
- Skill-tree JSON must stay in step with the model; the round-trip test guards it.
