local soundFile = "Interface\\AddOns\\MiniKillingBlow\\kill.ogg"
local frame = CreateFrame("Frame")

local function IsMidnight()
	if LE_EXPANSION_LEVEL_CURRENT == nil or LE_EXPANSION_MIDNIGHT == nil then
		return false
	end
	return LE_EXPANSION_LEVEL_CURRENT == LE_EXPANSION_MIDNIGHT
end

local function IsPlayerGUID(guid)
	return type(guid) == "string" and guid:match("^Player%-")
end

if IsMidnight() then
	frame:RegisterEvent("PARTY_KILL")

	frame:SetScript("OnEvent", function(_, _, killerGUID, victimGUID)
		if killerGUID ~= UnitGUID("player") then
			return
		end

		if not IsPlayerGUID(victimGUID) then
			return
		end

		PlaySoundFile(soundFile, "Master")
	end)
else
	frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

	frame:SetScript("OnEvent", function()
		local _, subEvent, _, killerGUID, _, _, _, victimGUID = CombatLogGetCurrentEventInfo()

		if subEvent ~= "PARTY_KILL" then
			return
		end

		if killerGUID ~= UnitGUID("player") then
			return
		end

		if not IsPlayerGUID(victimGUID) then
			return
		end

		PlaySoundFile(soundFile, "Master")
	end)
end
