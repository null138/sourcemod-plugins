#pragma semicolon 1

#define PLUGIN_AUTHOR "null138"
#define PLUGIN_VERSION "5.00"

#include <sourcemod>
#include <sdktools>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "Jump Stats aka semi Anti-Cheat",
	author = PLUGIN_AUTHOR,
	description = "Provides detailed information about jumps and detects hacks/scripts",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/null138/"
}

int 
	iStJumps[MAXPLAYERS + 1][32],
	iStPerfJumps[MAXPLAYERS + 1][32],
	iStClicks[MAXPLAYERS + 1][32][10],
	iStDuckJump[MAXPLAYERS + 1][32][10],
	iStMaxPerfsRate[MAXPLAYERS + 1][32],
	iStPerfPtrn[MAXPLAYERS + 1][32][10],
	iStLowFps[MAXPLAYERS + 1][32][10],
	iJumps[MAXPLAYERS + 1],
	iPerfJumps[MAXPLAYERS + 1],
	iIndex[MAXPLAYERS + 1],
	iTicks[MAXPLAYERS + 1],
	iMeasures[MAXPLAYERS + 1],
	iGains[MAXPLAYERS + 1],
	iDetected[MAXPLAYERS + 1][5],
	iTickrate,
	icvAction,
	icvBanDuration;
	
float 
	fStVelGain[MAXPLAYERS + 1][32][10],
	fStSync[MAXPLAYERS + 1][32][10],
	fStVelocity[MAXPLAYERS + 1][32][10],
	fTopVel[MAXPLAYERS + 1],
	fPrevVel[MAXPLAYERS + 1],
	fCalcTime[MAXPLAYERS + 1];
	
bool bCantBhop[MAXPLAYERS + 1];
static char cLogPath[PLATFORM_MAX_PATH];

public void OnPluginStart()
{
	RegAdminCmd("sm_jglobal", cmdGlobalStats, ADMFLAG_BAN);
	RegAdminCmd("sm_jgb", cmdGlobalStats, ADMFLAG_BAN);
	RegAdminCmd("sm_jstats", cmdStats, ADMFLAG_BAN);
	
	ConVar cvar;
	cvar = FindConVar("sv_mincmdrate");
	iTickrate = GetConVarInt(cvar);
	cvar.AddChangeHook(CVAR_SERVER_TICKRATE);
	
	cvar = CreateConVar("jsa_detect_action", "2", "Action to take on detect. 1 = ban, 2 = limit bhop");
	icvAction = cvar.IntValue;
	cvar.AddChangeHook(CVAR_DETECT_ACTION);
	
	cvar = CreateConVar("jsa_ban_duration", "30", "Ban duration in minutes");
	icvBanDuration = cvar.IntValue;
	cvar.AddChangeHook(CVAR_BAN_DURATION);
	
	AutoExecConfig(true);
	
	LoadTranslations("common.phrases.txt");
}

public void OnMapStart()
{
	char path[PLATFORM_MAX_PATH];
	int time = GetTime();
	
	FormatTime(path, sizeof(path), "%d_%b_%Y", time);
	BuildPath(Path_SM, cLogPath, sizeof(cLogPath), "logs/JSTATS_DETECTS_%s.txt", path);
	Handle file = OpenFile(cLogPath, "a+");
	CloseHandle(file);
}

public void CVAR_SERVER_TICKRATE(ConVar cvar, const char[] oldValue, const char[] newValue) 
{
	iTickrate = cvar.IntValue;
}

public void CVAR_DETECT_ACTION(ConVar cvar, const char[] oldValue, const char[] newValue) 
{
	icvAction = cvar.IntValue;
}

public void CVAR_BAN_DURATION(ConVar cvar, const char[] oldValue, const char[] newValue) 
{
	icvBanDuration = cvar.IntValue;
}

