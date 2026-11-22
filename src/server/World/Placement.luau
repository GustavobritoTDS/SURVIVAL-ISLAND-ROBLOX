--!strict
-- Posicionamento determinístico dos nós de recurso e pontos de chão para criaturas.
-- Usa Random.new(Regions.WORLD_SEED) e percorre os nós em ordem alfabética,
-- então o resultado é sempre o mesmo para o mesmo terreno.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Nodes = require(ReplicatedStorage.Shared.Config.Nodes)
local Regions = require(ReplicatedStorage.Shared.Config.Regions)
local Ground = require(script.Parent.Ground)
local TerrainGen = require(script.Parent.TerrainGen)

local Placement = {}

export type NodeSpawn = { nodeId: string, cframe: CFrame }
export type Exclusion = { pos: Vector3, r: number }

local M = Enum.Material
local TAU = math.pi * 2
local SPAWN = Regions.SPAWN
local MIN_DRY_Y = 1.5
local CELL = 10 -- célula da grade espacial (>= maior espaçamento)

local function set(list: { Enum.Material }): { [Enum.Material]: boolean }
	local s = {}
	for _, m in list do
		s[m] = true
	end
	return s
end

-- Materiais aceitos por região (evita palmeira em basalto etc.). nil = qualquer.
local REGION_MATS: { [string]: { [Enum.Material]: boolean } } = {
	beach = set({ M.Sand, M.Grass, M.LeafyGrass, M.Ground }),
	jungle = set({ M.Grass, M.LeafyGrass, M.Ground, M.Mud, M.Sand }),
	highlands = set({ M.Rock, M.Slate, M.Ground, M.Grass }),
}
local MIN_NORMAL_Y: { [string]: number } = { cave = 0.7, volcano = 0.65 }
local SPACING: { [string]: number } = { palm_tree = 8, jungle_tree = 9, rock = 8, iron_rock = 8 }

-- Parte dos nós sorteada perto do spawn (primeiro loop do jogador).
local NEAR_SPAWN: { [string]: { share: number, radius: number } } = {
	stick_pile = { share = 0.4, radius = 110 },
	loose_stone = { share = 0.4, radius = 110 },
	palm_tree = { share = 0.3, radius = 220 },
	fiber_bush = { share = 0.2, radius = 180 },
	banana_plant = { share = 0.15, radius = 200 },
}

local function disc(rng: Random, cx: number, cz: number, radius: number): (number, number)
	local r = radius * math.sqrt(rng:NextNumber())
	local a = rng:NextNumber(0, TAU)
	return cx + math.cos(a) * r, cz + math.sin(a) * r
end

local function flatDist(a: Vector3, b: Vector3): number
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- Sorteia (x, z, yInicial, profundidade) do raio para a região.
-- forNodes: no vulcão, nós ficam só no fundo da cratera.
local function candidate(regionId: string, rng: Random, forNodes: boolean): (number, number, number, number)
	if regionId == "cave" then
		local cave = TerrainGen.CAVE
		if rng:NextNumber() < 0.8 then
			local x, z = disc(rng, cave.center.X, cave.center.Z, 22)
			return x, z, cave.floorY + 22, 30
		end
		-- trecho do túnel já dentro da região da caverna
		local p = cave.tunnel[2]:Lerp(cave.tunnel[3], rng:NextNumber(0.15, 1))
		return p.X + rng:NextNumber(-4, 4), p.Z, p.Y + 2, 14
	elseif regionId == "volcano" then
		local v = TerrainGen.VOLCANO
		if forNodes then
			local a, rr = rng:NextNumber(0, TAU), rng:NextNumber(v.lavaR + 3, v.floorR)
			return v.x + math.cos(a) * rr, v.z + math.sin(a) * rr, 220, 200
		end
		local x, z = disc(rng, v.x, v.z, Regions.byId.volcano.radius)
		return x, z, 260, 260
	end
	local reg = Regions.byId[regionId]
	assert(reg, "Região desconhecida: " .. regionId)
	local cx, cz, radius = reg.center.X, reg.center.Z, reg.radius
	if regionId == "beach" then
		cx, cz, radius = 0, 0, Regions.ISLAND_RADIUS + 40
	end
	local x, z = disc(rng, cx, cz, radius)
	return x, z, 400, 520
