---@type string, Addon
local addonName, addon = ...
local soundsFolder = "Interface\\AddOns\\" .. addonName .. "\\Sounds\\"
local customSoundsFolder = "Interface\\AddOns\\MiniKillingBlowCustomSounds\\"
local mini = addon.Framework
local config = addon.Config
---@type Db
local db
local eventsFrame
local multiKillWindow = 10

local totalKills = 0
local killingBlowsInWindow = 0
local lastKillingBlowTime = nil
local resetTimer = nil

---Returns a number between 1 and N
local function OneToN(x, n)
	return ((x - 1) % n) + 1
end

local function StopResetTimer()
	if resetTimer and resetTimer.Cancel then
		resetTimer:Cancel()
	end
	resetTimer = nil
end

local function StartResetTimer()
	StopResetTimer()

	-- After 10 seconds of no kills, reset the streak.
	-- C_Timer is available in modern clients; if not, the time delta logic still works.
	if C_Timer and C_Timer.NewTimer then
		resetTimer = C_Timer.NewTimer(multiKillWindow, function()
			killingBlowsInWindow = 0
			lastKillingBlowTime = nil
			resetTimer = nil
		end)
	end
end

local function CurrentTotalKills()
	-- All credit goes to drmlol for finding this workaround
	-- Achievement -> Statistics -> Total Killing Blows
	local _, _, _, _, _, _, _, _, killCount = GetAchievementCriteriaInfoByID(1487, 0)

	return killCount
end

---@return number
local function IncrementKillingBlowsWindow()
	local now = GetTime()

	if not lastKillingBlowTime or (now - lastKillingBlowTime) > multiKillWindow then
		-- New streak
		killingBlowsInWindow = 1
	else
		-- Continue streak
		killingBlowsInWindow = killingBlowsInWindow + 1
	end

	lastKillingBlowTime = now
	StartResetTimer()

	return killingBlowsInWindow
end

local function GetSoundEffect(killingBlows)
	if db.SoundEffectPack == config.SoundPacks.Guns then
		local oneToFour = OneToN(killingBlows, 4)
		return soundsFolder .. "Guns\\" .. oneToFour .. ".ogg"
	end

	if db.SoundEffectPack == config.SoundPacks.OneGun then
		return soundsFolder .. "OneGun\\1.ogg"
	end

	if db.SoundEffectPack == config.SoundPacks.UnrealTournament then
		return soundsFolder .. "UnrealTournament\\" .. math.min(killingBlows, 7) .. ".ogg"
	end

	if db.SoundEffectPack == config.SoundPacks.Halo then
		return soundsFolder .. "Halo\\" .. math.min(killingBlows, 8) .. ".ogg"
	end

	if db.SoundEffectPack == config.SoundPacks.Custom then
		return customSoundsFolder .. math.min(killingBlows, db.CustomSoundEffectCount or 5) .. ".ogg"
	end

	return nil
end

local function HasPartyKillEvent()
	if LE_EXPANSION_LEVEL_CURRENT == nil or LE_EXPANSION_MIDNIGHT == nil then
		return false
	end

	return LE_EXPANSION_LEVEL_CURRENT >= LE_EXPANSION_MIDNIGHT
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

local function AchievementKillIncreased()
	local current = CurrentTotalKills()
	local previous = totalKills

	return current > previous
end

local function KillingBlow()
	-- Update multi-kill counter
	local killingBlows = IncrementKillingBlowsWindow()

	local soundFile = GetSoundEffect(killingBlows)
	if not soundFile then
		return
	end

	PlaySoundFile(soundFile, "SFX")
end

local function PartyKill(killerGUID, victimGUID)
	if IsSecret(killerGUID) or IsSecret(victimGUID) then
		if not AchievementKillIncreased() then
			return
		end
	else
		if not KillerIsSelf(killerGUID) then
			return
		end

		if not TargetIsPlayer(victimGUID) then
			return
		end
	end

	KillingBlow()

	-- update the current total kills
	totalKills = CurrentTotalKills()
end

function OnAddonLoaded()
	config:Init()

	db = mini:GetSavedVars()

	eventsFrame = CreateFrame("Frame")

	if HasPartyKillEvent() then
		eventsFrame:RegisterEvent("PARTY_KILL")
		eventsFrame:SetScript("OnEvent", function(_, _, killerGUID, victimGUID)
			PartyKill(killerGUID, victimGUID)
		end)
	else
		eventsFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		eventsFrame:SetScript("OnEvent", function()
			local _, subEvent, _, killerGUID, _, _, _, victimGUID = CombatLogGetCurrentEventInfo()

			if subEvent ~= "PARTY_KILL" then
				return
			end

			PartyKill(killerGUID, victimGUID)
		end)
	end

	totalKills = CurrentTotalKills()
end

function addon:TestKb()
	KillingBlow()
end

function addon:ResetWindow()
	killingBlowsInWindow = 0
end

mini:WaitForAddonLoad(OnAddonLoaded)

---@class Addon
---@field Config Config
---@field Framework MiniFramework
---@field TestKb fun(self: Addon)
---@field ResetWindow fun(self: Addon)
