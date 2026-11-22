--!strict
-- Criaturas: spawn por região, IA (vagar/fugir/perseguir/atacar), dano e recompensas.
-- A IA só roda perto de jogadores (economiza CPU); criaturas longe por muito tempo são recicladas.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Creatures = require(Shared.Config.Creatures)
local Regions = require(Shared.Config.Regions)
local Game = require(Shared.Config.Game)
local Rules = require(Shared.Logic.Rules)
local Net = require(Shared.Net)

local PlayerService = require(script.Parent.PlayerService)
local WorldService = require(script.Parent.WorldService)
local CreatureModels = require(script.Parent.Parent.Builders.CreatureModels)
local Env = require(script.Parent.Parent.Util.Env)

local CreatureService = {}

type Mob = {
	id: string,
	model: Model,
	hum: Humanoid,
	root: BasePart,
	home: Vector3,
	state: string,
	target: Player?,
	lastAttack: number,
	lastHitBy: Player?,
	nextWander: number,
	farSince: number?,
	provoked: boolean,
}

local mobs: { [Model]: Mob } = {}
local alive: { [string]: number } = {}
local folder: Folder
local rng = Random.new()
local fxEvent = Net.event("Fx")
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include

local TICK = 0.25
local ACTIVE_RANGE = 220

local function charOf(p: Player): (BasePart?, Humanoid?)
	local c = p.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		return hrp, hum
	end
	return nil, nil
end

local function nearestPlayer(pos: Vector3, maxDist: number): (Player?, number)
	local best, bestD = nil, maxDist
	for _, p in Players:GetPlayers() do
		local hrp = charOf(p)
		if hrp then
			local d = (hrp.Position - pos).Magnitude
			if d < bestD then
				best, bestD = p, d
			end
		end
	end
	return best, bestD
end

-- Dificuldade progressiva: noites passadas no servidor aumentam vida/dano das Sombras
local function difficulty(id: string): number
	if id == "tide_shade" then
		return 1 + math.min(Env.nightCount, 10) * 0.08
	end
	return 1
end

