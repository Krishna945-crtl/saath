from datetime import date, datetime, timezone

from sqlalchemy import JSON, Date, DateTime, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


def _now() -> datetime:
    return datetime.now(timezone.utc)


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(40))
    token: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    liked_tags: Mapped[list] = mapped_column(JSON, default=list)
    couple_id: Mapped[int | None] = mapped_column(ForeignKey("couples.id"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    couple: Mapped["Couple | None"] = relationship(back_populates="members")


class Couple(Base):
    __tablename__ = "couples"

    id: Mapped[int] = mapped_column(primary_key=True)
    invite_code: Mapped[str] = mapped_column(String(8), unique=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    members: Mapped[list[User]] = relationship(back_populates="couple")


class GameDay(Base):
    """Freezes which questions a couple got on a given day.

    Without this, changing your likes at 10pm would reshuffle a game
    your partner already half-finished.
    """

    __tablename__ = "game_days"
    __table_args__ = (UniqueConstraint("couple_id", "day"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    couple_id: Mapped[int] = mapped_column(ForeignKey("couples.id"), index=True)
    day: Mapped[date] = mapped_column(Date)
    question_ids: Mapped[list] = mapped_column(JSON)


class Answer(Base):
    __tablename__ = "answers"
    __table_args__ = (UniqueConstraint("user_id", "day", "question_id"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    couple_id: Mapped[int] = mapped_column(ForeignKey("couples.id"), index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    day: Mapped[date] = mapped_column(Date, index=True)
    question_id: Mapped[str] = mapped_column(String(16))
    mine: Mapped[str] = mapped_column(String(1))   # "a" or "b"
    guess: Mapped[str] = mapped_column(String(1))  # what I think my partner picked
