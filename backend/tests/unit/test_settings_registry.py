"""The settings registries (bolt 071, 022-light-and-dark-themes FR-8/FR-9):
every known key read with its default, updates checked all or nothing.
"""

from __future__ import annotations

import pytest

from app.domain.exceptions import InvalidSettingError
from app.domain.settings import ACCOUNT_SETTINGS, APP_CONFIG, Setting, SettingsRegistry


def _setting_list() -> list[Setting]:
    return [
        Setting("reduce_motion", "bool", False),
        Setting("reminder_hour", "int", 20),
        Setting("theme", "str", "system", choices=("system", "light", "dark")),
        Setting("nickname", "str", ""),
    ]


_REGISTRY = SettingsRegistry(_setting_list())


class TestResolve:
    def test_nothing_stored_is_every_default(self) -> None:
        assert _REGISTRY.resolve({}) == {
            "reduce_motion": False,
            "reminder_hour": 20,
            "theme": "system",
            "nickname": "",
        }
        assert _REGISTRY.resolve(None) == _REGISTRY.resolve({})

    def test_keeps_valid_stored_values(self) -> None:
        resolved = _REGISTRY.resolve({"reduce_motion": True, "theme": "dark"})
        assert resolved["reduce_motion"] is True
        assert resolved["theme"] == "dark"
        assert resolved["reminder_hour"] == 20

    def test_drops_keys_no_longer_known(self) -> None:
        assert "old_setting" not in _REGISTRY.resolve({"old_setting": 1})

    def test_a_wrong_typed_stored_value_reads_as_the_default(self) -> None:
        stored = {"reminder_hour": "eight", "theme": "sepia", "reduce_motion": 1}
        assert _REGISTRY.resolve(stored) == _REGISTRY.resolve({})
        assert _REGISTRY.invalid_keys(stored) == ["reduce_motion", "reminder_hour", "theme"]

    def test_a_new_key_reads_for_existing_stored_maps(self) -> None:
        # Story 007: a setting added later works for an account stored
        # before it existed, with no migration or backfill.
        stored = {"theme": "dark"}
        later = SettingsRegistry([*_setting_list(), Setting("daily_tip", "bool", True)])
        assert later.resolve(stored)["daily_tip"] is True
        assert later.resolve(stored)["theme"] == "dark"


class TestValidate:
    def test_accepts_known_keys_of_the_right_type(self) -> None:
        _REGISTRY.validate({"reduce_motion": True, "reminder_hour": 7, "theme": "light"})
        _REGISTRY.validate({})

    @pytest.mark.parametrize(
        ("changes", "message"),
        [
            ({"unknown": 1}, "unknown: unknown setting"),
            ({"reduce_motion": "yes"}, "reduce_motion: expected true or false"),
            ({"reminder_hour": True}, "reminder_hour: expected a whole number"),
            ({"reminder_hour": 7.5}, "reminder_hour: expected a whole number"),
            ({"theme": "sepia"}, "theme: expected one of system, light, dark"),
            ({"nickname": None}, "nickname: expected text"),
        ],
    )
    def test_refuses_unknown_keys_and_wrong_types(
        self, changes: dict[str, object], message: str
    ) -> None:
        with pytest.raises(InvalidSettingError, match=message):
            _REGISTRY.validate(changes)

    def test_names_every_problem_at_once(self) -> None:
        with pytest.raises(InvalidSettingError) as caught:
            _REGISTRY.validate({"unknown": 1, "theme": 3, "nickname": "Abebe"})
        assert "unknown" in caught.value.message
        assert "theme" in caught.value.message
        assert "nickname" not in caught.value.message


