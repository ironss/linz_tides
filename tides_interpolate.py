import sqlite3
import math


def tide_interpolate(db, port, time_ts):
    con = sqlite3.connect(db)
    res = con.execute("""
        WITH
            t1 as (
                SELECT timestamp, height
                FROM tides
                WHERE port = :port AND timestamp >= :ts
                ORDER BY timestamp ASC
                LIMIT 1
            ),
            t2 as (
                SELECT timestamp, height
                FROM tides
                WHERE port = :port AND timestamp < :ts
                ORDER BY timestamp DESC
                LIMIT 1
            )

        SELECT * from t1
        UNION
        SELECT * from t2;
    """, {'port':port, 'ts':time_ts})

    rows = res.fetchall()
    ts_prev, height_prev = rows[0]
    ts_next, height_next = rows[1]

    phase = (time_ts - ts_prev) / (ts_next - ts_prev) * math.pi
    height = (1 + math.cos(phase))/2 * (height_prev - height_next) + height_next

    return port, time_ts, height


if __name__ == '__main__':
    import argparse
    import sys

    import dateparser
    parse_date = dateparser.parse


    parser = argparse.ArgumentParser(
        description="Calculate tide height at any time."
    )
    parser.add_argument('-d', '--database', default='tides_db.sqlite3')
    parser.add_argument('-t', '--time', action='append')
    parser.add_argument('port', nargs='+')
    args = parser.parse_args()

    if not args.time:
        args.time = ['now']

    ports = args.port
    db_name = args.database

    timestamps_dt = []
    for dt_str in args.time:
        try:
            dt = parse_date(dt_str, settings={'RETURN_AS_TIMEZONE_AWARE': True})
        except dateutil.parser._parser.ParserError:
            print('{}: unrecognised time'.format(dt_str))
            dt = None

        if dt:
            timestamps_dt.append(dt)

    for port in ports:
        for dt in timestamps_dt:
            _, _, height = tide_interpolate(db_name, port, dt.timestamp())
            print(port, dt, height)
