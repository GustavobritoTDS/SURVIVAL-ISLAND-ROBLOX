--!strict
-- Decoração da ilha (workspace.World.Decor): naufrágio, placas das regiões, lagos,
-- cristais da caverna, cratera do vulcão, pedras, flora, conchas e troncos.
-- Tudo Anchored, sem colisão, sombras só em peças grandes. Orçamento ~2000 Parts.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Regions = require(ReplicatedStorage.Shared.Config.Regions)
local Ground = require(script.Parent.Ground)
local PartKit = require(script.Parent.PartKit)
local TerrainGen = require(script.Parent.TerrainGen)

local Decor = {}

export type Exclusion = { pos: Vector3, r: number }

local C = Color3.fromRGB
local M = Enum.Material
local TAU = math.pi * 2
local pick = PartKit.pick
local block, wedge, cyl, ball = PartKit.block, PartKit.wedge, PartKit.cylinder, PartKit.ball
local SPAWN = Regions.SPAWN

local WOOD = { C(112, 80, 54), C(96, 66, 44), C(128, 92, 60) }
local GREYS = { C(122, 122, 128), C(108, 108, 114), C(140, 138, 134) }

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function disc(rng: Random, cx: number, cz: number, radius: number): (number, number)
	local r = radius * math.sqrt(rng:NextNumber())
	local a = rng:NextNumber(0, TAU)
	return cx + math.cos(a) * r, cz + math.sin(a) * r
end

local function flatDist(a: Vector3, b: Vector3): number
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function groundAt(x: number, z: number, fallback: number): Vector3
	return Vector3.new(x, Ground.groundY(x, z) or fallback, z)
end

----------------------------------------------------------------------------------------
-- Naufrágio
----------------------------------------------------------------------------------------

local function crate(parent: Instance, pos: Vector3, size: number, yaw: number, tilt: number)
	local cf = CFrame.new(pos) * CFrame.Angles(tilt, yaw, tilt * 0.5)
	block({
		size = Vector3.one * size,
		cframe = cf,
		color = C(152, 112, 70),
		material = M.WoodPlanks,
		parent = parent,
		shadow = true,
	})
	for _, y in { -0.3, 0.3 } do
		block({
			size = Vector3.new(size + 0.12, 0.35, size + 0.12),
			cframe = cf * CFrame.new(0, y * size, 0),
			color = C(92, 64, 42),
			material = M.Wood,
			parent = parent,
		})
	end
end

local function barrel(parent: Instance, pos: Vector3, yaw: number, standing: boolean)
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	if standing then
		cf *= CFrame.Angles(0, 0, math.pi / 2)
	end
	local cylShape = Enum.PartType.Cylinder
	block({
		shape = cylShape,
		size = Vector3.new(3, 2.2, 2.2),
		cframe = cf,
		color = C(122, 82, 50),
		material = M.Wood,
		parent = parent,
	})
	for _, x in { -1, 1 } do
		block({
			shape = cylShape,
			size = Vector3.new(0.25, 2.35, 2.35),
			cframe = cf * CFrame.new(x, 0, 0),
			color = C(70, 66, 62),
			material = M.CorrodedMetal,
			parent = parent,
		})
	end
end

