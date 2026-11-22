--!strict
--!native
-- Terreno procedural da ilha: campo de altura determinístico (math.noise + WORLD_SEED),
-- escrito com Terrain:WriteVoxels em chunks de 64 studs (resolução 4).
-- Contém: praia larga ao sul, selva no centro, planalto ao norte/noroeste,
-- vulcão com cratera a nordeste, caverna escavada sob o planalto e 3 lagos de água doce.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Regions = require(ReplicatedStorage.Shared.Config.Regions)

local TerrainGen = {}

local RES = 4
local CHUNK = 64
local CELLS = CHUNK // RES
local HALF = 832 -- oceano de 1664 x 1664 studs
local Y_MIN = -32
local SEA_FLOOR = -30
local ISLAND_R = Regions.ISLAND_RADIUS
local YIELD_BUDGET = 0.025 -- segundos de trabalho antes de ceder o frame

local SEED = Regions.WORLD_SEED
local OX = (SEED % 997) * 0.7313 + 0.123
local OZ = (SEED % 991) * 0.5171 + 0.457

local M = Enum.Material
local AIR, WATER, SLATE = M.Air, M.Water, M.Slate
local C = Color3.fromRGB

-- Zonas: decidem o material da superfície.
local Z_BEACH, Z_JUNGLE, Z_HIGH, Z_VOLC, Z_CRATER, Z_LAVA, Z_LAKE, Z_SHORE = 1, 2, 3, 4, 5, 6, 7, 8

local HC = Regions.byId.highlands.center
local CC = Regions.byId.cave.center
local VC = Regions.byId.volcano.center

local VOLCANO = {
	x = VC.X,
	z = VC.Z,
	baseR = 230, -- raio da base do cone
	craterR = 46, -- borda da cratera
	floorR = 28, -- fundo plano da cratera
	lavaR = 12, -- poça de lava central
	floorY = 116,
	rimY = 148,
}
TerrainGen.VOLCANO = VOLCANO

