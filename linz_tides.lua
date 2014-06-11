#! /usr/bin/lua5.1

-- Convert tidal data from LINZ CVS format into a more friendly format
--    port, date, time, tz, height
--    port, date_time_utc, height

local linz_ports_data_filename = 'secondaryports2013-14.csv'
local ports_filename = 'linz_ports.db'

local driver = require 'luasql.sqlite3'
local env = assert(driver.sqlite3())
local cx = assert(env:connect(ports_filename))

local function clear_ports()
   local result = assert(cx:execute('PRAGMA foreign_keys = ON'))
   local result = cx:execute('DROP TABLE secondary_ports')
   local result = cx:execute('DROP TABLE primary_ports')
   local result = cx:execute('DROP TABLE ports')

   local result = assert(cx:execute([[
      CREATE TABLE ports(
         name varchar(50),
         id varchar(10),
         latitude real,
         longitude real,
         mean_sea_level real,

         PRIMARY KEY (name, id)
      )
   ]]))
   
   local result = assert(cx:execute([[
      CREATE TABLE primary_ports(
         name varchar(50),
         id varchar(10),
         
         PRIMARY KEY (name)
         FOREIGN KEY (name, id) REFERENCES ports(name, id)
      )
   ]]))
   
   local result = assert(cx:execute([[
      CREATE TABLE secondary_ports(
         name varchar(50),
         id varchar(10),
         reference_port varchar(50),
         mean_delta_hw real,
         mean_delta_lw real,
         ratio real,
         
         PRIMARY KEY (name, id)
         FOREIGN KEY (name, id) REFERENCES ports(name, id)
         FOREIGN KEY (reference_port) REFERENCES primary_ports(name)
      )
   ]]))
end

-- -----------------
-- New Zealand ports
-- -----------------

local port_name_translation = 
{
   ['AUCKLAND']='Auckland',
   ['BLUFF']='Bluff',
   ['LYTTELTON']='Lyttelton',
   ['MARSDEN POINT']='Marsden Point',
   ['NELSON']='Nelson',
   ['NAPIER']='Napier',
   ['ONEHUNGA']='Onehunga',
   ['PICTON']='Picton',
   ['PORT CHALMERS']='Port Chalmers',
   ['PORT TARANAKI']='Port Taranaki',
   ['TAURANGA']='Tauranga',
   ['TIMARU']='Timaru',
   ['WELLINGTON']='Wellington',
   ['WESTPORT']='Westport',
}


local ports = {}
local ports_by_id = {}
local primary_ports = {}
local secondary_ports = {}

local function Port_new(p)
   local name = p.name
   ports[name] = p
   
   local result = assert(cx:execute(string.format([[
      INSERT INTO 'ports'
      VALUES ("%s", '%s', '%3.6f', '%3.6f', '%3.1f')]], p.name, p.no, p.latitude, p.longitude, p.MSL)
   ))
   return p
end

local function Primary_Port_new(p)
   local name = p.name
   Port_new(p)
   primary_ports[name] = p
   
   local result = assert(cx:execute(string.format([[
      INSERT INTO 'primary_ports'
      VALUES ("%s", '%s')]], p.name, p.no)
   ))
   return p
end

local function Secondary_Port_new(p)
   local name = p.name
   Port_new(p)
   secondary_ports[name] = p

   local result = assert(cx:execute(string.format([[
      INSERT INTO 'secondary_ports'
      VALUES ("%s", '%s', '%s', '%6.1f', '%6.1f', '%6.2f')]], p.name, p.no, p.reference, p.high_delta_mean, p.low_delta_mean, p.ratio)
   ))
   return p
end

local function create_linz_ports_database(filename)
   local f = io.open(filename)
   local l1 = f:read('*l')
   local l2 = f:read('*l')
   local l3 = f:read('*l')
   
   local reference = ''
   local ports = {}
   for l in f:lines() do
      --print(l)
      local no, name, latd, latm, longd, longm, meanHW, _, meanLW, _, _, _, _, _, MSL, ratio = l:match('^(.-),(.-),(.-),(.-),(.-),(.-)W?,(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-).*$')
      print(no, name, latd, latm, longd, longm, meanHW, meanLW, MSL, ratio)
      
      if no ~= '' then  -- Avoid blank lines and the region heading lines
         local port
         local latitude = tonumber(latd) + tonumber(latm) / 60
         local longitude = tonumber(longd) + tonumber(longm) / 60

         if meanHW == 'hhmm'then -- Avoid primary ports, which have no mean_hw or mean_lw offset
            name=port_name_translation[name]
            Primary_Port_new{ no=no, name=name, latitude=latitude, longitude=longitude, reference=nil, MSL=tonumber(MSL)}
            reference = name
         else
            Secondary_Port_new{ no=no, name=name, latitude=latitude, longitude=longitude, reference=reference, high_delta_mean=tonumber(meanHW) or 0, low_delta_mean=tonumber(meanLW) or 0, MSL=tonumber(MSL) or 0, ratio=tonumber(ratio) or 1 }
         end
      end
   end
end

clear_ports()
create_linz_ports_database(linz_ports_data_filename)


-- -----------
-- Tide events
-- -----------

local datetime = require('datetime')

