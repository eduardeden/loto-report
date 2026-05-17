from __future__ import annotations

from decimal import Decimal

from src.tax import compute_net_values, compute_tax


def test_tax_threshold_10000() -> None:
    assert compute_tax(Decimal("10000")) == Decimal("400.00")


def test_tax_threshold_10001() -> None:
    assert compute_tax(Decimal("10001")) == Decimal("400.20")


def test_tax_threshold_66750() -> None:
    assert compute_tax(Decimal("66750")) == Decimal("11750.00")


def test_tax_threshold_66751() -> None:
    assert compute_tax(Decimal("66751")) == Decimal("11750.40")


def test_compute_net_values() -> None:
    tax, net_ron, net_eur = compute_net_values(Decimal("12000"), Decimal("5.00"))
    assert tax == Decimal("800.00")
    assert net_ron == Decimal("11200.00")
    assert net_eur == Decimal("2240.00")
