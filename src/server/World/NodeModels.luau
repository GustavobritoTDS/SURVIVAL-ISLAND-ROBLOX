--!strict
-- Modelos low-poly dos nós de recurso, feitos só com Parts nativas.
-- Todo modelo é construído na origem com a base em Y=0; o pivô (via Hitbox.PivotOffset)
-- fica na base, então model:PivotTo(cframeNoChao) apoia o modelo no terreno.

local PartKit = require(script.Parent.PartKit)

local NodeModels = {}

local C = Color3.fromRGB
local M = Enum.Material
local TAU = math.pi * 2
local pick = PartKit.pick
local block, cyl, ball = PartKit.block, PartKit.cylinder, PartKit.ball

local GREYS = { C(122, 122, 128), C(108, 108, 114), C(136, 134, 132) }

-- Hitbox invisível que vira PrimaryPart; pivô do modelo = origem (base).
local function hitbox(model: Model, size: Vector3, cf: CFrame, collide: boolean)
	local hb = Instance.new("Part")
	hb.Name = "Hitbox"
	hb.Anchored = true
	hb.Transparency = 1
	hb.CanCollide = collide
	hb.CanQuery = true
	hb.CanTouch = false
	hb.CastShadow = false
	hb.Size = size
	hb.CFrame = cf
	hb.PivotOffset = cf:Inverse()
	hb.Parent = model
	model.PrimaryPart = hb
end

-- Folha arqueada: segmentos finos que vão inclinando para baixo e afinando (fronde de palmeira)
local function frond(
	model: Model,
	origin: Vector3,
	yaw: number,
	length: number,
	width: number,
	lift: number,
	col: Color3
)
	local segs = 4
	local pos = origin
	local pitch = lift -- começa subindo, depois cai
	for i = 1, segs do
		local segLen = length / segs
		local w = width * (1 - (i - 1) / (segs + 0.5))
		local rot = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
		local dir = rot.LookVector
		local center = pos + dir * (segLen / 2)
		-- lâmina central (fina e larga) com leve inclinação lateral, parecendo folíolos
		block({
			size = Vector3.new(w, 0.18, segLen + 0.25),
			cframe = CFrame.new(center) * rot * CFrame.Angles(0, 0, math.rad(8)),
			color = col:Lerp(Color3.new(0, 0, 0), (i - 1) * 0.04),
			material = M.Grass,
			parent = model,
			shadow = i <= 2,
		})
		pos = pos + dir * segLen
		pitch -= math.rad(24) -- curva para baixo
	end
end

local function palmTree(model: Model, rng: Random)
	local s = rng:NextNumber(0.85, 1.2)
	local h = rng:NextNumber(16, 22) * s
	local lean = rng:NextNumber(3, 6.5) * s
	local yaw = rng:NextNumber(0, TAU)
	local dx, dz = math.cos(yaw), math.sin(yaw)
	local rings = { C(150, 118, 84), C(122, 94, 68) }

	-- tronco curvado (curva quadrática), afinando, com anéis alternados
	local segs = 7
	local prev = Vector3.new(0, -0.8, 0)
	for i = 1, segs do
		local t = i / segs
		local p = Vector3.new(dx * lean * t * t, h * t, dz * lean * t * t)
		local tip = p + (p - prev).Unit * 0.35
		cyl(prev, tip, (2.1 - 0.85 * t) * s, rings[i % 2 + 1], M.Wood, model, i <= 3)
		prev = p
	end
	local top = prev
	-- base alargada
	cyl(Vector3.new(0, -0.8, 0), Vector3.new(0, 1.4 * s, 0), 2.7 * s, C(128, 98, 70), M.Wood, model)
	-- coroa
	ball(top + Vector3.new(0, 0.2, 0), 1.8 * s, C(96, 112, 52), M.Grass, model)

	-- frondes em arco ao redor da coroa
	local leafCols = { C(62, 150, 62), C(80, 165, 66), C(54, 132, 58), C(96, 172, 74) }
	local count = rng:NextInteger(7, 9)
	for k = 1, count do
		local fy = (k / count) * TAU + rng:NextNumber(-0.2, 0.2)
		frond(
			model,
			top + Vector3.new(0, 0.6 * s, 0),
			fy,
			rng:NextNumber(9, 12) * s,
			rng:NextNumber(2.2, 2.8) * s,
			math.rad(rng:NextNumber(18, 32)),
			pick(rng, leafCols)
		)
	end

	-- cocos agrupados sob a copa
	for i = 1, 3 do
		local a = i / 3 * TAU + rng:NextNumber(-0.3, 0.3)
		ball(
			top + Vector3.new(math.cos(a) * 0.8 * s, -0.9 * s, math.sin(a) * 0.8 * s),
			1.1 * s,
			C(104, 72, 42),
			M.SmoothPlastic,
			model
		)
	end

	local mid = Vector3.new(dx * lean / 2, (h + 2) / 2, dz * lean / 2)
	hitbox(model, Vector3.new(lean + 3 * s, h + 2, 3 * s), CFrame.new(mid) * CFrame.Angles(0, -yaw, 0), true)
