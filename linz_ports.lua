#! /usr/bin/lua5.1

-- A list of all of the LINZ ports, along with the data needed to compute 
-- tide times and heights

-- local ports = require 'linz_ports'

local linz_ports_data_filename = 'secondaryports2013-14.csv'
local ports_filename = 'linz_tides.db'

local driver = require 'luasql.sqlite3'
local env = assert(driver.sqlite3())
local cx = assert(env:connect(ports_filename))
local result = assert(cx:execute('PRAGMA foreign_keys = ON'))

-- TODO: Automatically create ports if database is empty.

local function erase_ports()
   local result = cx:execute('DROP TABLE secondary_ports')
   local result = cx:execute('DROP TABLE primary_ports')
   local result = cx:execute('DROP TABLE ports')

   local result = assert(cx:execute([[
      CREATE TABLE ports(
         name varchar(50),
         id varchar(10),
         latitude real,
         longitude real,
         mean_sea_level real,

         PRIMARY KEY (name, id)
      )
   ]]))
   
   local result = assert(cx:execute([[
      CREATE TABLE primary_ports(
         name varchar(50),
         id varchar(10),
         
         PRIMARY KEY (name)
         FOREIGN KEY (name, id) REFERENCES ports(name, id)
      )
   ]]))
   
   local result = assert(cx:execute([[
      CREATE TABLE secondary_ports(
         name varchar(50),
         id varchar(10),
         reference_port varchar(50),
         mean_delta_hw real,
         mean_delta_lw real,
         ratio real,
         
         PRIMARY KEY (name, id)
         FOREIGN KEY (name, id) REFERENCES ports(name, id)
         FOREIGN KEY (reference_port) REFERENCES primary_ports(name)
      )
   ]]))

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


local ports = {}
local ports_by_id = {}
local primary_ports = {}
local secondary_ports = {}

local function Port_new(p)
   local result = assert(cx:execute(string.format([[
      INSERT INTO 'ports'
      VALUES ("%s", '%s', '%3.6f', '%3.6f', '%3.1f')]], p.name, p.no, p.latitude, p.longitude, p.MSL)
   ))
   return p
end

local function Primary_Port_new(p)
   Port_new(p)
   local result = assert(cx:execute(string.format([[
      INSERT INTO 'primary_ports'
      VALUES ("%s", '%s')]], p.name, p.no)
   ))
   return p
end

local function Secondary_Port_new(p)
   Port_new(p)
   local result = assert(cx:execute(string.format([[
      INSERT INTO 'secondary_ports'
      VALUES ("%s", '%s', '%s', '%6.1f', '%6.1f', '%6.2f')]], p.name, p.no, p.reference, p.high_delta_mean, p.low_delta_mean, p.ratio)
   ))
   return p
end


local function create_linz_ports_database(filename)
   erase_ports()

   local f = io.open(filename)
   local l1 = f:read('*l')
   local l2 = f:read('*l')
   local l3 = f:read('*l')
   
   local reference = ''
   local ports = {}
   for l in f:lines() do
      --print(l)
      local no, name, latd, latm, longd, longm, meanHW, _, meanLW, _, _, _, _, _, MSL, ratio = l:match('^(.-),(.-),(.-),(.-),(.-),(.-)W?,(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-).*$')
      print(no, name, latd, latm, longd, longm, meanHW, meanLW, MSL, ratio)
      
      if no ~= '' then  -- Avoid blank lines and the region heading lines
         local port
         local latitude = tonumber(latd) + tonumber(latm) / 60
         local longitude = tonumber(longd) + tonumber(longm) / 60

         if meanHW == 'hhmm'then -- Avoid primary ports, which have no mean_hw or mean_lw offset
            name=port_name_translation[name]
            Primary_Port_new{ no=no, name=name, latitude=latitude, longitude=longitude, reference=nil, MSL=tonumber(MSL)}
            reference = name
         else
            Secondary_Port_new{ no=no, name=name, latitude=latitude, longitude=longitude, reference=reference, high_delta_mean=tonumber(meanHW) or 0, low_delta_mean=tonumber(meanLW) or 0, MSL=tonumber(MSL) or 0, ratio=tonumber(ratio) or 1 }
         end
      end
   end
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
      SELECT * from secondary_ports WHERE name = "]] .. name .. [["
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

M.find = ports_find_any
M.find_secondary = ports_find_secondary
M.find_primary = ports_find_primary
M.create_db = create_linz_ports_database

return M

