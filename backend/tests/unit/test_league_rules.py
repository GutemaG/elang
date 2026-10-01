"""Unit tests: the league rules in `app.domain.league` (023-weekly-leagues,
bolt 073, stories 001-003). Pure functions, no database."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta, timezone

import pytest

from app.domain.league import (
    AVATAR_COLOURS,
    HIGHEST_TIER,
    LOWEST_TIER,
    TIERS,
    LeagueTier,
    MemberResult,
    Movement,
    Standing,
    Zones,
    avatar_colour,
    close_group,
    movement,
    rank,
    shown_name,
    tier_above,
    tier_below,
    week_end,
    week_start,
    zone_sizes,
)

_MONDAY = datetime(2026, 10, 5, tzinfo=UTC)  # A Monday.


class TestTiers:
    def test_five_tiers_lowest_first(self) -> None:
        assert [t.value for t in TIERS] == [
            "green_bean",
            "light_roast",
            "medium_roast",
            "dark_roast",
            "golden_cup",
        ]
        assert LOWEST_TIER is LeagueTier.GREEN_BEAN
        assert HIGHEST_TIER is LeagueTier.GOLDEN_CUP

    def test_moving_stops_at_both_ends(self) -> None:
        assert tier_above(LeagueTier.GREEN_BEAN) is LeagueTier.LIGHT_ROAST
        assert tier_above(HIGHEST_TIER) is HIGHEST_TIER
        assert tier_below(LeagueTier.LIGHT_ROAST) is LeagueTier.GREEN_BEAN
        assert tier_below(LOWEST_TIER) is LOWEST_TIER


class TestWeek:
    @pytest.mark.parametrize(
        "moment",
        [
            _MONDAY,
            _MONDAY + timedelta(days=3, hours=12),
            _MONDAY + timedelta(days=7) - timedelta(microseconds=1),  # Sunday 23:59:59.
        ],
    )
    def test_every_moment_of_the_week_belongs_to_its_monday(self, moment: datetime) -> None:
        assert week_start(moment) == _MONDAY
        assert week_end(moment) == _MONDAY + timedelta(days=7)

    def test_monday_midnight_starts_the_next_week(self) -> None:
        assert week_start(_MONDAY + timedelta(days=7)) == _MONDAY + timedelta(days=7)

    def test_the_week_is_in_utc_whatever_the_phone_says(self) -> None:
        # Monday 02:00 in Addis Ababa (UTC+3) is still Sunday in UTC.
        addis = timezone(timedelta(hours=3))
        moment = datetime(2026, 10, 12, 2, 0, tzinfo=addis)
        assert week_start(moment) == _MONDAY

    def test_a_time_with_no_zone_is_utc(self) -> None:
        assert week_start(datetime(2026, 10, 7, 9, 0)) == _MONDAY


class TestZones:
    @pytest.mark.parametrize(
        ("members", "expected"),
        [
            (0, Zones(0, 0)),
            (1, Zones(1, 0)),
            (4, Zones(1, 0)),
            (5, Zones(1, 1)),
            (6, Zones(2, 2)),
            (10, Zones(2, 2)),
            (11, Zones(3, 3)),
            (30, Zones(6, 6)),
            (31, Zones(7, 7)),
        ],
    )
    def test_a_fifth_up_and_down_rounded_up_and_small_groups_only_promote(
        self, members: int, expected: Zones
    ) -> None:
        assert zone_sizes(members, LeagueTier.MEDIUM_ROAST) == expected

    def test_nobody_moves_down_from_the_lowest_tier(self) -> None:
        assert zone_sizes(30, LOWEST_TIER) == Zones(6, 0)

    def test_nobody_moves_up_from_the_highest_tier(self) -> None:
        assert zone_sizes(30, HIGHEST_TIER) == Zones(0, 6)
        assert zone_sizes(3, HIGHEST_TIER) == Zones(0, 0)


def _s(user_id: str, xp: int, last_min: int | None, joined_min: int) -> Standing:
    return Standing(
        user_id=user_id,
        weekly_xp=xp,
        last_xp_at=_MONDAY + timedelta(minutes=last_min) if last_min is not None else None,
        joined_at=_MONDAY + timedelta(minutes=joined_min),
    )


class TestRank:
    def test_most_xp_first(self) -> None:
        ranked = rank([_s("a", 10, 5, 0), _s("b", 30, 9, 1), _s("c", 20, 7, 2)])
        assert [s.user_id for s in ranked] == ["b", "c", "a"]

    def test_a_tie_goes_to_whoever_reached_it_first(self) -> None:
        ranked = rank([_s("late", 20, 50, 0), _s("early", 20, 10, 5)])
        assert [s.user_id for s in ranked] == ["early", "late"]

    def test_then_to_whoever_joined_first(self) -> None:
        ranked = rank([_s("b", 0, None, 9), _s("a", 0, None, 3), _s("c", 15, 1, 20)])
        assert [s.user_id for s in ranked] == ["c", "a", "b"]


class TestNamesAndColours:
    def test_the_first_name_is_shown(self) -> None:
        assert shown_name("Abebe", "user-1") == "Abebe"

    @pytest.mark.parametrize("first_name", [None, ""])
    def test_without_one_a_stable_learner_number(self, first_name: str | None) -> None:
        name = shown_name(first_name, "user-1")
        assert name == shown_name(None, "user-1")
        prefix, digits = name.split(" ")
        assert prefix == "Learner"
        assert len(digits) == 4 and digits.isdigit()

    def test_different_accounts_usually_differ(self) -> None:
        names = {shown_name(None, f"user-{i}") for i in range(50)}
        assert len(names) > 40

    def test_the_colour_is_stable_and_in_range(self) -> None:
        colours = [avatar_colour(f"user-{i}") for i in range(200)]
        assert all(0 <= c < AVATAR_COLOURS for c in colours)
        assert set(colours) == set(range(AVATAR_COLOURS))
        assert avatar_colour("user-7") == avatar_colour("user-7")


def _standings(xps: list[int]) -> list[Standing]:
    """Members `m0`, `m1`, ... with these XP; earlier members reached their
    total earlier, so ties keep this order."""
    return [_s(f"m{i}", xp, i if xp else None, i) for i, xp in enumerate(xps)]


def _moves(tier: LeagueTier, xps: list[int]) -> list[tuple[int | None, str, int]]:
    by_user = {r.user_id: r for r in close_group(tier, _standings(xps))}
    return [
        (r.final_rank, movement(tier, r.tier_after).value, r.reward_amole)
        for r in (by_user[f"m{i}"] for i in range(len(xps)))
    ]


class TestCloseGroup:
    def test_alone_first_place_moves_up_and_earns_the_top_reward(self) -> None:
        assert _moves(LeagueTier.LIGHT_ROAST, [5]) == [(1, "up", 100)]

    def test_under_five_only_first_moves_and_only_existing_places_are_paid(self) -> None:
        assert _moves(LeagueTier.LIGHT_ROAST, [10, 40, 20, 5]) == [
            (3, "stayed", 40),
            (1, "up", 100),
            (2, "stayed", 60),
            (4, "stayed", 0),
        ]
        assert _moves(LeagueTier.LIGHT_ROAST, [10, 20]) == [(2, "stayed", 60), (1, "up", 100)]

    def test_five_move_one_up_and_one_down(self) -> None:
        assert _moves(LeagueTier.MEDIUM_ROAST, [50, 40, 30, 20, 10]) == [
            (1, "up", 100),
            (2, "stayed", 60),
            (3, "stayed", 40),
            (4, "stayed", 0),
            (5, "down", 0),
        ]

    def test_thirty_move_six_up_and_six_down(self) -> None:
        results = close_group(LeagueTier.MEDIUM_ROAST, _standings(list(range(300, 0, -10))))
        after = [r.tier_after for r in sorted(results, key=lambda r: r.final_rank or 0)]
        assert after[:6] == [LeagueTier.DARK_ROAST] * 6
        assert after[6:24] == [LeagueTier.MEDIUM_ROAST] * 18
        assert after[24:] == [LeagueTier.LIGHT_ROAST] * 6
        assert sum(r.reward_amole for r in results) == 200

    def test_the_end_tiers_hold(self) -> None:
        assert [m for _, m, _ in _moves(HIGHEST_TIER, [30, 20, 10, 5, 1])] == [
            "stayed",
            "stayed",
            "stayed",
            "stayed",
            "down",
        ]
        assert [m for _, m, _ in _moves(LOWEST_TIER, [30, 20, 10, 5, 1])] == [
            "up",
            "stayed",
            "stayed",
            "stayed",
            "stayed",
        ]

    def test_a_tie_goes_to_whoever_reached_it_first(self) -> None:
        assert _moves(LeagueTier.LIGHT_ROAST, [20, 20]) == [(1, "up", 100), (2, "stayed", 60)]

    def test_hidden_members_keep_their_xp_but_get_no_place_move_or_reward(self) -> None:
        results = close_group(
            LeagueTier.LIGHT_ROAST, _standings([50, 10]), hidden=frozenset({"m0"})
        )
        by_user = {r.user_id: r for r in results}
        assert by_user["m0"] == MemberResult("m0", 50, None, LeagueTier.LIGHT_ROAST, 0)
        assert by_user["m1"] == MemberResult("m1", 10, 1, LeagueTier.MEDIUM_ROAST, 100)

    def test_movement(self) -> None:
        assert movement(LeagueTier.GREEN_BEAN, LeagueTier.LIGHT_ROAST) is Movement.UP
        assert movement(LeagueTier.LIGHT_ROAST, LeagueTier.GREEN_BEAN) is Movement.DOWN
        assert movement(LeagueTier.LIGHT_ROAST, LeagueTier.LIGHT_ROAST) is Movement.STAYED
