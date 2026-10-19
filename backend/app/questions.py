"""Question bank + the daily picker.

The picker is deliberately boring: seeded random, weighted toward tags
both partners like, skipping anything they saw recently. It's the
baseline an AI generator would later have to beat.
"""

import random
from dataclasses import dataclass
from datetime import date

QUESTIONS_PER_DAY = 5
REPEAT_COOLDOWN_DAYS = 14


@dataclass(frozen=True)
class Question:
    id: str
    tag: str
    prompt: str
    a: str
    b: str


_BANK = [
    ("food", "Late-night craving?", "Maggi", "Ice cream"),
    ("food", "Sunday breakfast?", "Dosa", "Poha"),
    ("food", "Chai or coffee?", "Chai", "Coffee"),
    ("food", "Biryani with...", "Raita", "Salan"),
    ("food", "Street food pick?", "Pani puri", "Momos"),
    ("food", "Dessert after dinner?", "Gulab jamun", "Brownie"),
    ("travel", "Dream trip?", "Mountains", "Beach"),
    ("travel", "Travel style?", "Plan everything", "Go with the flow"),
    ("travel", "Long journey?", "Train", "Road trip"),
    ("travel", "Holiday stay?", "Cosy homestay", "Fancy hotel"),
    ("travel", "First trip together?", "Goa", "Manali"),
    ("movies", "Movie night genre?", "Romcom", "Thriller"),
    ("movies", "Watch where?", "Theatre", "Laptop in bed"),
    ("movies", "Rewatch or new?", "Old favourite", "Something new"),
    ("movies", "Subtitles?", "Always on", "Never"),
    ("movies", "Series binge?", "One episode a day", "Whole season tonight"),
    ("music", "Road trip playlist?", "Old Bollywood", "Latest hits"),
    ("music", "At a wedding you...", "Own the dance floor", "Guard the food"),
    ("music", "Concert or...", "Live concert", "Headphones at home"),
    ("music", "Sing in the shower?", "Full performance", "Never"),
    ("habits", "Morning person?", "Up at 6", "What is 6 am?"),
    ("habits", "Phone at night?", "Scroll till 2", "Lights out by 11"),
    ("habits", "Texting style?", "Long paragraphs", "One-word replies"),
    ("habits", "Messy or tidy?", "Tidy", "Organised chaos"),
    ("habits", "Reply time?", "Instant", "Whenever I see it"),
    ("deep", "Big fight. You...", "Talk it out now", "Need space first"),
    ("deep", "Love language?", "Words", "Time together"),
    ("deep", "Surprise gift or...", "Surprise", "Ask what they want"),
    ("deep", "Future home?", "Big city", "Quiet town"),
    ("deep", "Remember dates?", "Every one", "Need reminders"),
]

QUESTIONS: dict[str, Question] = {}
for i, (tag, prompt, a, b) in enumerate(_BANK, start=1):
    qid = f"{tag[:3]}-{i:02d}"
    QUESTIONS[qid] = Question(qid, tag, prompt, a, b)

ALL_TAGS = sorted({q.tag for q in QUESTIONS.values()})


def pick_questions(
    couple_id: int,
    day: date,
    liked_tags: list[set[str]],
    recently_seen: set[str],
) -> list[str]:
    """Pick today's question ids for one couple.

    Same couple + same day always gives the same result, so a retry or a
    second device never sees a different game.
    """
    rng = random.Random(f"{couple_id}:{day.isoformat()}")

    shared = set.intersection(*liked_tags) if liked_tags else set()
    either = set.union(*liked_tags) if liked_tags else set()

    def weight(q: Question) -> int:
        if q.tag in shared:
            return 4
        if q.tag in either:
            return 2
        return 1

    fresh = [q for q in QUESTIONS.values() if q.id not in recently_seen]
    # A long-running couple can exhaust the bank; fall back to everything
    # rather than serving fewer than 5 questions.
    pool = fresh if len(fresh) >= QUESTIONS_PER_DAY else list(QUESTIONS.values())
    pool.sort(key=lambda q: q.id)  # stable order before seeded shuffle

    picked: list[str] = []
    while len(picked) < QUESTIONS_PER_DAY:
        choice = rng.choices(pool, weights=[weight(q) for q in pool], k=1)[0]
        picked.append(choice.id)
        pool.remove(choice)
    return picked
