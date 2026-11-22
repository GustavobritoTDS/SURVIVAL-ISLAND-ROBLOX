--!strict
-- Estado autoritativo do jogador: inventário, armadura, XP, Conchas, contadores e sincronização.
-- Toda alteração passa por aqui e é enviada ao cliente com PlayerService.sync().

local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Items = require(Shared.Config.Items)
local Game = require(Shared.Config.Game)
local Progression = require(Shared.Config.Progression)
local Inventory = require(Shared.Logic.Inventory)
local Rules = require(Shared.Logic.Rules)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local Actions = require(script.Parent.Parent.Util.Actions)

local PlayerService = {}

type Session = {
	inv: any,
	equipped: number?, -- slot da hotbar selecionado
	vip: boolean,
	bigBackpack: boolean,
	protectedUntil: number,
	friends: { [number]: boolean },
}

local sessions: { [Player]: Session } = {}
local stateEvent = Net.event("State")
local notifyEvent = Net.event("Notify")

local counterListeners: { (Player, string, number) -> () } = {}
local readyListeners: { (Player, any) -> () } = {}
local inventoryListeners: { (Player) -> () } = {}

local function stackOf(id: string): number
	local d = Items[id]
	return d and d.stack or 1
end

local function isValidItem(id: string): boolean
	return Items[id] ~= nil
end

function PlayerService.session(player: Player): Session?
	return sessions[player]
end

function PlayerService.inv(player: Player): any
	local s = sessions[player]
	return s and s.inv
end

function PlayerService.data(player: Player): any
	return DataService.get(player)
end

function PlayerService.inventorySize(player: Player): number
	local s = sessions[player]
	return Game.INVENTORY_SLOTS + ((s and s.bigBackpack) and Game.BIG_BACKPACK_BONUS or 0)
end

-- ===== Notificações =====
-- kind: "info" | "good" | "bad" | "item" | "level" | "quest"
function PlayerService.notify(player: Player, text: string, kind: string?, icon: string?)
	notifyEvent:FireClient(player, { text = text, kind = kind or "info", icon = icon })
end

-- ===== Sincronização =====
function PlayerService.sync(player: Player, ...: string)
	local data = DataService.get(player)
	local s = sessions[player]
	if not data or not s then
		return
	end
	local out: { [string]: any } = {}
	local sections = { ... }
	if #sections == 0 then
		sections = { "inv", "stats", "progress", "quests", "cosmetics", "settings", "tutorial", "passes" }
	end
	for _, sec in sections do
		if sec == "inv" then
			out.inv = Inventory.serialize(s.inv)
			out.invSize = s.inv.size
			out.armor = data.armor
			out.equipped = s.equipped
		elseif sec == "stats" then
			out.stats = data.stats
		elseif sec == "progress" then
			out.level = data.level
			out.xp = data.xp
			out.xpNeed = Progression.xpForLevel(data.level)
			out.shells = data.shells
		elseif sec == "quests" then
			out.daily = data.daily
			out.achievements = data.achievements
			out.counters = data.counters
			out.login = data.login
		elseif sec == "cosmetics" then
			out.cosmetics = data.cosmetics
		elseif sec == "settings" then
			out.settings = data.settings
		elseif sec == "tutorial" then
			out.tutorial = data.tutorial
		elseif sec == "passes" then
			out.passes = {
				vip = s.vip,
				bigBackpack = s.bigBackpack,
				parrot = player:GetAttribute("PassParrot") == true,
				trails = player:GetAttribute("PassTrails") == true,
			}
			out.keepItems = data.keepItems
		end
	end
	stateEvent:FireClient(player, out)
end

-- ===== Inventário =====
local function inventoryChanged(player: Player)
	for _, fn in inventoryListeners do
		task.spawn(fn, player)
	end
	PlayerService.sync(player, "inv")
end

function PlayerService.onInventoryChanged(fn: (Player) -> ())
	table.insert(inventoryListeners, fn)
end

-- Dá itens; retorna quantos couberam. Avisa se o inventário estiver cheio.
function PlayerService.give(player: Player, id: string, n: number, silent: boolean?): number
	local s = sessions[player]
	local def = Items[id]
	if not s or not def or n <= 0 then
		return 0
	end
	local preferHotbar = def.stack == 1
	local added = Inventory.add(s.inv, id, math.floor(n), def.stack, Game.HOTBAR_SLOTS, preferHotbar)
	if added < n then
		PlayerService.notify(player, "Inventário cheio!", "bad", "🎒")
	end
	if added > 0 then
		if not silent then
			PlayerService.notify(player, ("+%d %s"):format(added, def.name), "item", def.icon)
		end
		inventoryChanged(player)
	end
	return added