local function smooth(e0: number, e1: number, x: number): number
	local t = math.clamp((x - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)
end

local function n2(x: number, z: number, scale: number, salt: number): number
	return math.noise(x / scale + OX + salt * 3.17, z / scale + OZ - salt * 1.73, 0.5 + salt * 0.37)
end

local function dist(x: number, z: number, cx: number, cz: number): number
	local dx, dz = x - cx, z - cz
	return math.sqrt(dx * dx + dz * dz)
end

-- Raio da costa na direção (ux, uz): ruído angular, mais suave ao sul (praia do spawn).
local function coastRadius(ux: number, uz: number): number
	local n = math.noise(ux * 1.7 + OX, uz * 1.7 + OZ, 3.3) * 70 + math.noise(ux * 5.3 + OX, uz * 5.3 + OZ, 7.7) * 22
	local south = math.max(0, uz)
	return ISLAND_R - 10 + n * (1 - 0.75 * south * south * south)
end

-- Degraus suaves (mesas do planalto).
local function terrace(h: number): number
	local step = 7
	local t = h / step
	local fl = math.floor(t)
	return step * (fl + smooth(0.3, 0.7, t - fl))
end

local function volcanoHeight(x: number, z: number, dv: number): number
	if dv >= VOLCANO.baseR then
		return -math.huge
	end
	if dv < VOLCANO.craterR then
		return VOLCANO.floorY + (VOLCANO.rimY - VOLCANO.floorY) * smooth(VOLCANO.floorR, VOLCANO.craterR, dv)
	end
	local k = (VOLCANO.baseR - dv) / (VOLCANO.baseR - VOLCANO.craterR)
	return VOLCANO.rimY * k ^ 1.5 + n2(x, z, 30, 7) * 8 * smooth(VOLCANO.craterR, 80, dv)
end

-- Altura da superfície sem lagos. Retorna (altura, zona).
local function sampleBase(x: number, z: number): (number, number)
	local r = math.sqrt(x * x + z * z)
	if r > ISLAND_R + 220 then
		return SEA_FLOOR, Z_BEACH
	end
	local ux, uz = 0, 1
	if r > 1 then
		ux, uz = x / r, z / r
	end

	-- costa: rampa submersa até o fundo do mar e praia plana
	local d = coastRadius(ux, uz) - r
	local h: number
	if d < 0 then
		h = 1 - 31 * smooth(0, 80, -d)
	else
		h = 1 + 4.5 * smooth(0, 40, d)
	end

	-- interior (selva): colinas suaves; a praia é mais larga ao sul
	local south = math.max(0, uz)
	local beachW = 60 + 95 * south * south
	local f = smooth(beachW, beachW + 140, d)
	if f > 0 then
		h += (13 + 9 * (n2(x, z, 170, 1) + 0.5 * n2(x, z, 70, 2))) * f
	end

	-- planalto de pedra
	local hm = smooth(215, 120, dist(x, z, HC.X, HC.Z) + n2(x, z, 90, 3) * 40)
	if hm > 0 then
		local p = 66 + 22 * n2(x, z, 140, 4) + 9 * (1 - 2 * math.abs(n2(x, z, 55, 5)))
		h += (terrace(p) - h) * hm
	end

	-- domo de rocha sobre a caverna (garante teto grosso, superfície >= 58)
	local cm = smooth(122, 86, dist(x, z, CC.X, CC.Z))
	if cm > 0 then
		local dome = 64 + 6 * n2(x, z, 40, 6)
		if dome > h then
			h += (dome - h) * cm
		end
	end

	-- vulcão
	local dv = dist(x, z, VOLCANO.x, VOLCANO.z)
	local hv = volcanoHeight(x, z, dv)
	if hv > h then
		h = hv
		if dv < VOLCANO.lavaR then
			return h, Z_LAVA
		elseif dv < VOLCANO.craterR then
			return h, Z_CRATER
		end
		return h, Z_VOLC
	end

	if math.max(hm, cm) > 0.45 then
		return h, Z_HIGH
	elseif h < 7.5 + 2 * n2(x, z, 40, 9) and f < 0.3 then
		return h, Z_BEACH
	end
	return h, Z_JUNGLE
end

export type Lake = {
	name: string,
	x: number,
	z: number,
	r: number,
	rim: number,
	depth: number,
	salt: number,
	surface: number,
	promptDir: Vector3, -- lado da margem onde fica o PondPrompt
}

local LAKES: { Lake } = {
	{
		name = "Lagoa da Selva",
		x = -60,
		z = 290,
		r = 22,
		rim = 16,
		depth = 6,
		salt = 11,
		surface = 0,
		promptDir = Vector3.new(60, 0, 140).Unit, -- virado para o spawn
	},
	{
		name = "Lago do Planalto",
		x = -150,
		z = -200,
		r = 26,
		rim = 18,
		depth = 7,
		salt = 12,
		surface = 0,
		promptDir = Vector3.new(0.3, 0, 1).Unit,
	},
	{
		name = "Poço da Caverna",
		x = 110,
		z = -380,
		r = 18,
		rim = 16,
		depth = 5,
		salt = 13,
		surface = 0,
		promptDir = Vector3.new(-70, 0, -36).Unit, -- virado para a boca do túnel
	},
}
-- Nível da água alinhado à grade de voxels (água ocupa células inteiras).
for _, lake in LAKES do
	local base = sampleBase(lake.x, lake.z)
	lake.surface = 4 * math.floor((base - 2) / 4)
end
TerrainGen.LAKES = LAKES

-- Altura final com lagos. Retorna (altura, zona, nível da água da coluna).
local function sample(x: number, z: number): (number, number, number)
	local h, zone = sampleBase(x, z)
	local water = 0
	for _, lake in LAKES do
		local dx, dz = x - lake.x, z - lake.z
		local reach = lake.r + lake.rim
		if dx * dx + dz * dz < (reach + 4) ^ 2 then
			local dl = math.sqrt(dx * dx + dz * dz) + n2(x, z, 12, lake.salt) * 3
			local shore = lake.surface + 1.5
			if dl < lake.r then
				h = shore - (lake.depth + 1.5) * smooth(lake.r, lake.r * 0.5, dl)
				zone = Z_LAKE
				water = lake.surface
			elseif dl < reach then
				local hh = shore + (h - shore) * smooth(lake.r, reach, dl)
				if dl < lake.r + lake.rim * 0.6 then
					hh = math.max(hh, lake.surface + 1) -- borda sempre fecha o lago
				end
				h = hh
				if dl < lake.r + 5 then
					zone = Z_SHORE
				end
			end
		end
	end
	return h, zone, water
end
TerrainGen.sample = sample

-- Caverna de Cristal: câmara elipsoidal + túnel vindo da encosta norte.
local ENTRANCE_Z = CC.Z - 166
local CAVE = {
	center = Vector3.new(CC.X, 20, CC.Z),
	radii = Vector3.new(34, 22, 34), -- teto máximo ~44.6 (< 45)
	floorY = 6,
	tunnelR = 8,
	tunnel = {
		Vector3.new(CC.X, sampleBase(CC.X, ENTRANCE_Z) + 3.5, ENTRANCE_Z),
		Vector3.new(CC.X, 14, CC.Z - 80),
		Vector3.new(CC.X, 11, CC.Z - 22),
	},
}
TerrainGen.CAVE = CAVE

local BOX_MIN_X, BOX_MAX_X = CC.X - 46, CC.X + 46
local BOX_MIN_Z, BOX_MAX_Z = ENTRANCE_Z - 14, CC.Z + 46
local BOX_MAX_Y = math.max(CAVE.tunnel[1].Y, CAVE.center.Y + 26) + 12

-- Fração sólida restante após escavar o túnel (segmento a-b).
local function tunnelSolid(px: number, py: number, pz: number, y0: number, a: Vector3, b: Vector3): number
	local abx, aby, abz = b.X - a.X, b.Y - a.Y, b.Z - a.Z
	local t = ((px - a.X) * abx + (py - a.Y) * aby + (pz - a.Z) * abz) / (abx * abx + aby * aby + abz * abz)
	t = math.clamp(t, 0, 1)
	local cx, cy, cz = a.X + abx * t, a.Y + aby * t, a.Z + abz * t
	local d = math.sqrt((px - cx) ^ 2 + (py - cy) ^ 2 + (pz - cz) ^ 2)
	local radius = CAVE.tunnelR + math.noise(px / 9 + OX, py / 9, pz / 9 + OZ) * 2
	local wall = math.clamp((d - radius) / RES + 0.5, 0, 1)
	local floor = math.clamp((cy - 3.5 - y0) / RES, 0, 1)
	return math.max(wall, floor)
end

-- Fração sólida de uma célula considerando câmara e túnel (1 = intocada).
local function caveSolid(px: number, yc: number, pz: number, y0: number): number
	local c, rr = CAVE.center, CAVE.radii
	local wob = 1 + 0.12 * math.noise(px / 14 + OX, yc / 14, pz / 14 + OZ)
	local dx, dy, dz = (px - c.X) / (rr.X * wob), (yc - c.Y) / (rr.Y * wob), (pz - c.Z) / (rr.Z * wob)
	local q = math.sqrt(dx * dx + dy * dy + dz * dz)
	local s = math.max(math.clamp((q - 1) * rr.Y / RES + 0.5, 0, 1), math.clamp((CAVE.floorY - y0) / RES, 0, 1))
	local tun = CAVE.tunnel
	for i = 1, #tun - 1 do
		s = math.min(s, tunnelSolid(px, yc, pz, y0, tun[i], tun[i + 1]))
	end
	return s
end

-- Materiais (superfície, subsolo) por zona e declive.
local function pickMaterials(zone: number, slope: number, x: number, z: number): (Enum.Material, Enum.Material)
	if zone == Z_BEACH then
		return M.Sand, M.Sandstone
	elseif zone == Z_JUNGLE then
		if slope > 1.1 then
			return M.Rock, M.Rock
		elseif slope > 0.75 then
			return M.Ground, M.Rock
		end
		return (if n2(x, z, 45, 12) > 0.02 then M.LeafyGrass else M.Grass), M.Rock
	elseif zone == Z_HIGH then
		if slope > 0.9 then
			return M.Slate, M.Rock
		end
		local p = n2(x, z, 38, 13)
		if p > 0.3 then
			return M.Ground, M.Rock
		elseif p < -0.32 then
			return M.Grass, M.Rock
		end
		return M.Rock, M.Rock
	elseif zone == Z_VOLC then
		if math.abs(n2(x, z, 28, 14)) < 0.035 then
			return M.CrackedLava, M.Basalt -- veios de lava escorrendo
		end
		return M.Basalt, M.Basalt
	elseif zone == Z_CRATER then
		return M.Basalt, M.Basalt
	elseif zone == Z_LAVA then
		return M.CrackedLava, M.Basalt
	elseif zone == Z_LAKE then
		return M.Mud, M.Rock
	elseif zone == Z_SHORE then
		return M.Ground, M.Rock
	end
	return M.Grass, M.Rock
end

local function writeChunk(terrain: Terrain, x0: number, z0: number)
	-- alturas com 1 célula de borda (para o declive)
	local W = CELLS + 2
	local hs: { number } = table.create(W * W, 0)
	local zs: { number } = table.create(W * W, 0)
	local ws: { number } = table.create(W * W, 0)
	local maxH = 0
	for i = 0, CELLS + 1 do
		local x = x0 + (i - 0.5) * RES
		for k = 0, CELLS + 1 do
			local h, zone, water = sample(x, z0 + (k - 0.5) * RES)
			local idx = i * W + k + 1
			hs[idx], zs[idx], ws[idx] = h, zone, water
			if h > maxH then
				maxH = h
			end
		end
	end

	local yMax = math.max(4, math.ceil((maxH + 2) / RES) * RES)
	local ny = (yMax - Y_MIN) // RES
	local inCave = x0 < BOX_MAX_X and x0 + CHUNK > BOX_MIN_X and z0 < BOX_MAX_Z and z0 + CHUNK > BOX_MIN_Z

	local mats: { { { Enum.Material } } } = table.create(CELLS)
	local occs: { { { number } } } = table.create(CELLS)
	for i = 1, CELLS do
		local x = x0 + (i - 0.5) * RES
		local mi: { { Enum.Material } } = table.create(ny)
		local oi: { { number } } = table.create(ny)
		for j = 1, ny do
			mi[j] = table.create(CELLS, AIR)
			oi[j] = table.create(CELLS, 0)
		end
		mats[i], occs[i] = mi, oi

		for k = 1, CELLS do
			local z = z0 + (k - 0.5) * RES
			local idx = i * W + k + 1
			local h, water = hs[idx], ws[idx]
			local sx = (hs[idx + W] - hs[idx - W]) / (2 * RES)
			local sz = (hs[idx + 1] - hs[idx - 1]) / (2 * RES)
			local surf, sub = pickMaterials(zs[idx], math.sqrt(sx * sx + sz * sz), x, z)
			local caveCol = inCave and x > BOX_MIN_X and x < BOX_MAX_X and z > BOX_MIN_Z and z < BOX_MAX_Z

			for j = 1, ny do
				local y0 = Y_MIN + (j - 1) * RES
				local yc = y0 + RES / 2
				if y0 >= h and yc >= water then
					break -- só ar daqui para cima
				end
				local occ = math.clamp((h - y0) / RES, 0, 1)
				local carved = false
				if caveCol and yc > 0 and yc < BOX_MAX_Y then
					local cs = caveSolid(x, yc, z, y0)
					if cs < occ then
						occ, carved = cs, true
					end
				end
				if occ > 0 and (occ >= 0.5 or yc >= water) then
					mi[j][k] = if carved then SLATE elseif h - yc > 5 then sub else surf
					oi[j][k] = occ
				elseif yc < water then
					mi[j][k] = WATER
					oi[j][k] = 1
				end
			end
		end
	end

	local region = Region3.new(Vector3.new(x0, Y_MIN, z0), Vector3.new(x0 + CHUNK, yMax, z0 + CHUNK))
	terrain:WriteVoxels(region, RES, mats, occs)
end

-- Cores tropicais dos materiais e da água.
local function applyLook(terrain: Terrain)
	terrain.WaterColor = C(28, 150, 168)
	terrain.WaterTransparency = 0.55
	terrain.WaterReflectance = 0.5
	terrain.WaterWaveSize = 0.12
	terrain.WaterWaveSpeed = 9
	local colors: { [Enum.Material]: Color3 } = {
		[M.Sand] = C(234, 214, 160),
		[M.Sandstone] = C(196, 166, 118),
		[M.Grass] = C(98, 162, 72),
		[M.LeafyGrass] = C(72, 134, 58),
		[M.Ground] = C(118, 96, 70),
		[M.Mud] = C(88, 74, 56),
		[M.Rock] = C(132, 130, 126),
		[M.Slate] = C(98, 98, 106),
		[M.Basalt] = C(46, 42, 46),
	}
	for mat, col in colors do
		terrain:SetMaterialColor(mat, col)
	end
end

-- Gera todo o terreno. onProgress recebe 0..1. Cede o frame entre chunks.
function TerrainGen.generate(onProgress: (number) -> ())
	local terrain = workspace.Terrain
	terrain:Clear()
	applyLook(terrain)
	local per = (2 * HALF) // CHUNK
	local total = per * per
	local done = 0
	local last = os.clock()
	for cx = 0, per - 1 do
		for cz = 0, per - 1 do
			writeChunk(terrain, -HALF + cx * CHUNK, -HALF + cz * CHUNK)
			done += 1
			if os.clock() - last > YIELD_BUDGET then
				onProgress(done / total)
				task.wait()
				last = os.clock()
			end
		end
	end
	onProgress(1)
end

return TerrainGen
