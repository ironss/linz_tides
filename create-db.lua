#! /usr/bin/lua5.1

db_filename = 'linz_tides.db'

--local ports_filename = 'secondary-ports-2017-2018.csv'
local ports_filename = 'secondary-ports-2019-20-fixed.csv'
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

ports.create_tables()
--ports.populate_tables('secondaryports2013-14.csv')
ports.populate_tables(ports_filename)

tides.create_tables()
for _, fn in ipairs(tides_filenames) do
   tides.populate_tables(fn)
end

trips.create_tables()
trips.populate_tables()

