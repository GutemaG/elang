"""Unit tests: the picture question types (019-image-choice-exercise-types,
bolt 050-image-choice-service) -- their content objects, `validate_exercise`
refusing each way of breaking one with the offending field named, and the
local store keeping pictures and audio apart.
"""

from __future__ import annotations

import copy
from datetime import UTC, datetime
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlsplit

import pytest

from app.config import Settings
from app.domain.lesson.exceptions import InvalidExerciseError, InvalidUploadLinkError
from app.domain.lesson.exercise_parts import (
    MAX_ALT_TEXT_LENGTH,
    content_from_json,
    validate_exercise,
)
from app.domain.lesson.value_objects import (
    AudioImageChoiceContent,
    ExerciseType,
    ImageChoiceContent,
    PictureChoice,
)
from app.infrastructure.external import local_audio_storage
from app.infrastructure.external.local_audio_storage import (
    AUDIO,
    IMAGES,
    LocalAudioStorage,
    choose_image_storage,
    is_valid_key,
)

NOW = datetime(2026, 9, 25, 12, 0, tzinfo=UTC)
AUDIO_URL = "https://cdn.example/am/buna.m4a"


def _picture(i: int, **overrides: Any) -> dict[str, Any]:
    return {
        "id": f"p{i}",
        "image_url": f"https://cdn.example/am/{i}.webp",
        "alt_text": f"Picture {i}",
        **overrides,
    }


def _content(exercise_type: str, pictures: list[dict[str, Any]]) -> dict[str, Any]:
    if exercise_type == "audio_image_choice":
        return {"audio_url": AUDIO_URL, "choices": pictures}
    return {"choices": pictures}


TYPES = ["image_choice", "audio_image_choice"]


def _refused(
    exercise_type: str,
    content: Any,
    answer_key: Any | None = None,
    *,
    local: bool = False,
) -> str:
    with pytest.raises(InvalidExerciseError) as caught:
        validate_exercise(
            exercise_type,
            "ቡና",
            content,
            answer_key if answer_key is not None else {"correct_choice_id": "p0"},
            allow_local_media=local,
        )
    return caught.value.field


class TestContentObjects:
    @pytest.mark.parametrize("count", [2, 3, 4])
    def test_two_to_four_pictures_are_allowed(self, count: int) -> None:
        pictures = tuple(PictureChoice(f"p{i}", f"https://x/{i}.webp", "A") for i in range(count))
        assert len(ImageChoiceContent(pictures).choices) == count
        assert len(AudioImageChoiceContent(AUDIO_URL, pictures).choices) == count

    @pytest.mark.parametrize("count", [0, 1, 5])
    def test_other_counts_are_refused(self, count: int) -> None:
        pictures = tuple(PictureChoice(f"p{i}", f"https://x/{i}.webp", "A") for i in range(count))
        with pytest.raises(ValueError, match="2 to 4"):
            ImageChoiceContent(pictures)
        with pytest.raises(ValueError, match="2 to 4"):
            AudioImageChoiceContent(AUDIO_URL, pictures)

    @pytest.mark.parametrize(
        ("field", "value"), [("id", ""), ("image_url", ""), ("alt_text", ""), ("alt_text", "  ")]
    )
    def test_a_picture_needs_every_field(self, field: str, value: str) -> None:
        fields = {"id": "p", "image_url": "https://x/p.webp", "alt_text": "A", field: value}
        with pytest.raises(ValueError, match=field):
            PictureChoice(**fields)

    def test_the_audio_question_needs_a_clip(self) -> None:
        pictures = tuple(PictureChoice(f"p{i}", f"https://x/{i}.webp", "A") for i in range(2))
        with pytest.raises(ValueError, match="audio_url"):
            AudioImageChoiceContent("", pictures)

    def test_json_is_read_into_pictures_not_text_tiles(self) -> None:
        content = content_from_json(
            ExerciseType.AUDIO_IMAGE_CHOICE,
            _content("audio_image_choice", [_picture(0), _picture(1)]),
        )
        assert isinstance(content, AudioImageChoiceContent)
        assert content.audio_url == AUDIO_URL
        assert content.choices[1] == PictureChoice(
            id="p1", image_url="https://cdn.example/am/1.webp", alt_text="Picture 1"
        )