end

function PlayerService.giveMany(player: Player, items: { [string]: number }, silent: boolean?)
	for id, n in items do
		PlayerService.give(player, id, n, silent)
	end
end

function PlayerService.has(player: Player, cost: { [string]: number }): boolean
	local s = sessions[player]
	return s ~= nil and Inventory.hasAll(s.inv, cost)
end

function PlayerService.take(player: Player, cost: { [string]: number }): boolean
	local s = sessions[player]
	if not s then
		return false
	end
	if Inventory.removeAll(s.inv, cost) then
		inventoryChanged(player)
		return true
	end
	return false
end

function PlayerService.takeFromSlot(player: Player, slot: number, n: number): string?
	local s = sessions[player]
	if not s then
		return nil
	end
	local id, taken = Inventory.takeFromSlot(s.inv, slot, n)
	if id and taken > 0 then
		inventoryChanged(player)
		return id
	end
	return nil
end

function PlayerService.changed(player: Player)
	inventoryChanged(player)
end

-- Item na hotbar selecionada
function PlayerService.equippedItem(player: Player): (string?, number?)
	local s = sessions[player]
	if not s or not s.equipped then
		return nil, nil
	end
	local st = s.inv.slots[s.equipped]
	return st and st.id, s.equipped
end

function PlayerService.setEquipped(player: Player, slot: number?)
	local s = sessions[player]
	if s then
		s.equipped = slot
		PlayerService.sync(player, "inv")
	end
end

-- ===== Progresso =====
function PlayerService.addXp(player: Player, amount: number)
	local data = DataService.get(player)
	local s = sessions[player]
	if not data or not s then
		return
	end
	local mult = s.vip and (1 + Game.VIP_XP_BONUS) or 1
	local ups = Rules.addXp(data, amount * mult, Progression.xpForLevel, Game.MAX_LEVEL)
	for _, lvl in ups do
		local reward = Progression.levelReward(lvl)
		data.shells += reward
		PlayerService.notify(player, ("Nível %d! +%d Conchas"):format(lvl, reward), "level", "⭐")
		player:SetAttribute("Level", lvl)
	end
	PlayerService.sync(player, "progress")
end

function PlayerService.addShells(player: Player, n: number)
	local data = DataService.get(player)
	if data and n > 0 then
		data.shells += math.floor(n)
		PlayerService.sync(player, "progress")
	end
end

function PlayerService.spendShells(player: Player, n: number): boolean
	local data = DataService.get(player)
	if data and n > 0 and data.shells >= n then
		data.shells -= n
		PlayerService.sync(player, "progress")
		return true
	end
	return false
end

-- Incrementa contador (missões / conquistas escutam)
function PlayerService.count(player: Player, stat: string, n: number)
	local data = DataService.get(player)
	if not data then
		return
	end
	data.counters[stat] = (data.counters[stat] or 0) + n
	for _, fn in counterListeners do
		task.spawn(fn, player, stat, n)
	end
end

function PlayerService.onCounter(fn: (Player, string, number) -> ())
	table.insert(counterListeners, fn)
end

-- Registra callback de "jogador pronto"; também é chamado para quem já estava pronto
function PlayerService.onReady(fn: (Player, any) -> ())
	table.insert(readyListeners, fn)
	for p in sessions do
		local data = DataService.get(p)
		if data and p.Parent then
			task.spawn(fn, p, data)
		end
	end
end

function PlayerService.isFriend(owner: Player?, other: Player): boolean
	if owner == nil then
		return false
	end
	if owner == other then
		return true
	end
	local s = sessions[owner]
	if not s then
		return false
	end
	local cached = s.friends[other.UserId]
	if cached ~= nil then
		return cached
	end
	local ok, res = pcall(function()
		return owner:IsFriendsWith(other.UserId)
	end)
	local val = ok and res == true
	s.friends[other.UserId] = val
	return val
end

