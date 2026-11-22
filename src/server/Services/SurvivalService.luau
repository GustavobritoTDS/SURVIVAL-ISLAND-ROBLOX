--!strict
-- Fome, sede, calor e vida; água doce; morte com bolsa de itens; renascimento; bloqueio de regiões.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Items = require(Shared.Config.Items)
local Game = require(Shared.Config.Game)
local Regions = require(Shared.Config.Regions)
local Rules = require(Shared.Logic.Rules)
local Inventory = require(Shared.Logic.Inventory)
local Net = require(Shared.Net)

local PlayerService = require(script.Parent.PlayerService)
local DataService = require(script.Parent.DataService)
local BuildService = require(script.Parent.BuildService)
local WorldService = require(script.Parent.WorldService)
local Env = require(script.Parent.Parent.Util.Env)

local SurvivalService = {}

local fxEvent = Net.event("Fx")
local lastSafe: { [Player]: CFrame } = {}
local lastPos: { [Player]: Vector3 } = {}
local MAX_SPEED = 75 -- studs/s horizontais (andar = 18; margem para empurrões e lag)

-- Teleportes legítimos do servidor ganham alguns segundos de tolerância
local function grace(player: Player)
	player:SetAttribute("TeleportGrace", os.clock() + 3)
	lastPos[player] = nil
end
SurvivalService.grace = grace
local alive: { [Player]: boolean } = {}

-- ===== Água doce =====
local function setupPond(part: Instance)
	if not part:IsA("BasePart") or part:FindFirstChildOfClass("ProximityPrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Beber"
	prompt.ObjectText = "Água doce"
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt:SetAttribute("Kind", "drink")
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		local data = DataService.get(player)
		if data then
			data.stats.thirst = math.min(Game.MAX_STAT, data.stats.thirst + 35)
			PlayerService.sync(player, "stats")
			fxEvent:FireClient(player, { kind = "drink" })
		end
	end)
end

-- ===== Morte =====
local function dropBag(player: Player, pos: Vector3)
	local data = DataService.get(player)
	local inv = PlayerService.inv(player)
	if not data or not inv then
		return
	end
	if data.keepItems > 0 then
		data.keepItems -= 1
		PlayerService.notify(player, "O Amuleto da Maré protegeu seus itens!", "good", "🧿")
		PlayerService.sync(player, "passes")
		return
	end
	local lost: { [string]: number } = {}
	local any = false
	for i = Game.HOTBAR_SLOTS + 1, inv.size do
		local st = inv.slots[i]
		if st and Items[st.id].category == "resource" then
			local n = math.floor(st.n * Game.DEATH_DROP_FRACTION)
			if n > 0 then
				Inventory.takeFromSlot(inv, i, n)
				lost[st.id] = (lost[st.id] or 0) + n
				any = true
			end
		end
	end
	if not any then
		return
	end
	PlayerService.changed(player)
	local bag = Instance.new("Part")
	bag.Name = "DeathBag"
	bag.Size = Vector3.new(2.2, 2, 2.2)
	bag.Shape = Enum.PartType.Ball
	bag.Color = Color3.fromRGB(140, 95, 55)
	bag.Material = Enum.Material.Fabric
	bag.Anchored = true
	bag.CanCollide = false
	local gy = WorldService.GetGroundY(pos.X, pos.Z)
	bag.Position = Vector3.new(pos.X, math.max(gy or pos.Y, 1) + 1, pos.Z)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 220, 120)
	light.Range = 10
	light.Parent = bag
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Recuperar itens"
	prompt.ObjectText = "Bolsa de " .. player.DisplayName
	prompt.HoldDuration = 0.5
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt:SetAttribute("Kind", "bag")
	prompt.Parent = bag
	prompt.Triggered:Connect(function(p)
		if p ~= player then
			PlayerService.notify(p, "Esta bolsa pertence a " .. player.DisplayName, "bad", "🔒")
			return
		end
		for id, n in lost do
			local got = PlayerService.give(p, id, n, true)
			lost[id] = n - got
			if lost[id] <= 0 then
				lost[id] = nil
			end
		end
		if next(lost) == nil then
			bag:Destroy()
			PlayerService.notify(p, "Itens recuperados!", "good", "🎒")
		end
	end)
	bag.Parent = workspace:WaitForChild("World")
	task.delay(Game.DEATH_BAG_LIFETIME, function()
		if bag.Parent then
			bag:Destroy()
		end
	end)
	PlayerService.notify(player, "Você deixou metade dos recursos numa bolsa onde morreu (5 min).", "bad", "💀")
end

