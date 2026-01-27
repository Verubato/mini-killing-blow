local soundFile = "Interface\\AddOns\\MiniKillingBlow\\Kill.ogg"
local frame = CreateFrame("Frame")

local function IsMidnight()
	if LE_EXPANSION_LEVEL_CURRENT == nil or LE_EXPANSION_MIDNIGHT == nil then
		return false
	end
	return LE_EXPANSION_LEVEL_CURRENT == LE_EXPANSION_MIDNIGHT
end

local function IsPlayerGUID(guid)
	return type(guid) == "string" and guid:match("^Player%-") or false
end

local function IsSecret(value)
	if not issecretvalue then
		return false
	end

	return issecretvalue(value)
end

local function KillerIsSelf(killerGUID)
	if IsSecret(killerGUID) then
		return false
	end

	return killerGUID == UnitGUID("player")
end

local function TargetIsPlayer(victimGUID)
	-- if it's secret, assume it's a player
	return IsSecret(victimGUID) or IsPlayerGUID(victimGUID)
end

local function PartyKill(killerGUID, victimGUID)
	if not KillerIsSelf(killerGUID) then
		return
	end

	if not TargetIsPlayer(victimGUID) then
		return
	end

	PlaySoundFile(soundFile, "SFX")
end

if IsMidnight() then
	frame:RegisterEvent("PARTY_KILL")

	frame:SetScript("OnEvent", function(_, _, killerGUID, victimGUID)
		PartyKill(killerGUID, victimGUID)
	end)
else
	frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

	frame:SetScript("OnEvent", function()
		local _, subEvent, _, killerGUID, _, _, _, victimGUID = CombatLogGetCurrentEventInfo()

		if subEvent ~= "PARTY_KILL" then
			return
		end

		PartyKill(killerGUID, victimGUID)
	end)
end
