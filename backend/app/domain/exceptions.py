"""Custom domain exceptions for the auth service.

Each exception carries a stable `error_code` that the presentation layer's
single FastAPI exception handler (see `app/infrastructure/api/error_handlers.py`)
maps to an HTTP status and response body, per `ddd-02-technical-design.md`'s
Error Handling table.

None of these exceptions may carry token values, provider claim contents, or
other PII in their message — only enough context to log/debug safely.
"""

from __future__ import annotations


class AuthDomainError(Exception):
    """Base class for all auth-service domain exceptions.

    Subclasses set `error_code`, which is the stable machine-readable code
    returned to API clients (matches `AuthenticationRejected.reason` values
    from the domain model where applicable).
    """

    error_code: str = "domain_error"

    def __init__(self, message: str) -> None:
        super().__init__(message)
        self.message = message


class InvalidTokenError(AuthDomainError):
    """Provider token failed cryptographic/signature/issuer/audience verification."""

    error_code = "invalid_token"


class ExpiredTokenError(AuthDomainError):
    """Provider token was well-formed and correctly signed, but has expired."""

    error_code = "expired_token"


class InvalidPendingSelectionError(AuthDomainError):
    """A pending onboarding selection's language code is not supported."""

    error_code = "invalid_pending_selection"


class ProviderUnreachableError(AuthDomainError):
    """The upstream Google/Apple verification endpoint could not be reached.

    Distinct from InvalidTokenError so the client can distinguish a retryable
    network condition from a terminal "sign in again" outcome (stories
    002/003's edge cases).
    """

    error_code = "provider_unreachable"


class MissingCredentialsError(AuthDomainError):
    """The Authorization header was missing or malformed on a session check.

    This is a request-shape error rather than a domain outcome, but is routed
    through the same exception-handler mapping for consistency.
    """

    error_code = "missing_credentials"