@pytest.mark.parametrize("exercise_type", TYPES)
class TestValidation:
    @pytest.mark.parametrize("count", [2, 3, 4])
    def test_two_to_four_pictures_save(self, exercise_type: str, count: int) -> None:
        pictures = [_picture(i) for i in range(count)]
        key = {"correct_choice_id": f"p{count - 1}"}
        parsed = validate_exercise(exercise_type, "ቡና", _content(exercise_type, pictures), key)
        assert parsed.value == exercise_type

    @pytest.mark.parametrize("count", [0, 1, 5])
    def test_other_counts_name_the_choices(self, exercise_type: str, count: int) -> None:
        pictures = [_picture(i) for i in range(count)]
        assert _refused(exercise_type, _content(exercise_type, pictures)) == "content.choices"

    def test_choices_that_are_not_a_list(self, exercise_type: str) -> None:
        content = _content(exercise_type, [])
        content["choices"] = {"p0": _picture(0)}
        assert _refused(exercise_type, content) == "content.choices"

    def test_a_repeated_id(self, exercise_type: str) -> None:
        pictures = [_picture(0), _picture(1, id="p0")]
        assert _refused(exercise_type, _content(exercise_type, pictures)) == "content.choices[1].id"

    @pytest.mark.parametrize("field", ["id", "image_url", "alt_text"])
    @pytest.mark.parametrize("value", ["", "   ", 7, None])
    def test_an_empty_or_non_text_field(self, exercise_type: str, field: str, value: Any) -> None:
        pictures = [_picture(0), _picture(1, **{field: value})]
        assert (
            _refused(exercise_type, _content(exercise_type, pictures))
            == f"content.choices[1].{field}"
        )

    @pytest.mark.parametrize("field", ["id", "image_url", "alt_text"])
    def test_a_missing_field(self, exercise_type: str, field: str) -> None:
        broken = _picture(1)
        del broken[field]
        pictures = [_picture(0), broken]
        assert (
            _refused(exercise_type, _content(exercise_type, pictures))
            == f"content.choices[1].{field}"
        )

    def test_an_extra_field(self, exercise_type: str) -> None:
        pictures = [_picture(0), _picture(1, text="coffee")]
        assert (
            _refused(exercise_type, _content(exercise_type, pictures)) == "content.choices[1].text"
        )

    def test_a_text_tile_is_not_a_picture(self, exercise_type: str) -> None:
        pictures = [_picture(0), {"id": "p1", "text": "coffee"}]
        field = _refused(exercise_type, _content(exercise_type, pictures))
        assert field.startswith("content.choices[1].")

    def test_a_picture_that_is_not_an_object(self, exercise_type: str) -> None:
        pictures = [_picture(0), "https://cdn.example/1.webp"]
        assert _refused(exercise_type, _content(exercise_type, pictures)) == "content.choices[1]"

    def test_alt_text_at_the_limit_saves_and_one_over_is_refused(self, exercise_type: str) -> None:
        at_limit = [_picture(0), _picture(1, alt_text="a" * MAX_ALT_TEXT_LENGTH)]
        validate_exercise(
            exercise_type, "P", _content(exercise_type, at_limit), {"correct_choice_id": "p0"}
        )
        over = [_picture(0), _picture(1, alt_text="a" * (MAX_ALT_TEXT_LENGTH + 1))]
        assert (
            _refused(exercise_type, _content(exercise_type, over)) == "content.choices[1].alt_text"
        )

    @pytest.mark.parametrize(
        "url",
        [
            "http://cdn.example/a.webp",
            "https://",
            "cdn.example/a.webp",
            "/media/images/am/l/0123456789ab.webp",
            "/media/audio/am/l/0123456789ab.m4a",
            "ftp://cdn.example/a.webp",
        ],
    )
    def test_image_url_must_be_https(self, exercise_type: str, url: str) -> None:
        pictures = [_picture(0), _picture(1, image_url=url)]
        assert (
            _refused(exercise_type, _content(exercise_type, pictures))
            == "content.choices[1].image_url"
        )

    def test_a_local_picture_saves_only_where_local_media_is_allowed(
        self, exercise_type: str
    ) -> None:
        pictures = [_picture(0), _picture(1, image_url="/media/images/am/l/0123456789ab.webp")]
        content = _content(exercise_type, pictures)
        validate_exercise(
            exercise_type, "P", content, {"correct_choice_id": "p1"}, allow_local_media=True
        )
        assert _refused(exercise_type, content) == "content.choices[1].image_url"

    @pytest.mark.parametrize("url", ["/media/audio/am/l/0123456789ab.m4a", "/media/images/", "/x"])
    def test_other_local_paths_are_not_pictures(self, exercise_type: str, url: str) -> None:
        pictures = [_picture(0), _picture(1, image_url=url)]
        field = _refused(exercise_type, _content(exercise_type, pictures), local=True)
        assert field == "content.choices[1].image_url"

    def test_an_answer_naming_no_choice(self, exercise_type: str) -> None:
        content = _content(exercise_type, [_picture(0), _picture(1)])
        field = _refused(exercise_type, content, {"correct_choice_id": "p9"})
        assert field == "answer_key.correct_choice_id"

    def test_a_sequence_answer_is_refused(self, exercise_type: str) -> None:
        content = _content(exercise_type, [_picture(0), _picture(1)])
        field = _refused(exercise_type, content, {"correct_sequence": ["p0"]})
        assert field == "answer_key.correct_choice_id"

    def test_an_unknown_content_key(self, exercise_type: str) -> None:
        content = {**_content(exercise_type, [_picture(0), _picture(1)]), "prompt": "ቡና"}
        assert _refused(exercise_type, content) == "content.prompt"


