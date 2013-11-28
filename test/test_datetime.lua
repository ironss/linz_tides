#! /usr/bin/lua

local datetime = require('datetime')

require 'luaunit'


Test_datetime_new = {}

function Test_datetime_new:disabled_test_table_ymd()
   local time1 = datetime.new{year=2013, month=10, day=29}
   assert_equals(time1.time_utc, 1382958000)
end

function Test_datetime_new:test_table_ymd000()
   local time1 = datetime.new{year=2013, month=10, day=29, hour=0, min=0, sec=0}
   assert_equals(time1.time_utc, 1382958000)
end

function Test_datetime_new:test_table_ymdhms()
   local time1 = datetime.new{year=2013, month=10, day=29, hour=1, min=2, sec=3}
   assert_equals(time1.time_utc, 1382958000 + 1*3600 + 2*60 + 3)
end

function Test_datetime_new:test_table_clone()
   local time1 = datetime.new{year=2013, month=10, day=29, hour=1, min=2, sec=3}
   local time2 = datetime.new(time1)
   time2.time_utc = time2.time_utc + 3600             -- Adjust the time in the copy
   assert_notequals(time2.time_utc, time1.time_utc)   -- Check that the original does not change
end

function Test_datetime_new:test_table_ymdhms_nzst_1()
   local time1 = datetime.new{year=2013, month=6, day=29, hour=0, min=0, sec=0, tz='NZST'}
   assert_equals(time1.time_utc, 1372420800 - 12*3600)
   assert_equals(time1.preferred_tz, 'NZST')
end

function Test_datetime_new:test_table_ymdhms_nzst_2()
   local time1 = datetime.new{year=2013, month=10, day=29, hour=1, min=2, sec=3, tz='NZST'}
   assert_equals(time1.time_utc, 1382958000 + 1*3600 + 2*60 + 3 - 12*3600)
end

function Test_datetime_new:test_table_ymdhms_nzdt_1()
   local time1 = datetime.new{year=2013, month=10, day=29, hour=1, min=2, sec=3, tz='NZDT'}
   assert_equals(time1.time_utc, 1382958000 + 1*3600 + 2*60 + 3 - 13*3600)
end




Test_datetime_format={}

function Test_datetime_format:test_format_default()
   local time1 = datetime.new{year=2013, month=10, day=29, hour=1, min=2, sec=3}
   local output = time1:format()
   assert_equals(output, '2013-10-29T01:02:03Z')
end

function Test_datetime_format:test_format_specified()
   local time1 = datetime.new{year=2013, month=10, day=29, hour=1, min=2, sec=3}
   local output = time1:format('%Y-%m-%d_%H.%M.%S+00')
   assert_equals(output, '2013-10-29_01.02.03+00')
end

function Test_datetime_format:test_format_specified_timezone()
   local time1 = datetime.new{year=2013, month=10, day=29, hour=1, min=2, sec=3}
   local output = time1:format('%Y-%m-%d_%H.%M.%S', 'NZDT')
   assert_equals(output, '2013-10-29_14.02.03')
end


LuaUnit:run()

