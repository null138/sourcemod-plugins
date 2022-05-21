#pragma semicolon 1

#define PLUGIN_AUTHOR "null138"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <dhooks>

#pragma newdecls required

Handle hGetPlayerSlot, hExecuteStringCommand;

#define KICK_REASON "DO NOT SPAM THE SERVER COMMANDS"
#define MAX_CMD_COUNT 40 // optimal value

public Plugin myinfo = 
{
	name = "Anti Command Spam",
	author = PLUGIN_AUTHOR,
	description = "Prevents any command spammings",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/null138/"
}

public void OnPluginStart()
{
	Handle conf = LoadGameConfigFile("anticmdspam");
	if (conf == INVALID_HANDLE)
		SetFailState("Failed to load gamedata anticmdspam");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(conf, SDKConf_Virtual, "CGameClient::GetPlayerSlot()"); // 3 linux, 14 win
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	hGetPlayerSlot = EndPrepSDKCall();
	
	hExecuteStringCommand = DHookCreateDetour(Address_Null, CallConv_THISCALL, ReturnType_Bool, ThisPointer_Address);
	if (!hExecuteStringCommand)
		SetFailState("Failed to setup detour for CGameClient::ExecuteStringCommand()");
	
	if (!DHookSetFromConf(hExecuteStringCommand, conf, SDKConf_Signature, "CGameClient::ExecuteStringCommand()"))
		SetFailState("Failed to load CGameClient::ExecuteStringCommand() signature from gamedata");
	
	DHookAddParam(hExecuteStringCommand, HookParamType_CharPtr);
	
	if (!DHookEnableDetour(hExecuteStringCommand, true, ExecuteStringCommand))
		SetFailState("Failed to detour CGameClient::ExecuteStringCommand()");
	
	delete conf;
}

public MRESReturn ExecuteStringCommand(Address addrThis, Handle hReturn, Handle hParams) 
{
	int client = SDKCall(hGetPlayerSlot, addrThis) + 1;
	
	if(client && CalcCmdSend(client))
	{
		DHookSetReturn(hReturn, 0);
		KickClientEx(client, KICK_REASON); // faster than KickClient()
		return MRES_Supercede;
	}

	return MRES_Ignored;
}

bool CalcCmdSend(int client)
{
	static float fLastCmd[MAXPLAYERS + 1];
	static int iCmdCount[MAXPLAYERS + 1];
	
	if(!IsClientConnected(client)) return false;
	
	if(iCmdCount[client]++ <= MAX_CMD_COUNT) return false;
	
	if(GetGameTime() >= fLastCmd[client] + 1.0)
	{
		fLastCmd[client] = GetGameTime();
		iCmdCount[client] = 0;
		return false;
	}
	
	fLastCmd[client] = GetGameTime();
	iCmdCount[client] = 0;
	return true;
}