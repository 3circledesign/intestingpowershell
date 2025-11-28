-- Players in your team will develop 3 times faster and will not decline

require 'imports/career_mode/helpers'

if (not IsInCM()) then
    MessageBox("Error", "This script can be executed only in career mode")
    return
end

-- Config START

local xp_mul = 3.0      -- Experience multiplier
local bonus_exp = 5     -- Not much extra exp, multiplier is high enough
local no_decline = true -- Stop from declining

-- Config END

-- Load First
LE.player_development_manager:Load()


-- Apply boost
local user_teamid = GetUserTeamID()

-- Get all rows for teamplayerlinks table
local teamplayerlinks_table = LE.db:GetTable("teamplayerlinks")
local teamplayerlinks_current_record = teamplayerlinks_table:GetFirstRecord()

local playerid = 0
while teamplayerlinks_current_record > 0 do
    if user_teamid == teamplayerlinks_table:GetRecordFieldValue(teamplayerlinks_current_record, "teamid") then
        playerid = teamplayerlinks_table:GetRecordFieldValue(teamplayerlinks_current_record, "playerid")

        LE.player_development_manager:AddPlayer(playerid, xp_mul, bonus_exp, no_decline)
    end

    teamplayerlinks_current_record = teamplayerlinks_table:GetNextValidRecord()
end

-- Make sure to Save
LE.player_development_manager:Save()