#! /usr/bin/lua5.1

db_filename = 'linz_tides.db'
os.execute('rm linz_tides.db')

local ports_filename = 'secondaryports2013-14.csv'
local tides_filenames = {}
local f = io.popen('ls -1 tide_data')
for l in f:lines() do
   l = 'tide_data/' .. l
--   print(l)
   tides_filenames[#tides_filenames+1] = l
end

local ports = require 'linz_ports'
local tides = require 'linz_tides'
local trips = require 'trips'

--trips.erase_tables()
--tides.erase_tables()
--ports.erase_tables()


local t0=os.clock()
ports.create_tables()
tides.create_tables()
trips.create_tables()
local t1=os.clock

ports.populate_tables('secondaryports2013-14.csv')
local t2=os.clock

-- 1 year
tides.populate_tables('tide_data/auckland-2013.csv')
local t3=os.clock

local t4=os.clock
local t5=os.clock

trips.populate_tables()
local t6=os.clock

print(t1-t0, t2-t1, t3-t2, t6-t3)
