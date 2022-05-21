#pragma semicolon 1

#define PLUGIN_AUTHOR "null138"
#define PLUGIN_VERSION "5.00"

#include <sourcemod>
#include <sdktools>
#include <clientprefs>

#pragma newdecls required

int iTracerTableID = -1, icvRandom, icvSilencer, icvPercent;
Handle hCookieDisabled;
bool bDisabled[MAXPLAYERS + 1] = {false, ...};

public Plugin myinfo = 
{
	name = "Bullet Tracers like on CS:GO/HL2",
	author = PLUGIN_AUTHOR,
	description = "Unlocks game effect",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/null138/"
};

public void OnPluginStart()
{
	ConVar cvar;
	cvar = CreateConVar("bullet_tracer_random", "0", "0 = Tracer appears for every shoot. \
														1 = Enable random appearance. \
														2 = Percentage mode");
	icvRandom = cvar.IntValue;
	cvar.AddChangeHook(CVAR_RANDOM);
	
	cvar = CreateConVar("bullet_tracer_nosilencer", "0", "0 = Enable tracers for any weapon. \
															1 = Tracers disabled for silenced weapons");
	icvSilencer = cvar.IntValue;
	cvar.AddChangeHook(CVAR_NOSILENCER);
	
	cvar = CreateConVar("bullet_tracer_percent", "30", "Value to use as appearance chance percentage if enabled");
	icvPercent = cvar.IntValue;
	cvar.AddChangeHook(CVAR_PERCENT);
	
	AutoExecConfig(true);
	
	RegConsoleCmd("sm_tracers", cmdTracers);
	
	// weapon_fire event is poor choice to use here
	HookEvent("bullet_impact", OnBulletImpact);
	
	hCookieDisabled = RegClientCookie("hl2tracer_disabled", "Tracers Disabled", CookieAccess_Protected);
}

public void CVAR_RANDOM(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	icvRandom = cvar.IntValue;
}

public void CVAR_NOSILENCER(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	icvSilencer = cvar.IntValue;
}

public void CVAR_PERCENT(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	icvPercent = cvar.IntValue;
}

public void OnMapStart()
{
	// Unlock the effect
	int tableId = FindStringTable("EffectDispatch");
	LockStringTables(false);
	AddToStringTable(tableId, "Tracer");
	LockStringTables(true);
	
	// Simply can be used as index 1, but this is in case if any other effects also unlocked in StringTable.
	iTracerTableID = FindStringIndex(FindStringTable("EffectDispatch"), "Tracer");
}

public void OnClientCookiesCached(int client)
{
	char buffer[2];
	GetClientCookie(client, hCookieDisabled, buffer, 2);
	bDisabled[client] = view_as<bool>(StringToInt(buffer));
}

public Action cmdTracers(int client, int args)
{
	if(IsClientInGame(client))
	{
		bDisabled[client] = !bDisabled[client];
		PrintToChat(client, "\x03 Tracers %sabled", bDisabled[client] ? "dis" : "en");
		SetClientCookie(client, hCookieDisabled, bDisabled[client] ? "1" : "0");
	}
	return Plugin_Handled;
}

public void OnBulletImpact(Event event, const char[] name, bool broadCast)
{
	bool cancel = false;
	switch(icvRandom)
	{
		case 0:
		{
				cancel = false;
		}
		case 1:
		{
			if(GetRandomInt(0, 1) != 0)
			{
				cancel = true;
			}
		}
		case 2:
		{
			if(GetRandomInt(0, 100) > icvPercent)
			{
				cancel = true;
			}
		}
	}	
	if(cancel) return;
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	int weapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	
	char clsnm[16];
	GetEntityClassname(weapon, clsnm, 16);
	
	if(icvSilencer)
	{
		if(clsnm[0] == 'w' && clsnm[7] == 't' && clsnm[8] == 'm') return;

		if(HasEntProp(weapon, Prop_Send, "m_bSilencerOn") && GetEntProp(weapon, Prop_Send, "m_bSilencerOn") == 1)
		{
			return;
		}
	}
	
	bool firingLeft = false;
	if(clsnm[0] == 'w' && clsnm[7] == 'e' && clsnm[8] == 'l')
	{
		if((GetEntProp(weapon, Prop_Send, "m_iClip1") & 1) == 0)
		{
			firingLeft = true;
		}
	}
	
	float startPos[3], endPos[3];
	GetClientEyePosition(client, startPos);
	endPos[0] = event.GetFloat("x");
	endPos[1] = event.GetFloat("y");
	endPos[2] = event.GetFloat("z");

	TE_Start("EffectDispatch");
	
	TE_WriteNum("m_iEffectName", iTracerTableID);	
	TE_WriteFloat("m_vStart[0]", startPos[0]);
	TE_WriteFloat("m_vStart[1]", startPos[1]);
	TE_WriteFloat("m_vStart[2]", startPos[2]);
	TE_WriteFloat("m_vOrigin[0]", endPos[0]);
	TE_WriteFloat("m_vOrigin[1]", endPos[1]);
	TE_WriteFloat("m_vOrigin[2]", endPos[2]);
	TE_WriteFloat("m_flScale", 5000.0);
	TE_WriteNum("m_nAttachmentIndex", firingLeft ? 2 : 1);
	TE_WriteNum("entindex", weapon);
	TE_WriteNum("m_fFlags", 2);
	
	int[] clients = new int[MAXPLAYERS];
	int numClients;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && !bDisabled[i]) clients[numClients++] = i;
	}
	
	TE_Send(clients, numClients);
}