-- Casco inclinado, mastro quebrado, velas rasgadas, caixotes, barris e tábuas.
local function buildShipwreck(parent: Instance, rng: Random): Vector3
	local ax, az = SPAWN.X + 46, SPAWN.Z + 50
	local anchor = groundAt(ax, az, 4)
	local ship = CFrame.new(anchor - Vector3.new(0, 1.2, 0))
		* CFrame.Angles(0, math.rad(-35), 0)
		* CFrame.Angles(math.rad(3), 0, math.rad(-16))
	local hull = Instance.new("Model")
	hull.Name = "Hull"
	hull.Parent = parent

	local function plank(size: Vector3, cf: CFrame, col: Color3?)
		block({
			size = size,
			cframe = ship * cf,
			color = col or pick(rng, WOOD),
			material = M.WoodPlanks,
			parent = hull,
			shadow = true,
		})
	end

	plank(Vector3.new(1.4, 1.4, 38), CFrame.new(0, 0.7, 0), C(80, 56, 38)) -- quilha
	for _, sx in { -1, 1 } do
		plank(Vector3.new(5.5, 0.7, 36), CFrame.new(sx * 2.4, 2.3, 0) * CFrame.Angles(0, 0, sx * math.rad(35)))
		for j = 0, 2 do
			local x, y, len = sx * (4.9 + j * 0.25), 4 + j * 1.9, 34 - j * 2
			local cf = CFrame.new(x, y, 0) * CFrame.Angles(0, 0, sx * math.rad(-8))
			if sx == -1 and j >= 1 then
				-- rombo no costado (lado virado para cima)
				plank(Vector3.new(0.7, 2, len * 0.34), cf * CFrame.new(0, 0, -len * 0.33))
				plank(Vector3.new(0.7, 2, len * 0.3), cf * CFrame.new(0, 0, len * 0.35))
			else
				plank(Vector3.new(0.7, 2, len), cf)
			end
		end
		-- proa convergindo
		local c = Vector3.new(sx * 2.45, 5.5, -20.75)
		plank(Vector3.new(0.7, 6, 9), CFrame.lookAt(c, c + Vector3.new(-sx * 4.9, 0, -7.5)))
	end
	cyl(ship * Vector3.new(0, 1, -24.5), ship * Vector3.new(0, 9.5, -25.6), 1, C(80, 56, 38), M.Wood, hull, true)
	plank(Vector3.new(10.5, 6.5, 0.7), CFrame.new(0, 5, 17.5)) -- popa

	-- convés com tábuas faltando
	for z = -12, 14, 2.3 do
		if rng:NextNumber() > 0.3 then
			plank(Vector3.new(9.2, 0.4, 2), CFrame.new(0, 8.2, z) * CFrame.Angles(0, 0, rng:NextNumber(-0.05, 0.05)))
		end
	end
	-- costelas expostas no rombo
	for i = 0, 3 do
		plank(
			Vector3.new(0.5, 7, 0.5),
			CFrame.new(-5.6, 5, -4 + i * 3) * CFrame.Angles(0, 0, math.rad(10)),
			C(86, 60, 40)
		)
	end

	-- mastro quebrado e vela rasgada pendurada
	local mastTop = ship * Vector3.new(0.5, 15, -2.4)
	cyl(ship * Vector3.new(0, 1, -3), mastTop, 1.6, C(104, 76, 50), M.Wood, hull, true)
	wedge({
		size = Vector3.new(1.6, 1.4, 1.6),
		cframe = CFrame.new(mastTop + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0),
		color = C(104, 76, 50),
		material = M.Wood,
		parent = hull,
	})
	wedge({
		size = Vector3.new(0.12, 5.5, 4),
		cframe = ship * CFrame.new(1.3, 11.5, -2.4) * CFrame.Angles(0.15, 0.3, 0.1),
		color = C(226, 216, 190),
		material = M.Fabric,
		parent = hull,
		shadow = true,
	})
	-- cordas do mastro ao costado
	for _, sx in { -1, 1 } do
		cyl(mastTop - Vector3.new(0, 1, 0), ship * Vector3.new(sx * 5, 8, 6), 0.2, C(170, 150, 110), M.Fabric, hull)
	end

	-- parte de cima do mastro caída na areia, com verga e vela
	local m0 = groundAt((ship * Vector3.new(-9, 0, -4)).X, (ship * Vector3.new(-9, 0, -4)).Z, anchor.Y)
	local far = ship * Vector3.new(-22, 0, -14)
	local m1 = groundAt(far.X, far.Z, anchor.Y)
	local up = Vector3.new(0, 0.6, 0)
	cyl(m0 + up, m1 + up, 1.3, C(104, 76, 50), M.Wood, parent, true)
	local along = (m1 - m0).Unit
	local perp = along:Cross(Vector3.yAxis).Unit
	local mid = m0:Lerp(m1, 0.4) + Vector3.new(0, 1.1, 0)
	cyl(mid - perp * 6, mid + perp * 6, 0.7, C(96, 70, 46), M.Wood, parent)
	local sailPos = mid + along * 3.6 - Vector3.new(0, 0.85, 0)
	block({
		size = Vector3.new(11, 0.15, 6),
		cframe = CFrame.lookAt(sailPos, sailPos + along) * CFrame.Angles(0, 0, 0.06),
		color = C(222, 212, 186),
		material = M.Fabric,
		parent = parent,
		shadow = true,
	})
	wedge({
		size = Vector3.new(0.15, 4, 5),
		cframe = ship * CFrame.new(-3, 8.6, 9) * CFrame.Angles(0, 0, math.pi / 2) * CFrame.Angles(0.2, 0.4, 0),
		color = C(206, 196, 170),
		material = M.Fabric,
		parent = hull,
	})

	-- caixotes (alguns empilhados), barris e tábuas soltas
	local crates = { { -14, 6 }, { -10, 12 }, { 12, -14 }, { 16, 10 }, { -4, 18 }, { 20, -2 }, { -18, -8 } }
	for i, o in crates do
		local size = rng:NextNumber(2.6, 3.6)
		local p = groundAt(ax + o[1], az + o[2], anchor.Y)
		crate(parent, p + Vector3.new(0, size / 2 - 0.4, 0), size, rng:NextNumber(0, TAU), rng:NextNumber(-0.12, 0.12))
		if i == 2 then
			crate(parent, p + Vector3.new(0.3, size * 1.45 - 0.4, 0.2), size * 0.8, rng:NextNumber(0, TAU), 0)
		end
	end
	local barrels = { { 9, 14 }, { -16, 2 }, { 6, -18 }, { 22, 6 } }
	for i, o in barrels do
		local standing = i == 3
		local p = groundAt(ax + o[1], az + o[2], anchor.Y)
		barrel(parent, p + Vector3.new(0, if standing then 1.3 else 0.95, 0), rng:NextNumber(0, TAU), standing)
	end
	for _ = 1, 8 do
		local x, z = disc(rng, ax, az, 28)
		local p = groundAt(x, z, anchor.Y)
		block({
			size = Vector3.new(1, 0.3, rng:NextNumber(4, 7)),
			cframe = CFrame.new(p + Vector3.new(0, 0.12, 0))
				* CFrame.Angles(0, rng:NextNumber(0, TAU), rng:NextNumber(-0.1, 0.1)),
			color = pick(rng, WOOD),
			material = M.Wood,
			parent = parent,
		})
	end
	return anchor
