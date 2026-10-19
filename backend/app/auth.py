import secrets

from fastapi import Depends, Header, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import User


def new_token() -> str:
    return secrets.token_urlsafe(32)


def current_user(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> User:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "missing bearer token")

    token = authorization.removeprefix("Bearer ").strip()
    user = db.scalar(select(User).where(User.token == token))
    if user is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "invalid token")
    return user


def current_couple_user(user: User = Depends(current_user)) -> User:
    """Same as current_user, but the game routes need a full couple."""
    if user.couple is None or len(user.couple.members) < 2:
        raise HTTPException(status.HTTP_409_CONFLICT, "pair with your partner first")
    return user
