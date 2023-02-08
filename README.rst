linz_tides
##########

Predict tides at various places around New Zealand tide from LINZ tide data.


Purpose
=======

* Calculate times of high and low tide at selected locations (ports)
  for specific time periods
  
    * eg. tides at ports around Tasman Bay (Nelson, Port Motueka, Kaiteriteri, etc)
      between Christmas and New Year 2021

* Interpolate between tidal extremes to calculate the tide height at times between
  the extremes, to allow plotting of a graph


Todo
====

[X] Import tidal data for primary ports from LINZ tidal tables in CSV format
  
[ ] Import secondary port data from LINZ data in CSV format

[ ] Calculate tidal extremes for secondary ports

    [ ] ... when new primary port data is added
    
    [ ] ... from existing primary port data
    
    [ ] ... when a forecast for a range of dates is requested

[ ] Format tidal extremes into a compact CSV format

[X] Calculate tidal height at a time between extremes at a specific primary port

    [ ] ... at a specific secondary port -- should Just Work (tm)

[X] Create a Munin plugin to calculate tidal height at a port, at the time the
    request is made

    [ ] Install Munin tides plugin on a suitable server, and hook up to a 
        suitable Munin master


Instructions
============

1. Decide on the prediction dates. I usually allow 1 day before and 2--3
   days after the planned travel.

2. Decide on the region that you will be travelling, and the primary and
   secondary ports in that region that you want predictions for.
   
3. Create a 'trip', with a name that ties together the region you will 
   be travelling in and the dates of the trip.

4. Download tide tables for the primary ports involved over the dates of 
   travel.
   
5. Ensure that the secondary ports data is up-to-date.

6. 



Database size
=============

Extremes
--------

* Number of ports:  ~250  (15 primary, 220 secondary)

* Number of events: 1460 per year per port (4 per day for 365 days)

* Number of events: 22000 per year (1460 per year per port for 15 primary ports)

* Number of events: 365000 per year (1460 per year per port for 250 ports)

We can avoid calculating events for all secondary ports by only calculating
events for specific trips -- a small number of ports over a small timeframe.


Interpolations
--------------

* Number of points (5 minutes): 105120 per port per year

* Number of points (5 minutes): 1.5 million per year (105 K x 15 primary ports)

* Number of points (5 minutes): 26 million per year (105 K x 250 ports)



Features
========

1. Read tide predictions for primary ports from a CSV file downloaded from LINZ -- DONE

2. Adjust to NZDT when appropriate -- DONE

3. Calculate tide time prediction for secondary ports -- DONE -- read data from LINZ data file..

4. Calculate tide height predicition for secondary ports -- DONE

5. Set up a number of different regions, with ports in that region -- DONE

6. Set up a number of trips, with a region that the trip will
   take place, a start date and an end date  -- DONE


TODO
----

1. Find timezone library, rather than using my own.

2. Choose port and time range to generate output for

3. Format output for easy import into spreadsheet::

      Date        Nelson       Motueka      Astrolabe…   Sun      Moon
      2013-12-27  0506 H 3.3   0511 H 3.3   0446 H 3.7            R 0129
      Friday      1111 L 1.4   1130 L 1.5   1051 L 1.4            S 1458
                  1744 H 3.4   1749 H 3.4   1724 H 3.8
                  2353 L 1.2                2333 L 1.1
                  
      2013-12-28               0012 L 1.3                R 0554   R 0203
      Saturday    0615 H 3.3   0620 H 3.3   0555 H 3.7   S 2102   S 1603
                  1228 L 1.3   1247 L 1.4   1208 L 1.3
                  1851 H 3.4   1856 H 3.4   1831 H 3.8
               
      2013-12-29  0059 L 1.1   0118 L 1.2   0039 L 1.0            R 0243
      Sunday      0729 H 3.5   0734 H 3.5   0709 H 3.9            S 1710
                  1340 L 1.2   1359 L 1.3   1320 L 1.1
                  1955 H 3.6   2000 H 3.6   1935 H 4.0

4. Use a view for the secondary tide events rather than a table. Don't
   think this is possible, as we have to do a cartesian product of
      secondary_ports x primary_tide_events

5. 