public void OnClientPutInServer(int client)
{
	for (int i = 0; i < 32; i++)
	{
		iStJumps[client][i] = iStPerfJumps[client][i] = iStMaxPerfsRate[client][i] = 0;
		iStClicks[client][i] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
		iStPerfPtrn[client][i] = {-1, -1, -1, -1, -1, -1, -1, -1, -1, -1};
		iStLowFps[client][i] = iStPerfPtrn[client][i];
		iStDuckJump[client][i] = iStPerfPtrn[client][i];
		
		fStVelGain[client][i] = view_as<float>({-8.3218, -8.3218, -8.3218, -8.3218, -8.3218, \
												-8.3218, -8.3218, -8.3218, -8.3218, -8.3218});
		fStSync[client][i] = view_as<float>({0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0});
		fStVelocity[client][i] = fStSync[client][i];
	}

	iJumps[client] = iPerfJumps[client] = iIndex[client] = iTicks[client] = iMeasures[client] = iGains[client] = 0;
	fTopVel[client] = fPrevVel[client] = fCalcTime[client] = 0.0;
	bCantBhop[client] = false;
	iDetected[client] = {0, 0, 0, 0, 0};
}

public Action cmdGlobalStats(int client, int args)
{
	if(args < 1) 
	{
		ReplyToCommand(client, "[SM] sm_jglobal <nick|#userid>");
		return Plugin_Handled;
	}
	
	char arg[64];
	GetCmdArg(1, arg, 64);
	
	int target = FindTarget(client, arg, true);
	if(target == -1 || !IsClientInGame(target) || IsFakeClient(target)) 
	{
		ReplyToCommand(client, "[SM] No player found");
		return Plugin_Handled;
	}
	
	if(iJumps[target] > 0)
	{
		PrintToChat(client, "\x04[J-Stats]: \x03%N \
							\n\x04 *Detected: \x03%s", target, \
							(iDetected[target][0] == 1 || iDetected[target][1] == 1 || \
							iDetected[target][2] == 1 || iDetected[target][3] == 1 || \
							iDetected[target][4] == 1) ? "Yes" : "No");
		PrintToChat(client, "\x04 *Hack:\x03 %i%", iPerfJumps[target] * 100 / iJumps[target]);	
		PrintToChat(client, "\x04 *Top Velocity:\x03 %.2f", fTopVel[target]);
		PrintToChat(client, "\x04 *Global Jumps:\x03 %i", iJumps[target]);
		PrintToChat(client, "\x04 *Perfect Jumps:\x03 %i", iPerfJumps[target]);
	}
	
	return Plugin_Handled;
}

