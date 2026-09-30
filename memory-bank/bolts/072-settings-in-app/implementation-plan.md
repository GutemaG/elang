---
stage: plan
bolt: 072-settings-in-app
created: '2026-09-30T20:54:47Z'
---

## Implementation Plan: settings-in-app

### Objective

Story 009 (FR-10): the app reads account settings (from the session
check) and app configuration (from `GET /api/v1/config`) through its own
list of known keys with defaults, keeps the last copy of each on the phone
for offline use, and never breaks when the backend adds a key. Adding a
setting in the app is one line plus the code that uses it.

### What the code says (checked before planning)

- **F1: The session check** (`SessionApi.checkSession`) parses the user
  field by field into `SessionUser` and ignores fields it doesn't know,
  so the new `settings` field is ignored today. An older backend won't
  send it at all.
- **F2: Where the check runs.** `SessionRenewer` checks the session in the
  background at every launch and passes the user to `onSessionChecked`,
  which `main.dart` already uses for the Notifications switch. Settings
  checks it again when it opens.
- **F3: Phone storage** is `SecureStorageService`, as for Sound and
  Appearance. Sign-out clears only the session key.
- **F4: Nothing uses a setting yet.** Both backend registries are empty
  (bolt 071, D3), so this bolt builds the path a first setting will use;
  it changes nothing a learner sees.

### Decisions

- **D1: The app's own lists** (`lib/shared/settings/known_settings.dart`):
  a `KnownSetting<T>` is a key and a default (`bool`, `int` or `String`).
  `accountSettings` and `appConfig` are two lists, both empty now, like the
  backend's. The file says: add one line here, then read it where it's
  used.
- **D2: Reading** (`RemoteSettings`): an immutable snapshot of a received
  map. `get(setting)` returns the value if it's there and of the right
  type, otherwise the default; keys the app doesn't know are ignored. So
  an older app keeps working when the backend adds a key, and a newer app
  keeps working against an older backend that sends nothing.
- **D3: Receiving.**
  - `SessionUser` gains `settings` (an empty map when the field is
    missing or isn't a map, so an older backend still passes the check).
  - `AppConfigApi.fetch()` calls `GET /api/v1/config` (no sign-in) and
    never throws: offline or on an error it returns `null`.
- **D4: Keeping the last copy** (`RemoteSettingsStore`): the account map is
  saved with the account id it belongs to, so after a sign-out and a
  sign-in as someone else, the previous learner's settings are never
  read; configuration is saved as is. Both are JSON under their own keys.
  A corrupt saved copy reads as empty (defaults).
- **D5: One place to read them** (`RemoteSettingsController`, handed down
  by a `RemoteSettingsScope` like the Appearance one):
  - loaded from the saved copies before the first frame;
  - updated from each session check (via the existing `onSessionChecked`
    in `main.dart`) and from a configuration fetch at launch, which runs
    in the background and never delays opening the app;
  - `account` and `config` snapshots; listeners hear each update.
- **D6: Writing account settings** from the app (a client for
  `PATCH /api/v1/users/me/settings`) is added with the first setting that
  has a control, not now: nothing would call it yet.

### Out of scope

- Any real setting, or a screen for one.
- Refreshing configuration more often than once a launch.

### Tests

- `KnownSetting` / `RemoteSettings`: a missing key reads the default, a
  wrong-typed value reads the default, an unknown key is ignored, a
  present value is returned (with test-only settings, since the real lists
  are empty).
- `SessionApi`: `settings` is parsed when present, and empty when missing
  or not a map; the check still succeeds either way.
- `AppConfigApi`: parses `{"config": {...}}`; returns `null` on a network
  error, a non-200 or a malformed body.
- `RemoteSettingsStore`: round-trips both; another account's saved copy
  isn't returned; a corrupt copy reads as empty.
- `RemoteSettingsController`: starts from the saved copies (offline), is
  updated by a session check and a config fetch, keeps the last copy when
  the fetch fails, and saves what it receives.
- The app still boots with the scope in place; the full suite, `flutter
  analyze` and a debug APK.

---

## Implementation Notes

### What changed

- **`lib/shared/settings/known_settings.dart`** (new):
  - `KnownSetting<T>` (key, default, `readFrom`);
  - `AccountSettings` and `AppConfig`, the app's two lists, empty, each
    with a how-to-add comment;
  - `RemoteSettings`, an immutable snapshot with `get(setting)` and value
    equality.
- **`lib/shared/services/app_config_api.dart`** (new): `AppConfigApi.fetch()`
  returns the config map or `null`, and never throws.
- **`lib/shared/settings/remote_settings_store.dart`** (new):
  - the account copy (`{user_id, settings}` under `account_settings`) and
    the config copy (under `app_config`) in `SecureStorageService`;
  - an unreadable copy counts as none;
  - `clearAccount()`.
- **`lib/shared/settings/remote_settings_controller.dart`** (new):
  - `RemoteSettingsController` (`load`, `applySession`, `refreshConfig`,
    `forgetAccount`; it notifies only on a real change);
  - `RemoteSettingsScope`, an `InheritedNotifier`.
- **`SessionApi`**: `SessionUser.settings`, empty when missing or not a
  map; the check never fails on it.
- **`SessionRepository`**: `addAccountChangedListener`, called on a
  sign-out or a save with a new token (not on a renewal of the same
  session).
- **`main.dart`**:
  - loads the controller from the saved copies before `runApp`;
  - the existing `onSessionChecked` also calls `applySession`;
  - a sign-out or new sign-in calls `forgetAccount`;
  - `refreshConfig()` runs in the background;
  - the app is wrapped in `RemoteSettingsScope`.

### Change from the plan

- **D4, who owns the account copy.** The saved session has no account id,
  so at launch (offline, before any session check) the app can't match a
  saved copy to the signed-in learner by id. Instead, the copy is
  forgotten, on the phone and in memory, the moment the account may
  change: sign-out, or a sign-in with a new token. So whatever copy is
  saved always belongs to whoever is signed in. The id is still saved
  beside it.

### Checks

- `test/shared/settings/remote_settings_test.dart`: 20 tests.
- Full app suite: 1812 passed. `flutter analyze`: clean. Debug APK: built.

---

## Test Report

- **Full app suite** (`flutter test --exclude-tags e2e`): 1812 passed, 0
  failed (+20 this bolt).
- **Targeted** (settings, session API, session renewer, app boot, auth
  flow): 110 passed, 3 runs out of 3.
- **`flutter analyze`**: clean. **Debug APK**: built.
- **Story 009, each criterion**:
  - the app lists the keys it knows with defaults; a missing or
    wrong-typed key reads the default and an unknown one is ignored
    (`RemoteSettings` tests);
  - settings come from the session check and configuration from
    `GET /api/v1/config` (`SessionApi` and `AppConfigApi` tests);
  - the last copy is kept on the phone and used offline (store and
    controller tests);
  - one learner's copy is never read for another (account-change tests);
  - adding a key is one `KnownSetting` line plus the code that reads it
    (the how-to in `known_settings.dart`).
- **Not tested here**: against the deployed backend. The endpoints go live
  with this push; until then the app gets no `settings` field, reads
  defaults, and the config fetch fails quietly, which the tests cover.

