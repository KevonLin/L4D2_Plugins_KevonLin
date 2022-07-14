#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <builtinvotes>
#undef REQUIRE_PLUGIN
#include <confogl>
#include <colors>
#define L4D2UTIL_STOCKS_ONLY 1
#include <l4d2util>

#define MATCHMODES_PATH		"configs/matchmodes.txt"
#define TRANSLATION_FILE 	"l4d2_votemenu.phrases"

#define MaxHP 100

// Menu
// 	g_MapList;

Handle
	// g_map_array = null,
	g_hVote = null;

KeyValues
	g_hModesKV = null;

ConVar
	sm_votemenu_enable,
	sm_votemenu_timedelay,
	sm_votemenu_givehp,
	sm_votemenu_pills,
	sm_votemenu_changeslots,
	sm_votemenu_nextmap,
	sm_votemenu_changethirdmaps,
	sm_votemenu_ban,
	sm_votemenu_kick,
	sm_votemenu_mute,
	sm_votemenu_toggleaddons,
	sm_votemenu_toggleready,
	sm_votemenu_changeconfigs,
	sm_match_player_limit,
	cvarMvMaxPlayers,
	cvarAddons,
	cvarConsistency,
	cvarPure,
	cvarPureKickClients,
	cvarReady;

char
	g_sCfg[32],
	g_sSlots[64];

int
	// g_map_serial = -1,
	g_cvarAddons = -2,
	g_cvarReady = -1,
	g_iSlots;

bool
	g_bVoteEnable = false;

enum voteType
{
	None,
	hp,
	pills,
	slots,
	nextmap,
	thirdmap,
	ban,
	kick,
	mute,
	addons,
	ready,
	config,
}

voteType g_voteType = None;

public Plugin myinfo =
{
	name = "Vote Menu",
	author = "Kevonlin",
	description = "Vote Menu.",
	version = "1.4.4",
	url = "https://steamcommunity.com/profiles/76561199044101393/"
};

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int iErrMax)
{
	EngineVersion iEngine = GetEngineVersion();
	if (iEngine != Engine_Left4Dead2) {
		strcopy(sError, iErrMax, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}

public void OnPluginStart()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "translations/"...TRANSLATION_FILE...".txt");
	if (!FileExists(sPath))
	{
		SetFailState("Missing translation \""...TRANSLATION_FILE..."\"");
	}
	LoadTranslations(TRANSLATION_FILE);

	char sBuffer[PLATFORM_MAX_PATH];
	g_hModesKV = new KeyValues("MatchModes");
	BuildPath(Path_SM, sBuffer, sizeof(sBuffer), MATCHMODES_PATH);

	if (!g_hModesKV.ImportFromFile(sBuffer)) {
		SetFailState("Couldn't load matchmodes.txt!");
	}

	sm_votemenu_enable = CreateConVar("sm_votemenu_enable", "1", "Plugin Enable", 0, true, 0.0, true, 1.0);
	sm_votemenu_timedelay = CreateConVar("sm_votemenu_timedelay", "30.0", "Vote time interval", 0, true, 0.0);
	sm_votemenu_givehp = CreateConVar("sm_votemenu_givehp", "1", "Give hp Enable", 0, true, 0.0, true, 1.0);
	sm_votemenu_pills = CreateConVar("sm_votemenu_pills", "1", "Give hp Enable", 0, true, 0.0, true, 1.0);
	sm_votemenu_changeslots = CreateConVar("sm_votemenu_changeslots", "1", "Change slots Enable", 0, true, 0.0, true, 1.0);
	sm_votemenu_nextmap = CreateConVar("sm_votemenu_nextmap", "0", "Change next map Enable", 0, true, 0.0, true, 1.0);
	sm_votemenu_changethirdmaps = CreateConVar("sm_votemenu_changethirdmaps", "0", "Change third maps Enable", 0, true, 0.0, true, 1.0);
	sm_votemenu_ban = CreateConVar("sm_votemenu_ban", "0", "Ban Enable", 0, true, 0.0, true, 1.0);
	sm_votemenu_kick = CreateConVar("sm_votemenu_kick", "0", "Kick Enable", 0, true, 0.0, true, 1.0);
	sm_votemenu_mute = CreateConVar("sm_votemenu_mute", "0", "Mute Enable", 0, true, 0.0, true, 1.0);
	sm_votemenu_toggleaddons = CreateConVar("sm_votemenu_toggleaddons", "0", "Toggle addons Enable", 0, true, 0.0, true, 1.0);
	sm_votemenu_toggleready = CreateConVar("sm_votemenu_toggleready", "0", "Toggle ready Enable", 0, true, 0.0, true, 1.0);
	sm_votemenu_changeconfigs = CreateConVar("sm_votemenu_changeconfigs", "1", "Change configs Enable", 0, true, 0.0, true, 1.0);
	sm_match_player_limit = CreateConVar("sm_match_player_limit", "1", "Minimum # of players in game to start the vote", _, true, 1.0, true, 32.0);

	cvarMvMaxPlayers = FindConVar("sv_maxplayers");
	cvarAddons = FindConVar("l4d2_addons_eclipse");
	cvarConsistency = FindConVar("sv_consistency");
	cvarPure = FindConVar("sv_pure");
	cvarPureKickClients = FindConVar("sv_pure_kick_clients");
	cvarReady = FindConVar("l4d_ready_enabled");
	
	g_cvarAddons = GetConVarInt(cvarAddons);
	g_cvarReady = GetConVarInt(cvarReady);

	HookConVarChange(cvarAddons, CVarChanged);
	HookConVarChange(cvarAddons, CVarChanged);

	RegConsoleCmd("sm_votemenu", Command_Votes, "Open vote menu.");
	RegConsoleCmd("sm_votes", Command_Votes, "Open vote menu.");

	AutoExecConfig(true, "l4d2_votemenu");
}

