from datetime import date, datetime, timezone

from app.clock import game_day
from app.questions import QUESTIONS, pick_questions


def test_game_day_rolls_over_at_4am_ist():
    # 23:50 IST on 19 Oct and 00:30 IST on 20 Oct are the same game night
    before_midnight = datetime(2026, 10, 19, 18, 20, tzinfo=timezone.utc)
    after_midnight = datetime(2026, 10, 19, 19, 0, tzinfo=timezone.utc)
    assert game_day(before_midnight) == game_day(after_midnight) == date(2026, 10, 19)

    # 04:30 IST is the next day's game
    morning = datetime(2026, 10, 19, 23, 0, tzinfo=timezone.utc)
    assert game_day(morning) == date(2026, 10, 20)


def test_picker_is_deterministic():
    d = date(2026, 10, 19)
    assert pick_questions(1, d, [set(), set()], set()) == pick_questions(1, d, [set(), set()], set())


def test_picker_returns_unique_questions():
    ids = pick_questions(7, date(2026, 10, 19), [{"food"}, {"food"}], set())
    assert len(ids) == len(set(ids)) == 5


def test_picker_leans_toward_shared_likes():
    shared_hits = 0
    for couple_id in range(200):
        ids = pick_questions(couple_id, date(2026, 10, 19), [{"food"}, {"food"}], set())
        shared_hits += sum(QUESTIONS[q].tag == "food" for q in ids)
    # food is 6/30 questions = 20% by chance; weighting should push it well above
    assert shared_hits / (200 * 5) > 0.35


def test_picker_falls_back_when_bank_exhausted():
    everything = set(QUESTIONS)
    ids = pick_questions(1, date(2026, 10, 19), [set(), set()], everything)
    assert len(ids) == 5
