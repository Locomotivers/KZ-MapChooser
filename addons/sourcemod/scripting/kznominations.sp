/**
 * vim: set ts=4 :
 * =============================================================================
 * Nominations Extended
 * Allows players to nominate maps for Mapchooser
 *
 * Nominations Extended (C)2012-2013 Powerlord (Ross Bemrose)
 * SourceMod (C)2004-2007 AlliedModders LLC.  All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 * Version: $Id$
 */

#include <sourcemod>
#include <mapchooser>
#include "include/mapchooser_extended"
#include <colors>
#pragma semicolon 1

#define MCE_VERSION "1.10.0"

public Plugin:myinfo =
{
	name = "KZ Map Nominations",
	author = "Powerlord, AlliedModders LLC & Infra",
	description = "Provides Map Nominations for KZ Servers.",
	version = "2.0.2",
	url = "https://github.com/1zc/KZ-MapChooser"
};

//new Handle:g_Cvar_ExcludeOld = INVALID_HANDLE;
//new Handle:g_Cvar_ExcludeCurrent = INVALID_HANDLE;
ConVar g_Cvar_ExcludeOld;
ConVar g_Cvar_ExcludeCurrent;
ConVar g_Cvar_ServerTier;

//new Handle:g_MapList = INVALID_HANDLE;
ArrayList g_MapList = null;
ArrayList g_MapListTier = null;
ArrayList g_MapListWhiteList = null;
new Handle:g_MapMenu = INVALID_HANDLE;
new g_mapFileSerial = -1;

#define MAPSTATUS_ENABLED (1<<0)
#define MAPSTATUS_DISABLED (1<<1)
#define MAPSTATUS_EXCLUDE_CURRENT (1<<2)
#define MAPSTATUS_EXCLUDE_PREVIOUS (1<<3)
#define MAPSTATUS_EXCLUDE_NOMINATED (1<<4)

new Handle:g_mapTrie;

// SQL Connection
Handle g_hDb = null;
#define PERCENT 0x25

// Nominations Extended Convars
new Handle:g_Cvar_MarkCustomMaps = INVALID_HANDLE;

public OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("nominations.phrases");
	LoadTranslations("basetriggers.phrases"); // for Next Map phrase
	LoadTranslations("mapchooser_extended.phrases");

	db_setupDatabase();
	
	//new arraySize = ByteCountToCells(PLATFORM_MAX_PATH);	
	//g_MapList = CreateArray(arraySize);
	int arraySize = ByteCountToCells(PLATFORM_MAX_PATH);
	g_MapList = new ArrayList(arraySize);
	g_MapListTier = new ArrayList(arraySize);
	g_MapListWhiteList = new ArrayList(arraySize);
	
	g_Cvar_ExcludeOld = CreateConVar("sm_nominate_excludeold", "1", "Specifies if the current map should be excluded from the Nominations list", 0, true, 0.00, true, 1.0);
	g_Cvar_ExcludeCurrent = CreateConVar("sm_nominate_excludecurrent", "1", "Specifies if the MapChooser excluded maps should also be excluded from Nominations", 0, true, 0.00, true, 1.0);
	g_Cvar_ServerTier = CreateConVar("sm_server_tier", "1.0", "Specifies the servers tier to only include maps from, for example if you want a tier 1-3 server make it 1.3, a tier 2 only server would be 2.0, etc", 0, true, 1.0, true, 6.0);

	RegConsoleCmd("say", Command_Say);
	RegConsoleCmd("say_team", Command_Say);
	
	RegConsoleCmd("sm_nominate", Command_Nominate);
	
	RegAdminCmd("sm_nominate_addmap", Command_Addmap, ADMFLAG_CHANGEMAP, "sm_nominate_addmap <mapname> - Forces a map to be on the next mapvote.");
	
	// Nominations Extended cvars
	CreateConVar("ne_version", MCE_VERSION, "Nominations Extended Version", FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_mapTrie = CreateTrie();

	AutoExecConfig(true, "KZ_Nominations");
}

public OnAllPluginsLoaded()
{
	// This is an MCE cvar... this plugin requires MCE to be loaded.  Granted, this plugin SHOULD have an MCE dependency.
	g_Cvar_MarkCustomMaps = FindConVar("mce_markcustommaps");
}

public OnConfigsExecuted()
{
	if (ReadMapList(g_MapListWhiteList,
					g_mapFileSerial,
					"nominations",
					MAPLIST_FLAG_CLEARARRAY|MAPLIST_FLAG_MAPSFOLDER)
		== INVALID_HANDLE)
	{
		if (g_mapFileSerial == -1)
		{
			SetFailState("Unable to create a valid map list.");
		}
	}
	
	SelectMapList();
	//BuildMapMenu();
}