class TestAudioImageChoiceClip:
    def test_a_missing_clip(self) -> None:
        field = _refused("audio_image_choice", {"choices": [_picture(0), _picture(1)]})
        assert field == "content.audio_url"

    @pytest.mark.parametrize(
        "url", ["", "http://cdn.example/a.m4a", "/media/audio/am/hello.m4a", 5]
    )
    def test_a_clip_that_is_not_https(self, url: Any) -> None:
        content = {"audio_url": url, "choices": [_picture(0), _picture(1)]}
        assert _refused("audio_image_choice", content) == "content.audio_url"

    def test_a_local_clip_saves_only_where_local_media_is_allowed(self) -> None:
        content = {"audio_url": "/media/audio/am/hello.m4a", "choices": [_picture(0), _picture(1)]}
        validate_exercise(
            "audio_image_choice",
            "Tap what you hear",
            content,
            {"correct_choice_id": "p0"},
            allow_local_media=True,
        )

    def test_image_choice_has_no_clip(self) -> None:
        content = {"audio_url": AUDIO_URL, "choices": [_picture(0), _picture(1)]}
        assert _refused("image_choice", content) == "content.audio_url"


class TestOtherTypesAreUnchanged:
    def test_a_picture_is_not_a_multiple_choice_tile(self) -> None:
        content = {"choices": [_picture(0), _picture(1)]}
        with pytest.raises(InvalidExerciseError) as caught:
            validate_exercise("multiple_choice", "P", content, {"correct_choice_id": "p0"})
        assert caught.value.field == "content.choices[0]"

    def test_the_input_is_not_changed(self) -> None:
        content = _content("image_choice", [_picture(0), _picture(1)])
        before = copy.deepcopy(content)
        validate_exercise("image_choice", "P", content, {"correct_choice_id": "p0"})
        assert content == before


class TestLocalStoreKinds:
    @pytest.fixture
    def stores(self, tmp_path: Path) -> tuple[LocalAudioStorage, LocalAudioStorage]:
        secret = b"s" * 32
        audio = LocalAudioStorage(tmp_path / "audio", "http://localhost:8000", secret)
        images = LocalAudioStorage(tmp_path / "images", "http://localhost:8000", secret, IMAGES)
        return audio, images

    def test_a_picture_link_points_at_the_picture_route_and_folder(
        self, stores: tuple[LocalAudioStorage, LocalAudioStorage]
    ) -> None:
        _, images = stores
        upload = images.presign_put(
            "am/l1/0123456789ab.webp", content_type="image/webp", size=9, expires_in=600, now=NOW
        )
        assert upload.url.startswith(
            "http://localhost:8000/api/v1/image-files/am/l1/0123456789ab.webp?"
        )
        assert upload.public_url == "/media/images/am/l1/0123456789ab.webp"
        assert images.path_for("am/l1/0123456789ab.webp").parent.parent.parent.name == "images"

    def test_a_link_signed_for_one_kind_never_verifies_for_the_other(
        self, stores: tuple[LocalAudioStorage, LocalAudioStorage]
    ) -> None:
        audio, images = stores
        key = "am/l1/0123456789ab.m4a"
        q = {
            k: v[0]
            for k, v in parse_qs(
                urlsplit(
                    audio.presign_put(
                        key, content_type="audio/mp4", size=9, expires_in=600, now=NOW
                    ).url
                ).query
            ).items()
        }
        args = {
            "content_type": q["type"],
            "size": int(q["size"]),
            "expires": int(q["expires"]),
            "signature": q["sig"],
            "now": NOW,
        }
        audio.verify(key, **args)
        with pytest.raises(InvalidUploadLinkError):
            images.verify(key, **args)

    @pytest.mark.parametrize(
        "key",
        ["am/l1/0123456789ab.webp", "om/lesson-1/abcdef012345.jpg", "ti/L_1/000000000000.webp"],
    )
    def test_picture_keys(self, key: str) -> None:
        assert is_valid_key(key, IMAGES)
        assert not is_valid_key(key, AUDIO)

    @pytest.mark.parametrize(
        "key",
        [
            "am/l1/0123456789ab.png",
            "am/l1/0123456789ab.m4a",
            "am/l1/0123456789ab.jpeg",
            "../l1/0123456789ab.webp",
            "am/l1/x/0123456789ab.webp",
            "am/l1/0123456789AB.webp",
            "/am/l1/0123456789ab.webp",
        ],
    )
    def test_not_picture_keys(self, key: str) -> None:
        assert not is_valid_key(key, IMAGES)

    def test_a_bad_picture_key_has_no_path(
        self, stores: tuple[LocalAudioStorage, LocalAudioStorage]
    ) -> None:
        _, images = stores
        with pytest.raises(InvalidUploadLinkError):
            images.path_for("am/l1/0123456789ab.m4a")

    def test_local_development_stores_pictures_in_the_images_folder(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        monkeypatch.setattr(local_audio_storage, "IMAGES_DIR", tmp_path / "images")
        chosen = choose_image_storage(
            Settings(_env_file=None, environment="local"), upload_base_url="http://x/"
        )
        assert isinstance(chosen, LocalAudioStorage)
        assert chosen.kind is IMAGES
        assert chosen.root == tmp_path / "images"

    def test_nowhere_to_store_pictures_outside_local_development(self) -> None:
        settings = Settings(_env_file=None, environment="production")
        assert choose_image_storage(settings, upload_base_url="http://x/") is None
