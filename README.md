linz_tides
==========

Lua module to calculate New Zealand tide prediction from the LINZ tide data.

1. Read tide predictions for primary ports from a CSV file downloaded from LINZ -- DONE

2. Adjust to NZDT when appropriate -- DONE

3. Calculate tide time prediction for secondary ports -- DONE -- read data from LINZ data file..

4. Calculate tide height predicition for secondary ports -- DONE


TODO
----

1. Find timezone library, rather than using my own.

2. Choose port and time range to generate output for

3. Format output for easy import into spreadsheet

      Date        Nelson		Motueka		Astrolabe…	Sun		Moon
      2013-12-27	0506 H 3.3	0511 H 3.3	0446 H 3.7				R 0129
      Friday		1111 L 1.4	1130 L 1.5	1051 L 1.4				S 1458
				      1744 H 3.4	1749 H 3.4	1724 H 3.8
				      2353 L 1.2					2333 L 1.1
						
      2013-12-28					0012 L 1.3					R 0554	R 0203
      Saturday		0615 H 3.3	0620 H 3.3	0555 H 3.7	S 2102	S 1603
				      1228 L 1.3	1247 L 1.4	1208 L 1.3
				      1851 H 3.4	1856 H 3.4	1831 H 3.8
					
      2013-12-29	0059 L 1.1	0118 L 1.2	0039 L 1.0				R 0243
      Sunday		0729 H 3.5	0734 H 3.5	0709 H 3.9				S 1710
				      1340 L 1.2	1359 L 1.3	1320 L 1.1
				      1955 H 3.6	2000 H 3.6	1935 H 4.0