end

-- Tufo de folhagem facetado: blocos girados sobrepostos (visual low-poly orgânico, não uma bola)
local function foliage(model: Model, rng: Random, center: Vector3, size: number, greens: { Color3 })
	for _ = 1, 3 do
		local off = Vector3.new(rng:NextNumber(-0.35, 0.35), rng:NextNumber(-0.2, 0.25), rng:NextNumber(-0.35, 0.35))
			* size
		local sz = Vector3.new(rng:NextNumber(0.75, 1.05), rng:NextNumber(0.5, 0.75), rng:NextNumber(0.75, 1.05)) * size
		block({
			size = sz,
			cframe = CFrame.new(center + off)
				* CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, TAU), rng:NextNumber(-0.5, 0.5)),
			color = pick(rng, greens),
			material = M.Grass,
			parent = model,
			shadow = true,
		})
	end
end

local function jungleTree(model: Model, rng: Random)
	local s = rng:NextNumber(0.85, 1.25)
	local h = rng:NextNumber(13, 18) * s
	local d = 2.4 * s
	local bark = { C(92, 68, 48), C(104, 78, 54), C(84, 62, 44) }
	local greens = { C(46, 122, 56), C(58, 138, 60), C(38, 108, 50), C(72, 148, 64) }

	-- raízes de apoio (sapopemas) saindo da base
	for i = 1, 4 do
		local a = i / 4 * TAU + rng:NextNumber(-0.3, 0.3)
		local foot = Vector3.new(math.cos(a) * 2.8 * s, -0.6, math.sin(a) * 2.8 * s)
		cyl(foot, Vector3.new(math.cos(a) * 0.4, 3.2 * s, math.sin(a) * 0.4), 1.0 * s, pick(rng, bark), M.Wood, model)
	end

	-- tronco em 3 segmentos levemente tortos, afinando
	local bend = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * 1.2 * s
	local p0 = Vector3.new(0, -0.8, 0)
	local p1 = Vector3.new(0, h * 0.4, 0) + bend * 0.5
	local p2 = Vector3.new(0, h * 0.75, 0) + bend
	local p3 = Vector3.new(0, h, 0) + bend * 0.6
	cyl(p0, p1, d * 1.15, pick(rng, bark), M.Wood, model, true)
	cyl(p1, p2, d, pick(rng, bark), M.Wood, model, true)
	cyl(p2, p3, d * 0.8, pick(rng, bark), M.Wood, model, true)

	-- galhos subindo para os lados, cada um terminando num tufo de folhas
	local nb = rng:NextInteger(3, 4)
	for i = 1, nb do
		local a = i / nb * TAU + rng:NextNumber(-0.4, 0.4)
		local from = p1:Lerp(p3, rng:NextNumber(0.45, 0.9))
		local reach = rng:NextNumber(4.5, 6.5) * s
		local to = from + Vector3.new(math.cos(a) * reach, rng:NextNumber(2.5, 4.5) * s, math.sin(a) * reach)
		cyl(from, to, 0.75 * s, pick(rng, bark), M.Wood, model)
		foliage(model, rng, to + Vector3.new(0, 0.8 * s, 0), rng:NextNumber(5.5, 7) * s, greens)
	end
	-- tufo central no topo
	foliage(model, rng, p3 + Vector3.new(0, 2 * s, 0), 8 * s, greens)

	-- cipós pendurados
	for _ = 1, 2 do
		local a = rng:NextNumber(0, TAU)
		local top = p3 + Vector3.new(math.cos(a) * 3.5 * s, 0, math.sin(a) * 3.5 * s)
		cyl(top, top - Vector3.new(0, rng:NextNumber(4, 7) * s, 0), 0.22 * s, C(70, 110, 50), M.Grass, model)
	end

	local hh = h + 7 * s
	hitbox(model, Vector3.new(d * 1.6 + 1, hh, d * 1.6 + 1), CFrame.new(0, hh / 2, 0), true)
