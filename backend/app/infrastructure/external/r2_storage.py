"""Presigned uploads to Cloudflare R2 (bolt `036-admin-audio-api`).

R2 speaks the S3 API, and a presigned PUT is a single AWS Signature
Version 4 over the request, carried in the query string. That is small
enough to write with the standard library instead of shipping boto3 and
botocore in the serverless deploy. `presign` is the generic SigV4 query
signer, checked against AWS's own published example; `R2Storage` applies it
to one bucket.

The access key secret is used only to derive the signature. It never
appears in a returned URL, a response or a log line.
"""

from __future__ import annotations

import hashlib
import hmac
from dataclasses import dataclass
from datetime import UTC, datetime
from urllib.parse import quote

from app.config import Settings

_ALGORITHM = "AWS4-HMAC-SHA256"
_UNSIGNED_PAYLOAD = "UNSIGNED-PAYLOAD"


def _encode(value: str, *, safe: str = "-_.~") -> str:
    return quote(value, safe=safe)


def _hmac(key: bytes, message: str) -> bytes:
    return hmac.new(key, message.encode("utf-8"), hashlib.sha256).digest()


def presign(
    *,
    method: str,
    host: str,
    path: str,
    headers: dict[str, str],
    access_key_id: str,
    secret_access_key: str,
    region: str,
    now: datetime,
    expires_in: int,
    service: str = "s3",
) -> str:
    """A SigV4 presigned URL. `headers` (besides `host`) become signed
    headers, so the eventual request must send exactly those values."""
    amz_date = now.astimezone(UTC).strftime("%Y%m%dT%H%M%SZ")
    date = amz_date[:8]
    scope = f"{date}/{region}/{service}/aws4_request"

    signed = {"host": host, **{k.lower(): v.strip() for k, v in headers.items()}}
    signed_names = ";".join(sorted(signed))
    canonical_headers = "".join(f"{k}:{signed[k]}\n" for k in sorted(signed))

    query = {
        "X-Amz-Algorithm": _ALGORITHM,
        "X-Amz-Credential": f"{access_key_id}/{scope}",
        "X-Amz-Date": amz_date,
        "X-Amz-Expires": str(expires_in),
        "X-Amz-SignedHeaders": signed_names,
    }
    canonical_query = "&".join(f"{_encode(k)}={_encode(query[k])}" for k in sorted(query))
    canonical_path = _encode(path, safe="-_.~/")

    canonical_request = "\n".join(
        [
            method,
            canonical_path,
            canonical_query,
            canonical_headers,
            signed_names,
            _UNSIGNED_PAYLOAD,
        ]
    )
    string_to_sign = "\n".join(
        [
            _ALGORITHM,
            amz_date,
            scope,
            hashlib.sha256(canonical_request.encode("utf-8")).hexdigest(),
        ]
    )
    key = _hmac(f"AWS4{secret_access_key}".encode(), date)
    for part in (region, service, "aws4_request"):
        key = _hmac(key, part)
    signature = hmac.new(key, string_to_sign.encode("utf-8"), hashlib.sha256).hexdigest()

    return f"https://{host}{canonical_path}?{canonical_query}&X-Amz-Signature={signature}"


@dataclass(frozen=True)
class PresignedUpload:
    url: str
    headers: dict[str, str]
    public_url: str
    expires_in: int


@dataclass(frozen=True)
class R2Storage:
    account_id: str
    bucket: str
    access_key_id: str
    secret_access_key: str
    public_base_url: str

    @classmethod
    def from_settings(cls, settings: Settings) -> R2Storage | None:
        """`None` unless every setting is present -- the upload endpoint then
        answers 503 rather than handing out a link that cannot work."""
        values = (
            settings.r2_account_id,
            settings.r2_bucket,
            settings.r2_access_key_id,
            settings.r2_secret_access_key,
            settings.audio_base_url,
        )
        if not all(v.strip() for v in values):
            return None
        return cls(
            account_id=settings.r2_account_id.strip(),
            bucket=settings.r2_bucket.strip(),
            access_key_id=settings.r2_access_key_id.strip(),
            secret_access_key=settings.r2_secret_access_key.strip(),
            public_base_url=settings.audio_base_url.strip().rstrip("/"),
        )

    @property
    def host(self) -> str:
        return f"{self.account_id}.r2.cloudflarestorage.com"

    def presign_put(
        self,
        key: str,
        *,
        content_type: str,
        size: int,
        expires_in: int,
        now: datetime | None = None,
    ) -> PresignedUpload:
        """A PUT link for exactly this key, content type and size."""
        headers = {"content-type": content_type, "content-length": str(size)}
        url = presign(
            method="PUT",
            host=self.host,
            path=f"/{self.bucket}/{key}",
            headers=headers,
            access_key_id=self.access_key_id,
            secret_access_key=self.secret_access_key,
            region="auto",
            now=now or datetime.now(UTC),
            expires_in=expires_in,
        )
        return PresignedUpload(
            url=url,
            # The browser sets Content-Length itself from the body; only
            # Content-Type has to be sent explicitly.
            headers={"Content-Type": content_type},
            public_url=f"{self.public_base_url}/{key}",
            expires_in=expires_in,
        )