public void OnMapStart()
{
	g_bVoteEnable = true;
}

public void OnMapEnd()
{
	g_bVoteEnable = false;
}

public void CVarChanged(Handle cvar, char[] oldValue, char[] newValue)
{
	g_cvarAddons = GetConVarInt(cvarAddons);
	g_cvarReady = GetConVarInt(cvarReady);
}


// public void OnConfigsExecuted()
// {
// 	LoadMapList(g_MapList);
// }

public Action Command_Votes(int iClient, int iArgs)
{
	//Test
	// CPrintToChat(iClient,"l4d2_addons_eclipse = %i", g_cvarAddons);
	// CPrintToChat(iClient,"l4d_ready_enabled = %i", g_cvarReady);

	if(iClient == 0 || !sm_votemenu_enable.BoolValue)
	{
		return Plugin_Handled;
	}

	if (GetClientTeam(iClient) <= L4D2Team_Spectator) {
		CPrintToChat(iClient, "{blue}[{default}Vote{blue}] {default}Match voting isn't allowed for spectators.");
		return Plugin_Handled;
	}

	if (!g_bVoteEnable)
	{
		CPrintToChat(iClient, "{blue}[{default}Vote{blue}] {default}You can not start after a vote at once.");
		return Plugin_Handled;
	}
	
	BuildVoteMenu(iClient);
	return Plugin_Handled;
}

void BuildVoteMenu(int iClient)
{
	char sBuffer[64];
	Menu vMenu = new Menu(VoteMenuHandler);
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Menu name" ,iClient);
	vMenu.SetTitle(sBuffer);
	
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Give hp" ,iClient);
	vMenu.AddItem("givehp", sBuffer);
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Give pills" ,iClient);
	vMenu.AddItem("givepills", sBuffer);
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Change slots" ,iClient);
	vMenu.AddItem("changeslots", sBuffer);
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Next map" ,iClient);
	vMenu.AddItem("nextmap", sBuffer);
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Change third maps" ,iClient);
	vMenu.AddItem("changethirdmaps", sBuffer);
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Ban players" ,iClient);
	vMenu.AddItem("banplayers", sBuffer);
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Kick players" ,iClient);
	vMenu.AddItem("kickplayers", sBuffer);
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Mute players" ,iClient);
	vMenu.AddItem("muteplayers", sBuffer);
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Toggle addons" ,iClient);
	vMenu.AddItem("toggleaddons", sBuffer);
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Toggle ready" ,iClient);
	vMenu.AddItem("toggleready", sBuffer);
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Change config" ,iClient);
	vMenu.AddItem("changeconfig", sBuffer);

	vMenu.ExitButton = true;
	vMenu.Display(iClient, 30);
}

