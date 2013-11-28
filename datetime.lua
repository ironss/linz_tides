#! /usr/bin/lua

-- Date-time functionality

local M={}

--local dateparse = require('dateparse')

local function datetime_format(format, timestamp)
end

local function datetime_clone(table)
   for i, v in pairs(table) do
      timestamp[i] = v
   end
   return timestamp
end


local function datetime_create(time_utc, ticks_utc, ticks_per_second, preferred_tz)
   local timestamp={_type='datetime'}
   
   timestamp.time_utc = time_utc
   timestamp.ticks_utc = ticks_utc or nil
   timestamp.ticks_per_second = ticks_per_second or 1000000
   timestamp.preferred_tz = preferred_tz or ''

   timestamp.format = function(self, format)
      return datetime_format(format, self)
   end

   return timestamp
end


local function datetime_new(value, ...)
   local timestamp
   
   if type(value) == 'table' then
      if table._type == 'datetime' then
         timestamp = datetime_clone(value)
      else
         timestamp = datetime_create(os.time(value), 0, 1000000, value.tz)
      end
   elseif type(value) == 'number' then
      timestamp = datetime_create(value, 0)
   end
   
   return timestamp
end

M.new = datetime_new
M.format = datetime_format

return M

