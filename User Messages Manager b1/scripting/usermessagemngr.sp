#include <sourcemod>

public Plugin myinfo =
{
    name        = "Usermessage Manager",
    author      = "null138",
    description = "Blocking and filtering unnecessary usermessages",
    version     = "1.0",
    url         = "http://steamcommunity.com/profiles/76561198098349799"
}

public void OnPluginStart()
{
	/*
		List of active usermessages that should be blocked entirely
		These messages are either legacy, client side only, or unnecessary ... 
		 for gameplay and can be safely suppressed
    */
	HookUserMessage(GetUserMessageId("Geiger"), OnUserMessageBlock, true);        // Legacy Xbox feature 
    HookUserMessage(GetUserMessageId("Rumble"), OnUserMessageBlock, true);        // Legacy Xbox controller vibration
    HookUserMessage(GetUserMessageId("Train"), OnUserMessageBlock, true);         // HL2 related message, unused
    HookUserMessage(GetUserMessageId("Damage"), OnUserMessageBlock, true);        // Triggers client on screen damage indicators. Fired every bullet hit
    HookUserMessage(GetUserMessageId("UpdateRadar"), OnUserMessageBlock, true);   // Players already handling the radar update on client side. Unnecessary in many cases.
    HookUserMessage(GetUserMessageId("HapSetDrag"), OnUserMessageBlock, true);    // Legacy Xbox haptic feature
    HookUserMessage(GetUserMessageId("ReloadEffect"), OnUserMessageBlock, true);  // Legacy weapon reload visual effect
	
	// HookUserMessage(GetUserMessageId("PlayerStatsUpdate"), OnUserMessageBlock, true);
    // Achievement related usermessage. Blocking this may interfere with achievement tracking
	
	// HookUserMessage(GetUserMessageId("ItemPickup"), OnUserMessageBlock, true);
    // Item pickup HUD history. Mostly useless but it depends...
	
	/*
		List of active usermessages to filter (not fully block)
		These can be inspected and conditionally cancelled or ignored
    */
	// HookUserMessage(GetUserMessageId("TextMsg"), OnUserMessageFilter, true);
}

public Action OnUserMessageBlock(UserMsg msg_id, Handle msg, const int[] players, int playersNum, bool reliable, bool init)
{
	return Plugin_Handled;
}

/* Filter for conditionally cancelling or ignoring messages sent to the client console
public Action OnUserMessageFilter(UserMsg msg_id, Handle msg, const int[] players, int playersNum, bool reliable, bool init)
{
	int dst = BfReadByte(msg); // HUD_PRINTCONSOLE, HUD_PRINTNOTIFY, HUD_PRINTCENTER, HUD_PRINTTALK
	char params[256];
	BfReadString(msg, params, 256, false);
	
	if(dst == 2) // byte HUD_PRINTCONSOLE
	{
		// damage given/taken and etc
	}
	
	return Plugin_Continue;
}
*/