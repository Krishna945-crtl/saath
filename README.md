# Saath 💞

**A daily "This or That" game for couples who can't be in the same place.**

Every night, both partners get the same 5 questions. For each one you pick your
own answer, then guess what your partner picked. When both of you are done, the
answers are revealed side by side with a score and a streak.

Flutter app + Python (FastAPI) backend + SQLite.

**Live demo:** https://saath-kittu.netlify.app

**Try it as a couple:** open the link in a normal window **and** an Incognito
window, sign up as two people, share the invite code from one window, enter it in
the other, and play. The backend runs on Render's free tier, so the first request
can take up to a minute while the server wakes up.

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
Flutter web app (Riverpod)            FastAPI                       SQLite
on Netlify                            on Render
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
│   └── tests/               pytest suite
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

**7. A partner can switch from their own unused code to the other's.**
Found while testing with two browser windows: if both partners tapped
"Get my invite code" first, joining failed with "you're already paired" and
neither could pair. Now, if nobody has joined your code, it's deleted and you
join your partner's instead. A user who is actually paired still gets a 409.

**8. What I deliberately skipped for the MVP.**
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
errors (500s) are never shown to the user. On a laptop the app stays in a
480px column so the layout doesn't stretch edge to edge.

## Deployment

| Part | Host | Notes |
|---|---|---|
| Backend (FastAPI) | Render (free) | Root `backend`, start `uvicorn app.main:app --host 0.0.0.0 --port $PORT`. Sleeps when idle. |
| Web app (Flutter) | Netlify | `flutter build web --dart-define=API_URL=<render url>`, then upload `build/web`. |

On the free tier the SQLite file can be reset when the server restarts, so demo
accounts may disappear — just sign up again. A real launch would move to Postgres.

## Running it locally

### Backend

```bash
cd backend
python -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements.txt -r requirements-dev.txt
pytest -q
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

API docs: http://localhost:8000/docs

### App (web)

```bash
cd app
flutter create . --project-name saath --platforms android,web   # once, generates platform folders
flutter pub get
flutter analyze
flutter test
flutter build web --dart-define=API_URL=http://localhost:8000
cd build/web
python -m http.server 5000
```

Open http://localhost:5000. Keep the backend and the web server running in
two separate terminals.

### App (Android)

```bash
flutter run                                                     # emulator (10.0.2.2 = your laptop)
flutter run --dart-define=API_URL=http://<your-laptop-ip>:8000  # real phone on same Wi-Fi
```

> Android blocks plain `http://` in release builds. For local testing use a
> debug build, or point `API_URL` at the HTTPS Render backend.

## Testing

**Backend** — pairing (idempotent create/join, case-insensitive code, third
person blocked), game flow (same questions for both, frozen after likes change,
hidden until both answer, exact scoring), retries (same payload OK, changed
payload 409), validation, new-day cooldown, streak rules, 4am rollover, picker
determinism and weighting.

Tests control "today" through a FastAPI dependency override, so streaks across
several days run instantly without mocking `datetime`.

**App** — `ApiClient` against a mock HTTP client (token header, error parsing,
timeouts, 404 → not paired), and widget tests for the error view (offline vs
server, retry callback, no raw tracebacks).

CI (GitHub Actions) runs `pytest`, `flutter analyze` and `flutter test` on every push.

## What I'd build next

1. **Metric to watch:** % of couples where *both* partners finish on the same
   night. If one partner often finishes and the other doesn't, the next feature
   is a "your partner is waiting" push notification, not more questions.
2. Push notifications (FCM) when the partner finishes.
3. Phone-number OTP instead of device-only tokens, so reinstalling doesn't lose
   the couple.
4. Make the ✓/✗ on the reveal cards self-explanatory — right now the meaning
   ("the other person guessed this right") is only in a footnote.
5. A tiny "why did you pick that?" reply on each reveal card — the conversation
   is the product.
6. Generated questions per couple, A/B tested against the weighted picker on
   the both-finished rate.

## How I used AI tools

I used Claude (Anthropic) as a pair programmer for this project.

- **What AI did:** generated the first version of the FastAPI backend, the
  Flutter app structure, the tests and this README from my requirements.
- **What I did:** set up and ran everything locally on Windows (Python venv,
  Flutter SDK, web build), ran the tests and the analyzer, played the game end
  to end as two users in separate browser windows, and deployed it (Render +
  Netlify).
- **What I found and fixed while testing:**
  - **Pairing bug:** if both partners tapped "Get my invite code", neither
    could join the other. I changed the join logic so an unused code is
    dropped (decision 7 above).
  - **Desktop layout:** the form stretched edge to edge on a laptop. I limited
    the app to a 480px column and refactored `main.dart` to reduce nesting.
  - Fixed an analyzer warning (`unused_result` on `ref.refresh`) and removed
    the default test file `flutter create` added.
- **How I verified:** `pytest`, `flutter analyze`, `flutter test`, and manual
  two-user testing locally and on the live deployment.
