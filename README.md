# MapChooser for KZ Servers

This is a modified version of MapChooserExtended intended for KZ Servers with support for dynamic map lists, tier display and KZTimer skillgroup limits for RTVing. This allows you to maintain several servers using a central-hosted map-pool - For KZTimer, this allows you to maintain skill-groups across servers even with different local map-pools!

It requires a database table with entries for all maps you want to track, along with tier information and LJ Room availability.

## Requirements

* Sourcemod 1.10
* MySQL Database Server
* KZTimer/GOKZ installed and set up correctly.

## Installation

* Grab the latest [release](https://github.com/1zc/KZ-MapChooser/releases/latest) and extract it to your csgo server directory.
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

## Related CVars:

### KZ_RTV.cfg
* sm_rtv_skillgroup_requirement -- Specify the minimum skillgroup a player must be to allow use of RTV. Only works for KZTimer! Set to 0 to disable or if you are using GOKZ. (0 = Unranked)

### KZ_Nominations.cfg
* sm_server_tier -- Specify the map tiers you intend to host on the server. For a tier 1-2 server, you should specify "1.2". For only tier 7s, specify "7.0" 

Let's say you host several KZ Climb servers, separated by difficulty tiers - A Tier1-2 server and a Tier3-7 server. Put all the maps you host (in total, tier1-7) in both the server's local mapcycle.txt file. Then, populate the kz_maps table in the kztimer/gokz database with all the maps - you can use the maplist.sql in this repository. 

All you need to then do is specify the local server's map tiers using the sm_server_tier CVar to host only those maps, while syncing skillgroups across all your servers!

## Try Out The Plugin:

```
IP: gokz.gflclan.com:27015
```
