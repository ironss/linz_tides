#! /usr/bin/lua

-- Convert tidal data from LINZ CVS format into a more friendly format
--    port, date, time, tz, height
--    port, date_time_utc, height


-- TODO: Timezone correction for primary and secondary ports
-- TODO: Tide height correction for secondary ports


local datetime = require('datetime')


local M={}
 
local ports = 
{
   ['Nelson'             ]={ no='6458' , latitdue='', longitude='', reference=''       ,
                                                                              msl='2.32'                          },
                                                                              
   ['Astrolabe Roadstead']={ no='6455' , latitude='', longitude='', reference='Nelson' ,
                             high_delta_mean='-0020', low_delta_mean='-0020', msl='2.5', ratio=1.21,              }, 
   ['Kaiteriteri'        ]={ no='6456' , latitude='', longitude='', reference='Nelson' , 
                             high_delta_mean='+0001', low_delta_mean='+0005', msl='2.1', ratio=0.95,              },
   ['Mapua'              ]={ no='6455b', latitude='', longitude='', reference='Nelson' , 
                             high_delta_mean='+0019', low_delta_mean='+0019', msl='2.4', ratio=0.92,              },
   ['Motueka'            ]={ no='6455a', latitude='', longitude='', reference='Nelson' , 
                             high_delta_mean='+0005', low_delta_mean='+0019', msl='2.4', ratio=0.95,              },
}

for i, v in pairs(ports) do
   v.name = i
end


-- Extract tidal data from an open file
local function parse_linz_tide_file(f)
   local l1 = f:read('*l')
   local _, port, latitude, longitude = l1:match('^(.-),(.-),(.-),(.-)%c*$')
   local l2 = f:read('*l')
   local l3 = f:read('*l')
   local tz, _ = l3:match('^(.-),(.-)%c*$')
 
--   print(port, tz, latitude, '"'..longitude..'"', tz)
   local events = {}
   for l in f:lines() do
      local day, _, month, year, t1, h1, t2, h2, t3, h3, t4, h4 = l:match('^(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-)%c*$')
      events[#events+1] = { port=port, timestamp=datetime.new{year=year, month=month, day=day, hour=t1:sub(1, 2), min=t1:sub(4, 5), tz=tz}, height=h1 }
      events[#events+1] = { port=port, timestamp=datetime.new{year=year, month=month, day=day, hour=t2:sub(1, 2), min=t2:sub(4, 5), tz=tz}, height=h2 }
      events[#events+1] = { port=port, timestamp=datetime.new{year=year, month=month, day=day, hour=t3:sub(1, 2), min=t3:sub(4, 5), tz=tz}, height=h3 }
      if (t4 ~= '') then
--         print (port, year, month, day, tz, t4, h4)
         events[#events+1] = { port=port, timestamp=datetime.new{year=year, month=month, day=day, hour=t4:sub(1, 2), min=t4:sub(4, 5), tz=tz}, height=h4 }
      end   
   end
   return events
end

local function parse_linz_tide_filename(filename)
   local f = io.open(filename)
   local events = parse_linz_tide_file(f)
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

local function print_linz_events(events)
   for _, e in ipairs(events) do
      print(e.port, e.date:format('%Y-%m-%d_%H:%M'), e.height) -- , e.event_type)
   end
end

local function time_offset(offset)
   local sign = offset:sub(1, 1)
   local hour = offset:sub(2, 3)
   local minute = offset:sub(4, 5)
   local offset_in_seconds = (tonumber(sign .. hour) * 60 + tonumber(sign .. minute)) * 60
   return offset_in_seconds
end

local function calculate_secondary_events(primary_events, secondary_port_name)
   local secondary_port = ports[secondary_port_name]

   if type(secondary_port.high_delta_mean) == 'string' then
      secondary_port.high_delta_mean = time_offset(secondary_port.high_delta_mean)
   end
   if type(secondary_port.low_delta_mean) == 'string' then
      secondary_port.low_delta_mean = time_offset(secondary_port.low_delta_mean)
   end
   
   local events = {}
   for _, primary_event in ipairs(primary_events) do
      if primary_event.port == secondary_port.reference then
         local ev = { port=secondary_port.name, tz=primary_event.tz, event_type=primary_event.event_type }
         if ev.event_type == 'high' then
            ev.timestamp = datetime.new(primary_event.timestamp.time_utc + secondary_port.high_delta_mean)
            ev.height = primary_event.height
         elseif ev.event_type == 'low' then
            ev.timestamp = datetime.new(primary_event.timestamp.time_utc + secondary_port.low_delta_mean)
            ev.height = primary_event.height
         end
         events[#events+1] = ev
      end
   end
   
   return events
end


M.parse_tide_file = parse_linz_tide_filename
M.calculate_secondary_events = calculate_secondary_events
M.print_events = print_linz_events

return M

