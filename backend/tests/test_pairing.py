from tests.conftest import signup


def test_signup_rejects_blank_name(client):
    assert client.post("/users", json={"name": "   "}).status_code == 422


def test_me_needs_token(client):
    assert client.get("/me").status_code == 401
    bad = {"Authorization": "Bearer nope"}
    assert client.get("/me", headers=bad).status_code == 401


def test_pair_happy_path(client, couple):
    rahul, priya = couple
    assert client.get("/couples/me", headers=rahul).json()["partner_name"] == "Priya"
    assert client.get("/couples/me", headers=priya).json()["partner_name"] == "Rahul"
    assert client.get("/me", headers=rahul).json()["paired"] is True


def test_create_twice_returns_same_code(client):
    rahul = signup(client, "Rahul")
    first = client.post("/couples", headers=rahul).json()["invite_code"]
    second = client.post("/couples", headers=rahul).json()["invite_code"]
    assert first == second


def test_join_is_case_insensitive(client):
    rahul = signup(client, "Rahul")
    priya = signup(client, "Priya")
    code = client.post("/couples", headers=rahul).json()["invite_code"]
    r = client.post("/couples/join", json={"code": f" {code.lower()} "}, headers=priya)
    assert r.status_code == 200


def test_join_retry_is_safe(client, couple):
    rahul, priya = couple
    code = client.get("/couples/me", headers=rahul).json()["invite_code"]
    # Priya's app retries after a timeout — should not error
    assert client.post("/couples/join", json={"code": code}, headers=priya).status_code == 200


def test_third_person_cannot_join(client, couple):
    rahul, _ = couple
    code = client.get("/couples/me", headers=rahul).json()["invite_code"]
    stranger = signup(client, "Stranger")
    r = client.post("/couples/join", json={"code": code}, headers=stranger)
    assert r.status_code == 409


def test_wrong_code(client):
    priya = signup(client, "Priya")
    assert client.post("/couples/join", json={"code": "ZZZZZZ"}, headers=priya).status_code == 404


def test_game_locked_until_paired(client):
    rahul = signup(client, "Rahul")
    client.post("/couples", headers=rahul)
    assert client.get("/games/today", headers=rahul).status_code == 409


def test_likes_validation(client):
    rahul = signup(client, "Rahul")
    ok = client.put("/me/likes", json={"tags": ["food", "movies", "food"]}, headers=rahul)
    assert ok.json()["liked_tags"] == ["food", "movies"]
    bad = client.put("/me/likes", json={"tags": ["cricket"]}, headers=rahul)
    assert bad.status_code == 422