end

-- Chão seco, pouco inclinado, na região certa e com material compatível.
local function validGround(hit: Ground.Hit, regionId: string): boolean
	if hit.position.Y <= MIN_DRY_Y or hit.normal.Y < (MIN_NORMAL_Y[regionId] or 0.8) then
		return false
	end
	local mats = REGION_MATS[regionId]
	if mats and not mats[hit.material] then
		return false
	end
	return Regions.at(hit.position).id == regionId
end

local function cellKey(cx: number, cz: number): number
	return (cx + 2048) * 4096 + (cz + 2048)
end

type Grid = { [number]: { { pos: Vector3, sp: number } } }

local function spaced(grid: Grid, pos: Vector3, sp: number): boolean
	local cx, cz = math.floor(pos.X / CELL), math.floor(pos.Z / CELL)
	for i = cx - 1, cx + 1 do
		for k = cz - 1, cz + 1 do
			local bucket = grid[cellKey(i, k)]
			if bucket then
				for _, e in bucket do
					if (e.pos - pos).Magnitude < math.max(sp, e.sp) then
						return false
					end
				end
			end
		end
	end
	return true
end

local function addToGrid(grid: Grid, pos: Vector3, sp: number)
	local key = cellKey(math.floor(pos.X / CELL), math.floor(pos.Z / CELL))
	local bucket = grid[key]
	if not bucket then
		bucket = {}
		grid[key] = bucket
	end
	table.insert(bucket, { pos = pos, sp = sp })
end

local function excluded(ex: { Exclusion }, pos: Vector3): boolean
	for _, e in ex do
		if flatDist(e.pos, pos) < e.r then
			return true
		end
	end
	return false
end

function Placement.computeNodeSpawns(ex: { Exclusion }): { NodeSpawn }
	local rng = Random.new(Regions.WORLD_SEED)
	local ids: { string } = {}
	for id in Nodes do
		table.insert(ids, id)
	end
	table.sort(ids)

	local out: { NodeSpawn } = {}
	local grid: Grid = {}
	for _, id in ids do
		local def = Nodes[id]
		local sp = SPACING[id] or 6
		local minSpawnDist = if def.harvest == "tool" then 25 else 8
		local near = NEAR_SPAWN[id]
		local nearTarget = if near then math.ceil(def.count * near.share) else 0
		local placed, tries = 0, 0
		while placed < def.count and tries < def.count * 80 do
			tries += 1
			local x, z, fromY, depth
			if near and placed < nearTarget and tries < def.count * 40 then
				x, z = disc(rng, SPAWN.X, SPAWN.Z, near.radius)
				fromY, depth = 400, 520
			else
				x, z, fromY, depth = candidate(def.region, rng, true)
			end
			local hit = Ground.castDry(x, z, fromY, depth)
			if
				hit
				and validGround(hit, def.region)
				and flatDist(hit.position, SPAWN) > minSpawnDist
				and not excluded(ex, hit.position)
				and spaced(grid, hit.position, sp)
			then
				addToGrid(grid, hit.position, sp)
				placed += 1
				table.insert(out, {
					nodeId = id,
					cframe = CFrame.new(hit.position) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0),
				})
			end
		end
		if placed < def.count then
			warn(string.format("[WorldService] %s: %d/%d posições encontradas", id, placed, def.count))
		end
	end
	return out
end

function Placement.randomGroundPoint(regionId: string, rng: Random): Vector3?
	for _ = 1, 20 do
		local x, z, fromY, depth = candidate(regionId, rng, false)
		local hit = Ground.castDry(x, z, fromY, depth)
		if hit and validGround(hit, regionId) then
			return hit.position
		end
	end
	return nil
end

return Placement
