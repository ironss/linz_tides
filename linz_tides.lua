#! /usr/bin/lua

-- Convert tidal data from LINZ CVS format into a more friendly format
--    port, date, time, tz, height
--    port, date_time_utc, height


local datetime = require('datetime')


local M={}


local refporttable = 
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

local function read_linz_port_data_filename(filename)
   local f = io.open(filename)
   local l1 = f:read('*l')
   local l2 = f:read('*l')
   local l3 = f:read('*l')
   
   local reference = ''
   local ports = {}
   for l in f:lines() do
      --print(l)
      local no, name, latd, latm, longd, longm, meanHW, _, meanLW, _, _, _, _, MSL, ratio = l:match('^(.-),(.-),(.-),(.-),(.-),(.-)W?,(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-).*$')
      --print(no, name, latd, latm, longd, longm, meanHW, meanLW, MSL, ratio)
      
      if no ~= '' then  -- Avoid blank lines and the region heading lines
         local port
         local latitude = tonumber(latd) + tonumber(latm) / 60
         local longitude = tonumber(longd) + tonumber(longm) / 60
      
         if meanHW == 'hhmm'then
            name=refporttable[name]
            port = { no=no, name=name, latitude=latitude, longitude=longitude, reference='x', MSL=MSL}
            reference = name
         else
            port = { no=no, name=name, latitude=latitude, longitude=longitude, reference=reference, high_delta_mean=meanHW, low_delta_mean=meanLW, MSL=MSL, ratio=ratio }
         end
         ports[name] = port
      end
   end
   
   return ports
end


local ports = read_linz_port_data_filename('secondaryports2013-14.csv')

--[[for _, p in pairs(ports) do
   print(p.no, p.name, p.reference, p.MSL, p.ratio)
end
--]]


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
         events[#events+1] = { port=port, timestamp=datetime.new{year=year, month=month, day=day, hour=t1:sub(1, 2), min=t1:sub(4, 5), tz=tz}, height=h1 }
         events[#events+1] = { port=port, timestamp=datetime.new{year=year, month=month, day=day, hour=t2:sub(1, 2), min=t2:sub(4, 5), tz=tz}, height=h2 }
         events[#events+1] = { port=port, timestamp=datetime.new{year=year, month=month, day=day, hour=t3:sub(1, 2), min=t3:sub(4, 5), tz=tz}, height=h3 }
         if (t4 ~= '') then
   --         print (port, year, month, day, tz, t4, h4)
            events[#events+1] = { port=port, timestamp=datetime.new{year=year, month=month, day=day, hour=t4:sub(1, 2), min=t4:sub(4, 5), tz=tz}, height=h4 }
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


M.read_tide_file = read_linz_tide_filename
M.calculate_secondary_events = calculate_secondary_events
M.print_events = print_linz_events

return M

