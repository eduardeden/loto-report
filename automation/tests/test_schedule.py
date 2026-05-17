from __future__ import annotations

from datetime import datetime, timezone
from zoneinfo import ZoneInfo

from src.utils import compute_next_expected_update_at, parse_iso_utc


def test_next_expected_update_is_fx_daily_when_earlier() -> None:
    # Sunday 2026-05-17 23:30 local -> next update should be Monday 13:17 local (FX daily).
    local_now = datetime(2026, 5, 17, 23, 30, tzinfo=ZoneInfo("Europe/Bucharest"))
    next_update = parse_iso_utc(compute_next_expected_update_at(local_now.astimezone(timezone.utc)))
    next_local = next_update.astimezone(ZoneInfo("Europe/Bucharest"))

    assert next_local.hour == 13
    assert next_local.minute == 17


def test_next_expected_update_can_be_jackpot_window() -> None:
    # Thursday 2026-05-21 18:00 local -> next update should be Thursday 22:07 local (jackpot).
    local_now = datetime(2026, 5, 21, 18, 0, tzinfo=ZoneInfo("Europe/Bucharest"))
    next_update = parse_iso_utc(compute_next_expected_update_at(local_now.astimezone(timezone.utc)))
    next_local = next_update.astimezone(ZoneInfo("Europe/Bucharest"))

    assert next_local.weekday() == 3
    assert next_local.hour == 22
    assert next_local.minute == 7
