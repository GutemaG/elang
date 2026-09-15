"""Single FastAPI exception handler mapping domain exceptions to the
Error Codes table in `ddd-02-technical-design.md`.
"""

from __future__ import annotations

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from app.domain.exceptions import (
    AuthDomainError,
    ExpiredTokenError,
    InvalidPendingSelectionError,
    InvalidTokenError,
    MissingCredentialsError,
    ProviderUnreachableError,
)

_STATUS_BY_EXCEPTION: dict[type[AuthDomainError], int] = {
    InvalidTokenError: 401,
    ExpiredTokenError: 401,
    InvalidPendingSelectionError: 400,
    ProviderUnreachableError: 502,
    MissingCredentialsError: 401,
}

_DEFAULT_STATUS = 400


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(AuthDomainError)
    async def handle_auth_domain_error(request: Request, exc: AuthDomainError) -> JSONResponse:
        status_code = _STATUS_BY_EXCEPTION.get(type(exc), _DEFAULT_STATUS)
        return JSONResponse(
            status_code=status_code,
            content={"error_code": exc.error_code, "message": exc.message},
        )
