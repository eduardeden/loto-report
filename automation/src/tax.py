from __future__ import annotations

from decimal import Decimal

from .utils import round_money

THRESHOLD_1 = Decimal("10000")
THRESHOLD_2 = Decimal("66750")


def compute_tax(gross_ron: Decimal) -> Decimal:
    if gross_ron <= THRESHOLD_1:
        tax = gross_ron * Decimal("0.04")
    elif gross_ron <= THRESHOLD_2:
        tax = Decimal("400") + (gross_ron - THRESHOLD_1) * Decimal("0.20")
    else:
        tax = Decimal("11750") + (gross_ron - THRESHOLD_2) * Decimal("0.40")

    return round_money(tax)


def compute_net_values(gross_ron: Decimal, eur_ron_rate: Decimal) -> tuple[Decimal, Decimal, Decimal]:
    if gross_ron < 0:
        raise ValueError("gross_ron must be >= 0")
    if eur_ron_rate <= 0:
        raise ValueError("eur_ron_rate must be > 0")

    tax = compute_tax(gross_ron)
    net_ron = max(Decimal("0"), gross_ron - tax)
    net_eur = net_ron / eur_ron_rate

    return round_money(tax), round_money(net_ron), round_money(net_eur)
