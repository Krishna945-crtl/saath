# Saath 💞

**A daily "This or That" game for couples who can't be in the same place.**

Every night, both partners get the same 5 questions. For each one you pick your
own answer, then guess what your partner picked. When both of you are done, the
answers are revealed side by side with a score and a streak.

Flutter app + Python (FastAPI) backend + SQLite.

---

## Why I built this

Long-distance and "can't-meet-at-night" couples mostly have a phone and a few
quiet hours before bed. I wanted to see how small a game could be and still give
two people something to talk about afterwards. The guessing step is the point:
getting a guess wrong ("you'd pick *beach*? since when?") starts a conversation.

## What it does

| Flow | Details |
|---|---|
| Sign up | Just a name + optional topics you like (food, travel, movies…). No passwords for the MVP. |
| Pair | One partner gets a 6-character invite code, the other enters it. The waiting screen polls and moves on by itself when the partner joins. |
| Play | 5 questions × 2 steps (your pick, your guess). Back button works across steps. |
| Reveal | Partner's picks stay hidden until both have played. Then: score out of 10, how many picks matched, ✓/✗ per guess. |
| Streak | Consecutive nights where *both* partners finished. |

## Architecture

```
Flutter app (Riverpod)                FastAPI                       SQLite
┌──────────────────────┐   HTTPS   ┌──────────────────────┐   ┌─────────────┐
│ RootGate             │──────────▶│ /users  /me/likes    │──▶│ users       │
│  ├ Onboarding        │           │ /couples /join       │   │ couples     │
│  ├ Pair (polls 5s)   │           │ /games/today         │   │ game_days   │
│  ├ Game (5 × 2 steps)│           │ /games/today/answers │   │ answers     │
│  └ Result            │           │ /games/today/result  │   └─────────────┘
└──────────────────────┘           └──────────────────────┘
```

```
saath/
├── backend/
│   ├── app/
│   │   ├── main.py          app factory, CORS, routers
│   │   ├── models.py        User, Couple, GameDay, Answer
│   │   ├── questions.py     question bank + daily picker
│   │   ├── game.py          scoring + streak rules (no HTTP here)
│   │   ├── clock.py         "game day" in IST, rolls over at 4am
│   │   ├── auth.py          bearer token dependency
│   │   └── routers/         users, couples, games
│   └── tests/               25 pytest tests
└── app/
    ├── lib/
    │   ├── api/             ApiClient + models
    │   ├── state/           Riverpod providers, session in shared_preferences
    │   ├── screens/         onboarding, pair, game, result
    │   └── widgets/         Loading / Error(+retry) / Empty views
    └── test/                api client + widget tests
```

## Decisions and trade-offs

These are the parts I'd want to talk through in a review.

**1. The "day" rolls over at 4am IST, not midnight.**
Most couples play between 9pm and midnight, and plenty of sessions run past 12.
With a midnight cutoff, one partner finishing at 11:58 and the other at 12:03
would land on *different* days and the game would never reveal. Moving the
boundary to 4am fixes that without any timezone UI. (`clock.py`, tested in
`test_units.py`.)

**2. Today's questions are frozen once generated.**
The picker uses a person's liked topics. If someone changes their likes at 10pm,
regenerating would swap questions under a partner who's halfway through. So the
first request of the day writes the chosen ids to `game_days`, and every later
request reads them back.

**3. Submitting answers is safe to retry.**
On a flaky mobile network the app may resend the same answers. The server
compares: identical payload → returns the result (no-op); different payload →
`409 answers already locked in`. The app keeps answers in memory so "Retry" on
the error snackbar resends exactly the same thing.

**4. No peeking.**
The result endpoint returns `waiting_for_partner` with an empty `items` list
until both have answered — the partner's picks never reach the client early.

**5. Streak doesn't drop to 0 at 9pm.**
If tonight isn't finished yet, the streak counts from yesterday. Otherwise every
couple would see "0-day streak" each evening until they played, which feels like
a punishment.

**6. Personalisation is a simple weighted picker, on purpose.**
Topics both partners like get weight 4, topics one likes get 2, the rest 1.
Questions seen in the last 14 days are skipped. It's deterministic per
couple + day, so retries and second devices agree. This is the baseline any
smarter (e.g. LLM-generated) game would need to beat.

**7. What I deliberately skipped for the MVP.**
Real auth (OTP), push notifications, unpairing, migrations (Alembic), and
Postgres. SQLite + `create_all` keeps setup to one command.

## Every screen has all its states

| Screen | Loading | Empty | Error | Retry |
|---|---|---|---|---|
| Root | spinner | → onboarding | full-screen error | button; expired token auto signs out |
| Onboarding | button spinner | — | inline message | tap Continue again |
| Pair | button disabled | "get my code" | inline message | tap again; join is idempotent |
| Game | "Getting tonight's game…" | "No game right now" + refresh | offline vs server icon | button |
| Submit | button spinner | — | snackbar | Retry resends same payload |
| Result | spinner | "Waiting for partner" | full-screen error | pull to refresh |

Network errors and server errors show different messages, and raw server
errors (500s) are never shown to the user.

## Running it

### Backend

```bash
cd backend
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt -r requirements-dev.txt
pytest -q                                            # 25 passed
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

API docs: http://localhost:8000/docs

### App

```bash
cd app
flutter create . --project-name saath --platforms android,ios,web   # generates platform folders once
flutter pub get
flutter analyze
flutter test

# Android emulator (10.0.2.2 = your laptop):
flutter run
# Real phone on the same Wi-Fi:
flutter run --dart-define=API_URL=http://<your-laptop-ip>:8000
# Browser:
flutter run -d chrome --dart-define=API_URL=http://localhost:8000
```

> Android blocks plain `http://` in release builds. For local testing either use
> a debug build, or add `android:usesCleartextTraffic="true"` to
> `android/app/src/main/AndroidManifest.xml`. A deployed backend should be HTTPS.

To try it as a couple on one machine: run the app in Chrome **and** on the
emulator, sign up as two people, pair them, and play.

## Testing

**Backend (25 tests)** — pairing (idempotent create/join, case-insensitive code,
third person blocked), game flow (same questions for both, frozen after likes
change, hidden until both answer, exact scoring), retries (same payload OK,
changed payload 409), validation, new-day cooldown, streak rules, 4am rollover,
picker determinism and weighting.

Tests control "today" through a FastAPI dependency override, so streaks across
several days run instantly without mocking `datetime`.

**App** — `ApiClient` against a mock HTTP client (token header, error parsing,
timeouts, 404 → not paired), and widget tests for the error view (offline vs
server, retry callback, no raw tracebacks).

## What I'd build next

1. **Metric to watch:** % of couples where *both* partners finish on the same
   night. If one partner often finishes and the other doesn't, the next feature
   is a "your partner is waiting" push notification, not more questions.
2. Push notifications (FCM) when the partner finishes.
3. Phone-number OTP instead of device-only tokens, so reinstalling doesn't lose
   the couple.
4. A tiny "why did you pick that?" reply on each reveal card — the conversation
   is the product.
5. Generated questions per couple, A/B tested against the weighted picker on
   the both-finished rate.

## How I used AI tools

<!-- Fill this in honestly yourself — Kulfi asks candidates to disclose this. -->
_Which tools, for which parts, and what you changed or verified by hand._
