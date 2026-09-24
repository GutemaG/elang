"""Unit tests: the local audio store's links, keys, writes and selection
(story 007-local-audio-storage, bolt 041-local-audio-storage)."""

from __future__ import annotations

from dataclasses import replace
from datetime import UTC, datetime, timedelta
from pathlib import Path
from urllib.parse import parse_qs, urlsplit

import pytest

from app.config import Settings
from app.domain.lesson.exceptions import (
    AudioFileExistsError,
    InvalidUploadLinkError,
    UploadLinkExpiredError,
)
from app.infrastructure.external import local_audio_storage
from app.infrastructure.external.local_audio_storage import (
    LocalAudioStorage,
    choose_audio_storage,
    is_valid_key,
)
from app.infrastructure.external.r2_storage import R2Storage

KEY = "am/lesson-1/a41f0c2b7d19.m4a"
NOW = datetime(2026, 9, 24, 12, 0, tzinfo=UTC)
R2_SETTINGS = {
    "audio_base_url": "https://pub-abc.r2.dev",
    "r2_account_id": "acct",
    "r2_bucket": "bucket",
    "r2_access_key_id": "AKID",
    "r2_secret_access_key": "secret",
}


@pytest.fixture
def store(tmp_path: Path) -> LocalAudioStorage:
    return LocalAudioStorage(
        root=tmp_path / "audio", upload_base_url="http://localhost:8000", secret=b"s" * 32
    )


def _link(store: LocalAudioStorage, key: str = KEY, size: int = 10) -> dict[str, str]:
    """The query of a fresh link, as the receiving route would read it."""
    upload = store.presign_put(key, content_type="audio/mp4", size=size, expires_in=600, now=NOW)
    return {k: v[0] for k, v in parse_qs(urlsplit(upload.url).query).items()}


def _verify(
    store: LocalAudioStorage, q: dict[str, str], *, key: str = KEY, now: datetime = NOW
) -> None:
    store.verify(
        key,
        content_type=q["type"],
        size=int(q["size"]),
        expires=int(q["expires"]),
        signature=q["sig"],
        now=now,
    )


class TestLinks:
    def test_has_the_same_shape_as_an_r2_link(self, store: LocalAudioStorage) -> None:
        upload = store.presign_put(KEY, content_type="audio/mp4", size=10, expires_in=600, now=NOW)

        url = urlsplit(upload.url)
        assert f"{url.scheme}://{url.netloc}" == "http://localhost:8000"
        assert url.path == f"/api/v1/audio-files/{KEY}"
        assert upload.headers == {"Content-Type": "audio/mp4"}
        assert upload.public_url == f"/media/audio/{KEY}"
        assert upload.expires_in == 600

    def test_carries_type_size_expiry_and_signature(self, store: LocalAudioStorage) -> None:
        q = _link(store)

        assert q["type"] == "audio/mp4"
        assert q["size"] == "10"
        assert int(q["expires"]) == int(NOW.timestamp()) + 600
        assert len(q["sig"]) == 64

    def test_never_carries_the_secret(self, store: LocalAudioStorage) -> None:
        upload = store.presign_put(KEY, content_type="audio/mp4", size=10, expires_in=600)
        assert "ssss" not in upload.url

    def test_a_fresh_link_verifies(self, store: LocalAudioStorage) -> None:
        _verify(store, _link(store))

    def test_still_valid_at_its_last_second(self, store: LocalAudioStorage) -> None:
        _verify(store, _link(store), now=NOW + timedelta(seconds=600))

    def test_expires_after_its_ten_minutes(self, store: LocalAudioStorage) -> None:
        with pytest.raises(UploadLinkExpiredError):
            _verify(store, _link(store), now=NOW + timedelta(seconds=601))

    @pytest.mark.parametrize(
        ("part", "value"),
        [
            ("type", "audio/mpeg"),
            ("size", "11"),
            ("sig", "0" * 64),
        ],
    )
    def test_any_altered_part_is_refused(
        self, store: LocalAudioStorage, part: str, value: str
    ) -> None:
        q = _link(store)
        q[part] = value

        with pytest.raises(InvalidUploadLinkError) as caught:
            _verify(store, q)
        assert type(caught.value) is InvalidUploadLinkError

    def test_a_pushed_back_expiry_reads_as_a_bad_link_not_a_live_one(
        self, store: LocalAudioStorage
    ) -> None:
        q = _link(store)
        q["expires"] = str(int(q["expires"]) + 3600)

        with pytest.raises(InvalidUploadLinkError) as caught:
            _verify(store, q, now=NOW + timedelta(seconds=900))
        assert type(caught.value) is InvalidUploadLinkError

    def test_a_link_for_one_key_does_not_open_another(self, store: LocalAudioStorage) -> None:
        with pytest.raises(InvalidUploadLinkError):
            _verify(store, _link(store), key="am/lesson-1/b41f0c2b7d19.m4a")

    def test_a_link_from_another_process_is_refused(self, store: LocalAudioStorage) -> None:
        other = replace(store, secret=b"t" * 32)
        with pytest.raises(InvalidUploadLinkError):
            _verify(other, _link(store))


