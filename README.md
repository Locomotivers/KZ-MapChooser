# MapChooser for KZ Servers

This is a modified version of MapChooserExtended intended for KZ Servers with support for dynamic map lists and tier display.
It requires a database table in a database with entries for all maps you want to track, along with it's tier information. For convenience, create the table in the "kztimer" or "gokz" databases!

## Requirements

* Sourcemod 1.10
* MySQL Database Server
* KZTimer/GOKZ installed and set up correctly.

## Installation

* Upload all the files to your csgo server directory
* Ensure you have the "kztimer" or "gokz" databases configured in database.cfg
* Create a table "kz_maps" in your database:
```
 CREATE TABLE IF NOT EXISTS `kz_maps` (`mapname` VARCHAR(50) NOT NULL PRIMARY KEY, `tier` TINYINT NOT NULL, `ljroom` TINYINT);
 ```
  Use maplist.sql to create the table and import all global maps into your database. This may not always be up-to-date!
 
* Fill it with all the maps you are tracking.
* Ensure you have all the maps you want in `mapcycle.txt` on your server. 
* If you are hosting several servers and would like to sync the ranks system between them (kztimer), list all maps you host across all servers in mapcycles - and specify the tiers you want per server in nominations.cfg!
* Open nominations.cfg and ensure you have specified what map tiers you are hosting.
