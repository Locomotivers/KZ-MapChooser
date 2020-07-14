# SourceMod MapChooser for KZTimer

This is a modified version of the original MapChooser intended for KZTimer with support for dynamic map lists and tier display.
It requires a database table in the "kztimer" database with entries for all maps you want to track, along with it's tier information.

## Requirements

* Sourcemod 1.10
* MySQL Database Server
* KZTimer installed and set up correctly.

## Installation

* Upload all the files to your csgo server directory
* Ensure you have the "kztimer" database configured in database.cfg
* Create a table "kz_maps" in the "kztimer" database:
```
 CREATE TABLE IF NOT EXISTS `kz_maps` (mapname VARCHAR(50) NOT NULL PRIMARY KEY, `tier` INT(2) NOT NULL);
 ```
* Fill it with all the maps you are tracking.
* Ensure you have all the maps you want in `mapcycle.txt` on your server.