public int VoteMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
			delete menu;

		case MenuAction_Select:
		{
			char item[64];
			menu.GetItem(param2, item, sizeof(item));

			if(strcmp(item, "givehp") == 0)
			{
				if (sm_votemenu_givehp.IntValue == 0)
				{
					CPrintToChat(param1, "{blue}[{default}Vote{blue}] {default}This function is disabled.");
					BuildVoteMenu(param1);
					return 0;
				}

				g_voteType = view_as<voteType>(hp);
				if (StartVote(param1))
				{
					LogMessage("Start a give hp vote.");
					//caller is voting for
					FakeClientCommand(param1, "Vote Yes");
				} 
				else
				{
					g_voteType = view_as<voteType>(None);
					BuildVoteMenu(param1);
				}
			}
			else if(strcmp(item, "givepills") == 0)
			{
				if (sm_votemenu_pills.IntValue == 0)
				{
					CPrintToChat(param1, "{blue}[{default}Vote{blue}] {default}This function is disabled.");
					BuildVoteMenu(param1);
					return 0;
				}

				g_voteType = view_as<voteType>(pills);
				if (StartVote(param1))
				{
					LogMessage("Start a give pills vote.");
					//caller is voting for
					FakeClientCommand(param1, "Vote Yes");
				} 
				else
				{
					g_voteType = view_as<voteType>(None);
					BuildVoteMenu(param1);
				}
			}
			else if(strcmp(item, "changeslots") == 0)
			{
				if (sm_votemenu_changeslots.IntValue == 0)
				{
					CPrintToChat(param1, "{blue}[{default}Vote{blue}] {default}This function is disabled.");
					BuildVoteMenu(param1);
					return 0;
				}

				SlotsMenu(param1);
			}
			else if (strcmp(item, "nextmap") == 0)
			{
				if (sm_votemenu_changethirdmaps.IntValue == 0)
				{
					CPrintToChat(param1, "{blue}[{default}Vote{blue}] {default}This function is disabled.");
					BuildVoteMenu(param1);
					return 0;
				}

				// MapMenu(param1);
			}
			else if (param2 == 4)
			{
				if (sm_votemenu_nextmap.IntValue == 0)
				{
					CPrintToChat(param1, "{blue}[{default}Vote{blue}] {default}This function is disabled.");
					BuildVoteMenu(param1);
					return 0;
				}
				// FakeClientCommand(param1, "sm_changeconfigs");
			}
			else if (param2 == 5)
			{
				if (sm_votemenu_ban.IntValue == 0)
				{
					CPrintToChat(param1, "{blue}[{default}Vote{blue}] {default}This function is disabled.");
					BuildVoteMenu(param1);
					return 0;
				}
				// FakeClientCommand(param1, "sm_voteban");
			}
			else if (param2 == 6)
			{
				if (sm_votemenu_kick.IntValue == 0)
				{
					CPrintToChat(param1, "{blue}[{default}Vote{blue}] {default}This function is disabled.");
					BuildVoteMenu(param1);
					return 0;
				}
				// FakeClientCommand(param1, "sm_votekick");
			}
			else if (param2 == 7)
			{
				if (sm_votemenu_mute.IntValue == 0)
				{
					CPrintToChat(param1, "{blue}[{default}Vote{blue}] {default}This function is disabled.");
					BuildVoteMenu(param1);
					return 0;
				}
				// FakeClientCommand(param1, "sm_mute");
			}
			else if (strcmp(item, "toggleaddons") == 0)
			{
				if (sm_votemenu_toggleaddons.IntValue == 0)
				{
					CPrintToChat(param1, "{blue}[{default}Vote{blue}] {default}This function is disabled.");
					BuildVoteMenu(param1);
					return 0;
				}
				
				AddonsMenu(param1);
			}
			else if (param2 == 9)
			{
				if (sm_votemenu_toggleready.IntValue == 0)
				{
					CPrintToChat(param1, "{blue}[{default}Vote{blue}] {default}This function is disabled.");
					BuildVoteMenu(param1);
					return 0;
				}
				
				ReadyMenu(param1);
			}
			else if (strcmp(item, "changeconfig") == 0)
			{
				if (sm_votemenu_changeconfigs.IntValue == 0)
				{
					CPrintToChat(param1, "{blue}[{default}Vote{blue}] {default}This function is disabled.");
					BuildVoteMenu(param1);
					return 0;
				}

				MatchModeMenu(param1);
			}
		}	
	}
	return 0;
}

void SlotsMenu(int iClient)
{
	char sBuffer[64];
	Menu vMenu = new Menu(SlotsMenuHandler);
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Slots Menu" ,iClient);
	vMenu.SetTitle(sBuffer);
	
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Slots 8" ,iClient);
	vMenu.AddItem("slots8", sBuffer);
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Slots 10" ,iClient);
	vMenu.AddItem("slots10", sBuffer);
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Slots 12" ,iClient);
	vMenu.AddItem("slots12", sBuffer);
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Slots 14" ,iClient);
	vMenu.AddItem("slots14", sBuffer);
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Slots 16" ,iClient);
	vMenu.AddItem("slots16", sBuffer);

	vMenu.ExitBackButton = true;
	vMenu.ExitButton = true;
	vMenu.Display(iClient, 30);
}

