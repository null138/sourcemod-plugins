#pragma semicolon 1

#define PLUGIN_AUTHOR "null138 & ZombieFeyk (CS:GO ver)"
#define PLUGIN_VERSION "2.00"

#include <sourcemod>
#include <sdktools>

#pragma newdecls required

EngineVersion iEngineVersion;

public Plugin myinfo = 
{
	name = "Movement Manipulate Fix",
	author = PLUGIN_AUTHOR,
	description = "Prevents hacks from manipulating player movement",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/null138/"
}

public void OnPluginStart()
{
	iEngineVersion = GetEngineVersion();
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3])
{
	if(IsPlayerAlive(client) && !IsFakeClient(client))
	{
		switch(iEngineVersion)
		{
			case Engine_CSS:
			{
				if(vel[0] != 0.0 && (vel[0] != 200.0 && vel[0] != 400.0 && vel[0] != -200.0 && vel[0] != -400.0))
				{
					vel[0] = vel[1] = vel[2] = 0.0;
					return Plugin_Changed;
				}
	
				if(vel[1] != 0.0 && (vel[1] != 200.0 && vel[1] != 400.0 && vel[1] != -200.0 && vel[1] != -400.0))
				{
					vel[0] = vel[1] = vel[2] = 0.0;
					return Plugin_Changed;
				}
	
				if(vel[2] != 0.0 && (vel[2] != 200.0 && vel[2] != 400.0 && vel[2] != -200.0 && vel[2] != -400.0))
				{
					vel[0] = vel[1] = vel[2] = 0.0;
					return Plugin_Changed;
				}
			}
			case Engine_CSGO:
			{
				if(vel[0] != 0.0 && (vel[0] != 225.0 && vel[0] != 450.0 && vel[0] != -225.0 && vel[0] != -450.0))
				{
					vel[0] = vel[1] = vel[2] = 0.0;
					return Plugin_Changed;
				}
	
				if(vel[1] != 0.0 && (vel[1] != 225.0 && vel[1] != 450.0 && vel[1] != -225.0 && vel[1] != -450.0))
				{
					vel[0] = vel[1] = vel[2] = 0.0;
					return Plugin_Changed;
				}
	
				if(vel[2] != 0.0 && (vel[2] != 225.0 && vel[2] != 450.0 && vel[2] != -225.0 && vel[2] != -450.0))
				{
					vel[0] = vel[1] = vel[2] = 0.0;
					return Plugin_Changed;
				}
			}
		}
	}
	return Plugin_Continue;
}