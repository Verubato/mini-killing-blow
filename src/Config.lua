---@type string, Addon
local addonName, addon = ...
local mini = addon.Framework

---@type Db
local db

---@class Config
local M = {
	SoundPacks = {
		UnrealTournament = "Unreal Tournament",
		Halo = "Halo",
		Guns = "Guns",
		OneGun = "One Gun",
		Custom = "Custom",
	},
}

-- Every field on this panel sits in from its own label by this much.
local FIELD_INSET = 4
-- The legacy dropdown template draws its field in from the frame's own left edge.
local LEGACY_DROPDOWN_INSET = 16

---@class Db
local dbDefaults = {
	SoundEffectPack = M.SoundPacks.UnrealTournament,
	SoundChannel = "SFX",
	CustomSoundEffectCount = 5,
	KillTextX = 0,
	KillTextY = 100,
	ShowKillText = false,
	KillText = "KILLING BLOW!",
	KillTextLocked = true,
}

addon.Config = M

function M:Init()
	-- A styled button clashes with the stock Blizzard art around it in the settings screen.
	mini:SetCustomStyling(true, { Button = false })

	db = mini:GetSavedVars(dbDefaults)

	local panel = CreateFrame("Frame")
	panel.name = addonName

	local category = mini:AddCategory(panel)

	if not category then
		return
	end

	local columns = 2
	local columnWidth = mini:ColumnWidth(columns, 0, 0)
	local verticalSpacing = mini.VerticalSpacing
	local horizontalSpacing = mini.HorizontalSpacing

	-- Forward declared so the reset button, built before these exist, can still call it.
	-- Forward declared so ShowHideCustomCount, defined before any of them exists, can see them.
	local soundPackDdl
	local textDivider
	local dropdownShift
	-- Forward declared so the reset button, built before it exists, can call it.
	local ShowHideCustomCount

	local header = mini:PanelHeader({
		Parent = panel,
		Description = "Increase your PvP immersion.",
		Gap = 6,
		Divider = true,
		Test = {
			OnClick = function()
				addon:TestKb()
			end,
		},
		Reset = {
			OnAccept = function()
				mini:ResetSavedVars(dbDefaults)
				ShowHideCustomCount()
				addon:UpdateKillText()
				addon:UpdateKillTextLocked()
			end,
		},
	})

	mini:RegisterSlashCommand(category, panel, {
		"/minikillingblow",
		"/minikb",
		"/mkb",
	})

	local packLbl = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	packLbl:SetText("Sound Pack")

	local customCount = mini:EditBox({
		Parent = panel,
		GetValue = function()
			return db.CustomSoundEffectCount
		end,
		SetValue = function(value)
			db.CustomSoundEffectCount = mini:ClampInt(value, 1, 50, 1)
		end,
		LabelText = "Custom sound effect count",
		Numeric = true,
		Width = columnWidth - horizontalSpacing,
	})

	function ShowHideCustomCount()
		local custom = db.SoundEffectPack == M.SoundPacks.Custom

		customCount.EditBox:SetShown(custom)
		customCount.Label:SetShown(custom)

		textDivider:ClearAllPoints()

		if custom then
			-- The count box is inset from its label, so the rule backs that out to keep one
			-- left edge down the column.
			textDivider:SetPoint("TOPLEFT", customCount.EditBox, "BOTTOMLEFT", -FIELD_INSET, -verticalSpacing)
		else
			-- A hidden count box still reserves its row, so the rule takes that row back.
			textDivider:SetPoint("TOPLEFT", soundPackDdl, "BOTTOMLEFT", -dropdownShift, -verticalSpacing)
		end

		textDivider:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
	end

	local modernDdl

	soundPackDdl, modernDdl = mini:Dropdown({
		Parent = panel,
		Items = {
			"Unreal Tournament",
			"Halo",
			"One Gun",
			"Guns",
			"Custom",
		},
		GetValue = function()
			return db.SoundEffectPack
		end,
		SetValue = function(value)
			db.SoundEffectPack = value
			ShowHideCustomCount()
			addon:ResetWindow()
		end,
	})

	local channelLbl = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	channelLbl:SetText("Sound Channel")

	local channelDdl = mini:Dropdown({
		Parent = panel,
		Items = {
			"Master",
			"Music",
			"SFX",
			"Ambience",
			"Dialog",
		},
		GetValue = function()
			return db.SoundChannel
		end,
		SetValue = function(value)
			db.SoundChannel = value
		end,
	})

	packLbl:SetPoint("TOPLEFT", header.Anchor, "BOTTOMLEFT", 0, -verticalSpacing)

	dropdownShift = modernDdl and 0 or -LEGACY_DROPDOWN_INSET

	soundPackDdl:SetPoint("TOPLEFT", packLbl, "BOTTOMLEFT", dropdownShift, -8)
	soundPackDdl:SetWidth(columnWidth - horizontalSpacing)

	channelLbl:SetPoint("TOP", packLbl, "TOP", 0, 0)
	channelLbl:SetPoint("LEFT", panel, "LEFT", columnWidth, 0)

	channelDdl:SetPoint("TOP", soundPackDdl, "TOP", 0, 0)
	channelDdl:SetPoint("LEFT", panel, "LEFT", columnWidth, 0)
	channelDdl:SetWidth(columnWidth - horizontalSpacing)

	-- The custom count box only applies to the Custom pack, so it lives under that column
	-- rather than under Sound Channel, which now holds the second column instead.
	customCount.Label:SetPoint("TOPLEFT", soundPackDdl, "BOTTOMLEFT", -dropdownShift, -verticalSpacing)
	customCount.EditBox:SetPoint("TOPLEFT", customCount.Label, "BOTTOMLEFT", FIELD_INSET, -4)

	textDivider = mini:Divider({
		Parent = panel,
		Text = "Text",
	})

	ShowHideCustomCount()

	local lockedChk = mini:Checkbox({
		Parent = panel,
		LabelText = "Locked",
		Tooltip = "When unchecked, the killing blow text stays visible and can be dragged to reposition it.",
		GetValue = function()
			return db.KillTextLocked
		end,
		SetValue = function(value)
			db.KillTextLocked = value
			addon:UpdateKillTextLocked()
		end,
	})
	lockedChk:SetPoint("TOPLEFT", textDivider, "BOTTOMLEFT", 0, -verticalSpacing)

	local showTextChk = mini:Checkbox({
		Parent = panel,
		LabelText = "Enable Text",
		Tooltip = "Shows the text below when you get a killing blow.",
		GetValue = function()
			return db.ShowKillText
		end,
		SetValue = function(value)
			db.ShowKillText = value
		end,
	})
	showTextChk:SetPoint("TOPLEFT", lockedChk, "TOPLEFT", 110, 0)

	local killTextBox = mini:EditBox({
		Parent = panel,
		LabelText = "Killing blow text",
		Width = columnWidth - horizontalSpacing,
		GetValue = function()
			return db.KillText
		end,
		SetValue = function(value)
			db.KillText = (value ~= "" and value) or dbDefaults.KillText
			addon:UpdateKillText()
		end,
	})
	killTextBox.Label:SetPoint("TOPLEFT", lockedChk, "BOTTOMLEFT", 0, -verticalSpacing)
	killTextBox.EditBox:SetPoint("TOPLEFT", killTextBox.Label, "BOTTOMLEFT", FIELD_INSET, -4)

	local intro = mini:TextBlock({
		Parent = panel,
		Lines = {
			"To make your own sound effects:",
			"  - Create a folder called 'MiniKillingBlowCustomSounds' in your AddOns folder.",
			"  - Create a set of sound effects in the 'ogg' file format and call them 1.ogg, 2.ogg, etc.",
			"  - Place them in the MiniKillingBlowCustomSounds folder.",
			"  - Then choose the 'Custom' sound effect pack.",
			"  - Type the number of files you are using in the box below the sound pack dropdown (e.g. 1.ogg, 2.ogg, 3.ogg = 3 files).",
			"  - Do a /reload.",
			"  - Then click the test button to see if it works.",
		},
	})
	intro:SetPoint("TOPLEFT", killTextBox.EditBox, "BOTTOMLEFT", -FIELD_INSET, -verticalSpacing)
end
