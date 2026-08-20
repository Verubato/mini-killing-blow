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
local killBlowFrame = nil

local function EnsureKillingBlowDisplay()
	if killBlowFrame then
		return killBlowFrame
	end

	local frame = CreateFrame("Frame", nil, UIParent)
	frame:SetSize(440, 72)
	frame:SetPoint("CENTER", UIParent, "CENTER", db.KillTextX or 0, db.KillTextY or 100)
	frame:SetFrameStrata("HIGH")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:Hide()

	frame:SetScript("OnDragStart", function(f)
		if db.KillTextLocked then return end
		f:StartMoving()
	end)
	frame:SetScript("OnDragStop", function(f)
		if db.KillTextLocked then return end
		f:StopMovingOrSizing()
		local cx, cy = f:GetCenter()
		local ux, uy = UIParent:GetCenter()
		db.KillTextX = cx - ux
		db.KillTextY = cy - uy
		f:ClearAllPoints()
		f:SetPoint("CENTER", UIParent, "CENTER", db.KillTextX, db.KillTextY)
	end)

	local label = db.KillText or "KILLING BLOW!"

	-- Dark red shadow (slight offset for depth)
	local shadow = frame:CreateFontString(nil, "BACKGROUND")
	shadow:SetFont("Fonts\\FRIZQT__.TTF", 38, "THICKOUTLINE")
	shadow:SetPoint("CENTER", frame, "CENTER", 2, -2)
	shadow:SetJustifyH("CENTER")
	shadow:SetText(label)
	shadow:SetTextColor(0.25, 0, 0, 1)

	-- Main bright red text
	local text = frame:CreateFontString(nil, "ARTWORK")
	text:SetFont("Fonts\\FRIZQT__.TTF", 38, "THICKOUTLINE")
	text:SetPoint("CENTER", frame, "CENTER")
	text:SetJustifyH("CENTER")
	text:SetText(label)
	text:SetTextColor(1, 0.05, 0.05, 1)

	frame.Text = text
	frame.Shadow = shadow

	-- Animation: fade-in, hold, fade-out (only played when locked)
	local ag = frame:CreateAnimationGroup()

	local fadeIn = ag:CreateAnimation("Alpha")
	fadeIn:SetFromAlpha(0)
	fadeIn:SetToAlpha(1)
	fadeIn:SetDuration(0.12)
	fadeIn:SetOrder(1)

	local hold = ag:CreateAnimation("Alpha")
	hold:SetFromAlpha(1)
	hold:SetToAlpha(1)
	hold:SetDuration(1.8)
	hold:SetOrder(2)

	local fadeOut = ag:CreateAnimation("Alpha")
	fadeOut:SetFromAlpha(1)
	fadeOut:SetToAlpha(0)
	fadeOut:SetDuration(0.6)
	fadeOut:SetOrder(3)

	ag:SetScript("OnFinished", function()
		frame:Hide()
	end)

	frame.AnimGroup = ag
	killBlowFrame = frame
	return frame
end

local function ShowKillingBlowText()
	if not db.ShowKillText then
		return
	end

	local frame = EnsureKillingBlowDisplay()

	if not db.KillTextLocked then
		-- Unlocked: frame stays permanently visible for repositioning
		frame:SetAlpha(1)
		frame:Show()
		return
	end

	frame.AnimGroup:Stop()
	frame:SetAlpha(0)
	frame:Show()
	frame.AnimGroup:Play()
end

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
		return soundsFolder .. "Halo\\" .. math.min(killingBlows, 10) .. ".ogg"
	end

	if db.SoundEffectPack == config.SoundPacks.Custom then
		return customSoundsFolder .. math.min(killingBlows, db.CustomSoundEffectCount or 5) .. ".ogg"
	end

	return nil
end

-- The clients that fire PARTY_KILL are exactly the ones that hide combat log GUIDs behind
-- secret values, so the two questions have the same answer.
local function HasPartyKillEvent()
	return mini:HasSecrets()
end

local function IsPlayerGUID(guid)
	return type(guid) == "string" and guid:match("^Player%-") or false
end

local function KillerIsSelf(killerGUID)
	if mini:IsSecret(killerGUID) then
		return false
	end

	return killerGUID == UnitGUID("player")
end

local function TargetIsPlayer(victimGUID)
	return not mini:IsSecret(victimGUID) and IsPlayerGUID(victimGUID)
end

local function IsInstancePvP()
	local inInstance, instanceType = IsInInstance()

	return inInstance and (instanceType == "arena" or instanceType == "pvp")
end

local function AchievementKillIncreased()
	local current = CurrentTotalKills()
	local previous = totalKills

	return current > previous
end

local function KillingBlow()
	local killingBlows = IncrementKillingBlowsWindow()

	ShowKillingBlowText()

	local soundFile = GetSoundEffect(killingBlows)
	if soundFile then
		PlaySoundFile(soundFile, db.SoundChannel or "Master")
	end
end

local function PartyKill(killerGUID, victimGUID)
	if mini:IsSecret(killerGUID) or mini:IsSecret(victimGUID) then
		if not IsInstancePvP() then
			totalKills = CurrentTotalKills()
			return
		end

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

local function OnAddonLoaded()
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

function addon:UpdateKillText()
	if not killBlowFrame then
		return
	end
	local label = db.KillText or "KILLING BLOW!"
	killBlowFrame.Text:SetText(label)
	killBlowFrame.Shadow:SetText(label)
end

function addon:UpdateKillTextLocked()
	if db.KillTextLocked then
		if killBlowFrame then
			killBlowFrame.AnimGroup:Stop()
			killBlowFrame:Hide()
		end
	else
		if db.ShowKillText then
			local frame = EnsureKillingBlowDisplay()
			frame.AnimGroup:Stop()
			frame:SetAlpha(1)
			frame:Show()
		end
	end
end

mini:WaitForAddonLoad(OnAddonLoaded)

---@class Addon
---@field Config Config
---@field Framework MiniFramework
---@field TestKb fun(self: Addon)
---@field ResetWindow fun(self: Addon)
---@field UpdateKillText fun(self: Addon)
---@field UpdateKillTextLocked fun(self: Addon)
