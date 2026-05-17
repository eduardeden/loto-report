from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime, timezone
from decimal import Decimal
from pathlib import Path


@dataclass
class LastSuccessfulState:
    loto649_gross_ron: Decimal | None
    joker_gross_ron: Decimal | None
    eur_ron_rate: Decimal | None
    fx_rate_date: str | None


@dataclass
class State:
    last_successful: LastSuccessfulState
    timestamps: dict[str, str]


def load_state(path: Path) -> State:
    if not path.exists():
        return State(
            last_successful=LastSuccessfulState(None, None, None, None),
            timestamps={},
        )

    raw = json.loads(path.read_text(encoding="utf-8"))
    ls = raw.get("last_successful", {})
    return State(
        last_successful=LastSuccessfulState(
            loto649_gross_ron=Decimal(ls["loto649_gross_ron"]) if ls.get("loto649_gross_ron") else None,
            joker_gross_ron=Decimal(ls["joker_gross_ron"]) if ls.get("joker_gross_ron") else None,
            eur_ron_rate=Decimal(ls["eur_ron_rate"]) if ls.get("eur_ron_rate") else None,
            fx_rate_date=ls.get("fx_rate_date"),
        ),
        timestamps=raw.get("timestamps", {}),
    )


def save_state(path: Path, state: State) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)

    payload = {
        "last_successful": {
            "loto649_gross_ron": str(state.last_successful.loto649_gross_ron)
            if state.last_successful.loto649_gross_ron is not None
            else None,
            "joker_gross_ron": str(state.last_successful.joker_gross_ron)
            if state.last_successful.joker_gross_ron is not None
            else None,
            "eur_ron_rate": str(state.last_successful.eur_ron_rate)
            if state.last_successful.eur_ron_rate is not None
            else None,
            "fx_rate_date": state.last_successful.fx_rate_date,
        },
        "timestamps": state.timestamps,
        "updated_at_utc": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
    }

    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
