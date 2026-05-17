from __future__ import annotations

import json
from decimal import Decimal

from src.main import build_report
from src.sources import FxRate, LotoGrossValues


def test_build_report_success(tmp_path, monkeypatch) -> None:
    state_path = tmp_path / "state.json"
    report_path = tmp_path / "report.json"

    monkeypatch.setattr(
        "src.main.fetch_loto_gross_values",
        lambda: LotoGrossValues(loto649=Decimal("20000"), joker=Decimal("30000")),
    )
    monkeypatch.setattr(
        "src.main.fetch_bnr_fx_rate",
        lambda: FxRate(eur_ron=Decimal("5.00"), rate_date="2026-05-17"),
    )

    report = build_report("jackpot", state_path, report_path)
    assert report["stale"] is False
    assert report["games"]["loto649"]["gross_ron"] == 20000.0
    assert report["games"]["joker"]["gross_ron"] == 30000.0


def test_build_report_fallback_stale(tmp_path, monkeypatch) -> None:
    state_path = tmp_path / "state.json"
    report_path = tmp_path / "report.json"

    state_path.write_text(
        json.dumps(
            {
                "last_successful": {
                    "loto649_gross_ron": "15000",
                    "joker_gross_ron": "25000",
                    "eur_ron_rate": "5.00",
                    "fx_rate_date": "2026-05-16",
                },
                "timestamps": {
                    "loto_fetched_at_utc": "2026-05-16T19:07:00+00:00",
                    "fx_fetched_at_utc": "2026-05-16T10:17:00+00:00",
                },
            }
        ),
        encoding="utf-8",
    )

    def _fail_loto():
        raise RuntimeError("loto down")

    def _fail_fx():
        raise RuntimeError("fx down")

    monkeypatch.setattr("src.main.fetch_loto_gross_values", _fail_loto)
    monkeypatch.setattr("src.main.fetch_bnr_fx_rate", _fail_fx)

    report = build_report("jackpot", state_path, report_path)
    assert report["stale"] is True
    assert report["games"]["loto649"]["stale"] is True
    assert report["games"]["joker"]["stale"] is True
    assert len(report["errors"]) == 2

def test_fx_daily_with_cached_gross_not_stale_when_fx_fresh(tmp_path, monkeypatch) -> None:
    state_path = tmp_path / "state.json"
    report_path = tmp_path / "report.json"

    state_path.write_text(
        json.dumps(
            {
                "last_successful": {
                    "loto649_gross_ron": "15000",
                    "joker_gross_ron": "25000",
                    "eur_ron_rate": "5.00",
                    "fx_rate_date": "2026-05-16",
                },
                "timestamps": {
                    "loto_fetched_at_utc": "2026-05-16T19:07:00+00:00",
                    "fx_fetched_at_utc": "2026-05-16T10:17:00+00:00",
                },
            }
        ),
        encoding="utf-8",
    )

    monkeypatch.setattr(
        "src.main.fetch_bnr_fx_rate",
        lambda: FxRate(eur_ron=Decimal("5.10"), rate_date="2026-05-17"),
    )

    report = build_report("fx_daily", state_path, report_path)
    assert report["stale"] is False
    assert report["games"]["loto649"]["stale"] is False
    assert report["games"]["joker"]["stale"] is False