public int SlotsMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End) {
		delete menu;
	} else if (action == MenuAction_Cancel){
		BuildVoteMenu(param1);
	} else if (action == MenuAction_Select) {
		g_voteType = view_as<voteType>(slots);

		char item[64];
		menu.GetItem(param2, item, sizeof(item));

		if(strcmp(item, "slots8") == 0)
		{
			g_sSlots = "8";
		}
		else if(strcmp(item, "slots10") == 0)
		{
			g_sSlots = "10";
		}
		else if(strcmp(item, "slots12") == 0)
		{
			g_sSlots = "12";
		}
		else if(strcmp(item, "slots14") == 0)
		{
			g_sSlots = "14";
		}
		else if(strcmp(item, "slots16") == 0)
		{
			g_sSlots = "16";
		}

		g_iSlots = StringToInt(g_sSlots);
		
		if (cvarMvMaxPlayers.IntValue == g_iSlots)
		{
			CPrintToChat(param1, "{blue}[{default}Vote{blue}] {default}Slots already has a value of %i", g_iSlots);
			return 0;
		}

		if(strcmp(item, "slots8") == 0)
		{
			if (StartVote(param1))
			{
				LogMessage("Start a Slots 8 vote.");
				//caller is voting for
				FakeClientCommand(param1, "Vote Yes");
			} 
			else
			{
				g_voteType = view_as<voteType>(None);
				BuildVoteMenu(param1);
			}
		}
		else if(strcmp(item, "slots10") == 0)
		{
			if (StartVote(param1))
			{
				LogMessage("Start a Slots 10 vote.");
				//caller is voting for
				FakeClientCommand(param1, "Vote Yes");
			} 
			else
			{
				g_voteType = view_as<voteType>(None);
				BuildVoteMenu(param1);
			}
		}
		else if(strcmp(item, "slots12") == 0)
		{
			if (StartVote(param1))
			{
				LogMessage("Start a Slots 12 vote.");
				//caller is voting for
				FakeClientCommand(param1, "Vote Yes");
			} 
			else
			{
				g_voteType = view_as<voteType>(None);
				BuildVoteMenu(param1);
			}
		}
		else if(strcmp(item, "slots14") == 0)
		{
			if (StartVote(param1))
			{
				LogMessage("Start a Slots 14 vote.");
				//caller is voting for
				FakeClientCommand(param1, "Vote Yes");
			} 
			else
			{
				g_voteType = view_as<voteType>(None);
				BuildVoteMenu(param1);
			}
		}
		else if(strcmp(item, "slots16") == 0)
		{
			if (StartVote(param1))
			{
				LogMessage("Start a Slots 16 vote.");
				//caller is voting for
				FakeClientCommand(param1, "Vote Yes");
			} 
			else
			{
				g_voteType = view_as<voteType>(None);
				BuildVoteMenu(param1);
			}
		}
	} 

	return 0;
}

// void MapMenu(int iClient)
// {
// 	g_MapList = new Menu(MenuHandler_ChangeMap, MenuAction_Display);
// 	g_MapList.SetTitle("%T", "Select map menu", iClient);
// 	g_MapList.ExitBackButton = true;
// }

// public int MenuHandler_ChangeMap(Menu menu, MenuAction action, int param1, int param2)
// {
// 	if (action == MenuAction_Cancel)
// 	{
// 		if (param2 == MenuCancel_ExitBack)
// 		{
// 			BuildVoteMenu(param1);
// 		}
// 	}
// 	else if (action == MenuAction_Select)
// 	{
// 		char map[PLATFORM_MAX_PATH];
		
// 		menu.GetItem(param2, map, sizeof(map));
	
// 		// ShowActivity2(param1, "[SM] ", "%t", "Changing map", map);

// 		LogAction(param1, -1, "\"%L\" changed map to \"%s\"", param1, map);

// 		DataPack dp;
// 		CreateDataTimer(3.0, Timer_ChangeMap, dp);
// 		dp.WriteString(map);
// 	}
// 	else if (action == MenuAction_Display)
// 	{
// 		char title[128];
// 		Format(title, sizeof(title), "%T", "Select map menu", param1);

// 		Panel panel = view_as<Panel>(param2);
// 		panel.SetTitle(title);
// 	}

// 	return 0;
// }

// public Action Timer_ChangeMap(Handle timer, DataPack dp)
// {
// 	char map[PLATFORM_MAX_PATH];

