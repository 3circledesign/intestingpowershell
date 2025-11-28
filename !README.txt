IW9 Steam (9.40 build 23226476 2025-07-18) and IW9 SP Steam (SP22 9.7 build 23096551 2025-07-10) Offline Patch v1

===============================
Instructions:
- Firstly, make sure the path on where you put the game folder is short and doesn't contain non latin characters or symbols to avoid issues with game launching.
- Extract everything in this archive into where you installed the game.
- Start the game ONLY FROM !start_cod22.bat (for MP) or !start_sp22.bat (for SP) and keep the console window open until it closes by itself when you close the game.
- If running either *.bat doesn't do anything, read the 1st step again (or check bootstrapper.log).

Default Hotkeys (Set your keyboard to US if you encounter issues) :
- Cbuf: Right Control + / (press this hotkey in the external console window)
- Noclip: Right Control + N
- God Mode: Right Control + M

To set a different keybind for each hotkeys, modify the "virtual key codes" values in _profile.ini. The decimal values for each keyboard keys can be found in many places on the internet (search query: virtual key codes).
===============================

Campaign, Multiplayer (only with bots), and Coop are playable offline (with some minor issues, check side notes below) with everything unlocked (weapons, operators, customizations, etc). LAN is currently not working, only offline play with bots for now (so don't bother asking about LAN).

To start coop lobbies, follow these steps:
- While in the main menu, execute 'opencoop' in cbuf
- Create systemlink lobby like you would normally do in MP
- Choose any gamemode in the GameModes screen (doesn't matter which one as this is not important)
- When in the lobby, execute 'xstartlobby' in cbuf then you can set up the maps and start the match

Steam notes:
This release uses a fork of GSE by alex47exe (originally created by Mr_Goldberg) for the steam emulator. You can change playername and language by editing steam_settings/configs.user.ini but make sure that you have installed the appropriate language files first.

Side notes:
- If for some reason you got the stats all messed up, execute 'resetstats' in cbuf to reset your stats (or delete the "_stats" folder)
- Campaign missions can be unlocked all at once by enabling 'UnlockAllMissions' in sp22/_profile.ini
- Some br and coop maps has collision issues like in IW8, so keep that in mind.
- In one of the coop mission called "Denied Area", you'll spawn under the ground so make sure to quickly toggle noclip to get back up to the ground.
- Raid coop missions are meant to be played by 3 players, so some sequences might not work correctly. To skip these sequences, enter pause menu and choose "JUMP TO START" to skip past the broken sequence.
- If you're stuck on "Launching..." screen after starting the game, simply press Esc.
- DMZ is also playable offline...

Huge thanks to purrplee for providing me with essential resources!

.r4v3n
