#pragma semicolon 1

#define PLUGIN_AUTHOR "null138"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <dhooks>

#pragma newdecls required

Handle 
	hProcessPackets,
	hFPSM_OnClientFpsUpdated;
	
int 
	iFpsSlow[MAXPLAYERS + 1],
	iFpsFast[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "FPS Monitoring Core",
	author = PLUGIN_AUTHOR,
	description = "Provides information about players frames-per-second",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/null138/"
}

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int err_max)
{
    RegPluginLibrary("FpsMonitoring");
}

public void OnPluginStart()
{
	Handle conf = LoadGameConfigFile("fpsmonitoring");
	if (conf == INVALID_HANDLE)
		SetFailState("Failed to load gamedata fpsmonitoring");
	
	hProcessPackets = DHookCreateDetour(Address_Null, CallConv_THISCALL, ReturnType_Void, ThisPointer_Ignore);
	if (!hProcessPackets)
		SetFailState("Failed to setup detour for CNetChan::ProcessPacket");
	
	if (!DHookSetFromConf(hProcessPackets, conf, SDKConf_Signature, "CNetChan::ProcessPacket"))
		SetFailState("Failed to load CNetChan::ProcessPacket signature from gamedata");
	
	DHookAddParam(hProcessPackets, HookParamType_ObjectPtr);
	DHookAddParam(hProcessPackets, HookParamType_Bool);
	
	if (!DHookEnableDetour(hProcessPackets, false, ProcessPackets))
		SetFailState("Failed to detour CNetChan::ProcessPacket");
		
	delete conf;
	
	hFPSM_OnClientFpsUpdated = CreateGlobalForward("FPSM_OnClientFpsUpdated", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	CreateNative("FPSM_GetClientFpsCount", Native_GetClientFpsCount);
}

public MRESReturn ProcessPackets(Handle hParams) 
{
	static int iPackets[MAXPLAYERS + 1];
	static int iPacketsFast[MAXPLAYERS + 1];
	static float fPacker[MAXPLAYERS + 1];
	static float fPackerFast[MAXPLAYERS + 1];
	
	int rawAdr = DHookGetParamObjectPtrVar(hParams, 1, 4, ObjectValueType_Int);
	int client = GetClientFromNetAdr(rawAdr);
	
	if(client > 0)
	{
		if(GetEngineTime() - fPackerFast[client] >= 0.25)
		{
			iFpsFast[client] = RoundToFloor(iPacketsFast[client]*3.75);
			iPacketsFast[client] = 0;
			fPackerFast[client] = GetEngineTime();
			
			Call_StartForward(hFPSM_OnClientFpsUpdated);
			Call_PushCell(client);
			Call_PushCell(iFpsSlow[client]);
			Call_PushCell(iFpsFast[client]);
			Call_Finish();
		}
		
		if(GetEngineTime() - fPacker[client] >= 1.0)
		{
			iFpsSlow[client] = iPackets[client];
			iPackets[client] = 0;
			fPacker[client] = GetEngineTime();
			
			Call_StartForward(hFPSM_OnClientFpsUpdated);
			Call_PushCell(client);
			Call_PushCell(iFpsSlow[client]);
			Call_PushCell(iFpsFast[client]);
			Call_Finish();
		}
	
		iPackets[client]++;
		iPacketsFast[client]++;
	}
}

int GetClientFromNetAdr(int netadr)
{
	int rawIp[4];
	char finalIp[16], targetIp[16];
	
	rawIp[0] = (netadr >> 24) & 0x000000FF;
	rawIp[1] = (netadr >> 16) & 0x000000FF; 
	rawIp[2] = (netadr >> 8) & 0x000000FF; 
	rawIp[3] = netadr & 0x000000FF; 
	
	Format(finalIp, 16, "%i.%i.%i.%i", rawIp[3], rawIp[2], rawIp[1], rawIp[0]);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			GetClientIP(i, targetIp, 16);
			if(!strcmp(finalIp, targetIp))
			{
				return i;
			}
		}
	}
	return -1;
}

public int Native_GetClientFpsCount(Handle plugin, int params)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients+1 || !IsClientInGame(client) || IsFakeClient(client))
	{
		LogError("Client %i is invalid", client);
		return -1;
	}
	return GetNativeCell(2) ? iFpsFast[client] : iFpsSlow[client];
}