public Action cmdStats(int client, int args)
{
	if(args < 1) 
	{
		ReplyToCommand(client, "[SM] sm_jstats <nick|#userid> <0|1|2|3>");
		return Plugin_Handled;
	}
	
	char arg[64], arg2[2];
	GetCmdArg(1, arg, 64);
	GetCmdArg(2, arg2, 2);
	
	int target = FindTarget(client, arg, true);
	if(target == -1 || !IsClientInGame(target) || IsFakeClient(target)) 
	{
		ReplyToCommand(client, "[SM] No player found");
		return Plugin_Handled;
	}

	int start = 0, end = 8;
	switch(StringToInt(arg2))
	{
		case 1: { start = 8; end = 16; }
		case 2: { start = 16; end = 24; }
		case 3: { start = 24; end = 32; }
	}
	
	char bf[256], bf2[256], bf3[256], bf4[256], bf5[128], bf6[128], bf7[128];
	for (int i = start; i < end; i++)
	{
		if(iStJumps[target][i] == 0)
			return Plugin_Handled;
			
		for (int i2 = 0; i2 < 10; i2++)
		{
			if(iStClicks[target][i][i2] != 0)	
				Format(bf, 256, "%s %i%s", bf, iStClicks[target][i][i2], i2 == 9 ? "." : ",");
				
			if(fStVelocity[target][i][i2] != 0.0)
				Format(bf2, 256, "%s %.2f%s", bf2, fStVelocity[target][i][i2], i2 == 9 ? "." : ",");
				
			if(fStVelGain[target][i][i2] != -8.3218)
				Format(bf3, 256, "%s %.2f%s", bf3, fStVelGain[target][i][i2], i2 == 9 ? "." : ",");
				
			if(fStSync[target][i][i2] != 0.0)
				Format(bf4, 256, "%s %.1f%\%\%s", bf4, fStSync[target][i][i2], i2 == 9 ? "." : ",");
			
			if(iStDuckJump[target][i][i2] != -1)
				Format(bf5, 128, "%s %s%s", bf5, iStDuckJump[target][i][i2] == 1 ? "+" : "-", i2 == 9 ? "." : ",");
			
			if(iStPerfPtrn[target][i][i2] != -1)
				Format(bf6, 128, "%s %s%s", bf6, iStPerfPtrn[target][i][i2] == 1 ? "+" : "-", i2 == 9 ? "." : ",");
			
			if(iStLowFps[target][i][i2] == 1)
				Format(bf7, 128, "%s %i%s", bf7, iStLowFps[target][i][i2], i2 == 9 ? "." : ",");
			else if(iStLowFps[target][i][i2] == 0)
				Format(bf7, 128, "%s -%s", bf7, i2 == 9 ? "." : ",");
		}
		
		PrintToConsole(client, "\n%i. Hack: %i%\% \
								\n Clicks:\n %s \
								\n Duck-Jump:\n %s", \
								i, iStPerfJumps[target][i] * 100 / \
								iStJumps[target][i], bf, bf5);
		
		PrintToConsole(client, " Perfect pattern:\n %s \
								\n Perfect row: %i \
								\n Low-Fps:\n %s \
								\n Velocity:\n %s \
								\n Gain:\n %s \
								\n Sync:\n %s", \
								bf6, iStMaxPerfsRate[target][i], \
								bf7, bf2, bf3, bf4);
			
		bf[0] = bf2[0] = bf3[0] = bf4[0] = bf5[0] = bf6[0] = bf7[0] = '\0';
	}
	PrintToConsole(client, "Type \"sm_jstats <nick|#userid> <0|1|2|3>\" to see other records");
	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3])
{
	static int iPerfCount[MAXPLAYERS + 1];
	static int iJumpInputs[MAXPLAYERS + 1];
	static int iTempJumps[MAXPLAYERS + 1];
	static float fLastAngle[MAXPLAYERS + 1];
	static float fLastJumpTime[MAXPLAYERS + 1];
	static float fLastGroundTime[MAXPLAYERS + 1];
	static bool bLastWasPerfect[MAXPLAYERS + 1];
	static bool bLastWasGround[MAXPLAYERS + 1];
	
	if(IsClientInGame(client) && !IsFakeClient(client) && IsPlayerAlive(client))
	{	
		if(!bCantBhop[client] && (iDetected[client][0] != 1 || iDetected[client][1] != 1 || \
			iDetected[client][2] != 1 || iDetected[client][4] != 1) && \
			fCalcTime[client] < GetGameTime())
		{
			fCalcTime[client] = GetGameTime() + 2.0;
			if(fCalcTime[client] != 0.0) CheckClientStats(client);
		}
		
		int lastButtons = GetEntProp(client, Prop_Data, "m_nOldButtons");
		int groundEnt = GetEntPropEnt(client, Prop_Send, "m_hGroundEntity");
		
		float vecVel[3], fAngles[3], curVel, fAngle, fTempAngle, avgPackets;
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vecVel);
		curVel = GetVectorLength(vecVel);

		if(buttons & IN_JUMP && !(lastButtons & IN_JUMP))
		{	
			if(iDetected[client][3] != 1)
			{
				static iTempJumpClicks[MAXPLAYERS + 1][5];
				
				if(iTempJumps[client] < 5) iTempJumpClicks[client][iTempJumps[client]]++;
				
				if((GetGameTime() - fLastJumpTime[client]) >= 0.27 || curVel < 240.0)
				{
					fLastJumpTime[client] = GetGameTime();
					iJumpInputs[client] = iTempJumps[client] = 0;
					iTempJumpClicks[client] = { 0, 0, 0, 0, 0 };
				}
				else 
				{
					if((GetGameTime() - fLastGroundTime[client]) >= 0.13) // to be sure the player is not in short zone
						iJumpInputs[client]++;
				}
				
				if(iJumpInputs[client] >= 29 && iTempJumps[client] >= 5) // player not stopped sending jump inputs	
				{													 	 // for whole 5 jumps xd
					int jumpsOverVal = 0;
					for (int i = 0; i < 5; i++)
					{
						if(iTempJumpClicks[client][i] >= 6)
						{
							jumpsOverVal++;
						}
					}
					if(jumpsOverVal >= 4)
					{
						NotifyAdmins("\x04 [J-Stats] Player \x03%N \x04suspected in using \x03hacks/scripts. \
									\n \x04Type \"sm_jstats <nick|#userid> <0|1|2|3>\" for more info!", client);
						iJumpInputs[client] = 0;
						iDetected[client][3] = 1;
						TakeAction(client, "Bunnyhop hacks/scripts");
					}
				}
				fLastJumpTime[client] = GetGameTime();
			}
			
			if(iTicks[client] < 10)
			{
				iStClicks[client][iIndex[client]][iTicks[client]]++;
					
				fAngle = GetAngleDiff(angles[1], fLastAngle[client]);
				fTempAngle = angles[1];
				GetVectorAngles(vecVel, fAngles);
				if (fTempAngle < 0.0)
				{
					fTempAngle += 360.0;
				}
				CalcSync(client, (fTempAngle - fAngles[1]), fAngle, vel);
			
				fStSync[client][iIndex[client]][iTicks[client]] = \
					(iGains[client] / float(iMeasures[client]) * 100.0);
			}
			
			avgPackets = GetClientAvgPackets(client, NetFlow_Incoming);
			if(avgPackets >= (iTickrate / 2) - 10.0 && avgPackets <= (iTickrate / 2) + 10.0) // 66 tick = >23 & <43.
				iStLowFps[client][iIndex[client]][iTicks[client]] = RoundToNearest(avgPackets);
			else iStLowFps[client][iIndex[client]][iTicks[client]] = 0;
			
			if(groundEnt != -1)
			{
				if(buttons & IN_DUCK) iStDuckJump[client][iIndex[client]][iTicks[client]] = 1;
				else iStDuckJump[client][iIndex[client]][iTicks[client]] = 0;
				
				iJumps[client]++;
				iStJumps[client][iIndex[client]]++;
				iTempJumps[client]++;
				if(iTempJumps[client] > 5) iTempJumps[client] = 0;
				
				if(!bLastWasGround[client])
				{
					if(bLastWasPerfect[client]) iPerfCount[client]++;
					else iPerfCount[client] = 1;
						
					if(iPerfCount[client] > iStMaxPerfsRate[client][iIndex[client]])
						iStMaxPerfsRate[client][iIndex[client]] = iPerfCount[client];
					
					bLastWasPerfect[client] = true;
					iPerfJumps[client]++;
					iStPerfJumps[client][iIndex[client]]++;
					iStPerfPtrn[client][iIndex[client]][iTicks[client]] = 1;
				}
				else
				{
					bLastWasPerfect[client] = false;
					iStPerfPtrn[client][iIndex[client]][iTicks[client]] = 0;
				}
				
				fStVelGain[client][iIndex[client]][iTicks[client]] = (curVel - fPrevVel[client]);
				fPrevVel[client] = fStVelocity[client][iIndex[client]][iTicks[client]] = curVel;
				
				iTicks[client]++;	
				if(iTicks[client] > 9)
				{
					iIndex[client]++;
					if(iIndex[client] > 31)
						iIndex[client] = 0;
					
					iTicks[client] = 0;
					iPerfCount[client] = 0;
				}
				
				if(curVel > fTopVel[client]) fTopVel[client] = curVel;
			}
		}
		
		if(groundEnt != -1) fLastGroundTime[client] = GetGameTime();		
		
		fLastAngle[client] = angles[1];
		bLastWasGround[client] = groundEnt > -1 ? true : false;
		
		if(bCantBhop[client])
		{
			if(curVel > 278.0)
			{
				buttons &= ~IN_JUMP;
				return Plugin_Changed;
			}
		}
	}
	return Plugin_Continue;
}

