#! /bin/sh

# Testing sql statement to generate the list of secondary events.


sqlite3 linz_tides.db '
SELECT 
   secondary_ports.name, 
   CASE 
      when event_type="high" then datetime(julianday(event_time) + mean_delta_hw/86400)
      WHEN event_type="low" then datetime(julianday(event_time) + mean_delta_lw/86400)
   END,
   event_type, 
   secondary_ports.mean_sea_level + (primary_tide_events.height_of_tide - primary_ports.mean_sea_level) * secondary_ports.range_ratio,

   primary_tide_events.port_name, event_time, event_type, height_of_tide, 
   primary_ports.mean_sea_level, 
   secondary_ports.mean_sea_level, 
   secondary_ports.range_ratio,
   secondary_ports.mean_delta_hw, secondary_ports.mean_delta_lw

FROM 
   region_ports, 
   secondary_ports, 
   primary_ports, 
   primary_tide_events 
WHERE 
         region_name="Bay of Islands" 
   AND   primary_tide_events.event_time BETWEEN datetime("2014-12-25") AND datetime("2015-01-03")
   AND   region_ports.port_name=secondary_ports.name
   AND   secondary_ports.reference_port=primary_ports.name
   AND   primary_tide_events.port_name=secondary_ports.reference_port 
;'

