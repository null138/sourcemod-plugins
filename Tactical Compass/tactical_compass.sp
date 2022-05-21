#pragma semicolon 1

#define PLUGIN_AUTHOR "null138"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <clientprefs>

#pragma newdecls required

// yeah i know thats a full mess xd
static const char compassString[400] = "3 -|- 553 -|- =:N:= -|- 01 -|- 51 -|- 02 -|- 52 -|- 03 -|- =:NE:= -|- 05 -|- 06 -\ 
		|- 56 -|- 07 -|- 57 -|- =:E:= -|- 001 -|- 501 -|- 511 -|- 021 -|- =:SE:= -|- 041 -|- 051 -\
		|- 551 -|- 061 | 561 | =:S:= | 091 | 591 -|- 002 -|- 012 -|- 022 -|- =:SW:= -|- 542 -|- 052 -\
		|- 062 -|- 562 -|- =:W:= -|-  582  -|-  592 -|- 003 -|- 503 -|- =:NW:= -|- 033 -|- 043 | 543 \
		| 053 -|- 553 -|- =:N:= -|- 01 -|- 5";

Handle hCookie;
bool bDisabled[MAXPLAYERS + 1] = {false, ...};

public Plugin myinfo = 
{
	name = "Tactical Compass",
	author = PLUGIN_AUTHOR,
	description = "Compass like on some FPS games",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/null138/"
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_compass", cmdCompass);
	hCookie = RegClientCookie("compass_disabled", "Compass Disabled", CookieAccess_Protected);
}

public void OnClientCookiesCached(int client)
{
	char buffer[2];
	GetClientCookie(client, hCookie, buffer, 2);
	bDisabled[client] = view_as<bool>(StringToInt(buffer));
}

public Action cmdCompass(int client, int args)
{
	if(IsClientInGame(client))
	{
		bDisabled[client] = !bDisabled[client];
		PrintToChat(client, "\x03 Tactical Compass %sabled", bDisabled[client] ? "dis" : "en");
		SetClientCookie(client, hCookie, bDisabled[client] ? "1" : "0");
	}
	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if(IsClientInGame(client) && !bDisabled[client])
	{
		float angles[3];
		GetClientEyeAngles(client, angles); // here we have current angles. the one on function param is delayed
		
		int pos, dir, count = 16;
		dir = AngleTo360Int(angles[1]);
		
		char buffer[64];		
		buffer[0] = '[';
		buffer[1] = ' ';
		for (int i = 0; i < 32; i++)
		{
			pos = dir + count;
			Format(buffer, 64, "%s%c", buffer, compassString[pos+16]);
			count--;
		}
		buffer[strlen(buffer)-1] = ' ';
		buffer[strlen(buffer)] = ']';
		
		PrintHintText(client, buffer);
		StopSound(client, SNDCHAN_STATIC, "UI/hint.wav");
	}
} 

int AngleTo360Int(const float angle)
{
	float temp = angle;
	if(temp < 0.0)
	{
		temp += 360.0;
	}
	return RoundToFloor(temp);
}