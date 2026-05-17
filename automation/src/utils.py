from __future__ import annotations

from datetime import datetime, timedelta, timezone
from decimal import Decimal, ROUND_HALF_UP
from typing import Iterable

from .config import (
    FX_HOUR,
    FX_MINUTE,
    JACKPOT_HOUR,
    JACKPOT_MINUTE,
    JACKPOT_WEEKDAYS,
    LOCAL_TIMEZONE,
)

TWOPLACES = Decimal("0.01")


def round_money(value: Decimal) -> Decimal:
    return value.quantize(TWOPLACES, rounding=ROUND_HALF_UP)


def amount_str_to_decimal(value: str) -> Decimal:
    normalized = value.replace(" ", "").replace(".", "").replace(",", ".")
    return Decimal(normalized)


def decimal_to_float(value: Decimal) -> float:
    return float(round_money(value))


def isoformat_utc(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).replace(microsecond=0).isoformat()


def parse_iso_utc(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(timezone.utc)


def _next_local_datetime(
    now_local: datetime,
    weekdays: Iterable[int] | None,
    hour: int,
    minute: int,
) -> datetime:
    candidate = now_local.replace(hour=hour, minute=minute, second=0, microsecond=0)

    if weekdays is None:
        if candidate <= now_local:
            candidate += timedelta(days=1)
        return candidate

    for days_ahead in range(0, 8):
        probe = candidate + timedelta(days=days_ahead)
        if probe.weekday() in weekdays and probe > now_local:
            return probe

    # Should never happen due to 8-day window, but safe fallback.
    return candidate + timedelta(days=7)


def compute_next_expected_update_at(now_utc: datetime) -> str:
    now_local = now_utc.astimezone(LOCAL_TIMEZONE)

    next_jackpot = _next_local_datetime(
        now_local,
        JACKPOT_WEEKDAYS,
        JACKPOT_HOUR,
        JACKPOT_MINUTE,
    )
    next_fx = _next_local_datetime(
        now_local,
        None,
        FX_HOUR,
        FX_MINUTE,
    )

    next_update = min(next_jackpot, next_fx)
    return isoformat_utc(next_update.astimezone(timezone.utc))
