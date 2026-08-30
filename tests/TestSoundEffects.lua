-- Drives GetSoundEffect(), OneToN() and the multi-kill window through addon:TestKb(), the
-- only public entry point that reaches them, and reads the choice back from the sound file
-- PlaySoundFile was called with.

local fw = require("TestFramework")
local harness = require("AddonHarness")
local WowMock = require("WowMock")

---Overrides one or more globals for the duration of fn, restoring them even if fn raises,
---so one failing assertion can't leave a later test running against a patched global.
---@param overrides table<string, any>
---@param fn fun()
local function WithGlobals(overrides, fn)
	local reals = {}

	for name, value in pairs(overrides) do
		reals[name] = _G[name]
		_G[name] = value
	end

	local ok, err = pcall(fn)

	for name, value in pairs(reals) do
		_G[name] = value
	end

	if not ok then
		error(err, 0)
	end
end

fw.describe("MiniKillingBlow - GetSoundEffect and OneToN", function()
	local context
	local db

	fw.before_each(function()
		context = harness.Load("MiniKillingBlow")
		harness.Login(context)
		db = _G["MiniKillingBlowDB"]
	end)

	local function CapturedFiles(count)
		local files = {}

		WithGlobals({
			PlaySoundFile = function(file)
				files[#files + 1] = file
			end,
		}, function()
			for _ = 1, count do
				context.Addon:TestKb()
			end
		end)

		return files
	end

	fw.it("cycles the Guns pack through OneToN(x, 4), wrapping after the fourth kill", function()
		db.SoundEffectPack = context.Addon.Config.SoundPacks.Guns

		local files = CapturedFiles(5)

		fw.truthy(files[1]:find("Guns\\1.ogg", 1, true) ~= nil, "OneToN(1, 4) = 1")
		fw.truthy(files[4]:find("Guns\\4.ogg", 1, true) ~= nil, "OneToN(4, 4) = 4")
		fw.truthy(files[5]:find("Guns\\1.ogg", 1, true) ~= nil, "OneToN(5, 4) wraps back to 1")
	end)

	fw.it("clamps the Unreal Tournament pack at its maximum of 7", function()
		db.SoundEffectPack = context.Addon.Config.SoundPacks.UnrealTournament

		local files = CapturedFiles(8)

		fw.truthy(files[7]:find("UnrealTournament\\7.ogg", 1, true) ~= nil, "the seventh kill reaches the maximum")
		fw.truthy(files[8]:find("UnrealTournament\\7.ogg", 1, true) ~= nil, "the eighth kill clamps at the maximum")
	end)

	fw.it("uses the raw window count for the Custom pack, clamped at CustomSoundEffectCount", function()
		db.SoundEffectPack = context.Addon.Config.SoundPacks.Custom
		db.CustomSoundEffectCount = 3

		local files = CapturedFiles(4)

		fw.truthy(files[1]:find("MiniKillingBlowCustomSounds\\1.ogg", 1, true) ~= nil, "first kill uses count 1")
		fw.truthy(files[3]:find("MiniKillingBlowCustomSounds\\3.ogg", 1, true) ~= nil, "third kill reaches the configured count")
		fw.truthy(files[4]:find("MiniKillingBlowCustomSounds\\3.ogg", 1, true) ~= nil, "fourth kill clamps at the configured count")
	end)
end)

fw.describe("MiniKillingBlow - the multi-kill window", function()
	local context
	local db

	fw.before_each(function()
		context = harness.Load("MiniKillingBlow")
		harness.Login(context)
		db = _G["MiniKillingBlowDB"]
		-- A high, unclamped count so the played file's number is the raw window count itself.
		db.SoundEffectPack = context.Addon.Config.SoundPacks.Custom
		db.CustomSoundEffectCount = 999
	end)

	local function KillAndReadCount()
		local file

		WithGlobals({
			PlaySoundFile = function(f)
				file = f
			end,
		}, function()
			context.Addon:TestKb()
		end)

		return tonumber(file:match("(%d+)%.ogg$"))
	end

	fw.it("gives 1 for the first kill", function()
		fw.eq(KillAndReadCount(), 1, "a fresh streak starts at 1")
	end)

	fw.it("gives 2 for a second kill inside the 10 second window", function()
		KillAndReadCount()

		fw.eq(KillAndReadCount(), 2, "the streak continues within the window")
	end)

	fw.it("resets to 1 once the 10 second window has expired", function()
		KillAndReadCount()

		WowMock.AdvanceTime(11)

		fw.eq(KillAndReadCount(), 1, "the streak reset once the window passed")
	end)
end)
