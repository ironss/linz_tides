#! /bin/sh

csvfilename=${1?"Must provide CSV filename"}

echo Importing $csvfilename...

sqlite3 linz_tides.db <<EOF
CREATE TABLE IF NOT EXISTS tides ( port TEXT, datetime TEXT, timestamp INTEGER, height REAL); 
.import --csv $csvfilename tides
EOF

echo Importing $csvfilename...done

