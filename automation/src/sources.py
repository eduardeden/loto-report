from __future__ import annotations

import re
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from decimal import Decimal

import requests
from bs4 import BeautifulSoup

from .config import BNR_XML_URL, LOTO_URL, REQUEST_TIMEOUT_SECONDS, USER_AGENT
from .utils import amount_str_to_decimal

MONEY_PATTERN = r"([0-9]{1,3}(?:\.[0-9]{3})*,[0-9]{2})"
LOTO649_REGEX = re.compile(
    rf"REPORT\s+LOTO\s*6/49.*?REPORTURI\s*{MONEY_PATTERN}",
    re.IGNORECASE | re.DOTALL,
)
JOKER_REGEX = re.compile(
    rf"REPORT\s+JOKER.*?REPORTURI\s*{MONEY_PATTERN}",
    re.IGNORECASE | re.DOTALL,
)


@dataclass(frozen=True)
class LotoGrossValues:
    loto649: Decimal
    joker: Decimal


@dataclass(frozen=True)
class FxRate:
    eur_ron: Decimal
    rate_date: str


class SourceError(RuntimeError):
    pass


def _default_headers() -> dict[str, str]:
    return {"User-Agent": USER_AGENT}


def parse_loto_gross_values(html: str) -> LotoGrossValues:
    soup = BeautifulSoup(html, "html.parser")
    text = soup.get_text("\n", strip=True)

    loto_match = LOTO649_REGEX.search(text)
    joker_match = JOKER_REGEX.search(text)

    if not loto_match:
        raise SourceError("Could not find Loto 6/49 report value in loto.ro page")
    if not joker_match:
        raise SourceError("Could not find Joker report value in loto.ro page")

    loto649 = amount_str_to_decimal(loto_match.group(1))
    joker = amount_str_to_decimal(joker_match.group(1))

    return LotoGrossValues(loto649=loto649, joker=joker)


def fetch_loto_gross_values() -> LotoGrossValues:
    response = requests.get(
        LOTO_URL,
        headers=_default_headers(),
        timeout=REQUEST_TIMEOUT_SECONDS,
    )
    response.raise_for_status()
    return parse_loto_gross_values(response.text)


def parse_bnr_fx_rate(xml_payload: str) -> FxRate:
    try:
        root = ET.fromstring(xml_payload)
    except ET.ParseError as exc:
        raise SourceError("Could not parse BNR XML") from exc

    for cube in root.findall(".//{*}Cube"):
        cube_date = cube.attrib.get("date")
        for rate in cube.findall("{*}Rate"):
            if rate.attrib.get("currency") == "EUR" and rate.text:
                eur_ron = Decimal(rate.text.strip())
                if not cube_date:
                    raise SourceError("BNR XML missing date for EUR rate")
                return FxRate(eur_ron=eur_ron, rate_date=cube_date)

    raise SourceError("Could not find EUR rate in BNR XML")


def fetch_bnr_fx_rate() -> FxRate:
    response = requests.get(
        BNR_XML_URL,
        headers=_default_headers(),
        timeout=REQUEST_TIMEOUT_SECONDS,
    )
    response.raise_for_status()
    return parse_bnr_fx_rate(response.text)
