#pragma semicolon 1

#define PLUGIN_AUTHOR "null138"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>

#pragma newdecls required

#define DUMP_CYCLE_TIME 60.0
#define LOG_WARNING_TIME 1.0

float 
	fMapStartTime = 0.0,
	fcvActivityLackRate = 0.0;

static char cLogPath[PLATFORM_MAX_PATH];
int icvDumpHandles = 0;

public Plugin myinfo = 
{
	name = "Performance Monitor",
	author = PLUGIN_AUTHOR,
	description = "Logs about lags, crashes and etc. Generates handles dump",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/null138/"
}

public void OnPluginStart()
{
	ConVar cvar = CreateConVar("pfm_dump_handles", "1", "Generate handle dump");
	icvDumpHandles = cvar.IntValue;
	cvar.AddChangeHook(CVAR_DUMP_HANDLES);
	
	cvar = CreateConVar("pfm_activity_lack_time", "0.3", "Maximum timeout time to start logging");
	fcvActivityLackRate = cvar.FloatValue;
	cvar.AddChangeHook(CVAR_ACTIVITY_LACK_TIME);
	
	AutoExecConfig(true);
}

public void OnPluginEnd()
{
	OnMapEnd();
}

public void CVAR_DUMP_HANDLES(ConVar cvar, const char[] oldValue, const char[] newValue) 
{
	icvDumpHandles = cvar.IntValue;
}

public void CVAR_ACTIVITY_LACK_TIME(ConVar cvar, const char[] oldValue, const char[] newValue) 
{
	fcvActivityLackRate = cvar.FloatValue;
}

public void OnMapStart()
{
	fMapStartTime = GetEngineTime();
	
	char path[PLATFORM_MAX_PATH];
	int time = GetTime();
	
	FormatTime(path, sizeof(path), "%d_%b_%Y", time);
	BuildPath(Path_SM, cLogPath, sizeof(cLogPath), "logs/LagLogs_%s.txt", path);
	Handle file = OpenFile(cLogPath, "a+");
	CloseHandle(file);
	
	BuildPath(Path_SM, path, sizeof(path), "configs/pfm_savedata.ini");

	KeyValues kv = CreateKeyValues("server");
	if(!kv.ImportFromFile(path)) 
	{
		LogMessage("Unable to load config \"%s\"!", path);
		delete kv;
		return;
	}
	
	char map[128], doMapEnded[2], playerCount[4];
	kv.Rewind();
	kv.GotoFirstSubKey();
	kv.GetString("map", map, 128);
	kv.GetString("domapended", doMapEnded, 2);
	kv.GetString("playercount", playerCount, 4);
		
	if(map[0] != '\0' && StringToInt(doMapEnded) != 1)
	{
		LogToFileEx(cLogPath, "Server probably got crashed. Last map was \"%s\", players count %s", map, playerCount);
	}
	
	GetCurrentMap(map, 128);
	kv.SetString("map", map);
	kv.SetString("domapended", "0");
	Format(playerCount, 4, "%i", GetClientCount(false));
	kv.SetString("playercount", playerCount);
	kv.Rewind();
	kv.ExportToFile(path);
	
	delete kv;
}

public void OnMapEnd()
{
	char path[PLATFORM_MAX_PATH], map[128], playerCount[4];
	BuildPath(Path_SM, path, sizeof(path), "configs/pfm_savedata.ini");
	
	KeyValues kv = CreateKeyValues("server");
	if(!kv.ImportFromFile(path)) 
	{
		LogMessage("Unable to load config \"%s\"!", path);
		delete kv;
		return;
	}
	
	kv.GotoFirstSubKey();
	GetCurrentMap(map, 128);
	kv.SetString("map", map);
	kv.SetString("domapended", "1");
	Format(playerCount, 4, "%i", GetClientCount(false));
	kv.SetString("playercount", playerCount);
	kv.Rewind();
	kv.ExportToFile(path);
	
	delete kv;
}

public void OnGameFrame()
{
	if(fMapStartTime == 0.0 || GetEngineTime() - fMapStartTime < 10.0)
		return;
	
	static int iTicks = 0;
	static int iLastTicks = 0;
	static float fTicker = 0.0;
	static float fLatestActivity = 0.0;
	static float fWarningTime = 0.0;
	static float fDumpHandlesTime = 0.0;
	
	if(fTicker == 0.0 || fLatestActivity == 0.0 || fWarningTime == 0.0)
	{
		fTicker = fLatestActivity = fWarningTime = fDumpHandlesTime = GetEngineTime();
		return;
	}
	
	if(GetEngineTime() - fTicker > 1.0)
	{
		if(iLastTicks != 0 && iTicks != iLastTicks && (iTicks - iLastTicks > 1 || iTicks - iLastTicks < -1))
		{
			if(GetEngineTime() - fWarningTime >= LOG_WARNING_TIME)
			{
				fWarningTime = GetEngineTime();
				LogToFileEx(cLogPath, "Performance problems! The engine is unstable. Ticks passed: %i", iLastTicks - iTicks);
				
				if(icvDumpHandles != 0 && GetEngineTime() - fDumpHandlesTime >= DUMP_CYCLE_TIME)
				{
					fDumpHandlesTime = GetEngineTime();
					int value = GetRandomInt(1, 999999);
					LogToFileEx(cLogPath, "Generated handle dump! File \"logs/Lagdumps_%i.txt\"", value);
					ServerCommand("sm_dump_handles \"addons/sourcemod/logs/LagDumps_%i.txt\"", value);
				}
			}
		}
		
		iLastTicks = iTicks;
		iTicks = 0;
		fTicker = GetEngineTime();
	}
	else iTicks++;
	
	if(GetEngineTime() - fLatestActivity > fcvActivityLackRate)
	{
		if(GetEngineTime() - fWarningTime >= LOG_WARNING_TIME)
		{
			fWarningTime = GetEngineTime();
			LogToFileEx(cLogPath, "Huge performance drop! Engine got timeout: %.4f second(s)", GetEngineTime() - fLatestActivity);
			
			if(icvDumpHandles != 0 && GetEngineTime() - fDumpHandlesTime >= DUMP_CYCLE_TIME)
			{
				fDumpHandlesTime = GetEngineTime();
				int value = GetRandomInt(1, 999999);
				LogToFileEx(cLogPath, "Generated handle dump! File \"logs/Lagdumps_%i.txt\"", value);
				ServerCommand("sm_dump_handles \"addons/sourcemod/logs/LagDumps_%i.txt\"", value);
			}
		}
	}
	
	fLatestActivity = GetEngineTime();
}
