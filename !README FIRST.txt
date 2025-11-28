IW8 Steam (5-13-2024) Steam Offline Patch v2 (Campaign, Multiplayer, Special Ops, Survival)

Instructions:
- Firstly, make sure the path on where you put the game folder is short and doesn't contain non latin characters or symbols to avoid issues with game launching.
- Extract everything in this archive into the game's directory.
- Start the game through !start_cod.bat and keep the console window open until it closes by itself when you close the game.
- If running !start_cod.bat doesn't do anything, read the 1st step again.

Campaign, Multiplayer with bots, and Coop game modes are fully playable (with some minor issues, check side notes below) with everything unlocked (weapons, operators, customizations, etc). LAN is currently not working, only offline play with bots for now (so don't bother asking about LAN).

Stats (loadouts, operators, customizations, etc) can now be saved locally. If anything happens with the stats, check the side notes. And keep in mind that some modes has a different set of stats, meaning that not every modes has the same set of loadouts. This release uses a fork of GSE by alex47exe (originally created by Mr_Goldberg) for the steam emulator. You can change playername and language by editing steam_settings/configs.user.ini but make sure that you have installed the appropriate language files first.

Hotkeys:
- Cbuf: Right Control + / (press this hotkey in the external console window)
- Noclip: Right Control + N
- God Mode: Right Control + M

To set a different keybind for each hotkeys, modify the "virtual key codes" values in profile.ini. The decimal values for each keyboard keys can be found in many places on the internet (search query: virtual key codes).

Side notes:
- If for some reason you got the stats all messed up, execute "resetstats" in cbuf to reset your stats (or delete the "_stats" folder)
- Some Ground War maps and Operation Headhunter coop mission are currently not working (physics related issues caused by collisions)
- Campaign missions can be unlocked all at once by executing 'unlock_missions' command
- BR mode can be selected from the gamemode list after executing 'set QTQRQPLNK 1;set MLQNQTRRTK 1;set MKQQKMRORQ 16;exec br_core.cfg' in the lobby
- Calling cards and emblems menus are not working, though they're not usable anyway. But if you really wanna explore them, then enable "Live_IsUserSignedInToDemonware" debug setting on the ini file (though this can cause the frontend to not load properly)
- I've heard reports of people getting stuck on broken online menus, this can happen when you're trying to edit the loadouts before creating a lobby. To work around this, make sure to create a lobby first before editing the loadouts.
- Trials can now be started from the Trials menu (only if you start them from online mp menu)

Changelogs:
v2
- Steam requirement has been removed
- Tweaked some online menus to prevent soft locks
- Added workaround for Trials

v3
- Fixed stats saving source inconsistencies

.r4v3n
