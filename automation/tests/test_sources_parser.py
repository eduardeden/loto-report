from __future__ import annotations

from decimal import Decimal

from src.sources import parse_bnr_fx_rate, parse_loto_gross_values


def test_parse_loto_gross_values() -> None:
    html = """
    <html><body>
      <div>REPORT LOTO 6/49</div>
      <div>REPORTURI</div>
      <div>24.787.237,04</div>
      <div>REPORT JOKER</div>
      <div>REPORTURI</div>
      <div>17.005.105,50</div>
    </body></html>
    """

    result = parse_loto_gross_values(html)
    assert result.loto649 == Decimal("24787237.04")
    assert result.joker == Decimal("17005105.50")


def test_parse_bnr_fx_rate() -> None:
    xml_payload = """
    <DataSet xmlns="http://www.bnr.ro/xsd">
      <Body>
        <Cube date="2026-05-17">
          <Rate currency="USD">4.4500</Rate>
          <Rate currency="EUR">5.1000</Rate>
        </Cube>
      </Body>
    </DataSet>
    """

    fx = parse_bnr_fx_rate(xml_payload)
    assert fx.rate_date == "2026-05-17"
    assert fx.eur_ron == Decimal("5.1000")