end

local function fiberBush(model: Model, rng: Random)
	local s = rng:NextNumber(0.85, 1.2)
	local greens = { C(78, 150, 62), C(64, 132, 54), C(96, 166, 70) }
	local blobs: { { pos: Vector3, d: number } } = {}
	for i = 1, 4 do
		local a = i / 3 * TAU + rng:NextNumber(-0.4, 0.4)
		local rr = if i == 1 then 0 else 1.3 * s
		local d = rng:NextNumber(2.6, 3.6) * s
		local pos = Vector3.new(math.cos(a) * rr, d * 0.38, math.sin(a) * rr)
		ball(pos, d, pick(rng, greens), M.Grass, model)
		table.insert(blobs, { pos = pos, d = d })
	end
	local berries = { C(170, 40, 70), C(110, 60, 180), C(200, 50, 60) }
	for _ = 1, 5 do
		local b = blobs[rng:NextInteger(1, #blobs)]
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.2, 1), rng:NextNumber(-1, 1)).Unit
		ball(b.pos + dir * b.d * 0.48, 0.5 * s, pick(rng, berries), M.SmoothPlastic, model)
	end
	hitbox(model, Vector3.new(5.5, 3.6, 5.5) * s, CFrame.new(0, 1.8 * s, 0), false)
end

local function bananaPlant(model: Model, rng: Random)
	local s = rng:NextNumber(0.9, 1.2)
	local h = 5.5 * s
	cyl(Vector3.new(0, -0.5, 0), Vector3.new(0, h, 0), 1.0 * s, C(118, 140, 70), M.SmoothPlastic, model, true)
	cyl(Vector3.new(0, -0.5, 0), Vector3.new(0, h * 0.45, 0), 1.35 * s, C(104, 124, 62), M.SmoothPlastic, model)

	local leafCols = { C(92, 170, 70), C(80, 155, 62), C(110, 180, 80) }
	for k = 1, 6 do
		local yaw = k / 6 * TAU + rng:NextNumber(-0.3, 0.3)
		local rise = math.rad(rng:NextNumber(10, 35))
		local len = rng:NextNumber(5.5, 7) * s
		block({
			size = Vector3.new(0.15, 2 * s, len),
			cframe = CFrame.new(0, h, 0) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(rise, 0, 0) * CFrame.Angles(
				0,
				0,
				math.pi / 2
			) * CFrame.new(0, 0, -len / 2),
			color = pick(rng, leafCols),
			parent = model,
			shadow = true,
		})
	end

	-- cacho de bananas + coração (flor)
	local side = CFrame.new(0, h * 0.8, 0) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0) * CFrame.new(0, 0, -0.9 * s)
	for i = 1, 3 do
		block({
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(1.3, 0.55, 0.55) * s,
			cframe = side * CFrame.new(0, -i * 0.5 * s, 0) * CFrame.Angles(0, i * 1.1, 0.35),
			color = C(236, 206, 72),
			parent = model,
		})
	end
	ball((side * CFrame.new(0, -2.1 * s, 0)).Position, 0.8 * s, C(120, 40, 70), M.SmoothPlastic, model)

	hitbox(model, Vector3.new(4, h + 1.5, 4), CFrame.new(0, (h + 1.5) / 2, 0), false)
end

