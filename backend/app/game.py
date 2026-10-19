"""Game rules that don't care about HTTP. Kept separate so they're easy to test."""

from datetime import date, timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Answer, Couple, GameDay, User
from app.questions import QUESTIONS, REPEAT_COOLDOWN_DAYS, pick_questions


def todays_question_ids(db: Session, couple: Couple, day: date) -> list[str]:
    existing = db.scalar(
        select(GameDay).where(GameDay.couple_id == couple.id, GameDay.day == day)
    )
    if existing:
        return existing.question_ids

    since = day - timedelta(days=REPEAT_COOLDOWN_DAYS)
    recent_rows = db.scalars(
        select(GameDay.question_ids).where(
            GameDay.couple_id == couple.id, GameDay.day >= since, GameDay.day < day
        )
    )
    recently_seen = {qid for ids in recent_rows for qid in ids}
    likes = [set(m.liked_tags or []) for m in couple.members]

    ids = pick_questions(couple.id, day, likes, recently_seen)
    db.add(GameDay(couple_id=couple.id, day=day, question_ids=ids))
    db.commit()
    return ids


def answers_for(db: Session, user_id: int, day: date) -> dict[str, Answer]:
    rows = db.scalars(select(Answer).where(Answer.user_id == user_id, Answer.day == day))
    return {a.question_id: a for a in rows}


def partner_of(user: User) -> User | None:
    return next((m for m in user.couple.members if m.id != user.id), None)


def completed_days(db: Session, couple: Couple) -> set[date]:
    """Days where both partners answered every question."""
    members = [m.id for m in couple.members]
    if len(members) < 2:
        return set()

    days: dict[date, set[int]] = {}
    for user_id, day in db.execute(
        select(Answer.user_id, Answer.day).where(Answer.couple_id == couple.id).distinct()
    ):
        days.setdefault(day, set()).add(user_id)
    return {d for d, who in days.items() if who == set(members)}


def streak(db: Session, couple: Couple, today: date) -> int:
    """Consecutive completed days ending today.

    If today isn't done yet, the streak is still alive from yesterday,
    so we start counting from yesterday instead of showing 0 at 9pm.
    """
    done = completed_days(db, couple)
    cursor = today if today in done else today - timedelta(days=1)
    count = 0
    while cursor in done:
        count += 1
        cursor -= timedelta(days=1)
    return count


def question_dict(qid: str) -> dict:
    q = QUESTIONS[qid]
    return {"id": q.id, "tag": q.tag, "prompt": q.prompt, "a": q.a, "b": q.b}
