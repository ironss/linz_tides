#! /usr/bin/python3

import sqlite3
import linz_normalize

def tide_import(db, tides):
    con = sqlite3.connect(db)
    with con:
        con.execute("""
            CREATE TABLE IF NOT EXISTS tides ( port_authority TEXT, port_name TEXT, timestamp INTEGER, height REAL, source TEXT);
        """)

        con.execute("""
                DELETE FROM tides WHERE source = :filename;
        """, { 'filename': filename } )

        for tide in tides:
            print(tide)
            con.execute("""
                INSERT INTO tides VALUES ( :pauth, :port, :timestamp, :height, :source )
            """, {
                'pauth': tide[0],
                'port': tide[1],
                'timestamp': tide[2].timestamp(),
                'height': tide[3],
                'source': tide[4],
            })



if __name__ == '__main__':
    import argparse
    import os.path
    import sys

    parser = argparse.ArgumentParser(
        description="Import tide predictions from published data files"
    )

    parser.add_argument('-d', '--database', default='tides_db.sqlite3')
    parser.add_argument('filename', nargs='+')
    args = parser.parse_args()

    for filename in args.filename:
        port_name = os.path.split(filename)[1][:-9]
        print("importing: {}: {}...".format(filename, port_name, filename))
        with open(filename, encoding='iso8859-1') as f_in:
            tides = linz_normalize.linz_normalize(filename, port_name, f_in)

        tide_import(args.database, tides)
        print("importing: {}: {}...done".format(filename, port_name))
