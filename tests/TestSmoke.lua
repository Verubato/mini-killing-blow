-- Loads the whole addon into a mocked client and drives it through login.
-- The shared body lives in build/Lua/SmokeTest.lua.

local fw = require("TestFramework")
local smoke = require("SmokeTest")
local WowMock = require("WowMock")

local VERTICAL_SPACING = 16

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

smoke.Run("MiniKillingBlow", {
	extra = function(context)
		fw.eq(context.Addon.Framework.CustomStyling, true, "custom styling on")
		fw.eq(context.Addon.Framework.CustomStylingOverrides.Button, false, "stock buttons")
		fw.not_nil(FindDivider("SETTINGS"), "the settings section rule under the header")

		local testBtn = FindButton("Test")
		fw.not_nil(testBtn, "the test button")

		local _, testBtnAnchor, _, testBtnX, testBtnY = testBtn:GetPoint()
		fw.eq(testBtnAnchor:GetObjectType(), "EditBox", "the test button anchors to the custom sound count box")
		fw.eq(testBtnX, 0, "the test button has no horizontal offset")
		fw.eq(testBtnY, -8, "the test button sits close under the custom sound count box")

		local textDivider = FindDivider("TEXT")
		fw.not_nil(textDivider, "the Text section rule")

		local _, textDividerAnchor, _, textDividerX, textDividerY = textDivider:GetPoint()
		fw.eq(textDividerAnchor, testBtn, "the Text section rule anchors to the test button")
		fw.eq(textDividerX, 0, "the Text section rule has no horizontal offset")
		fw.eq(textDividerY, -VERTICAL_SPACING, "one vertical spacing under the test button")

		local db = _G["MiniKillingBlowDB"]
		db.SoundEffectPack = "Custom"
		db.ShowKillText = true

		local resetBtn = FindButton("Reset to Defaults")
		fw.not_nil(resetBtn, "reset button exists")

		AcceptConfirm(function()
			resetBtn:Click()
		end)

		fw.eq(db.SoundEffectPack, context.Addon.Config.SoundPacks.UnrealTournament, "reset restored SoundEffectPack")
		fw.eq(db.ShowKillText, false, "reset restored ShowKillText")
	end,
})
