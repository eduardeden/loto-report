from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from decimal import Decimal
from pathlib import Path

from .sources import SourceError, fetch_bnr_fx_rate, fetch_loto_gross_values
from .state import LastSuccessfulState, State, load_state, save_state
from .tax import compute_net_values
from .utils import compute_next_expected_update_at, decimal_to_float, isoformat_utc


def _update_reason(mode: str) -> str:
    return {
        "jackpot": "jackpot_schedule",
        "fx_daily": "fx_daily",
        "manual": "manual",
    }[mode]


def build_report(mode: str, state_path: Path, report_path: Path) -> dict:
    now_utc = datetime.now(timezone.utc)
    state = load_state(state_path)
    errors: list[str] = []

    loto_fresh = False
    fx_fresh = False

    loto649_gross = state.last_successful.loto649_gross_ron
    joker_gross = state.last_successful.joker_gross_ron
    eur_ron_rate = state.last_successful.eur_ron_rate
    fx_rate_date = state.last_successful.fx_rate_date

    should_fetch_loto = mode in {"jackpot", "manual"}
    should_fetch_fx = mode in {"jackpot", "fx_daily", "manual"}

    if should_fetch_loto:
        try:
            loto_values = fetch_loto_gross_values()
            loto649_gross = loto_values.loto649
            joker_gross = loto_values.joker
            loto_fresh = True
            state.timestamps["loto_fetched_at_utc"] = isoformat_utc(now_utc)
        except (SourceError, Exception) as exc:  # noqa: BLE001
            errors.append(f"loto_fetch_failed: {exc}")

    if should_fetch_fx:
        try:
            fx = fetch_bnr_fx_rate()
            eur_ron_rate = fx.eur_ron
            fx_rate_date = fx.rate_date
            fx_fresh = True
            state.timestamps["fx_fetched_at_utc"] = isoformat_utc(now_utc)
        except (SourceError, Exception) as exc:  # noqa: BLE001
            errors.append(f"fx_fetch_failed: {exc}")

    # Bootstrap fallback in FX-only mode: try to recover jackpot values if state was empty.
    if mode == "fx_daily" and (loto649_gross is None or joker_gross is None):
        try:
            loto_values = fetch_loto_gross_values()
            loto649_gross = loto_values.loto649
            joker_gross = loto_values.joker
            loto_fresh = True
            state.timestamps["loto_fetched_at_utc"] = isoformat_utc(now_utc)
        except (SourceError, Exception) as exc:  # noqa: BLE001
            errors.append(f"loto_bootstrap_failed: {exc}")

    if loto649_gross is None or joker_gross is None:
        raise RuntimeError(
            "Missing jackpot gross values for Loto 6/49 or Joker. "
            "No fresh data and no valid cached state available."
        )
    if eur_ron_rate is None or fx_rate_date is None:
        raise RuntimeError(
            "Missing EUR/RON rate. No fresh data and no valid cached state available."
        )

    loto649_tax, loto649_net_ron, loto649_net_eur = compute_net_values(loto649_gross, eur_ron_rate)
    joker_tax, joker_net_ron, joker_net_eur = compute_net_values(joker_gross, eur_ron_rate)

    stale_loto = should_fetch_loto and not loto_fresh
    stale_fx = should_fetch_fx and not fx_fresh
    stale_value = stale_loto or stale_fx

    report = {
        "generated_at_utc": isoformat_utc(now_utc),
        "source_timestamps": {
            "loto_fetched_at_utc": state.timestamps.get("loto_fetched_at_utc"),
            "fx_fetched_at_utc": state.timestamps.get("fx_fetched_at_utc"),
            "fx_rate_date": fx_rate_date,
        },
        "eur_ron_rate": decimal_to_float(eur_ron_rate),
        "fx_rate_date": fx_rate_date,
        "games": {
            "loto649": {
                "gross_ron": decimal_to_float(loto649_gross),
                "tax_ron": decimal_to_float(loto649_tax),
                "net_ron": decimal_to_float(loto649_net_ron),
                "net_eur": decimal_to_float(loto649_net_eur),
                "stale": stale_value,
            },
            "joker": {
                "gross_ron": decimal_to_float(joker_gross),
                "tax_ron": decimal_to_float(joker_tax),
                "net_ron": decimal_to_float(joker_net_ron),
                "net_eur": decimal_to_float(joker_net_eur),
                "stale": stale_value,
            },
        },
        "next_expected_update_at": compute_next_expected_update_at(now_utc),
        "update_reason": _update_reason(mode),
        "stale": stale_value,
        "errors": errors,
    }

    state.last_successful = LastSuccessfulState(
        loto649_gross_ron=loto649_gross,
        joker_gross_ron=joker_gross,
        eur_ron_rate=eur_ron_rate,
        fx_rate_date=fx_rate_date,
    )
    save_state(state_path, state)

    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(
        json.dumps(report, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    return report


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate LotoNetTracker report.json")
    parser.add_argument(
        "--mode",
        required=True,
        choices=["jackpot", "fx_daily", "manual"],
        help="Run mode used for scheduler metadata.",
    )
    parser.add_argument(
        "--state-path",
        default="automation/state/state.json",
        help="Path to local state file.",
    )
    parser.add_argument(
        "--report-path",
        default="docs/report.json",
        help="Path for generated public JSON file.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    state_path = Path(args.state_path)
    report_path = Path(args.report_path)
    build_report(args.mode, state_path, report_path)


if __name__ == "__main__":
    main()
