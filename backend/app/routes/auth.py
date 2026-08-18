"""Public bootstrapping endpoints for App Attest anonymous sessions."""

from datetime import datetime
from typing import Literal, Self
from uuid import UUID

from fastapi import APIRouter, Depends, Request, Response, status
from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.auth.network import request_client_ip
from app.auth.runtime import get_auth_service, raise_auth_http_error
from app.auth.service import AppAttestAuthService, AppSession, AuthFlowError

router = APIRouter(prefix="/auth/app-attest", tags=["authentication"])


class ChallengeRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    purpose: Literal["attestation", "assertion", "deletion"]
    key_id: str | None = Field(default=None, max_length=128)

    @model_validator(mode="after")
    def validate_key_usage(self) -> Self:
        if self.purpose == "attestation" and self.key_id is not None:
            raise ValueError("key_id must be omitted for attestation.")
        if self.purpose in {"assertion", "deletion"} and self.key_id is None:
            raise ValueError(f"key_id is required for {self.purpose}.")
        return self


class ChallengeResponse(BaseModel):
    challenge_id: UUID
    challenge: str
    expires_at: datetime


class RegistrationRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    challenge_id: UUID
    key_id: str = Field(min_length=1, max_length=128)
    attestation_object: str = Field(min_length=1, max_length=90000)


class AssertionSessionRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    challenge_id: UUID
    key_id: str = Field(min_length=1, max_length=128)
    assertion_object: str = Field(min_length=1, max_length=12000)
    client_data: str = Field(min_length=1, max_length=6000)


class InstallationDeletionRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    challenge_id: UUID
    key_id: str = Field(min_length=1, max_length=128)
    assertion_object: str = Field(min_length=1, max_length=12000)
    client_data: str = Field(min_length=1, max_length=6000)


class SessionResponse(BaseModel):
    access_token: str
    token_type: Literal["Bearer"] = "Bearer"
    expires_in: int
    expires_at: datetime
    installation_id: UUID


@router.post("/challenge", response_model=ChallengeResponse)
def challenge_endpoint(
    body: ChallengeRequest,
    request: Request,
    service: AppAttestAuthService = Depends(get_auth_service),
) -> ChallengeResponse:
    try:
        challenge = service.issue_challenge(
            purpose=body.purpose,
            key_id=body.key_id,
            client_ip=_client_ip(request, service),
        )
    except AuthFlowError as exc:
        raise_auth_http_error(exc)
    return ChallengeResponse(
        challenge_id=UUID(challenge.challenge_id),
        challenge=challenge.challenge,
        expires_at=challenge.expires_at,
    )


@router.post("/register", response_model=SessionResponse)
def register_endpoint(
    body: RegistrationRequest,
    request: Request,
    service: AppAttestAuthService = Depends(get_auth_service),
) -> SessionResponse:
    try:
        session = service.register(
            challenge_id=str(body.challenge_id),
            key_id=body.key_id,
            attestation_object=body.attestation_object,
            client_ip=_client_ip(request, service),
        )
    except AuthFlowError as exc:
        raise_auth_http_error(exc)
    return _session_response(session)


@router.post("/session", response_model=SessionResponse)
def session_endpoint(
    body: AssertionSessionRequest,
    request: Request,
    service: AppAttestAuthService = Depends(get_auth_service),
) -> SessionResponse:
    try:
        session = service.create_session(
            challenge_id=str(body.challenge_id),
            key_id=body.key_id,
            assertion_object=body.assertion_object,
            client_data=body.client_data,
            client_ip=_client_ip(request, service),
        )
    except AuthFlowError as exc:
        raise_auth_http_error(exc)
    return _session_response(session)


@router.post(
    "/delete",
    status_code=status.HTTP_204_NO_CONTENT,
    response_class=Response,
)
def delete_installation_endpoint(
    body: InstallationDeletionRequest,
    request: Request,
    service: AppAttestAuthService = Depends(get_auth_service),
) -> Response:
    """Delete only the anonymous identity proven by a fresh App Attest assertion."""
    try:
        service.delete_installation(
            challenge_id=str(body.challenge_id),
            key_id=body.key_id,
            assertion_object=body.assertion_object,
            client_data=body.client_data,
            client_ip=_client_ip(request, service),
        )
    except AuthFlowError as exc:
        raise_auth_http_error(exc)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


def _session_response(session: AppSession) -> SessionResponse:
    # Kept separate so both enrollment and assertion refresh return an exactly
    # matching wire contract.
    return SessionResponse(
        access_token=session.access_token,
        expires_in=session.expires_in,
        expires_at=session.expires_at,
        installation_id=UUID(session.installation_id),
    )


def _client_ip(request: Request, service: AppAttestAuthService) -> str:
    return request_client_ip(
        request,
        production=service.configuration.deployment_environment == "production",
    )
