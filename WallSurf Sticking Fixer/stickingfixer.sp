#pragma semicolon 1

#define PLUGIN_AUTHOR "null138"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>

#pragma newdecls required

int iTickRate = 66;

public Plugin myinfo = 
{
	name = "Wall/Surf Sticking Fixer",
	author = PLUGIN_AUTHOR,
	description = "Fixes old annoying engine bug which causes sticking on some planes/surfaces",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/null138/"
}

public void OnMapStart()
{
	iTickRate = GetConVarInt(FindConVar("sv_mincmdrate"));
	if(!iTickRate) iTickRate = 66;
}

public Action OnPlayerRunCmd(int client, int & buttons, int & impulse, float vel[3])
{
	static int iResetCount[MAXPLAYERS + 1];
	static float fVecLastVelocity[MAXPLAYERS + 1][3];
	
	// dont do if player is touching the ground
	if(IsPlayerAlive(client) && GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") == -1)
	{
		// repeat this for some tick to release from stuckness
		if(iResetCount[client] > 0)
		{
			iResetCount[client]--;
			vel[0] = vel[1] = vel[2] = 0.0; // seems like this is the best option we can do
			return Plugin_Changed;
		}
		
		float vecVel[3];
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vecVel);
		if(GetVectorLength(vecVel) == 6.0) // Z axis stuck value in CreateStuckTable(void) is 6.0f
		{
			// reverse the values
			vel[0] > 0 ? (vel[0] *= -1) : (vel[0] -= vel[0] * 2);
			vel[1] > 0 ? (vel[1] *= -1) : (vel[1] -= vel[1] * 2);
			vel[2] > 0 ? (vel[2] *= -1) : (vel[2] -= vel[2] * 2);
				
			iResetCount[client] = view_as<int>(iTickRate / 3);
			SetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fVecLastVelocity[client]);
			return Plugin_Changed;
		}
		fVecLastVelocity[client][0] = vecVel[0];
		fVecLastVelocity[client][1] = vecVel[1];
		fVecLastVelocity[client][2] = vecVel[2];
	}
	else 
	{
		iResetCount[client] = 0;
	}
	return Plugin_Continue;
}