class TestKeys:
    @pytest.mark.parametrize(
        "key",
        [
            KEY,
            "om/1c9e0f7a-2b3c-4d5e-8f90-a1b2c3d4e5f6/0123456789ab.mp3",
            "ti/l_2/abcdefabcdef.webm",
            "amh/x/000000000000.ogg",
        ],
    )
    def test_the_keys_uploads_are_given_are_valid(self, key: str) -> None:
        assert is_valid_key(key)

    @pytest.mark.parametrize(
        "key",
        [
            "../evil.m4a",
            "am/../../evil/a41f0c2b7d19.m4a",
            "am/lesson-1/../a41f0c2b7d19.m4a",
            "/etc/a41f0c2b7d19.m4a",
            "am\\lesson-1\\a41f0c2b7d19.m4a",
            "am/lesson-1/sub/a41f0c2b7d19.m4a",
            "am/lesson-1/a41f0c2b7d1.m4a",
            "am/lesson-1/A41F0C2B7D19.m4a",
            "am/lesson-1/a41f0c2b7d19.exe",
            "am/lesson-1/a41f0c2b7d19.m4a/",
            "AM/lesson-1/a41f0c2b7d19.m4a",
            "am/lesson 1/a41f0c2b7d19.m4a",
            "",
        ],
    )
    def test_anything_else_is_not(self, key: str) -> None:
        assert not is_valid_key(key)

    def test_a_bad_key_has_no_path(self, store: LocalAudioStorage) -> None:
        with pytest.raises(InvalidUploadLinkError):
            store.path_for("../evil.m4a")


class TestSaving:
    def test_writes_the_bytes_under_the_key(self, store: LocalAudioStorage) -> None:
        store.save(KEY, b"clip")
        assert (store.root / KEY).read_bytes() == b"clip"

    def test_never_replaces_a_saved_file(self, store: LocalAudioStorage) -> None:
        store.save(KEY, b"first")

        with pytest.raises(AudioFileExistsError):
            store.save(KEY, b"second")
        assert (store.root / KEY).read_bytes() == b"first"

    def test_leaves_no_temporary_file_behind(self, store: LocalAudioStorage) -> None:
        store.save(KEY, b"clip")
        with pytest.raises(AudioFileExistsError):
            store.save(KEY, b"again")

        assert [p.name for p in (store.root / "am" / "lesson-1").iterdir()] == ["a41f0c2b7d19.m4a"]

    def test_losing_a_race_for_the_name_keeps_the_winner_and_cleans_up(
        self, store: LocalAudioStorage, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        # Another upload takes the name between the check and the link.
        def taken(src: Path, dst: Path) -> None:
            Path(dst).write_bytes(b"winner")
            raise FileExistsError(dst)

        monkeypatch.setattr(local_audio_storage.os, "link", taken)

        with pytest.raises(AudioFileExistsError):
            store.save(KEY, b"loser")
        assert (store.root / KEY).read_bytes() == b"winner"
        assert [p.name for p in (store.root / "am" / "lesson-1").iterdir()] == ["a41f0c2b7d19.m4a"]

    def test_refuses_a_bad_key_before_touching_the_disk(self, store: LocalAudioStorage) -> None:
        with pytest.raises(InvalidUploadLinkError):
            store.save("../evil.m4a", b"x")
        assert not store.root.exists()


class TestChoosing:
    def test_local_development_without_r2_uses_this_backend(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        monkeypatch.setattr(local_audio_storage, "AUDIO_DIR", tmp_path / "audio")

        chosen = choose_audio_storage(
            Settings(_env_file=None, environment="local"), upload_base_url="http://host:8000/"
        )

        assert isinstance(chosen, LocalAudioStorage)
        assert chosen.root == tmp_path / "audio"
        assert chosen.upload_base_url == "http://host:8000"

    def test_the_same_process_signs_every_link_alike(self) -> None:
        settings = Settings(_env_file=None, environment="local")
        a = choose_audio_storage(settings, upload_base_url="http://a/")
        b = choose_audio_storage(settings, upload_base_url="http://a/")

        assert isinstance(a, LocalAudioStorage) and isinstance(b, LocalAudioStorage)
        assert a.secret == b.secret

    @pytest.mark.parametrize("environment", ["production", "staging", "preview"])
    def test_a_deployed_server_without_r2_has_no_store(self, environment: str) -> None:
        settings = Settings(_env_file=None, environment=environment)
        assert choose_audio_storage(settings, upload_base_url="http://x/") is None

    @pytest.mark.parametrize("environment", ["local", "production"])
    def test_r2_wins_whenever_it_is_configured(self, environment: str) -> None:
        settings = Settings(_env_file=None, environment=environment, **R2_SETTINGS)
        assert isinstance(choose_audio_storage(settings, upload_base_url="http://x/"), R2Storage)

    def test_half_configured_r2_falls_back_to_local(self) -> None:
        settings = Settings(
            _env_file=None, environment="local", **{**R2_SETTINGS, "audio_base_url": ""}
        )
        chosen = choose_audio_storage(settings, upload_base_url="http://x/")
        assert isinstance(chosen, LocalAudioStorage)
