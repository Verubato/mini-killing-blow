-- Loads the whole addon into a mocked client and drives it through login.
-- The shared body lives in build/Lua/SmokeTest.lua.

local fw = require("TestFramework")
local smoke = require("SmokeTest")
local WowMock = require("WowMock")

local VERTICAL_SPACING = 16
-- Mirrors FIELD_INSET in src/Config.lua.
local FIELD_INSET = 4

---The section rule is built by the framework and never handed back to the addon, so a test
---finds it the way a player sees it, by its label.
---@param text string
---@return table?
local function FindDivider(text)
	for _, frame in ipairs(WowMock.Frames) do
		if frame.Label and frame.Label.GetText and frame.Label:GetText() == text then
			return frame
		end
	end
end

---The reset button is a frame the framework owns, so a test reaches it by its label.
---@param label string
---@return table?
local function FindButton(label)
	for _, frame in ipairs(WowMock.Frames) do
		if frame.GetText and frame:GetText() == label and frame.Click then
			return frame
		end
	end

	return nil
end

---A modern dropdown only exposes its choices through the generator it handed to SetupMenu,
---so a test replays that generator against a description that keeps the callbacks.
---@param dd table
---@return table<string, fun()>
local function MenuChoices(dd)
	local choices = {}
	local description = {}

	setmetatable(description, {
		__index = function()
			return function() end
		end,
	})

	description.CreateRadio = function(_, text, _, setSelected)
		choices[text] = setSelected

		return nil
	end

	dd.__menuGenerator(dd, description)

	return choices
end

---@param label string
---@return table?
local function FindDropdownOffering(label)
	for _, frame in ipairs(WowMock.Frames) do
		if frame.__menuGenerator and MenuChoices(frame)[label] then
			return frame
		end
	end

	return nil
end

---The client does nothing with a prompt in the mock, so a test stands in for it.
---@param open fun()
local function AcceptConfirm(open)
	local seen
	local real = StaticPopup_Show

	StaticPopup_Show = function(which, _, _, data)
		seen = { Which = which, Data = data }
	end

	local ok, err = pcall(open)

	StaticPopup_Show = real

	if not ok then
		error(err, 0)
	end

	if not seen then
		error("no confirmation was opened")
	end

	StaticPopupDialogs[seen.Which].OnAccept(nil, seen.Data)
end

---The block is never handed back, so a test finds it by the frame carrying its first line.
---@param text string
---@return table?
local function FindTextBlockUnder(text)
	for _, frame in ipairs(WowMock.Frames) do
		for _, region in ipairs({ frame:GetRegions() }) do
			if region.GetText and region:GetText() == text then
				return frame
			end
		end
	end
end

smoke.Run("MiniKillingBlow", {
	extra = function(context)
		fw.eq(context.Addon.Framework.CustomStyling, true, "custom styling on")
		fw.eq(context.Addon.Framework.CustomStylingOverrides.Button, false, "stock buttons")
		fw.not_nil(FindDivider("SETTINGS"), "the settings section rule under the header")

		local testBtn = FindButton("Test")
		local resetBtn = FindButton("Reset to Defaults")
		fw.not_nil(testBtn, "the test button")
		fw.not_nil(resetBtn, "reset button exists")

		local testPoint, testRelativeTo, testRelativePoint = testBtn:GetPoint()
		fw.eq(testPoint, "RIGHT", "the test button is anchored by its own right edge")
		fw.eq(testRelativeTo, resetBtn, "the test button hangs off the reset button")
		fw.eq(testRelativePoint, "LEFT", "the test button sits left of the reset button")

		local soundPackDdl = FindDropdownOffering("Custom")
		fw.not_nil(soundPackDdl, "the sound pack dropdown")

		local textDivider = FindDivider("TEXT")
		fw.not_nil(textDivider, "the Text section rule")

		-- Every pack but Custom hides the count box, so the rule has to take that row back
		-- rather than leave a gap where the box would have been.
		local _, dividerAnchor, _, dividerX, dividerY = textDivider:GetPoint()
		fw.eq(dividerAnchor, soundPackDdl, "the Text rule anchors to the sound pack dropdown")
		fw.eq(dividerX, 0, "the Text rule has no horizontal offset")
		fw.eq(dividerY, -VERTICAL_SPACING, "one vertical spacing under the sound pack dropdown")

		MenuChoices(soundPackDdl)["Custom"]()

		local _, customAnchor, _, customX, customY = textDivider:GetPoint()
		fw.eq(customAnchor:GetObjectType(), "EditBox", "the Text rule anchors to the custom sound count box")
		fw.eq(customX, -FIELD_INSET, "the Text rule backs out the count box's own inset")
		fw.eq(customY, -VERTICAL_SPACING, "one vertical spacing under the custom sound count box")

		MenuChoices(soundPackDdl)["Unreal Tournament"]()

		-- The help text hangs off a field that is itself inset, so it backs that out to keep
		-- one left edge down the panel.
		local intro = FindTextBlockUnder("To make your own sound effects:")
		fw.not_nil(intro, "the custom sound help text")
		fw.eq(select(4, intro:GetPoint()), -FIELD_INSET, "the help text starts on the panel's left edge")

		local db = _G["MiniKillingBlowDB"]
		db.SoundEffectPack = "Custom"
		db.ShowKillText = true

		AcceptConfirm(function()
			resetBtn:Click()
		end)

		fw.eq(db.SoundEffectPack, context.Addon.Config.SoundPacks.UnrealTournament, "reset restored SoundEffectPack")
		fw.eq(db.ShowKillText, false, "reset restored ShowKillText")
	end,
})