local function onCharacter(player: Player, char: Model)
	local hum = char:WaitForChild("Humanoid") :: Humanoid
	local hrp = char:WaitForChild("HumanoidRootPart") :: BasePart
	local data = DataService.await(player)
	if not data then
		return
	end
	alive[player] = true
	-- Renascimento: cama ou praia
	local bed = BuildService.bedOf(player)
	grace(player)
	task.defer(function()
		if bed then
			char:PivotTo(bed)
		else
			char:PivotTo(WorldService.GetSpawnCFrame() * CFrame.new(math.random(-8, 8), 3, math.random(-8, 8)))
		end
	end)
	-- Após a morte o jogador volta com stats razoáveis
	if data.stats.health <= 0 then
		data.stats.health = 100
		data.stats.hunger = math.max(data.stats.hunger, 60)
		data.stats.thirst = math.max(data.stats.thirst, 60)
		data.stats.warmth = math.max(data.stats.warmth, 70)
	end
	hum.MaxHealth = 100
	hum.Health = math.clamp(data.stats.health, 10, 100)
	local s = PlayerService.session(player)
	if s then
		s.protectedUntil = os.clock() + Game.RESPAWN_PROTECTION
	end
	-- regen padrão do Roblox desligada (nós controlamos a vida)
	local regen = char:FindFirstChild("Health")
	if regen then
		regen:Destroy()
	end
	hum.Died:Connect(function()
		alive[player] = false
		data.stats.health = 0
		PlayerService.count(player, "deaths", 1)
		dropBag(player, hrp.Position)
	end)
	PlayerService.sync(player, "stats")
end

-- ===== Tick de sobrevivência =====
local function tick(dt: number)
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if data and hum and hrp and hum.Health > 0 and alive[player] then
			local pos = hrp.Position
			-- Anti-teleporte/speed: deslocamento horizontal impossível volta à última posição
			local prev = lastPos[player]
			local graceUntil = (player:GetAttribute("TeleportGrace") :: number?) or 0
			if prev and os.clock() > graceUntil then
				local flat = (pos - prev) * Vector3.new(1, 0, 1)
				if flat.Magnitude / math.max(dt, 0.1) > MAX_SPEED then
					char:PivotTo(CFrame.new(prev + Vector3.new(0, 2, 0)))
					warn(("[Survival] movimento suspeito de %s: %.0f studs em %.1fs"):format(player.Name, flat.Magnitude, dt))
					pos = prev
				end
			end
			lastPos[player] = pos
			local region = Regions.at(pos)
			-- Regiões bloqueadas por nível: empurra de volta para o último ponto seguro
			if data.level < region.level then
				local back = lastSafe[player]
				if back then
					grace(player)
					char:PivotTo(back)
				end
				PlayerService.notify(player, ("%s requer nível %d"):format(region.name, region.level), "bad", "🔒")
			else
				lastSafe[player] = hrp.CFrame
			end
			local holdingTorch = char:FindFirstChildOfClass("Tool") and (char:FindFirstChildOfClass("Tool") :: Tool):GetAttribute("ItemId") == "torch"
			local inCave = region.id == "cave"
			local env = {
				dt = dt,
				night = Env.night or inCave,
				storm = Env.storm and not inCave,
				nearFire = Env.isWarm(pos) or holdingTorch == true,
				armorWarmth = (player:GetAttribute("ArmorWarmth") :: number?) or 0,
			}
			local st = data.stats
			st.health = hum.Health
			local dmg, heal = Rules.tickSurvival(st, env, Game)
			if dmg > 0 then
				hum:TakeDamage(dmg)
			elseif heal > 0 then
				hum.Health = math.min(hum.MaxHealth, hum.Health + heal)
			end
			-- vulcão: calor extremo perto da cratera
			if region.id == "volcano" then
				st.thirst = math.max(0, st.thirst - 0.4 * dt)
				st.warmth = Game.MAX_STAT
			end
			st.health = hum.Health
			player:SetAttribute("Region", region.id)
			PlayerService.sync(player, "stats")
		end
	end
end

function SurvivalService.init()
	local fresh = workspace:WaitForChild("World"):WaitForChild("FreshWater")
	for _, p in CollectionService:GetTagged("FreshWater") do
		setupPond(p)
	end
	CollectionService:GetInstanceAddedSignal("FreshWater"):Connect(setupPond)
	for _, p in fresh:GetChildren() do
		setupPond(p)
	end

	local function hook(player: Player)
		player.CharacterAdded:Connect(function(c)
			onCharacter(player, c)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		lastSafe[p] = nil
		lastPos[p] = nil
		alive[p] = nil
	end)

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(Game.SURVIVAL_TICK)
			local now = os.clock()
			local ok, err = pcall(tick, now - last)
			if not ok then
				warn("[Survival]", err)
			end
			last = now
		end
	end)
end

return SurvivalService
