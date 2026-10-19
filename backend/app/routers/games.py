from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.auth import current_couple_user
from app.clock import get_today
from app.db import get_db
from app.game import answers_for, partner_of, question_dict, streak, todays_question_ids
from app.models import Answer, User
from app.schemas import ResultOut, SubmitAnswers, TodayOut

router = APIRouter(prefix="/games/today", tags=["games"])


@router.get("", response_model=TodayOut)
def today_game(
    user: User = Depends(current_couple_user),
    db: Session = Depends(get_db),
    today=Depends(get_today),
):
    ids = todays_question_ids(db, user.couple, today)
    partner = partner_of(user)
    return {
        "day": today,
        "questions": [question_dict(q) for q in ids],
        "i_answered": bool(answers_for(db, user.id, today)),
        "partner_answered": bool(answers_for(db, partner.id, today)),
    }


@router.post("/answers", response_model=ResultOut)
def submit_answers(
    body: SubmitAnswers,
    user: User = Depends(current_couple_user),
    db: Session = Depends(get_db),
    today=Depends(get_today),
):
    ids = todays_question_ids(db, user.couple, today)
    sent = {a.question_id: a for a in body.answers}

    if len(sent) != len(body.answers):
        raise HTTPException(422, "duplicate question_id")
    if set(sent) != set(ids):
        raise HTTPException(
            422, "answer exactly today's questions"
        )

    existing = answers_for(db, user.id, today)
    if existing:
        # The app retries on timeouts. Same payload again = fine, return result.
        # Different payload = they're trying to change answers after the fact.
        same = all(
            existing[q].mine == sent[q].mine and existing[q].guess == sent[q].guess
            for q in ids
        )
        if not same:
            raise HTTPException(status.HTTP_409_CONFLICT, "answers already locked in")
        return build_result(db, user, today)

    for qid in ids:
        a = sent[qid]
        db.add(
            Answer(
                couple_id=user.couple_id,
                user_id=user.id,
                day=today,
                question_id=qid,
                mine=a.mine,
                guess=a.guess,
            )
        )
    db.commit()
    return build_result(db, user, today)


@router.get("/result", response_model=ResultOut)
def result(
    user: User = Depends(current_couple_user),
    db: Session = Depends(get_db),
    today=Depends(get_today),
):
    todays_question_ids(db, user.couple, today)
    return build_result(db, user, today)


def build_result(db: Session, user: User, today) -> dict:
    partner = partner_of(user)
    mine = answers_for(db, user.id, today)
    theirs = answers_for(db, partner.id, today)
    current_streak = streak(db, user.couple, today)

    if not mine:
        return {"state": "waiting_for_me", "day": today, "streak": current_streak}
    if not theirs:
        # Don't leak the partner's picks before they've played
        return {"state": "waiting_for_partner", "day": today, "streak": current_streak}

    items = []
    score = same = 0
    for qid in todays_question_ids(db, user.couple, today):
        me_a, them_a = mine[qid], theirs[qid]
        i_right = me_a.guess == them_a.mine
        they_right = them_a.guess == me_a.mine
        score += i_right + they_right
        same += me_a.mine == them_a.mine
        items.append(
            {
                "question": question_dict(qid),
                "my_pick": me_a.mine,
                "partner_pick": them_a.mine,
                "i_guessed_right": i_right,
                "partner_guessed_right": they_right,
            }
        )

    return {
        "state": "ready",
        "day": today,
        "score": score,
        "out_of": len(items) * 2,
        "same_picks": same,
        "items": items,
        "streak": current_streak,
    }