end

----------------------------------------------------------------------------------------
-- Placas das regiões
----------------------------------------------------------------------------------------

local function signText(gui: SurfaceGui, region: Regions.Region)
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.04, 0.06)
	title.Size = UDim2.fromScale(0.92, 0.5)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = C(255, 244, 220)
	title.TextStrokeColor3 = C(60, 40, 25)
	title.TextStrokeTransparency = 0.3
	title.Text = region.name
	title.Parent = gui

	local danger = math.clamp(region.danger, 0, 5)
	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromScale(0.04, 0.6)
	sub.Size = UDim2.fromScale(0.92, 0.32)
	sub.Font = Enum.Font.GothamBold
	sub.TextScaled = true
	sub.TextColor3 = region.color:Lerp(Color3.new(1, 1, 1), 0.35)
	sub.TextStrokeColor3 = C(40, 28, 18)
	sub.TextStrokeTransparency = 0.3
	sub.Text = string.format(
		"Nível %d+   Perigo %s%s",
		region.level,
		string.rep("★", danger),
		string.rep("☆", 5 - danger)
	)
	sub.Parent = gui
end

local function makeSign(parent: Instance, at: Vector2, viewer: Vector2, region: Regions.Region): Vector3
	local gy = Ground.groundY(at.X, at.Y) or 5
	local pos = Vector3.new(at.X, gy, at.Y)
	local base = CFrame.lookAt(pos, Vector3.new(viewer.X, gy, viewer.Y)) -- frente (-Z) para o leitor
	local model = Instance.new("Model")
	model.Name = "Sign_" .. region.id
	local dark, light = C(95, 66, 42), C(150, 108, 68)
	for _, sx in { -1, 1 } do
		block({
			size = Vector3.new(0.6, 8, 0.6),
			cframe = base * CFrame.new(sx * 3.1, 2, 0),
			color = dark,
			material = M.Wood,
			parent = model,
			shadow = true,
		})
	end
	local board = block({
		size = Vector3.new(7.4, 3.4, 0.45),
		cframe = base * CFrame.new(0, 4.3, 0),
		color = light,
		material = M.WoodPlanks,
		parent = model,
		shadow = true,
		name = "Board",
	})
	block({
		size = Vector3.new(8, 0.4, 0.8),
		cframe = base * CFrame.new(0, 6.15, 0),
		color = dark,
		material = M.Wood,
		parent = model,
	})
	block({
		size = Vector3.new(7.4, 0.35, 0.5),
		cframe = base * CFrame.new(0, 2.45, 0),
		color = region.color,
		parent = model,
	})
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0.6
		gui.MaxDistance = 140
		signText(gui, region)
		gui.Parent = board
	end
	model:SetAttribute("Region", region.id)
	model.Parent = parent
	return pos