public OnNominationRemoved(const String:map[], owner)
{
	new status;

	char resolvedMap[PLATFORM_MAX_PATH];
	FindMap(map, resolvedMap, sizeof(resolvedMap));
	
	/* Is the map in our list? */
	if (!GetTrieValue(g_mapTrie, resolvedMap, status))
	{
		return;	
	}
	
	/* Was the map disabled due to being nominated */
	if ((status & MAPSTATUS_EXCLUDE_NOMINATED) != MAPSTATUS_EXCLUDE_NOMINATED)
	{
		return;
	}
	
	SetTrieValue(g_mapTrie, resolvedMap, MAPSTATUS_ENABLED);	
}

public Action:Command_Addmap(client, args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "[\x0CKZ-MC\x01] Usage: sm_nominate_addmap <mapname>");
		return Plugin_Handled;
	}
	
	decl String:mapname[PLATFORM_MAX_PATH];
	char resolvedMap[PLATFORM_MAX_PATH];
	GetCmdArg(1, mapname, sizeof(mapname));

	if (FindMap(mapname, resolvedMap, sizeof(resolvedMap)) == FindMap_NotFound)
	{
		// We couldn't resolve the map entry to a filename, so...
		ReplyToCommand(client, "%t", "Map was not found", mapname);
		return Plugin_Handled;		
	}
	
	char displayName[PLATFORM_MAX_PATH];
	GetMapDisplayName(resolvedMap, displayName, sizeof(displayName));

	new status;
	if (!GetTrieValue(g_mapTrie, mapname, status))
	{
		CReplyToCommand(client, "%t", "Map was not found", displayName);
		return Plugin_Handled;		
	}

	RemoveMapPath(resolvedMap, resolvedMap, sizeof(resolvedMap));
	
	new NominateResult:result = NominateMap(mapname, true, 0);
	
	if (result > Nominate_Replaced)
	{
		/* We assume already in vote is the casue because the maplist does a Map Validity check and we forced, so it can't be full */
		CReplyToCommand(client, "%t", "Map Already In Vote", displayName);
		
		return Plugin_Handled;	
	}
	
	
	SetTrieValue(g_mapTrie, mapname, MAPSTATUS_DISABLED|MAPSTATUS_EXCLUDE_NOMINATED);

	
	CReplyToCommand(client, "%t", "Map Inserted", displayName);
	LogAction(client, -1, "\"%L\" inserted map \"%s\".", client, mapname);

	return Plugin_Handled;		
}

public Action:Command_Say(client, args)
{
	if (!client)
	{
		return Plugin_Continue;
	}

	decl String:text[192];
	if (!GetCmdArgString(text, sizeof(text)))
	{
		return Plugin_Continue;
	}
	
	new startidx = 0;
	if(text[strlen(text)-1] == '"')
	{
		text[strlen(text)-1] = '\0';
		startidx = 1;
	}
	
	new ReplySource:old = SetCmdReplySource(SM_REPLY_TO_CHAT);
	
	if (strcmp(text[startidx], "nominate", false) == 0)
	{
		if (IsNominateAllowed(client))
		{
			AttemptNominate(client);
		}
	}
	
	SetCmdReplySource(old);
	
	return Plugin_Continue;	
}

