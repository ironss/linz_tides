#! /usr/bin/lua

-- Date-time functionality

-- local datetime = require('datetime')

-- Create a timestamp
-- local time1 = datetime.new() -- current time, local timezone
-- local time2 = datetime.new{year=2013, month=11, day=29, hour=10, min=01, second=02}
-- local time3 = datetime.new{year=2013, month=11, day=29, hour=10, min=01, second=02, tz='NZDT'}
-- local time4 = datetime.new{year=2013, month=11, day=29, hour=10, min=01, second=02, tz='+1300'}
-- local time5 = datetime.new{time2}       -- create a copy of a datetime timestamp
-- local time6 = datetime.new(1356972240)  -- datetime from a Unix-style seconds-from-epoch number


-- Format a timestamp
-- local string1 = time1:format('%Y-%m-%d_%H:%M:%S')                -- specific format, preferred timezone
-- local string2 = time2:format()                                   -- default ISO8601 format, preferred timezone
-- local string3 = time3:format(nil, 'NZ')                          -- default ISO8601 format, specific timezone from tzdata (zoneinfo)
-- local string4 = time4:format(nil, 'Pacific/Auckland')            -- default ISO8601 format, specific timezone from tzdata (zoneinfo)
-- local string5 = time5:format(nil, '+1200')                       -- default ISO8601 format, specific offset from UTC
-- local string6 = time6:format(nil, 'EST+5EDT,M4.1.0/2,M10.5.0/2') -- default ISO8601 format, timezone as defined for TZ environment variable


-- Difference between times
-- local diff = time1 - time2                 -- simply subtract two timestamps, returns difference in seconds
-- local diff = datetime.diff(time3, time4)


-- Adjusting a time
-- local time2:set{hour=1}               -- set the hour to 1
-- local time3:add{minute=60}            -- add 60 minutes
-- local time4:add{minute=-60}           -- subtract 60 minutes
-- local time5:add{minute=60, second=-1) -- add 59 minutes and 59 seconds

-- local time7 = time1 + {hour=60, minute=5}
-- local time8 = time7 + 60                   -- add a number of seconds


-- TODO: Better support for timezone
-- TODO: Support for parsing a string


local M={}

local tzoffsets = 
{
   ['NZST'] = 12*3600,
   ['NZDT'] = 13*3600,
   ['SAST'] =  2*3600,
}

-- Format a timestamp
local function datetime_format(format, timestamp, tz)
   local format = format or '%Y-%m-%dT%H:%M:%SZ'
   local time = timestamp.time_utc -- TODO: or time now if not specified
   if tz ~= nil then
      local offset = tzoffsets[tz] or 0
      time = time + offset
   end
   local output = os.date(format, time)
   return output
end


local function datetime_clone(table)
   local timestamp={}
   for i, v in pairs(table) do
      timestamp[i] = v
   end
   return timestamp
end


local function datetime_create(time_utc, ticks_utc, ticks_per_second, preferred_tz)
   local timestamp={_type='datetime'}
   
   timestamp.time_utc = time_utc
   timestamp.ticks_utc = ticks_utc or 0
   timestamp.ticks_per_second = ticks_per_second or 1000000
   timestamp.preferred_tz = preferred_tz or ''

   timestamp.format = function(self, format, tz)
      return datetime_format(format, self, tz)
   end

   return timestamp
end


local function datetime_new(value, ...)
   local timestamp
   
   if type(value) == 'table' then
      if value._type == 'datetime' then
         timestamp = datetime_clone(value)
      else
         timestamp = datetime_create(os.time(value), 0, 1000000, value.tz)
         if value.tz ~= nil then
            local offset = tzoffsets[value.tz] or 0
            timestamp.time_utc = timestamp.time_utc - offset
         end
      end
   elseif type(value) == 'number' then
      timestamp = datetime_create(value)
   end
   
   return timestamp
end


M.new = datetime_new
M.format = datetime_format

return M

