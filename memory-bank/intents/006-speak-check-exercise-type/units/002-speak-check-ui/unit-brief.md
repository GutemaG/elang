---
unit: 002-speak-check-ui
intent: 006-speak-check-exercise-type
phase: inception
status: ready
created: '2026-09-17T14:45:00Z'
updated: '2026-09-17T14:45:00Z'
---

# Unit Brief: Speak-Check UI

## Purpose

The client half of the `speak_check` exercise: record/re-record/submit UI, pass/fail feedback with unlimited retries, microphone-permission handling, and excluding this exercise type from offline downloadable packs.

## Scope

### In Scope
- Recording widget: record, stop, re-record before submitting, submit
- Microphone-permission request/denial handling
- New Flutter audio-recording package (not yet in `pubspec.yaml`)
- Submits the recording to `001-speak-check-service`'s real endpoint; renders pass/fail (+ transcript, if useful for feedback)
- Unlimited retry loop within the exercise
- `LessonPackDownloader` handles a lesson containing a `speak_check` exercise without crashing, and excludes it from offline availability per FR-5 (exact granularity — whole-lesson vs. per-exercise — a Technical Design decision made once the real downloader code is read at Construction)

### Out of Scope
- Any backend change (owned by `001-speak-check-service`)
- Offline queueing/deferred scoring (excluded per FR-5)

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-3 | Client Audio-Recording UI | Must |
| FR-5 | Excluded from Offline Downloadable Packs | Must |

---

## Domain Concepts

### Key Operations
| Operation | Description | Inputs | Outputs |
|-----------|-------------|--------|---------|
| RecordAttempt | Records, previews, and submits a spoken attempt | microphone audio | pass/fail feedback (from the backend) |

---

## Technical Context

### Suggested Technology
A Flutter audio-recording package (e.g. `record`; exact choice a Technical Design decision at Construction, not fixed here), integrated the same way `AnswerFeedbackPlayer`/`LessonAudioPlayer` are already interface-abstracted for testability (mock at the plugin boundary only, per `coding-standards.md`).

### Integration Points
| Integration | Type | Protocol |
|-------------|------|----------|
| `001-speak-check-service` | API | REST over HTTPS, session-token auth (existing pattern), multipart/binary audio upload |

---

## Constraints

- Must not regress any existing exercise type's UI or the offline-download flow for lessons that don't contain a `speak_check` exercise.
- Microphone permission handling must degrade gracefully (no crash) if denied.

---

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 016-speak-check-ui | simple-construction-bolt | 001, 002 | Recording UI + offline exclusion |

---

## Notes

Blocked on `001-speak-check-service` completing first (needs the real endpoint contract) — same discipline as `012-match-pairs-ui` waiting on `011-match-pairs-service`. Since `001-speak-check-service` itself is blocked on external GCP provisioning, this unit cannot start until both that provisioning *and* the backend unit are done.