// 	dp.Reset();
// 	dp.ReadString(map, sizeof(map));

// 	ForceChangeLevel(map, "sm_map Command");

// 	return Plugin_Stop;
// }

void AddonsMenu(int iClient)
{
	char sBuffer[64];
	Menu vMenu = new Menu(AddonsMenuHandler);
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Toggle addons" ,iClient);
	vMenu.SetTitle(sBuffer);
	
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Enable addons" ,iClient);
	vMenu.AddItem("enablemod", sBuffer);
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Disable addons" ,iClient);
	vMenu.AddItem("disablemod", sBuffer);

	vMenu.ExitBackButton = true;
	vMenu.ExitButton = true;
	vMenu.Display(iClient, 30);
}

public int AddonsMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End) {
		delete menu;
	} else if (action == MenuAction_Cancel){
		BuildVoteMenu(param1);
	} else if (action == MenuAction_Select) {
		g_voteType = view_as<voteType>(addons);

		char item[64];
		menu.GetItem(param2, item, sizeof(item));

		if(strcmp(item, "enablemod") == 0)
		{
			if (g_cvarAddons == 1)
			{
				CPrintToChat(param1, "Addons is already Enable");
				AddonsMenu(param1);
				return 0;
			}

			if (StartVote(param1))
			{
				LogMessage("Start a enbale addons vote.");
				//caller is voting for
				FakeClientCommand(param1, "Vote Yes");
			} 
			else
			{
				g_voteType = view_as<voteType>(None);
				BuildVoteMenu(param1);
			}
		}
		else if(strcmp(item, "disablemod") == 0)
		{
			if (g_cvarAddons != 1)
			{
				CPrintToChat(param1, "Addons is already Disable");
				AddonsMenu(param1);
				return 0;
			}

			if (StartVote(param1))
			{
				LogMessage("Start a disable addons vote.");
				//caller is voting for
				FakeClientCommand(param1, "Vote Yes");
			} 
			else
			{
				g_voteType = view_as<voteType>(None);
				BuildVoteMenu(param1);
			}
		}
	}
	return 0;
}

void ReadyMenu(int iClient)
{
	char sBuffer[64];
	Menu vMenu = new Menu(ReadyMenuHandler);
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Toggle ready" ,iClient);
	vMenu.SetTitle(sBuffer);
	
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Enable ready" ,iClient);
	vMenu.AddItem("enableready", sBuffer);
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Disable ready" ,iClient);
	vMenu.AddItem("disableready", sBuffer);

	vMenu.ExitBackButton = true;
	vMenu.ExitButton = true;
	vMenu.Display(iClient, 30);
}

public int ReadyMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End) {
		delete menu;
	} else if (action == MenuAction_Cancel){
		BuildVoteMenu(param1);
	} else if (action == MenuAction_Select) {
		g_voteType = view_as<voteType>(ready);

		char item[64];
		menu.GetItem(param2, item, sizeof(item));

		if(strcmp(item, "enableready") == 0)
		{
			if (g_cvarReady == 1)
			{
				CPrintToChat(param1, "Ready plugin was already enabled");
				ReadyMenu(param1);
				return 0;
			}

			if (StartVote(param1))
			{
				LogMessage("Start a enbale ready plugin vote.");
				//caller is voting for
				FakeClientCommand(param1, "Vote Yes");
			} 
			else
			{
				g_voteType = view_as<voteType>(None);
				BuildVoteMenu(param1);
			}
		}
		else if(strcmp(item, "disableready") == 0)
		{
			if (g_cvarReady == 2 || g_cvarReady == 0)
			{
				CPrintToChat(param1, "Ready plugin was already disabled");
				ReadyMenu(param1);
				return 0;
			}

			if (StartVote(param1))
			{
				LogMessage("Start a disable ready plugin vote.");
				//caller is voting for
				FakeClientCommand(param1, "Vote Yes");
			} 
			else
			{
				g_voteType = view_as<voteType>(None);
				BuildVoteMenu(param1);
			}
		}
	}
	return 0;
}

void MatchModeMenu(int iClient)
{
	Menu hMenu = new Menu(MatchModeMenuHandler);

	char sBuffer[64];
	g_hModesKV.Rewind();

	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Match mode menu", iClient);
	hMenu.SetTitle(sBuffer);

	if (g_hModesKV.GotoFirstSubKey()) {
		do {
			g_hModesKV.GetSectionName(sBuffer, sizeof(sBuffer));
			hMenu.AddItem(sBuffer, sBuffer);
		} while (g_hModesKV.GotoNextKey(false));
	}

	hMenu.ExitBackButton = true;
	hMenu.ExitButton = true;
	hMenu.Display(iClient, 20);
}

