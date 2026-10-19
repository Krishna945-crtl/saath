from datetime import date, datetime, timedelta, timezone

IST = timezone(timedelta(hours=5, minutes=30))

# Most play happens 9pm-midnight and often runs past 12. If the game
# day flipped at midnight, a couple finishing at 12:10 would land on a
# different day than the partner who finished at 11:50. So the day
# rolls over at 4am IST instead.
DAY_ROLLOVER_HOUR = 4


def game_day(now: datetime | None = None) -> date:
    now = now or datetime.now(timezone.utc)
    local = now.astimezone(IST) - timedelta(hours=DAY_ROLLOVER_HOUR)
    return local.date()


def get_today() -> date:
    """FastAPI dependency. Tests override this to time-travel."""
    return game_day()