public Action:Command_Nominate(client, args)
{
	if (!client || !IsNominateAllowed(client))
	{
		return Plugin_Handled;
	}
	
	if (args == 0)
	{
		AttemptNominate(client);
		return Plugin_Handled;
	}
	
	decl String:mapname[PLATFORM_MAX_PATH];
	char resolvedMap[PLATFORM_MAX_PATH];
	char displayName[PLATFORM_MAX_PATH];
	GetCmdArg(1, mapname, sizeof(mapname));

	if (FindMap(mapname, resolvedMap, sizeof(resolvedMap)) == FindMap_NotFound)
	{
		// We couldn't resolve the map entry to a filename, so...
		ReplyToCommand(client, "%t", "Map was not found", mapname);
		return Plugin_Handled;		
	}

	else 
	{
		FindMap(mapname, resolvedMap, sizeof(resolvedMap));
		GetMapDisplayName(resolvedMap, displayName, sizeof(displayName));
	}

	new status;
	if (!GetTrieValue(g_mapTrie, displayName, status))
	{
		CReplyToCommand(client, "%t", "Map was not found", displayName);
		return Plugin_Handled;		
	}
	
	if ((status & MAPSTATUS_DISABLED) == MAPSTATUS_DISABLED)
	{
		if ((status & MAPSTATUS_EXCLUDE_CURRENT) == MAPSTATUS_EXCLUDE_CURRENT)
		{
			CReplyToCommand(client, "[\x0CKZ-MC\x01] %t", "Can't Nominate Current Map");
		}
		
		if ((status & MAPSTATUS_EXCLUDE_PREVIOUS) == MAPSTATUS_EXCLUDE_PREVIOUS)
		{
			CReplyToCommand(client, "[\x0CKZ-MC\x01] %t", "Map in Exclude List");
		}
		
		if ((status & MAPSTATUS_EXCLUDE_NOMINATED) == MAPSTATUS_EXCLUDE_NOMINATED)
		{
			CReplyToCommand(client, "[\x0CKZ-MC\x01] %t", "Map Already Nominated");
		}
		
		return Plugin_Handled;
	}

	RemoveMapPath(resolvedMap, resolvedMap, sizeof(resolvedMap));
	new NominateResult:result = NominateMap(displayName, false, client);
	
	if (result > Nominate_Replaced)
	{
		if (result == Nominate_AlreadyInVote)
		{
			CReplyToCommand(client, "%t", "Map Already In Vote", displayName);
		}
		else
		{
			CReplyToCommand(client, "[\x0CKZ-MC\x01] %t", "Map Already Nominated");
		}
		
		return Plugin_Handled;	
	}
	
	/* Map was nominated! - Disable the menu item and update the trie */
	
	SetTrieValue(g_mapTrie, mapname, MAPSTATUS_DISABLED|MAPSTATUS_EXCLUDE_NOMINATED);
	
	decl String:name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));
	PrintToChatAll("[\x0CKZ-MC\x01] %t", "Map Nominated", name, displayName);
	LogMessage("%s nominated %s", name, displayName);

	return Plugin_Continue;
}

AttemptNominate(client)
{
	SetMenuTitle(g_MapMenu, "%T", "Nominate Title", client);
	DisplayMenu(g_MapMenu, client, MENU_TIME_FOREVER);
	
	return;
}

BuildMapMenu()
{
	CloseHandle(g_MapMenu);
	g_MapMenu = INVALID_HANDLE;
	
	ClearTrie(g_mapTrie);
	
	g_MapMenu = CreateMenu(Handler_MapSelectMenu, MENU_ACTIONS_DEFAULT|MenuAction_DrawItem|MenuAction_DisplayItem);

	decl String:map[PLATFORM_MAX_PATH];
	
	new Handle:excludeMaps = INVALID_HANDLE;
	decl String:currentMap[PLATFORM_MAX_PATH];
	
	if (GetConVarBool(g_Cvar_ExcludeOld))
	{	
		excludeMaps = CreateArray(ByteCountToCells(PLATFORM_MAX_PATH));
		GetExcludeMapList(excludeMaps);
	}
	
	if (GetConVarBool(g_Cvar_ExcludeCurrent))
	{
		GetCurrentMap(currentMap, sizeof(currentMap));
	}
	
		
	for (new i = 0; i < GetArraySize(g_MapList); i++)
	{
		new status = MAPSTATUS_ENABLED;
		g_MapList.GetString(i, map, sizeof(map));
		FindMap(map, map, sizeof(map));
		char displayName[PLATFORM_MAX_PATH];
		GetArrayString(g_MapListTier, i, displayName, sizeof(displayName));
		// GetMapDisplayName(map, displayName, sizeof(displayName));
		//GetArrayString(g_MapListTier, i, map, sizeof(map));
		//GetArrayString(g_MapList, i, map, sizeof(map));
		
		if (GetConVarBool(g_Cvar_ExcludeCurrent))
		{
			if (StrEqual(map, currentMap))
			{
				status = MAPSTATUS_DISABLED|MAPSTATUS_EXCLUDE_CURRENT;
			}
		}
		
		/* Dont bother with this check if the current map check passed */
		if (GetConVarBool(g_Cvar_ExcludeOld) && status == MAPSTATUS_ENABLED)
		{
			if (FindStringInArray(excludeMaps, map) != -1)
			{
				status = MAPSTATUS_DISABLED|MAPSTATUS_EXCLUDE_PREVIOUS;
			}
		}
		
		AddMenuItem(g_MapMenu, map, displayName);
		SetTrieValue(g_mapTrie, map, status);
	}
	
	SetMenuExitButton(g_MapMenu, true);

	if (excludeMaps != INVALID_HANDLE)
	{
		CloseHandle(excludeMaps);
	}
}

