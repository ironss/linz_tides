#! /usr/bin/lua5.1

db_filename = 'linz_tides.db'

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


-- Regions and trips

local driver = require 'luasql.sqlite3'
local env = assert(driver.sqlite3())
local cx = assert(env:connect(db_filename))
local result = assert(cx:setautocommit(false))
local result = assert(cx:execute('PRAGMA foreign_keys = ON'))


local function erase_trips()
   local result = cx:execute('DROP TABLE trips')
   local result = cx:execute('DROP TABLE region_ports')
   local result = cx:execute('DROP TABLE regions')
   local result = cx:commit()
end

local function create_trips()
   local result = assert(cx:execute([[
      CREATE TABLE regions(
         name VARCHAR(50),
         
         PRIMARY KEY (name)
      );
   ]]))

   local result = assert(cx:execute([[
      CREATE TABLE region_ports (
         region_name VARCHAR(50),
         port_name VARCHAR(50),
         
         PRIMARY KEY (region_name, port_name)
         FOREIGN KEY (region_name) REFERENCES regions (name)
         FOREIGN KEY (port_name) REFERENCES ports (name)
      );
   ]]))

   local result = assert(cx:execute([[
      CREATE TABLE trips(
         name VARCHAR(50),
         region_name VARCHAR(50),
         start_date DATETIME,
         end_date DATETIME,
         
         PRIMARY KEY(name)
         FOREIGN KEY (region_name) REFERENCES regions (name)
      );
   ]]))

   local result = assert(cx:commit())
end

local function populate_trips()
   local regions = 
   {
      'Lyttelton',
      'Akaroa',
      'Abel Tasman',
      'Marlborough Sounds',
      'Bay of Islands',
   }
   
   for _, region in ipairs(regions) do
      print(region)
      local result = assert(cx:execute(string.format([[
         insert into regions values('%s');
      ]], region)))
   end
   local result = assert(cx:commit())

   local region_ports = 
   {
      {  'Lyttelton', 
         { 
            'Lyttelton', 
            'Sumner',
         }
      },
      {  'Akaroa', 
         { 
            'French Bay - Akaroa',
            'Tikao Bay',
         }
      },
      {  'Abel Tasman',
         {
            'Motueka',
            'Kaiteriteri',
            'Astrolabe Roadstead',
         }
      },
      {  'Bay of Islands',
         {
            'Doves Bay',
            'Kerikeri',
            'Opua',
            'Russell',
            'Waitangi',
         },
      },
   }

   for _, rp in ipairs(region_ports) do
      local region = rp[1]
      local ports = rp[2]
      for _, port in ipairs(ports) do
         print(region, port)
         local result = assert(cx:execute(string.format([[
            insert into region_ports values('%s', '%s');
         ]], region, port)))
      end
   end
   local result = assert(cx:commit())

   local trips = 
   {
      { 'Abel Tasman 2011-2012',    'Abel Tasman',    '2011-12-22', '2012-01-08' },
      { 'Abel Tasman 2012-2013',    'Abel Tasman',    '2012-12-20', '2013-01-10' },
      { 'Abel Tasman 2013-2014',    'Abel Tasman',    '2013-12-14', '2014-01-05' },
      { 'Bay of Islands 2014-2015', 'Bay of Islands', '2014-12-15', '2015-01-15' },
   }
   
   for _, trip in ipairs(trips) do
      local name = trip[1]
      local region = trip[2]
      local start_date = trip[3]
      local end_date = trip[4]
      
      print(name, region, start_date, end_date)
      local result = assert(cx:execute(string.format([[
         insert into trips values('%s', '%s', datetime('%s'), datetime('$s'));
      ]], name, region, start_date, end_date)))
   end
   local result = assert(cx:commit())

end

local M = {}
M.erase_tables = erase_trips
M.create_tables = create_trips
M.populate_tables = populate_trips

local trips = M

--tides.erase_tables()
--trips.erase_tables()
--ports.erase_tables()

ports.create_tables()
ports.populate_tables('secondaryports2013-14.csv')

trips.create_tables()
trips.populate_tables()

tides.create_tables()
for _, fn in ipairs(tides_filenames) do
   tides.populate_tables(fn)
end

