"""Domain services for the lesson-content service.

Pure domain orchestration -- no FastAPI, SQLAlchemy, or storage imports.
"""

from __future__ import annotations

from dataclasses import dataclass, replace
from datetime import date, datetime, timedelta

from app.domain.lesson.entities import Skill, UserBeans, UserSkillProgress, UserStreak
from app.domain.lesson.exceptions import (
    BeansExhaustedError,
    InvalidCompletionError,
    InvalidCompletionTimestampError,
    SkillLockedError,
)
from app.domain.lesson.value_objects import (
    AMOLE_LESSON_COMPLETION_AWARD,
    AMOLE_PERFECT_LESSON_BONUS,
    AMOLE_STREAK_MILESTONE_7_BONUS,
    AMOLE_STREAK_MILESTONE_30_BONUS,
    BEAN_REGEN_MINUTES,
    BEANS_MAX,
    FREEZE_GRANTED_AT_CROWN_LEVEL,
    MAX_CROWN_LEVEL,
    STREAK_MILESTONE_7_DAYS,
    STREAK_MILESTONE_30_DAYS,
    XP_PER_CORRECT_ANSWER,
    AmoleAward,
    AmoleSource,
    LessonCompletionOutcome,
    SkillState,
)


class CompletionTimestampValidator:
    """Pure domain logic -- no external dependencies (bolt 008).

    Bounds a client-supplied offline-completion timestamp against reality
    before it's trusted for streak/XP-day attribution: it must not be from
    the future beyond a small clock-skew allowance, and must not predate
    the account's own creation. Deliberately has no upper bound on how far
    in the past a valid timestamp may be -- supporting long offline gaps
    without penalizing them is the point (`003-offline-caching-and-sync`
    requirements.md, FR-3), so only genuinely impossible timestamps are
    rejected.
    """

    MAX_FUTURE_SKEW = timedelta(minutes=5)

    def validate(
        self, client_completed_at: datetime, account_created_at: datetime, now: datetime
    ) -> None:
        if client_completed_at > now + self.MAX_FUTURE_SKEW:
            raise InvalidCompletionTimestampError(
                f"client_completed_at={client_completed_at.isoformat()} is more than "
                f"{self.MAX_FUTURE_SKEW} ahead of server time"
            )
        if client_completed_at < account_created_at:
            raise InvalidCompletionTimestampError(
                f"client_completed_at={client_completed_at.isoformat()} predates the "
                f"account's creation at {account_created_at.isoformat()}"
            )


@dataclass(frozen=True)
class SkillTreeEntry:
    """A `Skill` paired with its computed per-user state and crown level."""

    skill: Skill
    state: SkillState
    crown_level: int


class SkillTreeProgressionPolicy:
    """Pure domain logic -- no external dependencies.

    Single source of truth for "what does a skill look like to this user
    right now," used identically by both the skill-tree read and the
    lesson-access check, so the two can never disagree about a skill's
    state.
    """

    def compute_states(
        self, skills: list[Skill], progress_rows: list[UserSkillProgress]
    ) -> list[SkillTreeEntry]:
        progress_by_skill = {p.skill_id: p for p in progress_rows}
        ordered = sorted(skills, key=lambda s: s.order_index)

        entries: list[SkillTreeEntry] = []
        for index, skill in enumerate(ordered):
            progress = progress_by_skill.get(skill.id)
            if progress is not None:
                if progress.completed_at is not None:
                    state = SkillState.COMPLETED
                    crown_level = progress.crown_level
                else:
                    state = SkillState.ACTIVE
                    crown_level = 0
            else:
                # New-user bootstrap: no row at all is the default,
                # expected state -- the first skill by order_index is
                # active, every other skill is locked. Computed on the fly,
                # never requires a pre-seeded row (story 001's edge case).
                state = SkillState.ACTIVE if index == 0 else SkillState.LOCKED
                crown_level = 0

            entries.append(SkillTreeEntry(skill=skill, state=state, crown_level=crown_level))

        return entries

    def state_for_skill(
        self, skill_id: str, skills: list[Skill], progress_rows: list[UserSkillProgress]
    ) -> SkillState:
        """Convenience lookup used by `LessonAccessPolicy`'s caller --
        computes the full tree (so ordering/bootstrap logic never diverges)
        and returns just the one skill's state.
        """
        for entry in self.compute_states(skills, progress_rows):
            if entry.skill.id == skill_id:
                return entry.state
        raise ValueError(f"Skill not found in provided skills list: {skill_id}")


class LessonAccessPolicy:
    """Pure domain logic -- no external dependencies.

    Enforces story 001's "a locked skill's lesson must be unreachable even
    by direct lesson ID" rule at the domain layer, so the guarantee doesn't
    depend on the API layer remembering to check it.
    """

    def ensure_accessible(self, skill_state: SkillState) -> None:
        if skill_state == SkillState.LOCKED:
            raise SkillLockedError("This skill is locked for the current user")


