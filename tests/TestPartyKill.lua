-- PartyKill() branches on whether the client hands it secret combat log GUIDs. The mock's
-- issecretvalue always answers false (see build/Lua/WowMock.lua), so the secret branch is
-- driven here by swapping it out for one that recognises a sentinel table as the only secret
-- value, exactly where a real secret GUID would arrive.

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

---Logs in with LE_EXPANSION_LEVEL_CURRENT raised to WowMock's own LE_EXPANSION_MIDNIGHT (11),
---so HasSecrets() reports true and the addon registers PARTY_KILL instead of the combat log
---route, letting a test drive PartyKill() by firing PARTY_KILL directly.
---@param preLoginOverrides table<string, any>?
---@return table context
local function LoginOnASecretsClient(preLoginOverrides)
	local context = harness.Load("MiniKillingBlow")
	local overrides = preLoginOverrides or {}
	overrides.LE_EXPANSION_LEVEL_CURRENT = 11

	WithGlobals(overrides, function()
		harness.Login(context)
	end)

	return context
end

fw.describe("MiniKillingBlow - event routing", function()
	fw.it("registers COMBAT_LOG_EVENT_UNFILTERED, not PARTY_KILL, on a client without secrets", function()
		local context = harness.Load("MiniKillingBlow")
		harness.Login(context)

		fw.eq(WowMock.FireEvent("PARTY_KILL", "x", "y"), 0, "PARTY_KILL was never registered")
		fw.truthy(WowMock.FireEvent("COMBAT_LOG_EVENT_UNFILTERED") > 0, "COMBAT_LOG_EVENT_UNFILTERED is the route this client uses")
	end)

	fw.it("registers PARTY_KILL, not COMBAT_LOG_EVENT_UNFILTERED, on a client with secrets", function()
		LoginOnASecretsClient()

		fw.truthy(WowMock.FireEvent("PARTY_KILL", "x", "y") > 0, "PARTY_KILL is the route this client uses")
		fw.eq(WowMock.FireEvent("COMBAT_LOG_EVENT_UNFILTERED"), 0, "COMBAT_LOG_EVENT_UNFILTERED was never registered")
	end)
end)

fw.describe("MiniKillingBlow - PartyKill with readable GUIDs", function()
	local context
	local db
	local playerGUID

	fw.before_each(function()
		context = LoginOnASecretsClient()
		db = _G["MiniKillingBlowDB"]
		db.SoundEffectPack = context.Addon.Config.SoundPacks.UnrealTournament
		playerGUID = UnitGUID("player")
	end)

	local function Fire(killerGUID, victimGUID)
		local calls = 0

		WithGlobals({
			PlaySoundFile = function()
				calls = calls + 1
			end,
		}, function()
			WowMock.FireEvent("PARTY_KILL", killerGUID, victimGUID)
		end)

		return calls
	end

	fw.it("registers a kill when the player is the killer and the victim is a player", function()
		fw.eq(Fire(playerGUID, "Player-1-victim"), 1, "self kill on a player target")
	end)

	fw.it("does nothing when someone else lands the kill", function()
		fw.eq(Fire("Player-1-someoneelse", "Player-1-victim"), 0, "not the player's own kill")
	end)

	fw.it("does nothing when the victim is not a player, even though the player landed the kill", function()
		fw.eq(Fire(playerGUID, "Creature-0-3-1-1-3111-000012345"), 0, "IsPlayerGUID rejects a non-player GUID")
	end)
end)

fw.describe("MiniKillingBlow - PartyKill with secret GUIDs", function()
	local context
	local db
	local killCount
	local sentinel

	fw.before_each(function()
		killCount = 0
		sentinel = {}

		context = LoginOnASecretsClient({
			GetAchievementCriteriaInfoByID = function()
				return nil, nil, nil, nil, nil, nil, nil, nil, killCount
			end,
		})

		db = _G["MiniKillingBlowDB"]
		db.SoundEffectPack = context.Addon.Config.SoundPacks.UnrealTournament
	end)

	local function FireSecret()
		local calls = 0

		WithGlobals({
			issecretvalue = function(v)
				return v == sentinel
			end,
			GetAchievementCriteriaInfoByID = function()
				return nil, nil, nil, nil, nil, nil, nil, nil, killCount
			end,
			PlaySoundFile = function()
				calls = calls + 1
			end,
		}, function()
			WowMock.FireEvent("PARTY_KILL", sentinel, sentinel)
		end)

		return calls
	end

	fw.it("falls back to the instance check without comparing the secret GUID, outside an arena", function()
		WowMock.State.InInstance = false

		fw.eq(FireSecret(), 0, "no kill registered outside an instance, regardless of the achievement count")
	end)

	fw.it("does nothing inside an arena until the achievement's kill count actually rises", function()
		WowMock.State.InInstance = true
		WowMock.State.InstanceType = "arena"

		fw.eq(FireSecret(), 0, "achievement count is unchanged from what totalKills already holds")
	end)

	fw.it("registers the kill once the achievement's kill count rises, inside an arena", function()
		WowMock.State.InInstance = true
		WowMock.State.InstanceType = "arena"

		killCount = 1

		fw.eq(FireSecret(), 1, "achievement delta rose, so this is treated as a real kill")
	end)
end)