public Handler_MapSelectMenu(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			decl String:map[PLATFORM_MAX_PATH], String:name[MAX_NAME_LENGTH]; 
			char displayName[PLATFORM_MAX_PATH];
			GetMenuItem(menu, param2, map, sizeof(map), _, displayName, sizeof(displayName));		
			
			GetClientName(param1, name, MAX_NAME_LENGTH);
	
			new NominateResult:result = NominateMap(map, false, param1);
			
			/* Don't need to check for InvalidMap because the menu did that already */
			if (result == Nominate_AlreadyInVote)
			{
				PrintToChat(param1, "[\x0CKZ-MC\x01] %t", "Map Already Nominated");
				return 0;
			}
			else if (result == Nominate_VoteFull)
			{
				PrintToChat(param1, "[\x0CKZ-MC\x01] %t", "Max Nominations");
				return 0;
			}
			
			SetTrieValue(g_mapTrie, map, MAPSTATUS_DISABLED|MAPSTATUS_EXCLUDE_NOMINATED);

			if (result == Nominate_Replaced)
			{
				PrintToChatAll("[\x0CKZ-MC\x01] %t", "Map Nomination Changed", name, displayName);
				return 0;	
			}
			
			PrintToChatAll("[\x0CKZ-MC\x01] %t", "Map Nominated", name, displayName);
			LogMessage("%s nominated %s", name, map);
		}
		
		case MenuAction_DrawItem:
		{
			decl String:map[PLATFORM_MAX_PATH];
			GetMenuItem(menu, param2, map, sizeof(map));
			
			new status;
			
			if (!GetTrieValue(g_mapTrie, map, status))
			{
				LogError("Menu selection of item not in trie. Major logic problem somewhere.");
				return ITEMDRAW_DEFAULT;
			}
			
			if ((status & MAPSTATUS_DISABLED) == MAPSTATUS_DISABLED)
			{
				return ITEMDRAW_DISABLED;	
			}
			
			return ITEMDRAW_DEFAULT;
						
		}
		
		case MenuAction_DisplayItem:
		{
			decl String:map[PLATFORM_MAX_PATH];
			char displayName[PLATFORM_MAX_PATH];
			//GetMenuItem(menu, param2, map, sizeof(map));
			GetMenuItem(menu, param2, map, sizeof(map), _, displayName, sizeof(displayName));
			
			new mark = GetConVarInt(g_Cvar_MarkCustomMaps);
			new bool:official;

			new status;
			
			if (!GetTrieValue(g_mapTrie, map, status))
			{
				LogError("Menu selection of item not in trie. Major logic problem somewhere.");
				return 0;
			}
			
			decl String:buffer[100];
			char display[PLATFORM_MAX_PATH + 64];
			
			if (mark)
			{
				official = IsMapOfficial(map);
			}
			
			if (mark && !official)
			{
				switch (mark)
				{
					case 1:
					{
						Format(buffer, sizeof(buffer), "%T", "Custom Marked", param1, map);
					}
					
					case 2:
					{
						Format(buffer, sizeof(buffer), "%T", "Custom", param1, map);
					}
				}
			}
			else
			{
				strcopy(buffer, sizeof(buffer), displayName);
			}
			
			if ((status & MAPSTATUS_DISABLED) == MAPSTATUS_DISABLED)
			{
				if ((status & MAPSTATUS_EXCLUDE_CURRENT) == MAPSTATUS_EXCLUDE_CURRENT)
				{
					Format(display, sizeof(display), "%s (%T)", buffer, "Current Map", param1);
					return RedrawMenuItem(display);
				}
				
				if ((status & MAPSTATUS_EXCLUDE_PREVIOUS) == MAPSTATUS_EXCLUDE_PREVIOUS)
				{
					Format(display, sizeof(display), "%s (%T)", buffer, "Recently Played", param1);
					return RedrawMenuItem(display);
				}
				
				if ((status & MAPSTATUS_EXCLUDE_NOMINATED) == MAPSTATUS_EXCLUDE_NOMINATED)
				{
					Format(display, sizeof(display), "%s (%T)", buffer, "Nominated", param1);
					return RedrawMenuItem(display);
				}
			}
			
			if (mark && !official)
				return RedrawMenuItem(buffer);
			
			return 0;
		}
	}
	
	return 0;
}

public void db_setupDatabase()
{
	char szError[255];
	g_hDb = SQL_Connect("kzMaps", false, szError, 255);

	if (g_hDb == null)
		SetFailState("[Nominations] Unable to connect to database (%s)", szError);
	
	return;
}

