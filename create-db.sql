CREATE TABLE IF NOT EXISTS primary_ports (
   name VARCHAR(50),
   id VARCHAR(10),
   latitude REAL,
   longitude REAL,
   mean_sea_level REAL,
     
   PRIMARY KEY (name)
   FOREIGN KEY (name) REFERENCES ports(name)
);

CREATE TABLE IF NOT EXISTS secondary_ports (
   name VARCHAR(50),
   id VARCHAR(10),
   latitude REAL,
   longitude REAL,
   mean_sea_level REAL,

   reference_port VARCHAR(50),
   mean_delta_hw REAL,
   mean_delta_lw REAL,
   range_ratio REAL,
 
   PRIMARY KEY (name)
   FOREIGN KEY (name) REFERENCES ports(name)
   FOREIGN KEY (reference_port) REFERENCES primary_ports(name)
);

CREATE VIEW IF NOT EXISTS ports
  AS    SELECT name, id, latitude, longitude, mean_sea_level, "primary_port"   AS _subtype FROM primary_ports
  UNION SELECT name, id, latitude, longitude, mean_sea_level, "secondary_port" AS _subtype FROM secondary_ports
;

CREATE TABLE IF NOT EXISTS primary_tide_events (
   port_name VARCHAR(50),
   event_time DATETIME,
   event_type VARCHAR(10),
   height_of_tide REAL,

   PRIMARY KEY (port_name, event_time)
   FOREIGN KEY (port_name) REFERENCES primary_ports (name)
);

CREATE VIEW IF NOT EXISTS secondary_tide_events
   AS
      SELECT 
         secondary_ports.name as port_name, 
	      CASE 
	         when event_type="high" then datetime(julianday(event_time) + mean_delta_hw/86400)
	         WHEN event_type="low" then datetime(julianday(event_time) + mean_delta_lw/86400)
	      END AS event_time,
	      event_type AS event_type, 
	      secondary_ports.mean_sea_level + (primary_tide_events.height_of_tide - primary_ports.mean_sea_level) * secondary_ports.range_ratio AS height_of_tide,
	    
	      primary_tide_events.port_name AS reference_port_name, 
	      event_time AS reference_event_time
   
      FROM 
         secondary_ports, 
         primary_ports, 
         primary_tide_events 

      WHERE 
               secondary_ports.reference_port=primary_ports.name
         AND   primary_tide_events.port_name=secondary_ports.reference_port 
;

CREATE VIEW IF NOT EXISTS tide_events 
   AS 
      SELECT port_name, event_time, event_type, height_of_tide, NULL as reference_port, NULL as reference_event_time FROM primary_tide_events
   UNION 
      SELECT port_name, event_time, event_type, height_of_tide, reference_port_name, reference_event_time FROM secondary_tide_events
;

