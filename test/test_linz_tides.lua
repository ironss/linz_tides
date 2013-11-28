#! /usr/bin/lua

local linz = require('linz_tides')


require 'luaunit'


Test_linz_parsing = {}
events = linz.parse_tide_file('test/data/nelson-2013.csv')

function Test_linz_parsing:test_port_name()
   assert_equals(events[1].port, 'Nelson')
end

function Test_linz_parsing:test_date_first()
   assert_equals(events[1].timestamp.time_utc, os.time{year='2013', month='01', day='01', hour='05', min='44'} - 12*3600)
end

function Test_linz_parsing:test_date_last()
   assert_equals(events[#events].timestamp.time_utc, os.time{year='2013', month='12', day='31', hour='20', min='51'} - 12*3600)
end

function Test_linz_parsing:test_height_first()
   assert_equals(events[1].height, '0.7')
   assert_equals(events[1].event_type, 'low')
end

function Test_linz_parsing:test_height_last()
   assert_equals(events[#events].height, '4.0')
   assert_equals(events[#events].event_type, 'high')
end



Test_secondary_ports = {}
astrolabe_events = linz.calculate_secondary_events(events, 'Astrolabe Roadstead')
motueka_events = linz.calculate_secondary_events(events, 'Motueka')

function Test_secondary_ports:test_port_name()
   assert_equals(astrolabe_events[1].port, 'Astrolabe Roadstead')
end

function Test_secondary_ports:test_low_offset_negative()
   assert_equals(astrolabe_events[1].timestamp.time_utc, os.time{year='2013', month='01', day='01', hour='05', min='24'} - 12*3600)
end

function Test_secondary_ports:test_low_offset_positive()
   assert_equals(motueka_events[1].timestamp.time_utc, os.time{year='2013', month='01', day='01', hour='06', min='03'} - 12*3600)
end

function Test_secondary_ports:test_high_offset_positive()
   assert_equals(motueka_events[#motueka_events].timestamp.time_utc, os.time{year='2013', month='12', day='31', hour='20', min='56'} - 12*3600)
end


LuaUnit:run()

--linz.print_events(events)
--linz.print_events(motueka_events)

