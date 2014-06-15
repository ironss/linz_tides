#! /usr/bin/lua5.1

db_filename = 'linz_tides.db'

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


   local result = assert(cx:execute([[
      CREATE TRIGGER IF NOT EXISTS create_trip
      AFTER INSERT ON trips
      BEGIN
         INSERT OR IGNORE INTO secondary_tide_events
         VALUES ("test", strftime('%Y-%m-%d %H:%M:%f'), 'hilo', 1.23, 'Nelson', datetime('2015-12-31 07:38:00'));
      END
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
            'Auckland',
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
      { 'Port Levy 2014-02-20',     'Lyttelton',      '2014-02-20', '2014-02-21' },
      { 'Bay of Islands 2014-2015', 'Bay of Islands', '2014-12-15', '2015-01-15' },
   }
   
   for _, trip in ipairs(trips) do
      local name = trip[1]
      local region = trip[2]
      local start_date = trip[3]
      local end_date = trip[4]
      
      print(name, region, start_date, end_date)
      local result = assert(cx:execute(string.format([[
         insert into trips values('%s', '%s', datetime('%s'), datetime('%s'));
      ]], name, region, start_date, end_date)))
   end
   local result = assert(cx:commit())

end



local function rows(connection, statement)
   local cur = assert(connection:execute(statement))
   return function()
      local row = cur:fetch({}, 'a')
      if row == nil then
         cur:close()
      end
      return row
   end
end

local function tablify(connection, statement)
   local t = {}
   for row in rows(connection, statement) do
      t[#t+1] = row
   end
   
   return t
end

local function get_trips()
   return tablify(cx, 'SELECT * FROM trips')
end

local ports = require 'linz_ports'

local function get_region_ports(region)
   local t = {}
   for row in rows(cx, string.format('SELECT * FROM region_ports WHERE region_name="%s"', region)) do
      t[#t+1] = ports.find(row.port_name)
   end

   return t
end

local M = {}

M.erase_tables = erase_trips
M.create_tables = create_trips
M.populate_tables = populate_trips

M.trips = get_trips
M.region_ports = get_region_ports
M.regions = get_regions
M.ports_in_trip = get_ports_in_trip

return M