end

local function buildSigns(parent: Instance, ex: { Exclusion })
	local function v2(v: Vector3): Vector2
		return Vector2.new(v.X, v.Z)
	end
	local spawn2 = v2(SPAWN)
	local hc, jc, vc =
		v2(Regions.byId.highlands.center), v2(Regions.byId.jungle.center), v2(Regions.byId.volcano.center)
	local dirH = (jc - hc).Unit
	local hPos = hc + dirH * (Regions.byId.highlands.radius + 10)
	local dirV = (Vector2.zero - vc).Unit
	local vPos = vc + dirV * 145
	local mouth = TerrainGen.CAVE.tunnel[1]
	local jungleEdge = jc.Y + Regions.byId.jungle.radius

	local spots: { { id: string, at: Vector2, viewer: Vector2 } } = {
		{ id = "beach", at = spawn2 + Vector2.new(-16, -10), viewer = spawn2 },
		{ id = "jungle", at = Vector2.new(spawn2.X + 12, jungleEdge - 6), viewer = spawn2 },
		{ id = "highlands", at = hPos, viewer = hPos + dirH * 12 },
		{ id = "volcano", at = vPos, viewer = vPos + dirV * 12 },
		{ id = "cave", at = Vector2.new(mouth.X + 13, mouth.Z - 4), viewer = Vector2.new(mouth.X, mouth.Z - 30) },
	}
	for _, s in spots do
		local pos = makeSign(parent, s.at, s.viewer, Regions.byId[s.id])
		table.insert(ex, { pos = pos, r = 5 })
	end
end

----------------------------------------------------------------------------------------
-- Lagos de água doce (PondPrompt + juncos + vitórias-régias)
----------------------------------------------------------------------------------------

local function buildLakes(parent: Instance, fresh: Instance, rng: Random, ex: { Exclusion })
	for _, lake in TerrainGen.LAKES do
		local f = folder(lake.name, parent)
		local px, pz = lake.x + lake.promptDir.X * (lake.r + 3), lake.z + lake.promptDir.Z * (lake.r + 3)
		local gy = Ground.groundY(px, pz) or (lake.surface + 1)

		local prompt = Instance.new("Part")
		prompt.Name = "PondPrompt"
		prompt.Anchored = true
		prompt.CanCollide = false
		prompt.CanTouch = false
		prompt.CanQuery = false
		prompt.Transparency = 1
		prompt.CastShadow = false
		prompt.Size = Vector3.new(6, 5, 6)
		prompt.CFrame = CFrame.new(px, gy + 2.5, pz)
		prompt:SetAttribute("LakeName", lake.name)
		CollectionService:AddTag(prompt, "FreshWater")
		prompt.Parent = fresh
		table.insert(ex, { pos = Vector3.new(lake.x, 0, lake.z), r = lake.r + 8 })

		-- juncos na margem
		for _ = 1, 12 do
			local a = rng:NextNumber(0, TAU)
			local rr = lake.r + rng:NextNumber(-1, 2.5)
			local x, z = lake.x + math.cos(a) * rr, lake.z + math.sin(a) * rr
			local y = Ground.groundY(x, z)
			if y and y > lake.surface - 1.5 then
				local h = rng:NextNumber(2.5, 4.5)
				local cf = CFrame.new(x, y + h / 2 - 0.3, z)
					* CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.15, 0.15))
				block({ size = Vector3.new(0.22, h, 0.22), cframe = cf, color = C(96, 128, 60), parent = f })
				if rng:NextNumber() < 0.5 then
					block({
						size = Vector3.new(0.4, 0.9, 0.4),
						cframe = cf * CFrame.new(0, h / 2 - 0.3, 0),
						color = C(110, 72, 44),
						parent = f,
					})
				end
			end
		end
		-- vitórias-régias
		for i = 1, 6 do
			local x, z = disc(rng, lake.x, lake.z, lake.r * 0.7)
			local y = Ground.groundY(x, z)
			if y and y < lake.surface - 0.5 then
				local d = rng:NextNumber(1.8, 2.8)
				local pos = Vector3.new(x, lake.surface + 0.05, z)
				block({
					shape = Enum.PartType.Cylinder,
					size = Vector3.new(0.15, d, d),
					cframe = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2),
					color = C(72, 150, 70),
					parent = f,
				})
				if i <= 2 then
					ball(pos + Vector3.new(0, 0.3, 0), 0.6, C(240, 140, 190), M.SmoothPlastic, f)
				end
			end
		end
	end
