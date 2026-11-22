--!strict
-- Missões diárias, conquistas e recompensa de login diário (sequência de 7 dias).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Progression = require(Shared.Config.Progression)
local Rules = require(Shared.Logic.Rules)

local PlayerService = require(script.Parent.PlayerService)
local DataService = require(script.Parent.DataService)
local Actions = require(script.Parent.Parent.Util.Actions)

local QuestService = {}

local function today(): number
	return math.floor(os.time() / 86400)
end

local function ensureDaily(player: Player, data: any)
	local day = today()
	if data.daily.day ~= day then
		local picks = Rules.pickDaily(Progression.dailyPool, Progression.DAILY_COUNT, day * 7919 + player.UserId)
		local quests = {}
		for _, q in picks do
			table.insert(quests, { id = q.id, progress = 0, claimed = false })
		end
		data.daily = { day = day, quests = quests }
	end
end

local function dailyDef(id: string): any
	for _, q in Progression.dailyPool do
		if q.id == id then
			return q
		end
	end
	return nil
end

local function onCounter(player: Player, stat: string, n: number)
	local data = DataService.get(player)
	if not data then
		return
	end
	ensureDaily(player, data)
	local changed = false
	for _, q in data.daily.quests do
		local def = dailyDef(q.id)
		if def and def.stat == stat and q.progress < def.goal then
			q.progress = math.min(def.goal, q.progress + n)
			changed = true
			if q.progress >= def.goal then
				PlayerService.notify(
					player,
					"Missão concluída: " .. def.text .. " — resgate a recompensa!",
					"quest",
					"📜"
				)
			end
		end
	end
	for _, a in Progression.achievements do
		if a.stat == stat and not data.achievements[a.id] and (data.counters[stat] or 0) >= a.goal then
			data.achievements[a.id] = true
			data.shells += a.shells
			PlayerService.notify(player, ("Conquista: %s! +%d Conchas"):format(a.text, a.shells), "level", "🏆")
			PlayerService.sync(player, "progress")
			changed = true
		end
	end
	if changed then
		PlayerService.sync(player, "quests")
	end
end

local function onClaim(player: Player, index: any)
	local data = DataService.get(player)
	local i = Actions.int(index, 1, Progression.DAILY_COUNT)
	if not data or not i then
		return
	end
	ensureDaily(player, data)
	local q = data.daily.quests[i]
	local def = q and dailyDef(q.id)
	if not q or not def or q.claimed or q.progress < def.goal then
		return
	end
	q.claimed = true
	PlayerService.addShells(player, def.shells)
	PlayerService.addXp(player, def.xp)
	PlayerService.notify(player, ("+%d Conchas, +%d XP"):format(def.shells, def.xp), "good", "🐚")
	PlayerService.sync(player, "quests")
end

local function login(player: Player, data: any)
	ensureDaily(player, data)
	local day = today()
	local streak, reward = Rules.loginStreak(data.login.lastDay, data.login.streak or 0, day)
	data.login.lastDay = day
	data.login.streak = streak
	if reward then
		local r = Progression.loginRewards[((streak - 1) % #Progression.loginRewards) + 1]
		local shells = r.shells
		if player:GetAttribute("VIP") then
			shells += 25
		end
		data.shells += shells
		task.delay(4, function()
			if player.Parent then
				PlayerService.giveMany(player, r.items, true)
				PlayerService.notify(
					player,
					("Bônus diário (dia %d): +%d Conchas e suprimentos!"):format(streak, shells),
					"level",
					"🎁"
				)
				PlayerService.sync(player, "progress", "quests")
			end
		end)
	end
end

function QuestService.init()
	PlayerService.onCounter(onCounter)
	PlayerService.onReady(login)
	Actions.on("ClaimQuest", onClaim, 3)
end

return QuestService