public int MatchModeMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End) {
		delete menu;
	} else if (action == MenuAction_Select) {
		char sInfo[64], sBuffer[64];
		menu.GetItem(param2, sInfo, sizeof(sInfo));

		g_hModesKV.Rewind();

		if (g_hModesKV.JumpToKey(sInfo) && g_hModesKV.GotoFirstSubKey()) {
			Menu hMenu = new Menu(ConfigsMenuHandler);

			FormatEx(sBuffer, sizeof(sBuffer), "%T", "Match config menu", param1);
			hMenu.SetTitle(sBuffer);

			do {
				g_hModesKV.GetSectionName(sInfo, sizeof(sInfo));
				g_hModesKV.GetString("name", sBuffer, sizeof(sBuffer));

				hMenu.AddItem(sInfo, sBuffer);
			} while (g_hModesKV.GotoNextKey());

			hMenu.Display(param1, 20);
		} else {
			CPrintToChat(param1, "{blue}[{default}Vote{blue}] {default}No configs for such mode were found.");
			MatchModeMenu(param1);
		}
	} else if (action == MenuAction_Cancel){
		BuildVoteMenu(param1);
	}

	return 0;
}

public int ConfigsMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End) {
		delete menu;
	} else if (action == MenuAction_Cancel) {
		MatchModeMenu(param1);
	} else if (action == MenuAction_Select) {
		char sInfo[64], sBuffer[64];
		menu.GetItem(param2, sInfo, sizeof(sInfo), _, sBuffer, sizeof(sBuffer));

		if (StartMatchVote(param1, sBuffer)) {
			strcopy(g_sCfg, sizeof(g_sCfg), sInfo);
			g_voteType = view_as<voteType>(config);
			LogMessage("Start a config vote.");
			//caller is voting for
			FakeClientCommand(param1, "Vote Yes");
		} else {
			MatchModeMenu(param1);
		}
	}

	return 0;
}

bool StartMatchVote(int iClient, const char[] sCfgName)
{
	if (GetClientTeam(iClient) <= L4D2Team_Spectator) {
		CPrintToChat(iClient, "{blue}[{default}Vote{blue}] {default}Match voting isn't allowed for spectators.");
		return false;
	}

	if (!IsBuiltinVoteInProgress()) {
		int iNumPlayers = 0;
		int[] iPlayers = new int[MaxClients];

		//list of non-spectators players
		for (int i = 1; i <= MaxClients; i++) {
			if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) <= L4D2Team_Spectator) {
				continue;
			}

			iPlayers[iNumPlayers++] = i;
		}

		if (iNumPlayers < sm_match_player_limit.IntValue) {
			CPrintToChat(iClient, "{blue}[{default}Vote{blue}] {default}Match vote cannot be started. Not enough players.");
			return false;
		}

		char sBuffer[64];
		FormatEx(sBuffer, sizeof(sBuffer), "Load confogl '%s' config?", sCfgName, iClient);

		g_hVote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		SetBuiltinVoteArgument(g_hVote, sBuffer);
		SetBuiltinVoteInitiator(g_hVote, iClient);
		SetBuiltinVoteResultCallback(g_hVote, VoteResultHandler);
		DisplayBuiltinVote(g_hVote, iPlayers, iNumPlayers, 15);

		return true;
	}

	CPrintToChat(iClient, "{blue}[{default}Vote{blue}] {default}Match vote cannot be started now.");
	return false;
}

