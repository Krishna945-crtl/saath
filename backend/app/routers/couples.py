import secrets
import string

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.auth import current_user
from app.clock import get_today
from app.db import get_db
from app.game import partner_of, streak
from app.models import Couple, User
from app.schemas import CoupleOut, JoinCouple

router = APIRouter(prefix="/couples", tags=["couples"])

# No 0/O or 1/I — people read these codes aloud over a call
_ALPHABET = "".join(c for c in string.ascii_uppercase + string.digits if c not in "01IO")


def _code() -> str:
    return "".join(secrets.choice(_ALPHABET) for _ in range(6))


def _out(db: Session, user: User, today) -> dict:
    partner = partner_of(user)
    return {
        "invite_code": user.couple.invite_code,
        "partner_name": partner.name if partner else None,
        "streak": streak(db, user.couple, today),
    }


@router.post("", response_model=CoupleOut, status_code=status.HTTP_201_CREATED)
def create_couple(
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
    today=Depends(get_today),
):
    # Tapping "create" twice shouldn't make two invite codes
    if user.couple is not None:
        return _out(db, user, today)

    for _ in range(5):
        couple = Couple(invite_code=_code())
        db.add(couple)
        try:
            db.flush()
            break
        except IntegrityError:  # code collision, very unlikely
            db.rollback()
    else:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "try again")

    user.couple_id = couple.id
    db.commit()
    db.refresh(user)
    return _out(db, user, today)


@router.post("/join", response_model=CoupleOut)
def join_couple(
    body: JoinCouple,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
    today=Depends(get_today),
):
    code = body.code.strip().upper()
    couple = db.scalar(select(Couple).where(Couple.invite_code == code))
    if couple is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "no couple with that code")

    # Retry after a dropped response: already in this couple, just return it
    if user.couple_id == couple.id:
        return _out(db, user, today)

    if len(couple.members) >= 2:
        raise HTTPException(status.HTTP_409_CONFLICT, "this code is already used")

    if user.couple_id is not None:
        old = user.couple
        if len(old.members) >= 2:
            raise HTTPException(status.HTTP_409_CONFLICT, "you're already paired")
        # Both partners tapped "get my code" before talking. Let this one
        # drop their unused code and join the other's instead of getting stuck.
        user.couple_id = None
        db.delete(old)
        db.flush()

    user.couple_id = couple.id
    db.commit()
    db.refresh(user)
    return _out(db, user, today)


@router.get("/me", response_model=CoupleOut)
def my_couple(
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
    today=Depends(get_today),
):
    if user.couple is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "not paired yet")
    return _out(db, user, today)