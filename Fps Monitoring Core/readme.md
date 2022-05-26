Retrieves the players frames-per-second value(bound to servers tickrates value, so server cant get the real value if its over servers tickrate).

Thats the core plugin which provides API to use on other plugins.


Example of using APIs:


int FPSM_GetClientFpsCount(int client, int method); // method - FPS_SLOW (accurate value, but gets updated every 1 seconds) | FPS_FAST (inaccurate value, but gets updated every 0.25ms

PrintCenterText(client, "FPS(SLOW) %i, FPS(FAST) %i", FPSM_GetClientFpsCount(client, FPS_SLOW), FPSM_GetClientFpsCount(client, FPS_FAST));


forward FPSM_OnClientFpsUpdated(int client, int fps_slow, int fps_fast) // gets fired every time the players fps value got updated