local function stickPile(model: Model, rng: Random)
	local s = rng:NextNumber(0.9, 1.15)
	local browns = { C(120, 85, 55), C(140, 100, 64), C(104, 74, 48) }
	for i = 1, 4 do
		local yaw = rng:NextNumber(0, TAU)
		local len = rng:NextNumber(3.2, 4.6) * s
		local c = Vector3.new(rng:NextNumber(-0.6, 0.6), 0.2 + i * 0.12, rng:NextNumber(-0.6, 0.6))
		local dir = Vector3.new(math.cos(yaw), rng:NextNumber(-0.06, 0.06), math.sin(yaw)).Unit
		cyl(c - dir * len / 2, c + dir * len / 2, rng:NextNumber(0.3, 0.42) * s, pick(rng, browns), M.Wood, model)
	end
	hitbox(model, Vector3.new(4.8, 1.4, 4.8) * s, CFrame.new(0, 0.7, 0), false)
end

local function looseStone(model: Model, rng: Random)
	local s = rng:NextNumber(0.9, 1.2)
	for _ = 1, 3 do
		local size = Vector3.new(rng:NextNumber(1.1, 1.7), rng:NextNumber(0.7, 1.1), rng:NextNumber(1, 1.5)) * s
		block({
			size = size,
			cframe = CFrame.new(rng:NextNumber(-1, 1), size.Y * 0.35, rng:NextNumber(-1, 1))
				* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, TAU), rng:NextNumber(-0.4, 0.4)),
			color = pick(rng, GREYS),
			material = M.Slate,
			parent = model,
		})
	end
	hitbox(model, Vector3.new(3.8, 1.6, 3.8) * s, CFrame.new(0, 0.8 * s, 0), false)
end

-- Bloco principal + 2 lascas. Retorna CFrame e tamanho do bloco principal.
local function rockCluster(model: Model, rng: Random, s: number, colors: { Color3 }): (CFrame, Vector3)
	local mainSize = Vector3.new(5.6, 4, 5) * s
	local mainCF = CFrame.new(0, 1.5 * s, 0)
		* CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, TAU), rng:NextNumber(-0.2, 0.2))
	block({
		size = mainSize,
		cframe = mainCF,
		color = pick(rng, colors),
		material = M.Slate,
		parent = model,
		shadow = true,
	})
	for _ = 1, 2 do
		local a = rng:NextNumber(0, TAU)
		local sz = Vector3.new(rng:NextNumber(2.6, 3.6), rng:NextNumber(1.8, 2.8), rng:NextNumber(2.4, 3.2)) * s
		block({
			size = sz,
			cframe = CFrame.new(math.cos(a) * 3 * s, sz.Y * 0.3, math.sin(a) * 3 * s)
				* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, TAU), rng:NextNumber(-0.3, 0.3)),
			color = pick(rng, colors),
			material = M.Slate,
			parent = model,
			shadow = true,
		})
	end
	return mainCF, mainSize
end

local function rock(model: Model, rng: Random)
	local s = rng:NextNumber(0.8, 1.25)
	rockCluster(model, rng, s, GREYS)
	hitbox(model, Vector3.new(8, 4.8, 8) * s, CFrame.new(0, 2.2 * s, 0), true)
end

local FACES = { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis, Vector3.yAxis }

local function ironRock(model: Model, rng: Random)
	local s = rng:NextNumber(0.85, 1.2)
	local mainCF, ms = rockCluster(model, rng, s, { C(104, 98, 96), C(92, 88, 88), C(116, 108, 104) })
	-- manchas cor de ferrugem coladas nas faces do bloco principal
	local rust = { C(176, 96, 52), C(150, 80, 45), C(190, 112, 60) }
	for _, nrm in FACES do
		local thin = 0.3
		local size = Vector3.new(
			if nrm.X ~= 0 then thin else rng:NextNumber(1.2, 2) * s,
			if nrm.Y ~= 0 then thin else rng:NextNumber(0.8, 1.4) * s,
			if nrm.Z ~= 0 then thin else rng:NextNumber(1.2, 2) * s
		)
		local jitter = Vector3.new(
			if nrm.X ~= 0 then 0 else rng:NextNumber(-0.25, 0.25) * ms.X,
			if nrm.Y ~= 0 then 0 else rng:NextNumber(-0.2, 0.2) * ms.Y,
			if nrm.Z ~= 0 then 0 else rng:NextNumber(-0.25, 0.25) * ms.Z
		)
		local offset = Vector3.new(nrm.X * (ms.X / 2 + 0.05), nrm.Y * (ms.Y / 2 + 0.05), nrm.Z * (ms.Z / 2 + 0.05))
		block({
			size = size,
			cframe = mainCF * CFrame.new(offset + jitter),
			color = pick(rng, rust),
			material = M.CorrodedMetal,
			parent = model,
		})
	end
	hitbox(model, Vector3.new(8, 4.8, 8) * s, CFrame.new(0, 2.2 * s, 0), true)
