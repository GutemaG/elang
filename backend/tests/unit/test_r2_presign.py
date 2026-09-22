"""Unit tests: the SigV4 presigner and `R2Storage` (bolt 036-admin-audio-api)."""

from __future__ import annotations

from datetime import UTC, datetime
from urllib.parse import parse_qs, urlsplit

import pytest

from app.config import Settings
from app.infrastructure.external.r2_storage import R2Storage, presign

SECRET = "super-secret-value-0123456789"


def test_matches_aws_published_presigned_url_example() -> None:
    """AWS S3 docs, "Authenticating Requests: Using Query Parameters"
    (SigV4): GET examplebucket/test.txt on 2013-05-24, valid 86400 s."""
    url = presign(
        method="GET",
        host="examplebucket.s3.amazonaws.com",
        path="/test.txt",
        headers={},
        access_key_id="AKIAIOSFODNN7EXAMPLE",
        secret_access_key="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
        region="us-east-1",
        now=datetime(2013, 5, 24, tzinfo=UTC),
        expires_in=86400,
    )
    assert url == (
        "https://examplebucket.s3.amazonaws.com/test.txt"
        "?X-Amz-Algorithm=AWS4-HMAC-SHA256"
        "&X-Amz-Credential=AKIAIOSFODNN7EXAMPLE%2F20130524%2Fus-east-1%2Fs3%2Faws4_request"
        "&X-Amz-Date=20130524T000000Z&X-Amz-Expires=86400&X-Amz-SignedHeaders=host"
        "&X-Amz-Signature=aeeed9bbccd4d02ee5c0109b86d86835f995330da4c265957d157751f604d404"
    )


def _storage(**overrides: str) -> R2Storage:
    return R2Storage(
        account_id="acct123",
        bucket="ethio-lang",
        access_key_id="AKIDTEST",
        secret_access_key=SECRET,
        public_base_url="https://pub-abc.r2.dev",
        **overrides,
    )


class TestPresignPut:
    def _upload(self):  # noqa: ANN202
        return _storage().presign_put(
            "am/lesson-1/abc.m4a",
            content_type="audio/mp4",
            size=40960,
            expires_in=600,
            now=datetime(2026, 9, 22, 12, 0, tzinfo=UTC),
        )

    def test_points_at_the_bucket_path_on_the_account_endpoint(self) -> None:
        parts = urlsplit(self._upload().url)
        assert parts.scheme == "https"
        assert parts.netloc == "acct123.r2.cloudflarestorage.com"
        assert parts.path == "/ethio-lang/am/lesson-1/abc.m4a"

    def test_binds_content_type_and_length_and_expires(self) -> None:
        query = parse_qs(urlsplit(self._upload().url).query)
        assert query["X-Amz-SignedHeaders"] == ["content-length;content-type;host"]
        assert query["X-Amz-Expires"] == ["600"]
        assert query["X-Amz-Credential"] == ["AKIDTEST/20260922/auto/s3/aws4_request"]
        assert len(query["X-Amz-Signature"][0]) == 64

    def test_a_different_size_or_type_gives_a_different_signature(self) -> None:
        at = datetime(2026, 9, 22, 12, 0, tzinfo=UTC)
        base = _storage().presign_put(
            "k.m4a", content_type="audio/mp4", size=10, expires_in=600, now=at
        )
        bigger = _storage().presign_put(
            "k.m4a", content_type="audio/mp4", size=11, expires_in=600, now=at
        )
        other_type = _storage().presign_put(
            "k.m4a", content_type="audio/mpeg", size=10, expires_in=600, now=at
        )
        assert len({base.url, bigger.url, other_type.url}) == 3

    def test_returns_public_url_and_headers_but_never_the_secret(self) -> None:
        upload = self._upload()
        assert upload.public_url == "https://pub-abc.r2.dev/am/lesson-1/abc.m4a"
        assert upload.headers == {"Content-Type": "audio/mp4"}
        assert SECRET not in upload.url
        assert SECRET not in repr(upload)


class TestFromSettings:
    FULL = {
        "r2_account_id": "acct",
        "r2_bucket": "b",
        "r2_access_key_id": "k",
        "r2_secret_access_key": "s",
        "audio_base_url": "https://pub.r2.dev/",
    }

    def test_all_settings_present(self) -> None:
        storage = R2Storage.from_settings(Settings(**self.FULL))
        assert storage is not None
        assert storage.public_base_url == "https://pub.r2.dev"

    @pytest.mark.parametrize("missing", sorted(FULL))
    def test_any_missing_setting_means_not_configured(self, missing: str) -> None:
        assert R2Storage.from_settings(Settings(**{**self.FULL, missing: " "})) is None