local events = {}
local function Event_new(e)
   events[#events+1] = e
   return e
end

-- Extract tidal data from an open file
local function read_linz_tide_file(f, events)
   local l1 = f:read('*l')
   local _, port, latitude, longitude = l1:match('^(.-),(.-),(.-),(.-)%c*$')
   local l2 = f:read('*l')
   local l3 = f:read('*l')
   local tz, _ = l3:match('^(.-),(.-)%c*$')
 
--   print(port, tz, latitude, '"'..longitude..'"', tz)
   local events = events or {}
   for l in f:lines() do
      local day, _, month, year, t1, h1, t2, h2, t3, h3, t4, h4 = l:match('^(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-)%c*$')
      if day ~= nil then
         events[#events+1] = Event_new{ port=port, timestamp=datetime.new{year=year, month=month, day=day, hour=t1:sub(1, 2), min=t1:sub(4, 5), tz=tz}, height=tonumber(h1) }
         events[#events+1] = Event_new{ port=port, timestamp=datetime.new{year=year, month=month, day=day, hour=t2:sub(1, 2), min=t2:sub(4, 5), tz=tz}, height=tonumber(h2) }
         events[#events+1] = Event_new{ port=port, timestamp=datetime.new{year=year, month=month, day=day, hour=t3:sub(1, 2), min=t3:sub(4, 5), tz=tz}, height=tonumber(h3) }
         if (t4 ~= '') then
   --         print (port, year, month, day, tz, t4, h4)
            events[#events+1] = Event_new{ port=port, timestamp=datetime.new{year=year, month=month, day=day, hour=t4:sub(1, 2), min=t4:sub(4, 5), tz=tz}, height=tonumber(h4) }
         end
      end
   end
   return events
end

local function read_linz_tide_filename(filename, events)
   local f = io.open(filename)
   local events = read_linz_tide_file(f, events)
   for i, _ in ipairs(events) do
      if events[i] ~= nil and events[i+1] ~= nil then
         if events[i].height > events[i+1].height then
            events[i].event_type = 'high'
            events[i+1].event_type = 'low'
         else
            events[i].event_type = 'low'
            events[i+1].event_type = 'high'
         end
      end
   end
   return events
end


local function time_offset(offset)
   local sign = offset:sub(1, 1)
   local hour = offset:sub(2, 3)
   local minute = offset:sub(4, 5)
   local offset_in_seconds = (tonumber(sign .. hour) * 60 + tonumber(sign .. minute)) * 60
   return offset_in_seconds
end

local function calculate_secondary_events(primary_events, secondary_port_name, secondary_events)
   --print(secondary_port_name)
   local secondary_port = ports[secondary_port_name]
   local primary_port_name = secondary_port.reference
   local primary_port = ports[primary_port_name]

   if type(secondary_port.high_delta_mean) == 'string' then
      secondary_port.high_delta_mean = time_offset(secondary_port.high_delta_mean)
   end
   if type(secondary_port.low_delta_mean) == 'string' then
      secondary_port.low_delta_mean = time_offset(secondary_port.low_delta_mean)
   end
   
   local events = secondary_events or {}
   for _, primary_event in ipairs(primary_events) do
      if primary_event.port == secondary_port.reference then
         local ev = { port=secondary_port.name, tz=primary_event.tz, event_type=primary_event.event_type }
         
         -- For details on how to calculate times and heights of tides at secondary ports, refer to
         -- http://www.linz.govt.nz/sites/default/files/docs/hydro/tidal-info/tide-tables/mfth-of-hlw.pdf
         if ev.event_type == 'high' then
            ev.timestamp = datetime.new(primary_event.timestamp.time_utc + secondary_port.high_delta_mean)
         elseif ev.event_type == 'low' then
            ev.timestamp = datetime.new(primary_event.timestamp.time_utc + secondary_port.low_delta_mean)
         end
         
         primary_event.ROT = primary_event.height - primary_port.MSL
         ev.ROT = primary_event.ROT * secondary_port.ratio
         ev.height = ev.ROT + secondary_port.MSL

--         print(primary_event.port, primary_event.timestamp:format('%H%M', 'NZDT'), primary_event.height, primary_port.MSL, primary_event.ROT)
--         print(ev.port, ev.timestamp:format('%H%M', 'NZDT'), secondary_port.MSL, secondary_port.ratio, ev.ROT, ev.height)
         events[#events+1] = ev
      end
   end
   
   return events
end


local function print_linz_events(events, tz)
   for _, e in ipairs(events) do
      print(e.port, e.timestamp:format('%Y-%m-%d\t%H%M\t'..tz, tz), string.format("% 3.1f", e.height))
   end
end


local M={}

M.read_tide_file = read_linz_tide_filename
M.calculate_secondary_events = calculate_secondary_events
M.print_events = print_linz_events

return M


--[=[
local author_list = {
  { name="Jose das Couves", email="jose@couves.com", },
  { name="Manoel Joaquim", email="manoel.joaquim@cafundo.com", },
  { name="Maria das Dores", email="maria@dores.com", },
}

for i, p in pairs (author_list) do
  res = assert (con:execute(string.format([[
    INSERT INTO 'people'
    VALUES ('%s', '%s')]], p.name, p.email)
  ))
end


local book_list = {
   { title="A short introduction", author="Jose das Couves", year="1950", _expected=1 },
   { title="A quick survey", author="Jose das Couves", year="1951", _expected=1 },
   { title="A brief summary", author="Jose das Couves", year="1960", _expected=1 },
   { title="A complete coverage", author="Manoel Joaquim", year="1999",_expected=1 },
   { title="A non-existant author", author="No Name", year="2022", _expected=nil },
}

for i, p in pairs (book_list) do
  res = con:execute(string.format([[
    INSERT INTO books
    VALUES ('%s', '%s', '%s')]], p.author, p.title, p.year)
  )
--  print(res, p._expected)
  assert(res == p._expected)
end


cur = assert(con:execute('SELECT name, email from people'))
row = cur:fetch ({}, 'a')
while row do
  print(string.format('Name: %s, E-mail: %s', row.name, row.email))
  row = cur:fetch (row, 'a')
end


   cur:close()
   con:close()
   env:close()
--]=]