-- Recalcula tamanho do inventário (pass de mochila)
function PlayerService.refreshInventorySize(player: Player)
	local s = sessions[player]
	if not s then
		return
	end
	local size = PlayerService.inventorySize(player)
	if size > s.inv.size then
		s.inv.size = size
	elseif size < s.inv.size then
		local overflow = Inventory.resize(s.inv, size)
		for _, st in overflow do
			Inventory.add(s.inv, st.id, st.n, stackOf(st.id))
		end
	end
	inventoryChanged(player)
end

-- ===== Ações do cliente =====
local function onMove(player: Player, from: any, to: any)
	local s = sessions[player]
	if not s then
		return
	end
	local f = Actions.int(from, 1, s.inv.size)
	local t = Actions.int(to, 1, s.inv.size)
	if f and t and Inventory.move(s.inv, f, s.inv, t, stackOf) then
		inventoryChanged(player)
	end
end

local function onDrop(player: Player, slot: any)
	local s = sessions[player]
	local sl = s and Actions.int(slot, 1, s.inv.size)
	if not s or not sl then
		return
	end
	local st = s.inv.slots[sl]
	if st then
		s.inv.slots[sl] = nil
		PlayerService.notify(player, ("Descartou %d %s"):format(st.n, Items[st.id].name), "info", Items[st.id].icon)
		inventoryChanged(player)
	end
end

local function onSettings(player: Player, settings: any)
	local data = DataService.get(player)
	if not data or type(settings) ~= "table" then
		return
	end
	for _, key in { "music", "sfx", "fx", "shadows" } do
		if type(settings[key]) == "boolean" then
			data.settings[key] = settings[key]
		end
	end
	if settings.quality == "auto" or settings.quality == "low" or settings.quality == "high" then
		data.settings.quality = settings.quality
	end
end

local function onTutorial(player: Player, step: any)
	local data = DataService.get(player)
	local st = Actions.int(step, 0, 100)
	if data and st and st > data.tutorial then
		data.tutorial = st
	end
end

function PlayerService.init()
	local function onLoaded(player: Player)
		local data = DataService.get(player)
		if not data or sessions[player] then
			return
		end
		local s: Session = {
			inv = Inventory.new(Game.INVENTORY_SLOTS),
			equipped = nil,
			vip = false,
			bigBackpack = false,
			protectedUntil = 0,
			friends = {},
		}
		s.inv = Inventory.deserialize(data.inv, Game.INVENTORY_SLOTS + Game.BIG_BACKPACK_BONUS, isValidItem, stackOf)
		sessions[player] = s
		-- tamanho real é definido depois que o MonetizationService checar os passes
		s.inv.size = math.max(Game.INVENTORY_SLOTS, s.inv.size)
		local overflow = Inventory.resize(s.inv, Game.INVENTORY_SLOTS + Game.BIG_BACKPACK_BONUS)
		for _, st in overflow do
			Inventory.add(s.inv, st.id, st.n, stackOf(st.id))
		end
		player:SetAttribute("Level", data.level)
		for _, fn in readyListeners do
			task.spawn(fn, player, data)
		end
		PlayerService.refreshInventorySize(player)
		PlayerService.sync(player)
		player:SetAttribute("DataReady", true)
	end
	DataService.loaded:Connect(onLoaded)
	-- Jogadores cujo perfil carregou antes deste serviço iniciar (entraram durante a geração do mundo)
	for _, p in Players:GetPlayers() do
		task.spawn(onLoaded, p)
	end

	DataService.onBeforeSave(function(player, data)
		local s = sessions[player]
		if s then
			data.inv = Inventory.serialize(s.inv)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		task.defer(function()
			sessions[player] = nil
		end)
	end)

	Actions.on("Move", onMove, 15)
	Actions.on("Drop", onDrop, 5)
	Actions.on("Settings", onSettings, 2)
	Actions.on("Tutorial", onTutorial, 2)
	Actions.on("RequestSync", function(player)
		PlayerService.sync(player)
	end, 1)
end

-- Inicia novo personagem dentro do tamanho correto mesmo se ainda sem pass
function PlayerService.setPasses(player: Player, vip: boolean, bigBackpack: boolean)
	local s = sessions[player]
	if s then
		s.vip = vip
		s.bigBackpack = bigBackpack
		player:SetAttribute("VIP", vip)
		PlayerService.refreshInventorySize(player)
		PlayerService.sync(player, "passes")
	end
end

return PlayerService
