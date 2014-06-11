#! /usr/bin/lua5.1

-- Convert tidal data from LINZ CVS format into a more friendly format
--    port, date, time, tz, height
--    port, date_time_utc, height

local ports = require 'linz_ports'

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
   local secondary_port = ports.find_secondary(secondary_port_name)
   local primary_port_name = secondary_port.reference_port
   local primary_port = ports.find(primary_port_name)

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


