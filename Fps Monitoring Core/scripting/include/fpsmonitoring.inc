#if defined _FpsMonitoring_included
  #endinput
#endif
#define _FpsMonitoring_included

enum FPS_METHOD
{
	FPS_SLOW = 0,
	FPS_FAST
}

/**
 * Called when clients fps value changed
 *
 * @param client       	Client index.
 * @param slow       	Fps value(correct)
 * @param fast      	Fps value(correct value is not guaranteed)
 * @noreturn
 */

forward void FPSM_OnClientFpsUpdated(int client, int fps_slow, int fps_fast);

/**
 *  Gets clients fps value for given method
 *
 * @param client       	Client index.
 * @param method       	Method to get fps with
 * @return 				Fps value
 */

native int FPSM_GetClientFpsCount(int client, FPS_METHOD method);

public SharedPlugin __pl_FpsMonitoring = 
{
	name = "FpsMonitoring",
	file = "FpsMonitoring.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};