end

----------------------------------------------------------------------------------------
-- Caverna de Cristal e Cratera do Vulcão
----------------------------------------------------------------------------------------

local CRYSTAL_COLS = { C(90, 220, 230), C(150, 110, 240), C(120, 240, 250) }

local function crystalCluster(parent: Instance, pos: Vector3, up: Vector3, rng: Random, light: boolean)
	local base = PartKit.alignUp(pos - up * 0.4, up, rng:NextNumber(0, TAU))
	local col = pick(rng, CRYSTAL_COLS)
	for i = 1, 2 do
		local len, w = rng:NextNumber(1.8, 3.8), rng:NextNumber(0.5, 0.9)
		local shard = block({
			size = Vector3.new(w, len, w),
			cframe = base
				* CFrame.Angles(rng:NextNumber(-0.5, 0.5), 0, rng:NextNumber(-0.5, 0.5))
				* CFrame.new(0, len / 2, 0)
				* CFrame.Angles(0, math.pi / 4, 0),
			color = col,
			material = if i == 1 then M.Neon else M.Glass,
			transparency = if i == 1 then 0 else 0.2,
			parent = parent,
		})
		if light and i == 1 then
			PartKit.light(shard, col, 16, 1.3)
		end
	end
end

local function buildCave(parent: Instance, rng: Random)
	local cave = TerrainGen.CAVE
	local placed, lit = 0, 0
	for _ = 1, 140 do
		if placed >= 28 then
			break
		end
		local hit = Ground.ray(cave.center, rng:NextUnitVector() * 50)
		-- prefere paredes e teto (deixa o chão para os nós de cristal)
		if hit and (hit.Normal.Y < 0.6 or rng:NextNumber() < 0.2) then
			local light = lit < 6 and placed % 4 == 0
			crystalCluster(parent, hit.Position, hit.Normal, rng, light)
			placed += 1
			if light then
				lit += 1
			end
		end
	end
	-- cristais-guia ao longo do túnel
	local t = cave.tunnel
	for i = 1, 8 do
		local seg = if i <= 4 then 1 else 2
		local p = t[seg]:Lerp(t[seg + 1], ((i - 1) % 4 + 0.5) / 4)
		local side = if i % 2 == 0 then 1 else -1
		local hit = Ground.ray(p, Vector3.new(side * 14, rng:NextNumber(-2, 4), rng:NextNumber(-2, 2)))
		if hit then
			crystalCluster(parent, hit.Position, hit.Normal, rng, i % 2 == 1)
		end
	end
end

