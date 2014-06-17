#! /usr/bin/lua5.1

-- Convert tidal data from LINZ CVS format into a more friendly format
--    port, date, time, tz, height
--    port, date_time_utc, height


local ports_filename = 'linz_tides.db'

local driver = require 'luasql.sqlite3'
local env = assert(driver.sqlite3())
local cx = assert(env:connect(ports_filename))
local result = assert(cx:execute('PRAGMA foreign_keys = ON'))
local result = assert(cx:setautocommit(false))

local function erase_tides()
   local result = cx:execute('DROP TABLE primary_tide_events')
   local result = cx:commit()
end

local function create_tides()
   local result = assert(cx:execute([[
      CREATE TABLE IF NOT EXISTS primary_tide_events (
         port_name VARCHAR(50),
         event_time DATETIME,
         event_type VARCHAR(10),
         height_of_tide REAL,

         PRIMARY KEY (port_name, event_time)
         FOREIGN KEY (port_name) REFERENCES primary_ports (name)
      );
   ]]))

   local result = assert(cx:execute([[
      CREATE TABLE IF NOT EXISTS secondary_tide_events (
         port_name VARCHAR(50),
         event_time DATETIME,
         event_type VARCHAR(10),
         height_of_tide REAL,
         
         reference_port_name VARCHAR(50),
         reference_event_time DATETIME,

         PRIMARY KEY (port_name, event_time)
         FOREIGN KEY (port_name) REFERENCES secondary_ports (name)
         FOREIGN KEY (reference_port_name, reference_event_time) REFERENCES primary_tide_events (port_name, event_time)
      );
   ]]))

--[=[
   local result = assert(cx:execute([[
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
   ]]))
--]=]

   local result = assert(cx:execute([[
      CREATE VIEW IF NOT EXISTS tide_events 
      AS SELECT port_name, event_time, event_type, height_of_tide, NULL as reference_port, NULL as reference_event_time FROM primary_tide_events
      UNION SELECT port_name, event_time, event_type, height_of_tide, reference_port_name, reference_event_time FROM secondary_tide_events
   ]]))

   local result = assert(cx:execute([[
      CREATE TABLE IF NOT EXISTS primary_tide_event_sources(
         content_id VARCHAR(32),
         filename VARCHAR(100),
         date_imported DATETIME,

         port_name VARCHAR(50),
         year DATETIME,

         PRIMARY KEY (content_id)
         FOREIGN KEY (port_name) REFERENCES primary_ports(name)
      );
   ]]))

   local result = assert(cx:commit())
end   


local ports = require 'linz_ports'

-- -----------
-- Tide events
-- -----------

local function Event_new(e)
   print(e.port, e.timestamp:format('%Y-%m-%d %H:%M:%S', 'UTC'), e.event_type, e.height)
   local result = assert(cx:execute(string.format([[
      INSERT INTO 'primary_tide_events'
      VALUES ("%s", '%s', '%s', '%3.1f')]], e.port, e.timestamp:format('%Y-%m-%d %H:%M:%S', 'UTC'), e.event_type, e.height)
   ))
end


local datetime = require('datetime')

-- Extract tidal data from an open file
local function read_linz_tide_file(f)
   local l1 = f:read('*l')
   local _, port, latitude, longitude = l1:match('^(.-),(.-),(.-),(.-)%c*$')
   local l2 = f:read('*l')
   local l3 = f:read('*l')
   local tz, _ = l3:match('^(.-),(.-)%c*$')
 
--   print(port, tz, latitude, '"'..longitude..'"', tz)
   for l in f:lines() do
