#! /usr/bin/lua

-- Convert tidal data from LINZ CVS format into a more friendly format
--    port, date, time, tz, height
--    port, date_time_utc, height

-- TODO: Convert date, time and tz to UTC time


local M={}

 
local ports = 
{
   { no='6458' , name='Nelson'             , latitdue='', longitude='', reference=''                                                       , msl='2.32'             },
   { no='6455' , name='Astrolabe Roadstead', latitude='', longitude='', reference='Nelson', high_delta_mean='-0020', low_delta_mean='-0020', msl='2.5', ratio=1.21, }, 
   { no='6456' , name='Kaiteriteri'        , latitude='', longitude='', reference='Nelson', high_delta_mean='+0001', low_delta_mean='+0005', msl='2.1', ratio=0.95, },
   { no='6455b', name='Mapua'              , latitude='', longitude='', reference='Nelson', high_delta_mean='+0019', low_delta_mean='+0019', msl='2.4', ratio=0.92, },
   { no='6455a', name='Motueka'            , latitdue='', longitude='', reference='Nelson', high_delta_mean='+0005', low_delta_mean='+0019', msl='2.4', ratio=0.95, },
}


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
      events[#events+1] = { port=port, date=os.time{year=year, month=month, day=day, hour=t1:sub(1, 2), min=t1:sub(4, 5)}, tz=tz, height=h1 }
      events[#events+1] = { port=port, date=os.time{year=year, month=month, day=day, hour=t2:sub(1, 2), min=t2:sub(4, 5)}, tz=tz, height=h2 }
      events[#events+1] = { port=port, date=os.time{year=year, month=month, day=day, hour=t3:sub(1, 2), min=t3:sub(4, 5)}, tz=tz, height=h3 }
      if (t4 ~= '') then
--         print (port, year, month, day, tz, t4, h4)
         events[#events+1] = { port=port, date=os.time{year=year, month=month, day=day, hour=t4:sub(1, 2), min=t4:sub(4, 5)}, tz=tz, height=h4 }
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
      print(e.port, e.date, e.time, e.tz, e.height, e.event_type)
   end
end

local function calculate_secondary_events(primary_events, secondary_port)
   local events = {}
   for _, primary_event in ipairs(primary_events) do
      if primary_event.port == secondary_port then
         local ev = { port=secondary_port, date=primary_event.date, tz=primary_event.tz, event_type=primary_event.event_type }
         if ev.event_type == 'high' then
            -- Calculate offset
         elseif ev.event_type == 'low' then
            -- Calculate offset
         end
      end
   end
end


--if type(arg[1] == 'string') then
--   local events = parse_linz_tide_filename(arg[1])
--   print_linz_events(events)
--end

M.parse_tide_file = parse_linz_tide_filename

return M