local function buildVolcano(parent: Instance, rng: Random)
	local v = TerrainGen.VOLCANO
	local gy = Ground.groundY(v.x, v.z) or v.floorY
	local lava = block({
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.5, v.lavaR * 2 - 1, v.lavaR * 2 - 1),
		cframe = CFrame.new(v.x, gy + 0.35, v.z) * CFrame.Angles(0, 0, math.pi / 2),
		color = C(255, 96, 28),
		material = M.Neon,
		parent = parent,
		name = "LavaPool",
	})
	PartKit.light(lava, C(255, 120, 40), 50, 3)
	local fire = Instance.new("Fire")
	fire.Size = 14
	fire.Heat = 14
	fire.Color = C(255, 120, 30)
	fire.SecondaryColor = C(255, 60, 20)
	fire.Parent = lava

	local smokePart = block({
		size = Vector3.new(2, 2, 2),
		cframe = CFrame.new(v.x, gy + 34, v.z),
		color = C(0, 0, 0),
		transparency = 1,
		parent = parent,
		name = "SmokeEmitter",
	})
	local smoke = Instance.new("Smoke")
	smoke.Size = 40
	smoke.Opacity = 0.12
	smoke.RiseVelocity = 12
	smoke.Color = C(90, 85, 85)
	smoke.Parent = smokePart

	-- brasas no fundo da cratera
	for _ = 1, 8 do
		local a = rng:NextNumber(0, TAU)
		local rr = rng:NextNumber(v.lavaR + 1, v.floorR)
		local x, z = v.x + math.cos(a) * rr, v.z + math.sin(a) * rr
		local y = Ground.groundY(x, z)
		if y then
			block({
				size = Vector3.new(rng:NextNumber(0.8, 1.6), rng:NextNumber(0.4, 0.8), rng:NextNumber(0.8, 1.6)),
				cframe = CFrame.new(x, y + 0.2, z) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0),
				color = C(255, 110, 40),
				material = M.Neon,
				parent = parent,
			})
		end
	end
end

----------------------------------------------------------------------------------------
-- Espalhados: pedras, samambaias, flores, conchas, estrelas-do-mar, troncos
----------------------------------------------------------------------------------------

local GRASSY: { [Enum.Material]: boolean } = { [M.Grass] = true, [M.LeafyGrass] = true }

-- Tenta `tries` pontos na ilha; chama build(hit) quando accept(hit) até `count` acertos.
local function scatter(
	rng: Random,
	count: number,
	tries: number,
	accept: (Ground.Hit) -> boolean,
	build: (Ground.Hit) -> ()
)
	local placed = 0
	for _ = 1, tries do
		if placed >= count then
			return
		end
		local x, z = disc(rng, 0, 0, Regions.ISLAND_RADIUS + 20)
		local hit = Ground.castDry(x, z)
		if hit and hit.position.Y > 1.2 and flatDist(hit.position, SPAWN) > 10 and accept(hit) then
			build(hit)
			placed += 1
		end
	end
end

local function scatterRocks(parent: Instance, rng: Random)
	scatter(rng, 130, 700, function(hit)
		return hit.normal.Y > 0.7
	end, function(hit)
		local volcanic = hit.material == M.Basalt or hit.material == M.CrackedLava
		local col = if volcanic
			then C(48, 44, 48)
			elseif hit.material == M.Sand then C(170, 160, 140)
			else pick(rng, GREYS)
		local n = if rng:NextNumber() < 0.5 then 2 else 1
		for i = 1, n do
			local s = rng:NextNumber(0.6, 2.2) / i
			local off = if i == 1 then Vector3.zero else Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2))
			block({
				size = Vector3.new(rng:NextNumber(1.2, 2), rng:NextNumber(0.8, 1.4), rng:NextNumber(1.1, 1.8)) * s,
				cframe = CFrame.new(hit.position + off + Vector3.new(0, 0.25 * s, 0))
					* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, TAU), rng:NextNumber(-0.4, 0.4)),
				color = col,
				material = if volcanic then M.Basalt else M.Slate,
				parent = parent,
				shadow = s > 1.4,
			})
		end
	end)
end

local function fern(parent: Instance, pos: Vector3, rng: Random)
	local s = rng:NextNumber(0.8, 1.4)
	local col = pick(rng, { C(58, 128, 52), C(74, 146, 60), C(48, 112, 46) })
	for k = 1, 4 do
		local len, w = 2.6 * s, 0.9 * s
		wedge({
			size = Vector3.new(0.1, w, len),
			cframe = CFrame.new(pos) * CFrame.Angles(0, k / 4 * TAU + rng:NextNumber(-0.3, 0.3), 0) * CFrame.Angles(
				math.rad(rng:NextNumber(25, 45)),
				0,
				0
			) * CFrame.Angles(0, 0, math.pi / 2) * CFrame.new(0, w / 2, -len / 2),
			color = col,
			parent = parent,
		})
	end
end

local FLOWER_COLS = { C(240, 90, 120), C(250, 210, 70), C(245, 245, 240), C(250, 130, 60), C(190, 110, 230) }

