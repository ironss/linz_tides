#! /usr/bin/lua5.1

db_filename = 'linz_tides.db'

local ports_filename = 'secondaryports2013-14.csv'
local tides_filenames = {}
local f = io.popen('ls -1 tide_data')
for l in f:lines() do
   l = 'tide_data/' .. l
   print(l)
   tides_filenames[#tides_filenames+1] = l
   
end

local ports = require 'linz_ports'
local tides = require 'linz_tides'

--ports.create_tables()
--ports.populate_tables('secondaryports2013-14.csv')

tides.erase_tables()
tides.create_tables()
for _, fn in ipairs(tides_filenames) do
   tides.populate_tables(fn)
end


-- Additional tables

local driver = require 'luasql.sqlite3'
local env = assert(driver.sqlite3())
local cx = assert(env:connect(db_filename))
local result = assert(cx:execute('PRAGMA foreign_keys = ON'))


local function erase_trips()
   local result = assert(cx:execute([[
      DROP TABLE region_ports;
      DROP TABLE trips;
      DROP TABLE regions;
   ]]))
end

local function create_trips()
   local result = assert(cx:execute([[
      CREATE TABLE regions(
         name VARCHAR(50),
         
         PRIMARY KEY (name)
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
      CREATE TABLE region_ports (
         region_name VARCHAR(50),
         port_name VARCHAR(50),
         
         PRIMARY KEY (region_name, port_name)
         FOREIGN KEY (region_name) REFERENCES regions (name)
         FOREIGN KEY (port_name) REFERENCES ports (name)
      );
   ]]))
end

local function populate_trips()
   local result = assert(cx:execute([[
      insert into regions values('Lyttelton');
      insert into regions values('Akaroa');
      insert into regions values('Abel Tasman');
      insert into regions values('Bay of Islands');
   ]]))

   local result = assert(cx:execute([[
      insert into region_ports values('Lyttelton', 'Lyttelton');
      insert into region_ports values('Lyttelton', 'Sumner');

      insert into region_ports values('Akaroa', 'French Bay - Akaroa');
      insert into region_ports values('Akaroa', 'Tikao Bay');

      insert into region_ports values('Abel Tasman', 'Nelson');
      insert into region_ports values('Abel Tasman', 'Motueka');
      insert into region_ports values('Abel Tasman', 'Kaiteriteri');
      insert into region_ports values('Abel Tasman', 'Astrolabe Roadstead');

      insert into region_ports values('Bay of Islands', 'Doves Bay');
      insert into region_ports values('Bay of Islands', 'Kerikeri');
      insert into region_ports values('Bay of Islands', 'Opua');
      insert into region_ports values('Bay of Islands', 'Russell');
      insert into region_ports values('Bay of Islands', 'Waitangi');
   ]]))

   local result = assert(cx:execute([[
      insert into trips values('Abel Tasman 2011-2012', 'Abel Tasman', datetime('2011-12-22'), datetime('2012-01-08'));
      insert into trips values('Abel Tasman 2012-2013', 'Abel Tasman', datetime('2012-12-20'), datetime('2013-01-10'));
      insert into trips values('Abel Tasman 2013-2014', 'Abel Tasman', datetime('2013-12-14'), datetime('2013-01-05'));
      insert into trips values('Bay of Islands 2014-2015', 'Bay of Islands', datetime('2014-12-15'), datetime('2015-01-15'));
   ]]))
end

local M = {}
M.erase_tables = erase_trips
M.create_tables = create_trips
M.populate_tables = populate_trips

local trips = M


--ports.create_tables()
--ports.populate_tables('secondaryports2013-14.csv')

tides.erase_tables()
tides.create_tables()
for _, fn in ipairs(tides_filenames) do
   tides.populate_tables(fn)
end

trips.erase_tables()
trips.create_tables()
trips.populate_tables()

