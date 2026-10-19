from datetime import date
from typing import Literal

from pydantic import BaseModel, Field, field_validator

Choice = Literal["a", "b"]


class CreateUser(BaseModel):
    name: str = Field(min_length=1, max_length=40)

    @field_validator("name")
    @classmethod
    def strip_name(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("name can't be blank")
        return v


class UserOut(BaseModel):
    id: int
    name: str
    liked_tags: list[str]
    paired: bool


class Session(UserOut):
    token: str


class UpdateLikes(BaseModel):
    tags: list[str] = Field(max_length=10)


class JoinCouple(BaseModel):
    code: str = Field(min_length=4, max_length=8)


class CoupleOut(BaseModel):
    invite_code: str
    partner_name: str | None  # None until the partner joins
    streak: int


class QuestionOut(BaseModel):
    id: str
    tag: str
    prompt: str
    a: str
    b: str


class TodayOut(BaseModel):
    day: date
    questions: list[QuestionOut]
    i_answered: bool
    partner_answered: bool


class AnswerIn(BaseModel):
    question_id: str
    mine: Choice
    guess: Choice


class SubmitAnswers(BaseModel):
    answers: list[AnswerIn]


class RevealItem(BaseModel):
    question: QuestionOut
    my_pick: Choice
    partner_pick: Choice
    i_guessed_right: bool
    partner_guessed_right: bool


class ResultOut(BaseModel):
    state: Literal["waiting_for_me", "waiting_for_partner", "ready"]
    day: date
    score: int | None = None      # correct guesses by both, out of 2 * questions
    out_of: int | None = None
    same_picks: int | None = None
    items: list[RevealItem] = []
    streak: int = 0