local function flowerPatch(parent: Instance, pos: Vector3, rng: Random)
	local col = pick(rng, FLOWER_COLS)
	for _ = 1, rng:NextInteger(1, 3) do
		local p = pos + Vector3.new(rng:NextNumber(-1.2, 1.2), 0, rng:NextNumber(-1.2, 1.2))
		local h = rng:NextNumber(0.8, 1.5)
		block({
			size = Vector3.new(0.15, h, 0.15),
			cframe = CFrame.new(p + Vector3.new(0, h / 2 - 0.1, 0)),
			color = C(70, 140, 60),
			parent = parent,
		})
		ball(p + Vector3.new(0, h, 0), 0.7, col, M.SmoothPlastic, parent)
	end
end

local function scatterFlora(parent: Instance, rng: Random)
	local ferns, flowers = folder("Ferns", parent), folder("Flowers", parent)
	scatter(rng, 160, 900, function(hit)
		return GRASSY[hit.material] == true and hit.normal.Y > 0.75 and Regions.at(hit.position).id == "jungle"
	end, function(hit)
		fern(ferns, hit.position - Vector3.new(0, 0.1, 0), rng)
	end)
	task.wait()
	scatter(rng, 150, 900, function(hit)
		return GRASSY[hit.material] == true and hit.normal.Y > 0.8
	end, function(hit)
		flowerPatch(flowers, hit.position, rng)
	end)
end

local function starfish(parent: Instance, pos: Vector3, rng: Random)
	local cf = CFrame.new(pos + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0)
	local col = pick(rng, { C(240, 120, 70), C(230, 90, 90), C(250, 170, 80) })
	for k = 1, 5 do
		block({
			size = Vector3.new(0.25, 0.12, 0.9),
			cframe = cf * CFrame.Angles(0, k / 5 * TAU, 0) * CFrame.new(0, 0, -0.45),
			color = col,
			parent = parent,
		})
	end
end

local function scatterBeach(parent: Instance, rng: Random)
	local shells, logs = folder("Shells", parent), folder("Driftwood", parent)
	local shellCols = { C(250, 236, 220), C(240, 200, 190), C(230, 214, 170), C(250, 220, 200) }
	local wet = function(hit: Ground.Hit): boolean
		return hit.material == M.Sand and hit.position.Y < 4.8
	end
	scatter(rng, 135, 2500, wet, function(hit)
		if rng:NextNumber() < 0.11 then
			starfish(shells, hit.position, rng)
			return
		end
		wedge({
			size = Vector3.new(0.5, 0.25, 0.6) * rng:NextNumber(0.8, 1.4),
			cframe = CFrame.new(hit.position + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0),
			color = pick(rng, shellCols),
			parent = shells,
		})
	end)
	scatter(rng, 22, 1500, wet, function(hit)
		local yaw = rng:NextNumber(0, TAU)
		local len = rng:NextNumber(4, 8)
		local dir = Vector3.new(math.cos(yaw), 0, math.sin(yaw))
		local c = hit.position + Vector3.new(0, 0.3, 0)
		cyl(c - dir * len / 2, c + dir * len / 2, rng:NextNumber(0.6, 0.9), C(166, 142, 112), M.Wood, logs)
	end)
end

----------------------------------------------------------------------------------------

-- Constrói toda a decoração. Retorna zonas a evitar ao posicionar nós.
function Decor.build(decor: Instance, fresh: Instance, onProgress: (number) -> ()): { Exclusion }
	local rng = Random.new(Regions.WORLD_SEED + 77)
	local ex: { Exclusion } = {}

	local wreck = buildShipwreck(folder("Shipwreck", decor), rng)
	table.insert(ex, { pos = wreck, r = 30 })
	onProgress(0.1)
	buildSigns(folder("Signs", decor), ex)
	onProgress(0.2)
	buildLakes(folder("Lakes", decor), fresh, rng, ex)
	onProgress(0.3)
	buildCave(folder("Cave", decor), rng)
	buildVolcano(folder("Volcano", decor), rng)
	onProgress(0.4)
	task.wait()
	scatterRocks(folder("Rocks", decor), rng)
	onProgress(0.55)
	task.wait()
	scatterFlora(folder("Flora", decor), rng)
	onProgress(0.8)
	task.wait()
	scatterBeach(folder("Beach", decor), rng)
	onProgress(1)
	return ex
end

return Decor
