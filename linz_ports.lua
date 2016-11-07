#! /usr/bin/lua5.1

-- A list of all of the LINZ ports, along with the data needed to compute 
-- tide times and heights

local ports_filename = 'linz_tides.db'

local driver = require 'luasql.sqlite3'
local env = assert(driver.sqlite3())
local cx = assert(env:connect(ports_filename))
local result = assert(cx:execute('PRAGMA foreign_keys = ON'))
local result = assert(cx:setautocommit(false))

-- TODO: Automatically create ports if database is empty.

local function erase_tables()
   local result = cx:execute('DROP TABLE secondary_ports')
   local result = cx:execute('DROP TABLE primary_ports')
   local result = cx:execute('DROP TABLE ports')
   local result = cx:commit()
end

local function create_tables()
--[=[   local result = assert(cx:execute([[
      CREATE TABLE IF NOT EXISTS ports(
         name VARCHAR(50),
         id VARCHAR(10),
         latitude REAL,
         longitude REAL,
         mean_sea_level REAL,
         _subtype VARCHAR(10),

         PRIMARY KEY (name)
      );
   ]]))
--]=]
   
   local result = assert(cx:execute([[
      CREATE TABLE IF NOT EXISTS primary_ports (
         name VARCHAR(50),
         id VARCHAR(10),
         latitude REAL,
         longitude REAL,
         mean_sea_level REAL,
         
         PRIMARY KEY (name)
      );
   ]]))
   
   local result = assert(cx:execute([[
      CREATE TABLE IF NOT EXISTS secondary_ports (
         name VARCHAR(50),
         id VARCHAR(10),
         latitude REAL,
         longitude REAL,
         mean_sea_level REAL,

         reference_port VARCHAR(50),
         mean_delta_hw REAL,
         mean_delta_lw REAL,
         range_ratio REAL,
         
         PRIMARY KEY (name)
         FOREIGN KEY (reference_port) REFERENCES primary_ports(name)
      );
   ]]))

   local result = assert(cx:execute([[
      CREATE VIEW IF NOT EXISTS ports
      AS SELECT name, id, latitude, longitude, mean_sea_level, "primary_port" AS _subtype FROM primary_ports
      UNION SELECT name, id, latitude, longitude, mean_sea_level, "secondary_port" AS _subtype FROM secondary_ports
   ]]))


   local result = assert(cx:execute([[
      CREATE TABLE port_sources(
         content_id VARCHAR(32),
         filename VARCHAR(100),
         date_imported DATETIME,

         PRIMARY KEY (content_id)
      );
   ]]))

   local result = cx:commit()
end

-- -----------------
-- New Zealand ports
-- -----------------

local port_name_translation = 
{
   ['AUCKLAND']='Auckland',
   ['BLUFF']='Bluff',
   ['LYTTELTON']='Lyttelton',
   ['MARSDEN POINT']='Marsden Point',
   ['NELSON']='Nelson',
   ['NAPIER']='Napier',
   ['ONEHUNGA']='Onehunga',
   ['PICTON']='Picton',
   ['PORT CHALMERS']='Port Chalmers',
   ['PORT TARANAKI']='Port Taranaki',
   ['TAURANGA']='Tauranga',
   ['TIMARU']='Timaru',
   ['WELLINGTON']='Wellington',
   ['WESTPORT']='Westport',
}


local function Port_new(p, subtype)
   print(p.name, p.no, p.latitude, p.longitude, p.MSL)

   return p
end

local function Primary_Port_new(p)
   Port_new(p, 'primary_port')
   local result = assert(cx:execute(string.format([[
      INSERT INTO 'primary_ports'
      VALUES ("%s", '%s', '%3.6f', '%3.6f', '%3.1f')]], p.name, p.no, p.latitude, p.longitude, p.MSL)
   ))

   return p
end

