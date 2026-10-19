from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.auth import current_user, new_token
from app.db import get_db
from app.models import User
from app.questions import ALL_TAGS
from app.schemas import CreateUser, Session as SessionOut, UpdateLikes, UserOut

router = APIRouter(tags=["users"])


def _out(user: User) -> dict:
    return {
        "id": user.id,
        "name": user.name,
        "liked_tags": user.liked_tags or [],
        "paired": user.couple is not None and len(user.couple.members) == 2,
    }


@router.post("/users", response_model=SessionOut, status_code=status.HTTP_201_CREATED)
def create_user(body: CreateUser, db: Session = Depends(get_db)):
    user = User(name=body.name, token=new_token(), liked_tags=[])
    db.add(user)
    db.commit()
    return {**_out(user), "token": user.token}


@router.get("/me", response_model=UserOut)
def me(user: User = Depends(current_user)):
    return _out(user)


@router.get("/tags", response_model=list[str])
def tags():
    return ALL_TAGS


@router.put("/me/likes", response_model=UserOut)
def update_likes(
    body: UpdateLikes,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    unknown = set(body.tags) - set(ALL_TAGS)
    if unknown:
        raise HTTPException(
            422, f"unknown tags: {sorted(unknown)}"
        )
    user.liked_tags = sorted(set(body.tags))
    db.commit()
    return _out(user)