class TestDefinitions:
    def test_a_default_must_fit_its_own_type(self) -> None:
        with pytest.raises(ValueError, match="default"):
            Setting("hour", "int", "20")
        with pytest.raises(ValueError, match="default"):
            Setting("theme", "str", "sepia", choices=("light", "dark"))

    def test_choices_are_for_strings_only(self) -> None:
        with pytest.raises(ValueError, match="choices"):
            Setting("hour", "int", 1, choices=("1",))

    def test_a_pattern_is_for_strings_only(self) -> None:
        with pytest.raises(ValueError, match="pattern"):
            Setting("hour", "int", 1, pattern=r"\d+")

    def test_a_pattern_and_choices_are_not_both_taken(self) -> None:
        with pytest.raises(ValueError, match="not both"):
            Setting("theme", "str", "light", choices=("light", "dark"), pattern=r"[a-z]+")

    def test_a_default_must_match_its_pattern(self) -> None:
        with pytest.raises(ValueError, match="default"):
            Setting("code", "str", "x1", pattern=r"[a-z]+")

    def test_a_key_is_listed_once(self) -> None:
        with pytest.raises(ValueError, match="twice"):
            SettingsRegistry([Setting("a", "bool", True), Setting("a", "bool", False)])

    def test_the_real_registries(self) -> None:
        # Bolt 073 (023-weekly-leagues) added the first account setting and
        # bolt 077 (024-app-localization) the app language. App
        # configuration holds the app versions the phone checks itself
        # against.
        assert ACCOUNT_SETTINGS.keys == ["show_in_leagues", "app_language"]
        assert ACCOUNT_SETTINGS.resolve({}) == {"show_in_leagues": True, "app_language": ""}
        assert APP_CONFIG.keys == [
            "min_build_android",
            "min_build_ios",
            "latest_build_ios",
            "ios_store_url",
        ]

    def test_the_app_versions_start_open(self) -> None:
        # Every build may run until the team raises a minimum.
        assert APP_CONFIG.resolve({}) == {
            "min_build_android": 0,
            "min_build_ios": 0,
            "latest_build_ios": 0,
            "ios_store_url": "",
        }

    def test_the_ios_store_url_must_be_an_https_address(self) -> None:
        APP_CONFIG.validate({"ios_store_url": "https://apps.apple.com/app/id1"})
        APP_CONFIG.validate({"ios_store_url": ""})
        with pytest.raises(InvalidSettingError):
            APP_CONFIG.validate({"ios_store_url": "javascript:alert(1)"})


_LANGUAGE_CODE = Setting("code", "str", "", pattern=r"(?:[a-z]{2,3})?")


class TestPattern:
    """A `str` setting with a pattern (bolt 077): the whole value must
    match it."""

    @pytest.mark.parametrize("value", ["", "am", "om", "en", "sid"])
    def test_accepts_a_full_match(self, value: str) -> None:
        assert _LANGUAGE_CODE.accepts(value)

    @pytest.mark.parametrize("value", ["AM", "amharic", "a", "a1", "am ", " am", "am\n", None, 5])
    def test_refuses_anything_else(self, value: object) -> None:
        assert not _LANGUAGE_CODE.accepts(value)

    def test_validate_names_the_pattern(self) -> None:
        registry = SettingsRegistry([_LANGUAGE_CODE])
        with pytest.raises(InvalidSettingError, match=r"code: expected text matching"):
            registry.validate({"code": "Amharic"})

    def test_a_stored_value_that_does_not_match_reads_as_the_default(self) -> None:
        registry = SettingsRegistry([_LANGUAGE_CODE])
        assert registry.resolve({"code": "AM"}) == {"code": ""}
        assert registry.invalid_keys({"code": "AM"}) == ["code"]
        assert registry.resolve({"code": "om"}) == {"code": "om"}


class TestAppLanguage:
    """The real `app_language` account setting (024-app-localization,
    story 001)."""

    def test_is_empty_until_chosen(self) -> None:
        assert ACCOUNT_SETTINGS.resolve({})["app_language"] == ""

    @pytest.mark.parametrize("code", ["", "en", "am", "om", "sid"])
    def test_takes_any_two_or_three_letter_code(self, code: str) -> None:
        ACCOUNT_SETTINGS.validate({"app_language": code})

    @pytest.mark.parametrize("value", ["AM", "amharic", "a", "a1", None, 1, True])
    def test_refuses_anything_else(self, value: object) -> None:
        with pytest.raises(InvalidSettingError, match="app_language"):
            ACCOUNT_SETTINGS.validate({"app_language": value})


class TestMinimum:
    """An `int` setting may name the smallest value it takes."""

    def test_a_value_below_the_minimum_is_refused(self) -> None:
        build = Setting("build", "int", 0, minimum=0)
        assert build.accepts(0)
        assert build.accepts(7)
        assert not build.accepts(-1)
        with pytest.raises(InvalidSettingError, match="a whole number from 0"):
            SettingsRegistry([build]).validate({"build": -1})

    def test_only_an_int_takes_a_minimum(self) -> None:
        with pytest.raises(ValueError, match="only an int"):
            Setting("name", "str", "", minimum=0)

    def test_the_default_must_meet_it(self) -> None:
        with pytest.raises(ValueError, match="default"):
            Setting("build", "int", 0, minimum=1)
