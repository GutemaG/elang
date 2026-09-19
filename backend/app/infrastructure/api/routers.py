"""FastAPI routers: `/api/v1/auth/google`, `/api/v1/auth/apple`,
`/api/v1/auth/session`. Parses/validates the HTTP request into a DTO, calls
the relevant application use case, and maps the result to the HTTP response
shapes in `ddd-02-technical-design.md`. No business logic lives here.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, Header

from app.application.use_cases import (
    PendingSelectionInput,
    authenticate_with_apple,
    authenticate_with_google,
    validate_session,
)
from app.domain.exceptions import MissingCredentialsError
from app.domain.services import (
    AuthenticationService,
    AuthResult,
    SessionValidationService,
)
from app.infrastructure.api.dependencies import (
    get_authentication_service,
    get_session_validation_service,
)
from app.infrastructure.api.schemas import (
    AppleAuthRequest,
    AuthResponse,
    AuthUserResponse,
    GoogleAuthRequest,
    PendingSelectionRequest,
    SessionInvalidResponse,
    SessionUserResponse,
    SessionValidResponse,
)

router = APIRouter(prefix="/api/v1/auth", tags=["auth"])


def _to_pending_selection_input(
    pending_selection: PendingSelectionRequest | None,
) -> PendingSelectionInput | None:
    if pending_selection is None:
        return None
    return PendingSelectionInput(
        language=pending_selection.language,
        daily_goal_minutes=pending_selection.daily_goal_minutes,
        from_language=pending_selection.from_language,
    )


def _to_auth_response(result: AuthResult) -> AuthResponse:
    return AuthResponse(
        session_token=result.raw_session_token,
        expires_at=result.session.token.expires_at.isoformat(),
        user=AuthUserResponse(
            id=result.user.id,
            selected_language=result.user.selected_language.code,
            daily_xp_target=result.user.daily_xp_target.xp_per_day,
            notification_enabled=result.user.notification_enabled,
            is_new_user=result.is_new_user,
            active_course_id=result.user.active_course_id,
        ),
    )


@router.post("/google", response_model=AuthResponse)
async def auth_with_google(
    body: GoogleAuthRequest,
    service: AuthenticationService = Depends(get_authentication_service),
) -> AuthResponse:
    """Story 002: sign up / log in with Google."""
    pending = _to_pending_selection_input(body.pending_selection)
    result = await authenticate_with_google(service, body.id_token, pending)
    return _to_auth_response(result)


@router.post("/apple", response_model=AuthResponse)
async def auth_with_apple(
    body: AppleAuthRequest,
    service: AuthenticationService = Depends(get_authentication_service),
) -> AuthResponse:
    """Story 003: sign up / log in with Sign in with Apple."""
    pending = _to_pending_selection_input(body.pending_selection)
    result = await authenticate_with_apple(service, body.identity_token, pending)
    return _to_auth_response(result)


@router.get("/session", response_model=SessionValidResponse | SessionInvalidResponse)
async def get_session(
    authorization: str | None = Header(default=None),
    service: SessionValidationService = Depends(get_session_validation_service),
) -> SessionValidResponse | SessionInvalidResponse:
    """Stories 002/003's session-recognition ACs: validated on every app
    restart. A malformed/missing header is a 401 (request-shape error); an
    unknown/expired token is a 200 `{ "valid": false }` (expected outcome,
    not an error).
    """
    if not authorization or not authorization.lower().startswith("bearer "):
        raise MissingCredentialsError("Missing or malformed Authorization header")
    token_value = authorization.split(" ", 1)[1].strip()
    if not token_value:
        raise MissingCredentialsError("Missing or malformed Authorization header")

    user = await validate_session(service, token_value)
    if user is None:
        return SessionInvalidResponse()

    return SessionValidResponse(
        user=SessionUserResponse(
            id=user.id,
            selected_language=user.selected_language.code,
            daily_xp_target=user.daily_xp_target.xp_per_day,
            notification_enabled=user.notification_enabled,
            active_course_id=user.active_course_id,
        )
    )
