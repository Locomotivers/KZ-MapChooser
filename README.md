# MapChooser for KZ Servers

This is a modified version of MapChooserExtended intended for KZ Servers with support for dynamic map lists and tier display. This allows you to maintain several servers using a central-hosted map-pool - For KZTimer, this allows you to maintain skill-groups across servers amongst other things!

It requires a database table with entries for all maps you want to track, along with tier information and LJ Room availability.

## Planned Features
* Ability to lock RTV votes to players above a certain rank.

## Requirements

* Sourcemod 1.10
* MySQL Database Server
* KZTimer/GOKZ installed and set up correctly.

## Installation

* Upload all the files to your csgo server directory
* Create a database entry in `databases.cfg` called `kzMaps`. You may copy the same config you use for the `kztimer` or `gokz` database configurations for convenience sake. 
* Create a table "kz_maps" in your selected database. This depends on what you set in the previous step (whether you set kzMaps to your KZTimer/GOKZ databases or if you're using something else)
```
 CREATE TABLE IF NOT EXISTS `kz_maps` (`mapname` VARCHAR(50) NOT NULL PRIMARY KEY, `tier` TINYINT NOT NULL, `ljroom` TINYINT);
 ```
  Use maplist.sql to create the table and import all global maps into your database. This may not always be up-to-date!
 
* Fill it with all the maps you are tracking.
* Ensure you have all the maps you want in `mapcycle.txt` on your server. 
* If you are hosting several servers and would like to sync the ranks system between them (kztimer), list all maps you host across all servers in `mapcycle.txt` - and specify the tiers you want per server in nominations.cfg!
* Open nominations.cfg and ensure you have specified what map tiers you are hosting. This will allow you to divide your servers in terms of difficulty.

## Try Out The Plugin:

```
IP: gokz.gflclan.com:27015
```
