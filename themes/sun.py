#!/usr/bin/env python3
"""Day or night for `theme auto`: today's sunrise and sunset from wttr.in, cached for the day.

    sun.py phase    print 'light' between sunrise and sunset, else 'dark'
    sun.py times    print today's sunrise and sunset as HH:MM HH:MM

wttr.in locates the machine by IP, or uses WEATHER_LOC when set (the same location the bar's weather
uses). Its times are local to that place, so they are compared with the local clock. One fetch a day is
cached in $XDG_CACHE_HOME/theme-sun; with no network and no cache for today, FALLBACK applies."""
import datetime as dt
import os
import sys
import urllib.parse
import urllib.request
from pathlib import Path

FALLBACK = ('07:00', '19:00')
FETCH_TIMEOUT_S = 8
URL = 'https://wttr.in/{loc}?format=%S+%s'


def cache_path():
    base = os.environ.get('XDG_CACHE_HOME') or os.path.expanduser('~/.cache')
    return Path(base) / 'theme-sun'


def parse(text):
    """'06:13:29 17:39:44' -> ('06:13', '17:39'); None for anything else (an error page, an empty body)."""
    parts = text.split()
    if len(parts) != 2:
        return None
    out = []
    for p in parts:
        try:
            out.append(dt.datetime.strptime(p, '%H:%M:%S').strftime('%H:%M'))
        except ValueError:
            return None
    rise, set_ = out
    return (rise, set_) if rise < set_ else None


def fetch():
    loc = urllib.parse.quote(os.environ.get('WEATHER_LOC', ''))
    req = urllib.request.Request(URL.format(loc=loc), headers={'User-Agent': 'curl'})
    try:
        with urllib.request.urlopen(req, timeout=FETCH_TIMEOUT_S) as r:
            return parse(r.read().decode('utf-8', 'replace'))
    except OSError:
        return None


def times(today, cache, fetcher=fetch):
    """Sunrise and sunset for `today` (a date): the cache when it holds today's, else a fetch (cached on
    success), else the last cached times, else FALLBACK."""
    cached = None
    if cache.is_file():
        fields = cache.read_text().split()
        if len(fields) == 3:
            cached = (fields[1], fields[2])
            if fields[0] == today.isoformat():
                return cached
    got = fetcher()
    if got:
        cache.parent.mkdir(parents=True, exist_ok=True)
        cache.write_text(f'{today.isoformat()} {got[0]} {got[1]}\n')
        return got
    return cached or FALLBACK


def phase(now, rise, set_):
    """'light' when HH:MM `now` is in [rise, set), else 'dark'."""
    return 'light' if rise <= now < set_ else 'dark'


def main(argv):
    now = dt.datetime.now()
    rise, set_ = times(now.date(), cache_path())
    if argv == ['phase']:
        print(phase(now.strftime('%H:%M'), rise, set_))
        return 0
    if argv == ['times']:
        print(rise, set_)
        return 0
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
