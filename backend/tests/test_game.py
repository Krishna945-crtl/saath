from datetime import timedelta

from tests.conftest import answer_all


def test_both_partners_get_same_questions(client, couple):
    rahul, priya = couple
    a = client.get("/games/today", headers=rahul).json()
    b = client.get("/games/today", headers=priya).json()
    assert len(a["questions"]) == 5
    assert a["questions"] == b["questions"]


def test_questions_frozen_even_if_likes_change(client, couple):
    rahul, _ = couple
    before = client.get("/games/today", headers=rahul).json()["questions"]
    client.put("/me/likes", json={"tags": ["deep"]}, headers=rahul)
    after = client.get("/games/today", headers=rahul).json()["questions"]
    assert before == after


def test_partner_picks_hidden_until_both_answer(client, couple):
    rahul, priya = couple
    r = answer_all(client, rahul)
    assert r.json()["state"] == "waiting_for_partner"
    assert r.json()["items"] == []

    assert client.get("/games/today/result", headers=priya).json()["state"] == "waiting_for_me"
    assert client.get("/games/today", headers=priya).json()["partner_answered"] is True


def test_scoring(client, couple):
    rahul, priya = couple
    qs = client.get("/games/today", headers=rahul).json()["questions"]
    first = qs[0]["id"]

    # Rahul picks "a" everywhere and guesses Priya picks "a"
    answer_all(client, rahul, mine="a", guess="a")
    # Priya picks "a" everywhere except q1, and guesses Rahul picks "b" everywhere
    r = answer_all(client, priya, mine="a", guess="b", overrides={first: ("b", "b")})

    body = r.json()
    assert body["state"] == "ready"
    assert body["out_of"] == 10
    assert body["same_picks"] == 4      # differ only on q1
    assert body["score"] == 4           # Rahul right on 4, Priya right on 0
    q1 = next(i for i in body["items"] if i["question"]["id"] == first)
    assert q1["my_pick"] == "b" and q1["partner_pick"] == "a"


def test_resubmitting_same_answers_is_idempotent(client, couple):
    rahul, _ = couple
    assert answer_all(client, rahul).status_code == 200
    assert answer_all(client, rahul).status_code == 200


def test_cannot_change_locked_answers(client, couple):
    rahul, _ = couple
    answer_all(client, rahul, mine="a")
    assert answer_all(client, rahul, mine="b").status_code == 409


def test_must_answer_exactly_todays_questions(client, couple):
    rahul, _ = couple
    qs = client.get("/games/today", headers=rahul).json()["questions"]
    partial = [{"question_id": q["id"], "mine": "a", "guess": "a"} for q in qs[:3]]
    r = client.post("/games/today/answers", json={"answers": partial}, headers=rahul)
    assert r.status_code == 422

    dupes = partial + partial[:1] + [{"question_id": qs[3]["id"], "mine": "a", "guess": "a"}]
    r = client.post("/games/today/answers", json={"answers": dupes}, headers=rahul)
    assert r.status_code == 422


def test_invalid_choice_rejected(client, couple):
    rahul, _ = couple
    qs = client.get("/games/today", headers=rahul).json()["questions"]
    payload = [{"question_id": q["id"], "mine": "c", "guess": "a"} for q in qs]
    r = client.post("/games/today/answers", json={"answers": payload}, headers=rahul)
    assert r.status_code == 422


def test_new_day_new_questions(client, couple, clock):
    rahul, _ = couple
    day1 = {q["id"] for q in client.get("/games/today", headers=rahul).json()["questions"]}
    clock.today += timedelta(days=1)
    day2 = {q["id"] for q in client.get("/games/today", headers=rahul).json()["questions"]}
    assert day1.isdisjoint(day2)  # recent questions are on cooldown


def test_streak_counts_consecutive_days(client, couple, clock):
    rahul, priya = couple
    for _ in range(3):
        answer_all(client, rahul)
        answer_all(client, priya)
        clock.today += timedelta(days=1)

    # New day, nobody played yet: streak is still alive at 3
    assert client.get("/couples/me", headers=rahul).json()["streak"] == 3

    # Only one partner plays — doesn't count
    answer_all(client, rahul)
    assert client.get("/couples/me", headers=rahul).json()["streak"] == 3

    # Skip a whole day: streak breaks
    clock.today += timedelta(days=2)
    assert client.get("/couples/me", headers=rahul).json()["streak"] == 0