class BeanLedger:
    """Pure domain logic -- no external dependencies.

    Beans regenerate lazily (never a scheduled job): every read/write first
    "catches up" `current_count` from however much time has passed since
    `last_regen_at`, advancing `last_regen_at` only by whole regen
    intervals consumed so partial progress toward the next bean survives
    between calls.
    """

    def regenerate(self, beans: UserBeans, now: datetime) -> UserBeans:
        if beans.current_count >= BEANS_MAX:
            return beans
        elapsed = now - beans.last_regen_at
        if elapsed.total_seconds() <= 0:
            return beans
        interval = timedelta(minutes=BEAN_REGEN_MINUTES)
        intervals_passed = int(elapsed // interval)
        if intervals_passed <= 0:
            return beans
        new_count = min(BEANS_MAX, beans.current_count + intervals_passed)
        # Only advance last_regen_at by the whole intervals actually
        # consumed (capped at what was needed to reach BEANS_MAX), so any
        # leftover partial progress toward the *next* bean isn't lost.
        intervals_consumed = min(intervals_passed, BEANS_MAX - beans.current_count)
        new_last_regen_at = beans.last_regen_at + interval * intervals_consumed
        return replace(beans, current_count=new_count, last_regen_at=new_last_regen_at)

    def next_bean_at(self, beans: UserBeans) -> datetime | None:
        if beans.current_count >= BEANS_MAX:
            return None
        return beans.last_regen_at + timedelta(minutes=BEAN_REGEN_MINUTES)

    def consume(self, beans: UserBeans, wrong_count: int, now: datetime) -> UserBeans:
        """Regenerates first, then subtracts `wrong_count`.

        Raises `BeansExhaustedError` if `wrong_count` exceeds the
        regenerated balance -- the attempt implies more mistakes than the
        account could have afforded (ADR-5, Decision 1).
        """
        regenerated = self.regenerate(beans, now)
        if wrong_count > regenerated.current_count:
            raise BeansExhaustedError(
                f"Attempt implies {wrong_count} wrong answers but only "
                f"{regenerated.current_count} beans were available"
            )
        return replace(regenerated, current_count=regenerated.current_count - wrong_count)

    def refill(self, beans: UserBeans, now: datetime) -> UserBeans:
        return replace(beans, current_count=BEANS_MAX, last_regen_at=now)


class AmoleAwardPolicy:
    """Pure domain logic -- no repository/DB dependency (bolt
    `017-amole-service`, ADR-8). Decides which Amole awards a completion
    qualifies for; the application layer turns each result into an
    `AmoleTransaction` keyed to the completion's own `attempt_id` and posts
    it -- idempotency lives entirely in that posting step's uniqueness
    constraint, not here.

    Streak milestones are decided by *transition*, not by "has this ever
    happened before": a milestone qualifies exactly when this completion's
    streak update carries the streak from below the threshold to at or
    above it. This needs no repository read (the caller already has both
    values from its own streak-update step) and means one completion can
    only cross a given threshold once, by construction -- no separate
    "already awarded" tracking is needed.
    """

    def awards_for_completion(
        self, *, correct_count: int, total_count: int, previous_streak: int, new_streak: int
    ) -> list[AmoleAward]:
        awards = [
            AmoleAward(amount=AMOLE_LESSON_COMPLETION_AWARD, source=AmoleSource.LESSON_COMPLETION)
        ]
        if correct_count == total_count:
            awards.append(
                AmoleAward(amount=AMOLE_PERFECT_LESSON_BONUS, source=AmoleSource.PERFECT_LESSON)
            )
        if previous_streak < STREAK_MILESTONE_7_DAYS <= new_streak:
            awards.append(
                AmoleAward(
                    amount=AMOLE_STREAK_MILESTONE_7_BONUS, source=AmoleSource.STREAK_MILESTONE_7
                )
            )
        if previous_streak < STREAK_MILESTONE_30_DAYS <= new_streak:
            awards.append(
                AmoleAward(
                    amount=AMOLE_STREAK_MILESTONE_30_BONUS, source=AmoleSource.STREAK_MILESTONE_30
                )
            )
        return awards


@dataclass(frozen=True)
class StreakEvaluation:
    """Pure output of `StreakPolicy.evaluate` -- the caller writes its
    fields onto `UserStreak`, never persisted as its own record.
    """

    new_streak_count: int
    freeze_consumed: bool
    increased_today: bool


class StreakPolicy:
    """Pure domain logic -- no external dependencies. Calendar day = UTC
    (Technical Design Decision 5) -- no per-user timezone tracking.
    """

    def evaluate(self, streak: UserStreak, completion_date: date) -> StreakEvaluation:
        if streak.last_completed_date is None:
            return StreakEvaluation(new_streak_count=1, freeze_consumed=False, increased_today=True)

        gap = (completion_date - streak.last_completed_date).days
        if gap <= 0:
            # Same day (or a clock/replay oddity) -- already counted today.
            return StreakEvaluation(
                new_streak_count=streak.current_streak, freeze_consumed=False, increased_today=False
            )
        if gap == 1:
            return StreakEvaluation(
                new_streak_count=streak.current_streak + 1,
                freeze_consumed=False,
                increased_today=True,
            )
        if gap == 2 and streak.active_freeze_count > 0:
            # Exactly one full calendar day missed, and a freeze covers it --
            # the streak continues uninterrupted rather than resetting.
            return StreakEvaluation(
                new_streak_count=streak.current_streak + 1,
                freeze_consumed=True,
                increased_today=True,
            )
        # Gap too large (or no freeze available) -- start over at day 1.
        return StreakEvaluation(new_streak_count=1, freeze_consumed=False, increased_today=True)


@dataclass(frozen=True)
class LessonCompletionResult:
    """Everything the application layer needs to persist after one
    `LessonCompletionService.complete` call -- the mutated aggregates plus
    the response-shaped outcome. Never persisted as its own record.
    """

    progress: UserSkillProgress
    unlocked_progress: UserSkillProgress | None
    streak: UserStreak
    outcome: LessonCompletionOutcome


class LessonCompletionService:
    """Pure domain logic -- no repository/DB calls. The application layer
    feeds it fully-loaded aggregates and persists whatever it returns.
    """

    def complete(
        self,
        *,
        lesson_id: str,
        skill_lesson_ids: frozenset[str],
        all_skills: list[Skill],
        progress: UserSkillProgress,
        streak: UserStreak,
        correct_count: int,
        total_count: int,
        time_spent_seconds: float,
        daily_xp_total_before: int,
        daily_xp_target: int,
        now: datetime,
        completion_date: date,
    ) -> LessonCompletionResult:
        """`lesson_id` is the lesson just completed; `skill_lesson_ids` is
        every lesson id belonging to `progress.skill_id` (the full set that
        must be covered for one pass through the skill to count).
        """
        if total_count <= 0 or correct_count < 0 or correct_count > total_count:
            raise InvalidCompletionError(
                f"Invalid completion counts: correct_count={correct_count}, "
                f"total_count={total_count}"
            )

        xp_awarded = correct_count * XP_PER_CORRECT_ANSWER
        was_completed_before = progress.completed_at is not None
        crown_before = progress.crown_level

        completed_ids = progress.completed_lesson_ids_this_cycle | {lesson_id}
        cycle_complete = skill_lesson_ids <= completed_ids

        unlocked_progress: UserSkillProgress | None = None
        skill_unlocked_title: str | None = None
        streak_freeze_unlocked = False

        if cycle_complete:
            new_crown_level = min(MAX_CROWN_LEVEL, crown_before + 1) if was_completed_before else 1
            new_progress = replace(
                progress,
                crown_level=new_crown_level,
                completed_at=progress.completed_at or now,
                completed_lesson_ids_this_cycle=frozenset(),
            )
            if new_crown_level == FREEZE_GRANTED_AT_CROWN_LEVEL and crown_before != new_crown_level:
                streak = replace(streak, active_freeze_count=streak.active_freeze_count + 1)
                streak_freeze_unlocked = True
            if not was_completed_before:
                ordered = sorted(all_skills, key=lambda s: s.order_index)
                current_index = next(i for i, s in enumerate(ordered) if s.id == progress.skill_id)
                if current_index + 1 < len(ordered):
                    next_skill = ordered[current_index + 1]
                    skill_unlocked_title = next_skill.title
                    unlocked_progress = UserSkillProgress(
                        user_id=progress.user_id,
                        skill_id=next_skill.id,
                        unlocked=True,
                        crown_level=0,
                        completed_at=None,
                    )
        else:
            new_progress = replace(progress, completed_lesson_ids_this_cycle=completed_ids)
            new_crown_level = crown_before if crown_before > 0 else None

        streak_eval = StreakPolicy().evaluate(streak, completion_date)
        new_streak = replace(
            streak,
            current_streak=streak_eval.new_streak_count,
            active_freeze_count=(
                streak.active_freeze_count - 1
                if streak_eval.freeze_consumed
                else streak.active_freeze_count
            ),
            last_completed_date=completion_date,
        )

        accuracy_percent = round((correct_count / total_count) * 100)
        outcome = LessonCompletionOutcome(
            xp_awarded=xp_awarded,
            daily_xp_total=daily_xp_total_before + xp_awarded,
            daily_xp_target=daily_xp_target,
            streak_count=new_streak.current_streak,
            streak_increased_today=streak_eval.increased_today,
            accuracy_percent=accuracy_percent,
            correct_count=correct_count,
            total_count=total_count,
            time_spent_seconds=time_spent_seconds,
            skill_unlocked_title=skill_unlocked_title,
            crown_level=new_crown_level if cycle_complete else (crown_before or None),
            crown_leveled_up=cycle_complete and was_completed_before,
            streak_freeze_unlocked=streak_freeze_unlocked,
        )

        return LessonCompletionResult(
            progress=new_progress,
            unlocked_progress=unlocked_progress,
            streak=new_streak,
            outcome=outcome,
        )