bool StartVote(int iClient)
{
	if (GetClientTeam(iClient) <= L4D2Team_Spectator) {
		CPrintToChat(iClient, "{blue}[{default}Vote{blue}] {default}Vote isn't allowed for spectators.");
		return false;
	}

	g_bVoteEnable = false;
	CreateTimer(sm_votemenu_timedelay.FloatValue, Timer_VoteDelay, _);

	if (!IsBuiltinVoteInProgress()) {
		int iNumPlayers = 0;
		int[] iPlayers = new int[MaxClients];

		//list of non-spectators players
		for (int i = 1; i <= MaxClients; i++) {
			if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) <= L4D2Team_Spectator) {
				continue;
			}

			iPlayers[iNumPlayers++] = i;
		}

		if (iNumPlayers < sm_match_player_limit.IntValue) {
			CPrintToChat(iClient, "{blue}[{default}Vote{blue}] {default}Vote cannot be started. Not enough players.");
			return false;
		}

		char sBuffer[64];
		if (g_voteType == view_as<voteType>(hp))
			FormatEx(sBuffer, sizeof(sBuffer), "%T", "Give hp context", iClient);
		else if (g_voteType == view_as<voteType>(pills))
			FormatEx(sBuffer, sizeof(sBuffer), "%T", "Give pills context", iClient);
		else if (g_voteType == view_as<voteType>(slots))
		{
			if (g_iSlots == 8)
				FormatEx(sBuffer, sizeof(sBuffer), "%T", "Slots 8", iClient);
			else if (g_iSlots == 10)
				FormatEx(sBuffer, sizeof(sBuffer), "%T", "Slots 10", iClient);
			else if (g_iSlots == 12)
				FormatEx(sBuffer, sizeof(sBuffer), "%T", "Slots 12", iClient);
			else if (g_iSlots == 14)
				FormatEx(sBuffer, sizeof(sBuffer), "%T", "Slots 14", iClient);
			else if (g_iSlots == 16)
				FormatEx(sBuffer, sizeof(sBuffer), "%T", "Slots 16", iClient);
		}
		else if (g_voteType == view_as<voteType>(addons))
		{
			if(g_cvarAddons == 1)
			{
				FormatEx(sBuffer, sizeof(sBuffer), "%T", "Disable addons", iClient);
			}
			else if(g_cvarAddons != 1)
			{
				FormatEx(sBuffer, sizeof(sBuffer), "%T", "Enable addons", iClient);
			}
		}
		else if (g_voteType == view_as<voteType>(ready))
		{
			if(g_cvarReady == 1)
			{
				FormatEx(sBuffer, sizeof(sBuffer), "%T", "Disable ready", iClient);
			}
			else if(g_cvarReady == 2 || g_cvarReady == 0)
			{
				FormatEx(sBuffer, sizeof(sBuffer), "%T", "Enable ready", iClient);
			}
		}

		g_hVote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		SetBuiltinVoteArgument(g_hVote, sBuffer);
		SetBuiltinVoteInitiator(g_hVote, iClient);
		SetBuiltinVoteResultCallback(g_hVote, VoteResultHandler);
		DisplayBuiltinVote(g_hVote, iPlayers, iNumPlayers, 15);

		return true;
	}

	CPrintToChat(iClient, "{blue}[{default}Vote{blue}] {default}Vote cannot be started now.");
	return false;
}

public void VoteActionHandler(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
	switch (action) {
		case BuiltinVoteAction_End: {
			delete vote;
			g_hVote = null;
		}
		case BuiltinVoteAction_Cancel: {
			DisplayBuiltinVoteFail(vote, view_as<BuiltinVoteFailReason>(param1));
		}
	}
}

public void VoteResultHandler(Handle vote, int num_votes, int num_clients, \
										const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++) {
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES) {
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2)) {
				ExecVoteRes(vote);
				return;
			}
		}
	}

	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

void ExecVoteRes(Handle vote)
{
	switch (g_voteType)
	{
		case (view_as<voteType>(hp)):
		{
			RecoveryHealth(vote);
			LogMessage("Vote to give hp");	
		}

		case (view_as<voteType>(pills)):
		{
			GivePills(vote);
			LogMessage("Vote to give pills");	
		}

		case (view_as<voteType>(slots)):
		{
			ChangeSlots(vote);
			LogMessage("Vote to change slots");	
		}

		case (view_as<voteType>(addons)):
		{
			ToggleAddons(vote);
			LogMessage("Vote to toggle addons");	
		}

		case (view_as<voteType>(ready)):
		{
			ToggleReady(vote);
			LogMessage("Vote to toggle ready");	
		}

		case (view_as<voteType>(config)):
		{
			LoadConfig(vote);
			LogMessage("Vote to change config pass");	
		}
	}

	g_voteType = view_as<voteType>(None);

	return;
}

public Action Timer_VoteDelay(Handle timer, any client)
{
	g_bVoteEnable = true;
	return Plugin_Continue;
}

void RecoveryHealth(Handle vote)
{
	DisplayBuiltinVotePass(vote, "Give Health");
	int flags = GetCommandFlags("give");	
	SetCommandFlags("give", flags & ~FCVAR_CHEAT);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			FakeClientCommand(i, "give health");
			SetSurvivorPermanentHealth(i, MaxHP);
			SetSurvivorTempHealth(i, 0);
		}
	}
	SetCommandFlags("give", flags|FCVAR_CHEAT);
	CPrintToChatAll("{blue}[{default}Vote{blue}] {olive}All survivors {default}has restored.");
}

