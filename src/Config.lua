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

---@class Db
local dbDefaults = {
	SoundEffectPack = M.SoundPacks.UnrealTournament,
	CustomSoundEffectCount = 5,
}

addon.Config = M

function M:Init()
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
	local version = C_AddOns.GetAddOnMetadata(addonName, "Version")
	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 0, -verticalSpacing)
	title:SetText(string.format("%s - %s", addonName, version))

	local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontWhite")
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	subtitle:SetText("Increase your PvP immersion.")

	mini:RegisterSlashCommand(category, panel, {
		"/minikillingblow",
		"/minikb",
		"/mkb",
	})

	local packLbl = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
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

	local function ShowHideCustomCount()
		if db.SoundEffectPack == M.SoundPacks.Custom then
			customCount.EditBox:Show()
			customCount.Label:Show()
		else
			customCount.EditBox:Hide()
			customCount.Label:Hide()
		end
	end

	local soundPackDdl, modernDdl = mini:Dropdown({
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

	packLbl:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -verticalSpacing)
	soundPackDdl:SetPoint("TOPLEFT", packLbl, "BOTTOMLEFT", modernDdl and 0 or -16, -8)
	soundPackDdl:SetWidth(columnWidth - horizontalSpacing)

	customCount.Label:SetPoint("TOP", packLbl, "TOP", 0, 0)
	customCount.Label:SetPoint("LEFT", panel, "LEFT", columnWidth, 0)

	customCount.EditBox:SetPoint("TOP", soundPackDdl, "TOP", 0, 0)
	customCount.EditBox:SetPoint("LEFT", panel, "LEFT", columnWidth, 0)

	ShowHideCustomCount()

	local testBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	testBtn:SetSize(120, 26)
	testBtn:SetPoint("TOPLEFT", soundPackDdl, "BOTTOMLEFT", 0, -verticalSpacing)
	testBtn:SetText("Test")
	testBtn:SetScript("OnClick", function()
		addon:TestKb()
	end)

	local intro = mini:TextBlock({
		Parent = panel,
		Lines = {
			"To make your own sound effects:",
			"  - Create a folder called 'MiniKillingBlowCustomSounds' in your AddOns folder.",
			"  - Create a set of sound effects in the 'ogg' file format and call them 1.ogg, 2.ogg, etc.",
			"  - Place them in the MiniKillingBlowCustomSounds folder.",
			"  - Then choose the 'Custom' sound effect pack.",
			"  - Type the number of files you are using in the right text box (e.g. 1.ogg, 2.ogg, 3.ogg = 3 files).",
			"  - Do a /reload.",
			"  - Then click the test button to see if it works.",
		},
	})
	intro:SetPoint("TOPLEFT", testBtn, "BOTTOMLEFT", 0, -verticalSpacing)
end
