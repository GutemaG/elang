---
stage: plan
bolt: 077-app-language-service
created: '2026-10-02T19:16:50Z'
---

## Implementation Plan: app-language-service

### Objective

Story 001 (FR-6, backend): keep the learner's app language on the account
and return it at session validation, so a new phone can show the app in
their language after sign-in.

### What the code says (checked before planning)

- **F1 Account settings already exist.** Bolt 071 added `users.settings`
  (JSON) and `ACCOUNT_SETTINGS` in `app/domain/settings.py`: "To add a
  setting, add one `Setting` line to a registry. No migration, seed or
  backfill." `show_in_leagues` is the one setting so far.
- **F2 It has the endpoint and the read path.** `PATCH /api/v1/users/me/settings`
  merges a partial map (unknown key or wrong value: `422 invalid_setting`,
  nothing saved) and returns the full map; session validation already
  returns `settings` resolved with defaults. The app already has
  `AccountSettings` / `account_settings_api.dart` for it.
- **F3 A `str` setting** can be free text or limited to `choices`. Neither
  fits "any 2-3 lowercase letters": `choices` would need a backend edit per
  new app language (against NFR-3), free text would accept anything.
- **F4 Settings cannot be null.** A `Setting` has a typed default.

### Deviation from the inception plan (needs approval)

The inception artifacts say "a new nullable `users.app_language` column,
one migration, via `PATCH /api/v1/users/me`". The code has a better home
for it (F1, F2), so this plan uses **an account setting instead**:

- **No migration, nothing to run on Neon.**
- The endpoint is `PATCH /api/v1/users/me/settings`, and session
  validation returns it inside `settings` (already parsed by the app).
- "Not chosen yet" is the empty string `""` (the default), instead of
  null (F4).

FR-6, the unit brief, story 001 and bolt 078's account story are updated
to match once this is approved.

### Decisions

- **D1 Pattern on a `str` setting.** `Setting` gains an optional
  `pattern` (a regex the whole value must match), for `str` settings only,
  checked in `accepts` (so `validate` gives 422 and `resolve` drops a bad
  stored value back to the default). Error text: `expected text matching
  <pattern>`. A pattern together with `choices` is refused at start-up,
  like `choices` on a non-`str`.
- **D2 The setting.** `Setting("app_language", "str", "",
  pattern=r"(?:[a-z]{2,3})?")`: `""` = not chosen; `am`, `om`, `en`, `sid`
  accepted; `AM`, `amharic`, `a`, `a1`, `null`, `5` refused (422).
- **D3 No list of app languages on the server.** The app decides which
  codes it has, and shows English for one it lacks (unit 2).
- **D4 Nothing else changes.** `PATCH /users/me` (learning language, daily
  goal, notifications) and the league side effect of the settings PATCH are
  untouched.

### Deliverables

- `app/domain/settings.py`: `pattern` on `Setting`; the `app_language`
  line with a comment.
- Tests:
  - `tests/unit/test_settings_registry.py`: pattern accepted/refused,
    resolve drops a bad stored value, pattern + choices refused, pattern
    on a non-`str` refused.
  - `tests/integration/test_settings_endpoints.py`: a new account reads
    `app_language: ""`; PATCH `am` stores and returns it and session
    validation returns it; bad values are 422 with nothing saved; the
    real-registry listing test now lists both keys.
- API notes: `docs` entry for the setting, if the settings endpoint is
  documented there.

### Acceptance criteria (story 001, revised)

- [ ] `PATCH /api/v1/users/me/settings` with `{"app_language": "am"}`
  stores it and returns it; other settings are unchanged.
- [ ] `"AM"`, `"amharic"`, `"a"`, non-strings: 422 `invalid_setting`,
  nothing saved; `""` (clear) and `"sid"` accepted.
- [ ] Session validation returns `settings.app_language`: `""` for an
  account that never set it.
- [ ] No migration; a single Alembic head, unchanged.
- [ ] Full backend suite, ruff and mypy (apart from the existing
  `lesson_repositories.py:392` error) pass.

### Dependencies

None. Bolt 078 reads and writes the setting through the existing
`AccountSettings` client.

---

## Implement (2026-10-02T19:19:27Z)

Approved at the plan checkpoint: the account setting, no migration. FR-6,
the unit briefs (001 and 002), units.md, this bolt and the inception log
were revised to match.

- `app/domain/settings.py`: `Setting` takes an optional `pattern` for
  `str` settings, matched in full in `accepts` (so `validate` refuses
  with "expected text matching ..." and `resolve` drops a bad stored value
  to the default). A pattern on a non-`str`, or with `choices`, is
  refused when the registry is built.
- `ACCOUNT_SETTINGS` gains `Setting("app_language", "str", "",
  pattern=r"(?:[a-z]{2,3})?")`.
- No endpoint, schema or migration change: `PATCH /users/me/settings`
  and session validation already carry every account setting.
- ruff and mypy are clean on the file. Two existing tests that list the
  real registries (`show_in_leagues` only) now fail as expected; they are
  updated in the test stage.

---

## Test (2026-10-02T19:30:28Z)

- `tests/unit/test_settings_registry.py`:
  - definitions: a pattern only on a `str`, not with `choices`, and the
    default must match it;
  - `TestPattern`: full matches accepted (`""`, `am`, `om`, `en`,
    `sid`), anything else refused (`AM`, `amharic`, `a`, `a1`,
    padded, a trailing newline, `None`, `5`); `validate` names the
    pattern; a bad stored value reads as the default and is listed by
    `invalid_keys`;
  - `TestAppLanguage`: the real setting is `""` until chosen, takes any
    2-3 letter code and refuses the rest;
  - the real-registries test lists `show_in_leagues` and `app_language`.
- `tests/integration/test_settings_endpoints.py`: `TestAppLanguage`
  through the real registry: saved, returned and read back at the session
  check; other settings untouched; `""` clears and `sid` is taken; a
  bad code is `422 invalid_setting` with nothing saved (even alongside a
  valid key); the real-registries test lists both keys.
- `tests/integration/test_league_endpoints.py`: two assertions compared
  the whole settings map; they now check `show_in_leagues` alone.

Results: full backend suite 1584 passed (1582 in the full run, plus the
two league tests fixed after it, re-run on their own); ruff clean; mypy
has the 4 errors that are there without this change (checked by stashing
it), none in `settings.py`. No migration; the Alembic head is unchanged.