--      print(l)
      local day, _, month, year, t1, h1, t2, h2, t3, h3, t4, h4 = l:match('^(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-)%c*$')
      h1 = tonumber(h1)
      h2 = tonumber(h2)
      h3 = tonumber(h3)
      h4 = tonumber(h4)

      if day ~= nil then
         local events = {}

         events[#events+1] = Event_new{ port=port, timestamp=datetime.new{year=year, month=month, day=day, hour=t1:sub(1, 2), min=t1:sub(4, 5), tz=tz}, height=h1, event_type=h1 > h2 and "high" or "low" }
         events[#events+1] = Event_new{ port=port, timestamp=datetime.new{year=year, month=month, day=day, hour=t2:sub(1, 2), min=t2:sub(4, 5), tz=tz}, height=h2, event_type=h2 > h3 and "high" or "low" }
         events[#events+1] = Event_new{ port=port, timestamp=datetime.new{year=year, month=month, day=day, hour=t3:sub(1, 2), min=t3:sub(4, 5), tz=tz}, height=h3, event_type=h3 > h2 and "high" or "low" }
         if (t4 ~= '') then
   --         print (port, year, month, day, tz, t4, h4)
            events[#events+1] = Event_new{ port=port, timestamp=datetime.new{year=year, month=month, day=day, hour=t4:sub(1, 2), min=t4:sub(4, 5), tz=tz}, height=h4, event_type=h4 > h3 and "high" or "low" }
         end
      end
   end
end


local file_id = require 'file_id'
local function read_linz_tide_filename(filename)
   local content_id = file_id.md5sum(filename)
   local f = io.open(filename)
   local events = read_linz_tide_file(f)

   print(content_id, filename)
   local result = assert(cx:execute(string.format([[
      INSERT INTO 'primary_tide_event_sources'
      VALUES ("%s", '%s', datetime('now'), 'Auckland', '')]], content_id, filename)
   ))

   local result = assert(cx:commit())

   return events
end


local function get_events_primary(port, start_date, end_date)
   local port_name = port.name
   local cur = assert(cx:execute(string.format([[
      SELECT * FROM primary_tide_events 
      WHERE port_name = "%s" 
         AND event_time > datetime("%s") 
         AND event_time < datetime("%s")
   ]], port_name, start_date, end_date)))
   
   local events = {}
   row = cur:fetch({}, "a")
   while row do
      events[#events+1] = row
      row = cur:fetch({}, "a")
   end
   cur:close()

   return events
end

local function get_events_secondary(port, start_date, end_date)
   print(port.name)
   for k, v in pairs(port) do
      print(k, v)
   end
   local secondary_port = ports.find_secondary(port.name)
   local reference_port = ports.find(secondary_port.reference_port)
   local primary_events = get_events_primary(reference_port, start_date, end_date)
   
   local events = {}
   for _, primary_event in ipairs(primary_events) do
      local ev = {}      
      ev.reference_port = primary_event.port_name
      ev.reference_event_time = primary_event.event_time
      ev.event_type = primary_event.event_type
      ev.port_name = port.name
      
      -- For details on how to calculate times and heights of tides at secondary ports, refer to
      -- http://www.linz.govt.nz/sites/default/files/docs/hydro/tidal-info/tide-tables/mfth-of-hlw.pdf
      if primary_event.event_type == 'high' then
         ev.event_time = datetime.new(ev.reference_event_time):add(secondary_port.mean_delta_hw):format('%Y-%m-%d %H:%M:%S')
      elseif ev.event_type == 'low' then
          ev.event_time = datetime.new(ev.reference_event_time):add(secondary_port.mean_delta_lw):format('%Y-%m-%d %H:%M:%S')
      end
      
      local primary_rise_of_tide = primary_event.height_of_tide - reference_port.mean_sea_level
      local rise_of_tide = primary_rise_of_tide * secondary_port.range_ratio
      ev.height_of_tide = rise_of_tide + port.mean_sea_level

      events[#events+1] = ev
   end
   
   return events
end


local function get_events(port, start_date, end_date)
   if type(port) == 'string' then
      port = ports.find(port)
   end

--   print(port, port.name, port._subtype)
   if port._subtype == 'primary_port' then
      return get_events_primary(port, start_date, end_date)
   else
      return get_events_secondary(port, start_date, end_date)
   end
end


local M={}

M.erase_tables = erase_tides
M.create_tables = create_tides
M.populate_tables = read_linz_tide_filename

M.get_events = get_events

return M