end

local function crystalNode(model: Model, rng: Random)
	local s = rng:NextNumber(0.85, 1.15)
	block({
		size = Vector3.new(3.6, 1.4, 3.4) * s,
		cframe = CFrame.new(0, 0.4 * s, 0) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0),
		color = C(70, 72, 82),
		material = M.Slate,
		parent = model,
	})
	local cols = { C(90, 220, 230), C(130, 240, 250), C(70, 190, 220) }
	for i = 1, 5 do
		local main = i == 1
		local len = (if main then 6 else rng:NextNumber(2.6, 4.6)) * s
		local w = (if main then 1.4 else rng:NextNumber(0.8, 1.1)) * s
		local tilt = if main then rng:NextNumber(-0.08, 0.08) else rng:NextNumber(0.3, 0.65)
		local glass = i % 2 == 0
		local shard = block({
			size = Vector3.new(w, len, w),
			cframe = CFrame.new(0, 0.6 * s, 0)
				* CFrame.Angles(0, i / 5 * TAU + rng:NextNumber(-0.3, 0.3), 0)
				* CFrame.Angles(tilt, 0, 0)
				* CFrame.new(0, len / 2, 0)
				* CFrame.Angles(0, math.pi / 4, 0),
			color = pick(rng, cols),
			material = if glass then M.Glass else M.Neon,
			transparency = if glass then 0.15 else 0,
			parent = model,
		})
		if main then
			PartKit.light(shard, C(110, 230, 240), 14, 1.6)
		end
	end
	hitbox(model, Vector3.new(5, 6.6 * s, 5), CFrame.new(0, 3.3 * s, 0), true)
end

local function obsidianRock(model: Model, rng: Random)
	local s = rng:NextNumber(0.85, 1.2)
	block({
		size = Vector3.new(4.2, 1.5, 4) * s,
		cframe = CFrame.new(0, 0.5 * s, 0) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0),
		color = C(40, 36, 42),
		material = M.Basalt,
		parent = model,
	})
	for i = 1, 3 do
		local len = rng:NextNumber(3, 4.5) * s
		block({
			size = Vector3.new(1.6, len, 1.3) * Vector3.new(s, 1, s),
			cframe = CFrame.new(0, 0.8 * s, 0)
				* CFrame.Angles(0, i / 3 * TAU + rng:NextNumber(-0.3, 0.3), 0)
				* CFrame.Angles(rng:NextNumber(0.15, 0.45), 0, 0)
				* CFrame.new(0, len / 2, 0)
				* CFrame.Angles(0, math.pi / 4, 0),
			color = if i == 2 then C(62, 34, 82) else C(32, 22, 44),
			material = M.Glass,
			reflectance = 0.3,
			parent = model,
		})
	end
	-- fenda brilhante roxa
	block({
		size = Vector3.new(2.6, 0.12, 0.25) * s,
		cframe = CFrame.new(0, 1.27 * s, 0) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0),
		color = C(150, 70, 210),
		material = M.Neon,
		parent = model,
	})
	hitbox(model, Vector3.new(5.4, 5, 5.4) * s, CFrame.new(0, 2.5 * s, 0), true)
end

local BUILDERS: { [string]: (Model, Random) -> () } = {
	palm_tree = palmTree,
	jungle_tree = jungleTree,
	fiber_bush = fiberBush,
	banana_plant = bananaPlant,
	stick_pile = stickPile,
	loose_stone = looseStone,
	rock = rock,
	iron_rock = ironRock,
	crystal_node = crystalNode,
	obsidian_rock = obsidianRock,
}

function NodeModels.build(nodeId: string, rng: Random?): Model
	local builder = BUILDERS[nodeId]
	assert(builder, "Nó sem modelo: " .. nodeId)
	local model = Instance.new("Model")
	model.Name = nodeId
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	builder(model, rng or Random.new())
	model:SetAttribute("NodeId", nodeId)
	return model
end

return NodeModels