local function spawnMob(id: string, pos: Vector3)
	local def = Creatures[id]
	local model = CreatureModels.build(id)
	local mult = difficulty(id)
	local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.MaxHealth = def.health * mult
	hum.Health = hum.MaxHealth
	model:SetAttribute("CreatureId", id)
	model:SetAttribute("Damage", def.damage * mult)
	model:PivotTo(CFrame.new(pos + Vector3.new(0, 4, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	model.Parent = folder
	local root = model.PrimaryPart :: BasePart
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	CollectionService:AddTag(model, "Creature")
	local mob: Mob = {
		id = id,
		model = model,
		hum = hum,
		root = root,
		home = pos,
		state = "wander",
		target = nil,
		lastAttack = 0,
		lastHitBy = nil,
		nextWander = 0,
		farSince = nil,
		provoked = false,
	}
	mobs[model] = mob
	alive[id] = (alive[id] or 0) + 1
	hum.Died:Connect(function()
		CreatureService.onDeath(mob)
	end)
end

local function removeMob(mob: Mob)
	if mobs[mob.model] then
		mobs[mob.model] = nil
		alive[mob.id] = math.max(0, (alive[mob.id] or 1) - 1)
	end
	mob.model:Destroy()
end

function CreatureService.onDeath(mob: Mob)
	local def = Creatures[mob.id]
	local killer = mob.lastHitBy
	if killer and killer.Parent then
		local got = Rules.rollDrops(def.drops, function(a, b)
			return rng:NextInteger(a, b)
		end, function()
			return rng:NextNumber()
		end)
		for item, n in got do
			PlayerService.give(killer, item, n)
		end
		PlayerService.addXp(killer, def.xp)
		PlayerService.count(killer, "kill", 1)
		PlayerService.count(killer, "kill_" .. mob.id, 1)
	end
	fxEvent:FireAllClients({ kind = "creatureDie", pos = mob.root.Position })
	if mobs[mob.model] then
		mobs[mob.model] = nil
		alive[mob.id] = math.max(0, (alive[mob.id] or 1) - 1)
	end
	task.delay(1.2, function()
		mob.model:Destroy()
	end)
end

-- Dano a jogador considerando armadura e proteção pós-renascimento
function CreatureService.damagePlayer(player: Player, amount: number, from: Vector3?)
	local _, hum = charOf(player)
	local s = PlayerService.session(player)
	if not hum or not s or os.clock() < s.protectedUntil then
		return
	end
	local def = (player:GetAttribute("ArmorDefense") :: number?) or 0
	local dmg = amount * (1 - math.clamp(def, 0, 0.8))
	hum:TakeDamage(dmg)
	fxEvent:FireClient(player, { kind = "hurt", amount = math.floor(dmg), from = from })
end

-- Golpe do jogador em criaturas (qualquer ferramenta; armas causam dano cheio)
function CreatureService.tryHit(player: Player, itemDef: any): boolean
	local hrp = charOf(player)
	if not hrp then
		return false
	end
	local range = itemDef.range or 8
	local center = hrp.Position + hrp.CFrame.LookVector * (range * 0.5)
	local parts = workspace:GetPartBoundsInRadius(center, range * 0.75 + 1, overlap)
	local best: Mob? = nil
	local bestD = math.huge
	for _, p in parts do
		local m = p:FindFirstAncestorOfClass("Model")
		local mob = m and mobs[m]
		if mob and mob.hum.Health > 0 then
			local d = (mob.root.Position - hrp.Position).Magnitude
			if d < bestD and d <= range + Game.HIT_RANGE_TOLERANCE + 2 then
				best, bestD = mob, d
			end
		end
	end
	if not best then
		return false
	end
	local mob = best :: Mob
	local dmg = (itemDef.damage or 5) * (itemDef.toolType == "weapon" and 1 or 0.5)
	mob.hum:TakeDamage(dmg)
	mob.lastHitBy = player
	mob.provoked = true
	if Creatures[mob.id].behavior ~= "passive" then
		mob.target = player
		mob.state = "chase"
	else
		mob.state = "flee"
		mob.target = player
	end
	-- empurrão leve
	mob.root.AssemblyLinearVelocity += hrp.CFrame.LookVector * 30 + Vector3.new(0, 18, 0)
	fxEvent:FireAllClients({ kind = "creatureHit", pos = mob.root.Position, damage = math.floor(dmg) })
	return true
end

local function think(mob: Mob, now: number)
	local def = Creatures[mob.id]
	local pos = mob.root.Position
	local nearP, nearD = nearestPlayer(pos, ACTIVE_RANGE)
	if not nearP then
		mob.farSince = mob.farSince or now
		if now - (mob.farSince :: number) > 60 then
			removeMob(mob)
		end
		return
	end
	mob.farSince = nil

	-- Sombras fogem da luz das fogueiras e somem ao amanhecer
	if mob.id == "tide_shade" then
		if not Env.night then
			mob.hum:TakeDamage(mob.hum.MaxHealth * 0.2)
			return
		end
		if Env.isRepelled(pos) then
			mob.hum:TakeDamage(6)
			local away = (pos - (nearP.Character :: Model):GetPivot().Position).Unit
			mob.hum:MoveTo(pos + away * 20)
			return
		end
	end

	-- Escolha de alvo
	if def.behavior == "hostile" and nearD <= def.aggroRange then
		mob.target = nearP
		mob.state = "chase"
	elseif def.behavior == "passive" and nearD < def.aggroRange * 0.6 then
		mob.target = nearP
		mob.state = "flee"
	end

	local target = mob.target
	local thrp = target and charOf(target)
	if mob.state == "chase" and thrp then
		local d = (thrp.Position - pos).Magnitude
		if d > def.aggroRange * 2.2 or (mob.id == "tide_shade" and Env.isRepelled(thrp.Position)) then
			mob.state = "wander"
			mob.target = nil
			return
		end
		mob.hum.WalkSpeed = def.runSpeed
		if d <= def.attackRange then
			if now - mob.lastAttack >= def.attackCooldown and def.damage > 0 then
				mob.lastAttack = now
				CreatureService.damagePlayer(target :: Player, mob.model:GetAttribute("Damage") :: number, pos)
			end
		else
			mob.hum:MoveTo(thrp.Position)
		end
	elseif mob.state == "flee" and thrp then
		mob.hum.WalkSpeed = def.runSpeed
		local away = (pos - thrp.Position) * Vector3.new(1, 0, 1)
		if away.Magnitude > def.aggroRange * 1.5 then
			mob.state = "wander"
		else
			mob.hum:MoveTo(pos + away.Unit * 16)
		end
	else
		mob.state = "wander"
		mob.hum.WalkSpeed = def.walkSpeed
		if now >= mob.nextWander then
			mob.nextWander = now + rng:NextNumber(3, 7)
			local off = Vector3.new(rng:NextNumber(-25, 25), 0, rng:NextNumber(-25, 25))
			mob.hum:MoveTo(mob.home + off)
		end
	end
end

-- Mantém a população de cada espécie perto de jogadores
local function populate()
	for id, def in Creatures do
		local count = alive[id] or 0
		local cap = def.maxAlive
		if def.nightOnly then
			if not Env.night then
				cap = 0
			else
				cap = math.min(def.maxAlive + Env.nightCount, def.maxAlive * 2)
			end
		end
		if count < cap then
			-- escolhe um jogador numa das regiões da criatura e nasce perto (mas fora da vista imediata)
			for _, p in Players:GetPlayers() do
				local hrp = charOf(p)
				if hrp and count < cap then
					local region = Regions.at(hrp.Position)
					if table.find(def.regions, region.id) then
						local ang = rng:NextNumber(0, math.pi * 2)
						local dist = rng:NextNumber(45, 80)
						local x = hrp.Position.X + math.cos(ang) * dist
						local z = hrp.Position.Z + math.sin(ang) * dist
						local y = WorldService.GetGroundY(x, z)
						if region.id == "cave" then
							y = hrp.Position.Y
							x, z = hrp.Position.X + math.cos(ang) * 25, hrp.Position.Z + math.sin(ang) * 25
						end
						if y and y > 1.5 then
							local spot = Vector3.new(x, y, z)
							local inRegion = table.find(def.regions, Regions.at(spot).id) ~= nil
							if inRegion and not (def.nightOnly and Env.isRepelled(spot)) then
								spawnMob(id, spot)
								count += 1
							end
						end
					end
				end
			end
		end
	end
end

function CreatureService.init()
	local world = workspace:WaitForChild("World")
	folder = world:WaitForChild("Creatures") :: Folder
	overlap.FilterDescendantsInstances = { folder }

	task.spawn(function()
		while true do
			local now = os.clock()
			for _, mob in mobs do
				if mob.hum.Health > 0 then
					local ok, err = pcall(think, mob, now)
					if not ok then
						warn("[Creature] IA:", err)
						removeMob(mob)
					end
				end
			end
			task.wait(TICK)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(6)
			local ok, err = pcall(populate)
			if not ok then
				warn("[Creature] populate:", err)
			end
		end
	end)
end

return CreatureService