local function Secondary_Port_new(p)
   Port_new(p, 'secondary_port')
   local result = assert(cx:execute(string.format([[
      INSERT INTO 'secondary_ports'
      VALUES ("%s", '%s', '%3.6f', '%3.6f', '%3.1f', '%s', '%6.1f', '%6.1f', '%6.2f')]], p.name, p.no, p.latitude, p.longitude, p.MSL, p.reference, p.high_delta_mean, p.low_delta_mean, p.ratio)
   ))

   return p
end


local function time_offset(offset)
   local sign = tonumber(offset:sub(1, 1) .. '1')
   local hour = tonumber(offset:sub(2, 3)) or 0
   local minute = tonumber(offset:sub(4, 5)) or 0

   local offset_in_seconds = sign * (hour * 60 + minute) * 60
   return offset_in_seconds
end

local function create_linz_ports_database(filename)
   local f = io.open(filename)
   local l1 = f:read('*l')
   local l2 = f:read('*l')
   local l3 = f:read('*l')
   
   local reference = ''
   local ports = {}
   for l in f:lines() do
      --print(l)
      local no, name, latd, latm, longd, longm, meanHW, _, meanLW, _, _, _, _, _, MSL, ratio = l:match('^(.-),(.-),(.-),(.-),(.-),(.-)W?,(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-).*$')
--      print(no, name, latd, latm, longd, longm, meanHW, meanLW, MSL, ratio)
      
      if no ~= '' then  -- Avoid blank lines and the region heading lines
         local port
         local latitude = tonumber(latd) + tonumber(latm) / 60
         local longitude = tonumber(longd) + tonumber(longm) / 60

         if meanHW == 'hhmm'then -- Avoid primary ports, which have no mean_hw or mean_lw offset
            name=port_name_translation[name]
            Primary_Port_new{ no=no, name=name, latitude=latitude, longitude=longitude, reference=nil, MSL=tonumber(MSL)}
            reference = name
         else
            local high_delta_mean = time_offset(meanHW)
            local low_delta_mean = time_offset(meanLW)

            Secondary_Port_new{ no=no, name=name, latitude=latitude, longitude=longitude, reference=reference, high_delta_mean=high_delta_mean, low_delta_mean=low_delta_mean, MSL=tonumber(MSL) or 0, ratio=tonumber(ratio) or 1 }
         end
      end
   end

   local file_id = require 'file_id'
   local content_id = file_id.md5sum(filename)
   
   local result = assert(cx:execute(string.format([[
      INSERT INTO 'port_sources'
      VALUES ("%s", '%s', datetime('now'))]], content_id, filename)
   ))

   local result = assert(cx:commit())
end

local function rows(connection, statement)
   local cur = assert(connection:execute(statement))
   return function()
      return cur:fetch({}, 'a')
   end
end

local function tablify(connection, statement)
   local t = {}
   for row in rows(connection, statement) do
      t[#t+1] = row
   end
   
   return t
end

local function ports_find_all(name)
   return tablify(cx, 'SELECT * from ports')
end


local function ports_find_any(name)
   local cur = assert(cx:execute([[
      SELECT * from ports WHERE name = "]] .. name .. [["
   ]]))
   local row = cur:fetch({}, 'a')
   return row
end

local function ports_find_primary(name)
   local cur = assert(cx:execute([[
      SELECT * from primary_ports WHERE name = "]] .. name .. [["
   ]]))
   local row = cur:fetch({}, 'a')
   return row
end

local function ports_find_secondary(name)
   local cur = assert(cx:execute([[
      SELECT * from secondary_ports WHERE name = "]] .. name .. [["
   ]]))
   local row = cur:fetch({}, 'a')
   return row
end

local M={}

M.erase_tables = erase_tables
M.create_tables = create_tables
M.populate_tables = create_linz_ports_database

M.find = ports_find_any
M.find_secondary = ports_find_secondary
M.find_primary = ports_find_primary

return M