void SetSurvivorPermanentHealth(int client, int health)
{
	SetEntProp(client, Prop_Send, "m_iHealth", health);
}

void SetSurvivorTempHealth(int client, int health)
{
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", float(health));
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
}

void GivePills(Handle vote)
{
	DisplayBuiltinVotePass(vote, "Give Pills");
	int flags = GetCommandFlags("give");	
	SetCommandFlags("give", flags & ~FCVAR_CHEAT);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			FakeClientCommand(i, "give pain_pills");
		}
	}
	SetCommandFlags("give", flags|FCVAR_CHEAT);
	CPrintToChatAll("{blue}[{default}Vote{blue}] {olive}Pills {default}has distributed to {blue}All survivors");
}

void ChangeSlots(Handle vote)
{
	DisplayBuiltinVotePass(vote, "Limiting Slots...");
	SetConVarInt(cvarMvMaxPlayers, g_iSlots);
	CPrintToChatAll("{blue}[{default}Vote{olive}] {blue}Slots {default}has limited to {blue}%i", g_iSlots);
}

void ToggleAddons(Handle vote)
{
	DisplayBuiltinVotePass(vote, "Toggle Addons...");
	if (g_cvarAddons == -1 || g_cvarAddons == 0)
	{
		SetConVarString(cvarAddons, "1");
		SetConVarString(cvarConsistency, "0");
		SetConVarBool(cvarPure, false);
		SetConVarString(cvarPureKickClients, "0");
		CPrintToChatAll("{blue}[{default}Vote{olive}] {blue}Addons {default}has toggle to {blue}disalbe");
	}
	else if (g_cvarAddons == 1)
	{
		SetConVarString(cvarAddons, "0");
		SetConVarString(cvarConsistency, "1");
		SetConVarString(cvarPure, "2");
		SetConVarString(cvarPureKickClients, "1");
		CPrintToChatAll("{blue}[{default}Vote{olive}] {blue}Addons {default}has toggle to {blue}enable");
	}

	CPrintToChatAll("{blue}[{default}Vote{olive}] {default}Map will restart after {blue}3s");
	CreateTimer(3.0, RestartMap,_);
}

void ToggleReady(Handle vote)
{
	DisplayBuiltinVotePass(vote, "Toggle ready...");
	if (g_cvarReady == 1)
	{
		SetConVarInt(cvarReady, 2);
		CPrintToChatAll("{blue}[{default}Vote{olive}] {blue}Ready {default}has toggle to {blue}disalbe");
	}
	else if (g_cvarReady == 0 || g_cvarReady == 2)
	{
		SetConVarInt(cvarReady, 1);
		CPrintToChatAll("{blue}[{default}Vote{olive}] {blue}Ready {default}has toggle to {blue}enalbe");
	}

	CPrintToChatAll("{blue}[{default}Vote{olive}] {default}Map will restart after {blue}3s");
	CreateTimer(3.0, RestartMap,_);
}

public Action RestartMap(Handle timer,any client)
{
	char currentMap[256];
	GetCurrentMap(currentMap, 256);
	ServerCommand("changelevel %s", currentMap);

	return Plugin_Continue;
}

// int LoadMapList(Menu menu)
// {
// 	Handle map_array;
	
// 	if ((map_array = ReadMapList(g_map_array,
// 			g_map_serial,
// 			"sm_map menu",
// 			MAPLIST_FLAG_CLEARARRAY|MAPLIST_FLAG_MAPSFOLDER))
// 		!= null)
// 	{
// 		g_map_array = map_array;
// 	}
	
// 	if (g_map_array == null)
// 	{
// 		return 0;
// 	}
	
// 	menu.RemoveAllItems();
	
// 	char map_name[PLATFORM_MAX_PATH];
// 	int map_count = GetArraySize(g_map_array);
	
// 	for (int i = 0; i < map_count; i++)
// 	{
// 		char displayName[PLATFORM_MAX_PATH];
// 		GetArrayString(g_map_array, i, map_name, sizeof(map_name));
// 		GetMapDisplayName(map_name, displayName, sizeof(displayName));
// 		menu.AddItem(map_name, displayName);
// 	}
	
// 	return map_count;
// }

void LoadConfig(Handle vote)
{
	DisplayBuiltinVotePass(vote, "Matchmode Loaded");
	if (LGO_IsMatchModeLoaded()) {
		ServerCommand("sm_resetmatch");
	}
	ServerCommand("sm_forcematch %s", g_sCfg);
}