void CheckClientStats(int client)
{
	int click2Perf = 0, clicksOverVal = 0, detectIndex;
	for (int i = 0; i < 32; i++)
	{
		if(iStJumps[client][i] == 0)
			break;
			
		for (int i2 = 0; i2 < 10; i2++)
		{
			if(iDetected[client][1] != 1 && iStClicks[client][i][i2] <= 2 && iStPerfPtrn[client][i][i2] == 1)
				click2Perf++;
				
			if(iDetected[client][2] != 1 && iStClicks[client][i][i2] >= 16)
				clicksOverVal++;
		}
		
		if(iDetected[client][1] != 1)
		{
			if(click2Perf < 6) click2Perf = 0;
			else
			{
				detectIndex = i;
				break;
			}
		}
		
		if(iDetected[client][2] != 1)
		{
			if(clicksOverVal < 8) clicksOverVal = 0;
			else
			{
				detectIndex = i;
				break;
			}
		}
	}
	
	// the percentages taken here are most realistic ones in my opinion
	// so probably there will be no false triggers hopefully.
	if(iDetected[client][0] != 1)
	{
		bool detect = false;
		
		if(iJumps[client] >= 30 && iJumps[client] - \
			iPerfJumps[client] <= 7)
		{
			detect = true;
		}
		
		if(iJumps[client] > 50 && iJumps[client] <= 100 && \
		(iPerfJumps[client] * 100 / iJumps[client]) >= 70.0)
		{
			detect = true;
		}
		
		if(iJumps[client] > 100 && iJumps[client] <= 150 && \
		(iPerfJumps[client] * 100 / iJumps[client]) >= 65.0)
		{
			detect = true;
		}
		
		if(iJumps[client] > 150 && (iPerfJumps[client] * 100 \
			/ iJumps[client]) >= 60.0)
		{
			detect = true;
		}
		
		if(detect)
		{
			iDetected[client][0] = 1;
			NotifyAdmins("\x04 [J-Stats] Player \x03%N \x04triggering \x03unrealistic perfect jumps. \
						\n \x04Type \"sm_jstats <nick|#userid> <0|1|2|3>\" for more info!", client);
			TakeAction(client, "BunnyHop Hack");
		}
	}
	
	if(click2Perf >= 6)
	{
		iDetected[client][1] = 1;
		NotifyAdmins("\x04 [J-Stats] Player \x03%N \x04with \x03extremely suspicious jumps(ID:#%i). \
					\n \x04Type \"sm_jstats <nick|#userid> <0|1|2|3>\" for more info!", client, detectIndex);
		TakeAction(client, "BunnyHop Hack");
	}
	
	if(clicksOverVal >= 8)
	{
		iDetected[client][2] = 1;
		NotifyAdmins("\x04 [J-Stats] Player \x03%N \x04suspected in using \x03hyperscroll/scripts(ID:#%i). \
					\n \x04Type \"sm_jstats <nick|#userid> <0|1|2|3>\" for more info!", client, detectIndex);
		TakeAction(client, "Hyperscroll/Scripts");
	}
	
	int equalCount, thisCount[32], ptrnBest, records;
	for (int i = 0; i < 32; i++)
	{
		if(iStJumps[client][i] < 10)
			break;
		
		records++;
		
		if(iStPerfJumps[client][i] < 4)
			continue;
		
		for (int i2 = 0; i2 < 32; i2++)
		{
			if(iStJumps[client][i2] < 10)
				break;
			
			if(iStPerfJumps[client][i2] < 4)
				continue;
				
			for (int i3 = 0; i3 < 10; i3++)
			{
				if(iStPerfPtrn[client][i][i3] != -1 && iStPerfPtrn[client][i2][i3] != -1 && \
					iStPerfPtrn[client][i][i3] == iStPerfPtrn[client][i2][i3])
				{
					equalCount++;
				}
			}
			
			if(equalCount >= 10)
			{
				thisCount[i]++;
			}
			
			equalCount = 0;
		}
		
		if(thisCount[i] > ptrnBest) ptrnBest = thisCount[i];
	}
	
	if(iDetected[client][4] != 1 && records > 2 && (records - ptrnBest) <= records / 2)
	{
		iDetected[client][4] = 1;
		NotifyAdmins("\x04 [J-Stats] Player \x03%N \x04repeatedly perfect patterns: \x03%i out of %i jumps!. \
					\n \x04Type \"sm_jstats <nick|#userid> <0|1|2|3>\" for more info!", client, ptrnBest*10, records*10);
		TakeAction(client, "BunnyHop Hack");
	}
}

