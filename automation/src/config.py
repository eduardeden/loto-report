from zoneinfo import ZoneInfo

LOTO_URL = "https://www.loto.ro/"
# Public BNR XML feed for daily exchange rates.
BNR_XML_URL = "https://www.bnr.ro/nbrfxrates.xml"

LOCAL_TIMEZONE = ZoneInfo("Europe/Bucharest")

JACKPOT_WEEKDAYS = {3, 6}  # Thursday=3, Sunday=6
JACKPOT_HOUR = 22
JACKPOT_MINUTE = 7

FX_HOUR = 13
FX_MINUTE = 17

REQUEST_TIMEOUT_SECONDS = 20
USER_AGENT = "LotoNetTrackerBot/1.0 (+https://github.com/)"