public void SelectMapList()
{
	char szQuery[512], szTier[16], szBuffer[2][32];

	GetConVarString(g_Cvar_ServerTier, szTier, sizeof(szTier));
	ExplodeString(szTier, ".", szBuffer, 2, 32);

	if (StrEqual(szBuffer[1], "0"))
		Format(szQuery, sizeof(szQuery), "select kz_maps.mapname, kz_maps.tier, kz_maps.ljroom from kz_maps where kz_maps.tier = %s group by mapname;", szBuffer[0]);
	else if (strlen(szBuffer[1]) > 0)
		Format(szQuery, sizeof(szQuery), "select kz_maps.mapname, kz_maps.tier, kz_maps.ljroom from kz_maps WHERE kz_maps.tier >= %s AND kz_maps.tier <= %s group by mapname;", szBuffer[0], szBuffer[1]);
	else
		Format(szQuery, sizeof(szQuery), "select kz_maps.mapname, kz_maps.tier, kz_maps.ljroom from kz_maps group by mapname;");

	SQL_TQuery(g_hDb, SelectMapListCallback, szQuery, DBPrio_Low);
}

public void SelectMapListCallback(Handle owner, Handle hndl, const char[] error, any tier)
{
	if (hndl == null)
	{
		LogError("[Nominations] SQL Error (SelectMapListCallback): %s", error);
		return;
	}

	if (SQL_HasResultSet(hndl))
	{
		g_MapList.Clear();
		g_MapListTier.Clear();

		char szValue[512], szMapName[128];
		int ljroom = 0;
		while (SQL_FetchRow(hndl))
		{
			SQL_FetchString(hndl, 0, szMapName, sizeof(szMapName));
			tier = SQL_FetchInt(hndl, 1);
			ljroom = SQL_FetchInt(hndl, 2);
			if (ljroom == 1)
				Format(szValue, sizeof(szValue), "%s - Tier %d | LJ Room", szMapName, tier);
			else
				Format(szValue, sizeof(szValue), "%s - Tier %d", szMapName, tier);

			if (FindStringInArray(g_MapListWhiteList, szMapName) > -1){
				g_MapList.PushString(szMapName);
				g_MapListTier.PushString(szValue);
			}
		}

		BuildMapMenu();
	}
}

stock bool:IsNominateAllowed(client)
{
	new CanNominateResult:result = CanNominate();
	
	switch(result)
	{
		case CanNominate_No_VoteInProgress:
		{
			CReplyToCommand(client, "[ME] %t", "Nextmap Voting Started");
			return false;
		}
		
		case CanNominate_No_VoteComplete:
		{
			new String:map[PLATFORM_MAX_PATH];
			GetNextMap(map, sizeof(map));
			CReplyToCommand(client, "[\x0CKZ-MC\x01] %t", "Next Map", map);
			return false;
		}
		
		case CanNominate_No_VoteFull:
		{
			CReplyToCommand(client, "[ME] %t", "Max Nominations");
			return false;
		}
	}
	
	return true;
}

public void RemoveMapPath(const char[] map, char[] destination, any maxlen)
{
	if (strlen(map) < 1)
	{
		ThrowError("Bad map name: %s", map);
	}
	
	// UNIX paths
	char pos = FindCharInString(map, '/', true);
	if (pos == -1)
	{
		// Windows paths
		pos = FindCharInString(map, '\\', true);
		if (pos == -1)
		{
			//destination[0] = '\0';
			strcopy(destination, maxlen, map);
		}
	}

	// strlen is last + 1
	int len = strlen(map) - 1 - pos;
	
	// pos + 1 is because pos is the last / or \ location and we want to start one char further
	SubString(map, pos + 1, len, destination, maxlen);
}

public void SubString(const char[] source, any start, any len, char[] destination, any maxlen)
{
	if (maxlen < 1)
	{
		ThrowError("Destination size must be 1 or greater, but was %d", maxlen);
	}
	
	// optimization
	if (len == 0)
	{
		destination[0] = '\0';
	}
	
	if (start < 0)
	{
		// strlen doesn't count the null terminator, so don't -1 on it.
		start = strlen(source) + start;
		if (start < 0)
			start = 0;
	}
	
	if (len < 0)
	{
		len = strlen(source) + len - start;
		// If length is still less than 0, that'd be an error.
	}
	
	// Check to make sure destination is large enough to hold the len, or truncate it.
	// len + 1 because second arg to strcopy counts 1 for the null terminator
	int realLength = len + 1 < maxlen ? len + 1 : maxlen;
	
	strcopy(destination, realLength, source[start]);
}