void NotifyAdmins(const char[] message, any ...)
{
	char buffer[254];
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetAdminFlag(GetUserAdmin(i), Admin_Kick)) 
		{
			SetGlobalTransTarget(i);
			VFormat(buffer, 254, message, 2);
			PrintToChat(i, buffer);
		}
	}
}

void TakeAction(int client, const char[] reason)
{
	char buf[32];
	GetClientAuthId(client, AuthId_Steam2, buf, 32);
	switch(icvAction)
	{
		case 0:
		{
			LogToFileEx(cLogPath, "Player: %N (%s) was detected for: %s", client, buf, reason);
		}
		case 1: // ban ip - duration - reason
		{
			NotifyAdmins("\x04 [J-Stats] Player \x03%N \x04got banned with reason: \x03%s", client, reason);
			LogToFileEx(cLogPath, "Player: %N (%s) got banned for: %s", client, buf, reason);
			GetClientIP(client, buf, 32);
			ServerCommand("sm_banip %s %i \"%s\"", buf, icvBanDuration, reason);
			if(IsClientInGame(client)) KickClientEx(client, reason);
		}
		case 2: // turn off bunnyhop for this session
		{
			LogToFileEx(cLogPath, "Player: %N (%s) was detected for: %s", client, buf, reason);
			bCantBhop[client] = true;
			PrintToChat(client, "\x04 [J-Stats] \x03Your bunnyhop is now limited for suspicious activity!");
		}
	}
}

// from shavit, all credits to the authors for this part

void CalcSync(int client, float angle, float yaw, const float vel[3])
{
	if(angle < 0.0)
	{
		angle = -angle;
	}

	// normal
	if(angle < 22.5 || angle > 337.5)
	{
		iMeasures[client]++;

		if((yaw > 0.0 && vel[1] <= -100.0) || (yaw < 0.0 && vel[1] >= 100.0))
		{
			iGains[client]++;
		}
	}

	// hsw (thanks nairda!)
	else if((angle > 22.5 && angle < 67.5))
	{
		iMeasures[client]++;

		if((yaw != 0.0) && (vel[0] >= 100.0 || vel[1] >= 100.0) && (vel[0] >= -100.0 || vel[1] >= -100.0))
		{
			iGains[client]++;
		}
	}

	// sw
	else if((angle > 67.5 && angle < 112.5) || (angle > 247.5 && angle < 292.5))
	{
		iMeasures[client]++;

		if(vel[0] <= -100.0 || vel[0] >= 100.0)
		{
			iGains[client]++;
		}
	}
}

stock float GetAngleDiff(float current, float previous)
{
	float diff = current - previous;
	return diff - 360.0 * RoundToFloor((diff + 180.0) / 360.0);
}