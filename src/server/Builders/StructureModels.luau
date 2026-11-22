--!strict
-- Visual das construções. Cada modelo tem PrimaryPart "Hitbox" com o tamanho definido em Structures.
-- Peças estruturais (piso/parede/porta/telhado) usam a própria hitbox como visual.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Structures = require(Shared.Config.Structures)

local StructureModels = {}

local C = Color3.fromRGB
local V = Vector3.new
local WOOD = C(150, 100, 58)
local DARKWOOD = C(105, 70, 40)
local STONE = C(135, 135, 140)
local LEAF = C(85, 150, 70)

local function part(
	model: Model,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	mat: Enum.Material,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = offset
	p.Color = color
	p.Material = mat
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = size.Magnitude > 3
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end

local function light(parent: BasePart, range: number, color: Color3, fire: boolean)
	local l = Instance.new("PointLight")
	l.Range = range
	l.Brightness = 2.2
	l.Color = color
	l.Shadows = range > 15
	l.Parent = parent
	if fire then
		local f = Instance.new("Fire")
		f.Size = 4
		f.Heat = 7
		f.Color = C(255, 140, 50)
		f.SecondaryColor = C(255, 220, 120)
		f.Parent = parent
	end
end

-- Constrói o modelo centrado na origem (Hitbox em CFrame.new())
function StructureModels.build(id: string): Model
	local def = Structures.defs[id]
	local model = Instance.new("Model")
	model.Name = id
	local hb = Instance.new("Part")
	hb.Name = "Hitbox"
	hb.Size = def.size
	hb.Anchored = true
	hb.CanCollide = true
	hb.Transparency = 1
	hb.CFrame = CFrame.new()
	hb.Parent = model
	model.PrimaryPart = hb
	local o = CFrame.new()
	local h = def.size.Y / 2

	if id == "wood_floor" or id == "wood_wall" then
		hb.Transparency = 0
		hb.Material = Enum.Material.WoodPlanks
		hb.Color = WOOD
		-- travessas
		local beamSize = id == "wood_wall" and V(8.1, 0.5, 1.15) or V(8.1, 1.1, 0.6)
		part(
			model,
			beamSize,
			o * CFrame.new(0, id == "wood_wall" and 2.5 or 0, id == "wood_wall" and 0 or 3.7),
			DARKWOOD,
			Enum.Material.Wood
		)
		part(
			model,
			beamSize,
			o * CFrame.new(0, id == "wood_wall" and -2.5 or 0, id == "wood_wall" and 0 or -3.7),
			DARKWOOD,
			Enum.Material.Wood
		)
	elseif id == "stone_floor" or id == "stone_wall" then
		hb.Transparency = 0
		hb.Material = Enum.Material.Cobblestone
		hb.Color = STONE
	elseif id == "leaf_roof" then
		hb.Transparency = 0
		hb.Material = Enum.Material.Grass
		hb.Color = LEAF
		for i = -1, 1 do
			part(
				model,
				V(8.3, 0.4, 2.2),
				o * CFrame.new(0, 0.55, i * 2.7) * CFrame.Angles(math.rad(8), 0, 0),
				C(110, 165, 75),
				Enum.Material.Grass
			)
		end
	elseif id == "wood_door" then
		hb.Transparency = 1
		hb.CanCollide = false
		local panel = part(model, V(4, 7.6, 0.6), o * CFrame.new(0, -0.2, 0), C(130, 85, 48), Enum.Material.WoodPlanks)
		panel.Name = "DoorPanel"
		panel.CanCollide = true
		part(model, V(2, 8, 1), o * CFrame.new(-3, 0, 0), WOOD, Enum.Material.WoodPlanks).CanCollide = true
		part(model, V(2, 8, 1), o * CFrame.new(3, 0, 0), WOOD, Enum.Material.WoodPlanks).CanCollide = true
		local knob = part(
			model,
			V(0.4, 0.4, 0.9),
			o * CFrame.new(1.4, -0.4, 0),
			C(60, 60, 60),
			Enum.Material.Metal,
			Enum.PartType.Ball
		)
		knob.Name = "Knob"
	elseif id == "campfire" then
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			part(
				model,
				V(1.2, 0.9, 1.2),
				o * CFrame.new(math.cos(a) * 2, -h + 0.45, math.sin(a) * 2),
				STONE,
				Enum.Material.Slate,
				Enum.PartType.Ball
			)
		end
		for i = 0, 2 do
			part(
				model,
				V(0.5, 0.5, 3.2),
				o * CFrame.new(0, -h + 0.5, 0) * CFrame.Angles(0, i * math.pi / 3, 0),
				DARKWOOD,
				Enum.Material.Wood
			)
		end
		local core = part(model, V(0.5, 0.5, 0.5), o * CFrame.new(0, -h + 0.9, 0), C(255, 140, 50), Enum.Material.Neon)
		core.Name = "FireCore"
		core.Transparency = 0.5
		light(core, 26, C(255, 160, 80), true)
	elseif id == "workbench" then
		part(model, V(7, 0.6, 4), o * CFrame.new(0, h - 0.8, 0), WOOD, Enum.Material.WoodPlanks)
		for _, x in { -3, 3 } do
			for _, z in { -1.6, 1.6 } do
				part(model, V(0.6, 3.2, 0.6), o * CFrame.new(x, -0.4, z), DARKWOOD, Enum.Material.Wood)
			end
		end
		part(model, V(1.6, 0.4, 0.8), o * CFrame.new(-1.5, h - 0.3, 0.6), STONE, Enum.Material.Slate)
		part(
			model,
			V(0.3, 0.3, 2),
			o * CFrame.new(1.8, h - 0.35, -0.3) * CFrame.Angles(0, 0.4, 0),
			DARKWOOD,
			Enum.Material.Wood
		)
	elseif id == "forge" then
		part(model, V(6, 4.5, 6), o * CFrame.new(0, -0.75, 0), C(110, 105, 100), Enum.Material.Cobblestone)
		part(model, V(2.5, 2.5, 2), o * CFrame.new(0, h - 1.2, 0), C(90, 85, 80), Enum.Material.Cobblestone)
		local mouth = part(model, V(2.4, 1.6, 0.4), o * CFrame.new(0, -1.2, -3), C(255, 120, 40), Enum.Material.Neon)
		light(mouth, 14, C(255, 130, 60), true)
	elseif id == "chest" then
		part(model, V(4, 2, 3), o * CFrame.new(0, -0.5, 0), C(140, 92, 50), Enum.Material.WoodPlanks)
		part(model, V(4.1, 1, 3.1), o * CFrame.new(0, 1, 0), C(120, 78, 42), Enum.Material.WoodPlanks)
		part(model, V(4.15, 0.3, 3.15), o * CFrame.new(0, 0.5, 0), C(80, 80, 85), Enum.Material.Metal)
		part(model, V(0.6, 0.6, 0.2), o * CFrame.new(0, 0.5, -1.6), C(220, 190, 90), Enum.Material.Metal)
	elseif id == "leaf_bed" then
		part(model, V(4, 0.6, 7), o * CFrame.new(0, -0.45, 0), DARKWOOD, Enum.Material.Wood)
		part(model, V(3.6, 0.6, 6.6), o * CFrame.new(0, 0.15, 0), LEAF, Enum.Material.Grass)
		part(model, V(2.6, 0.5, 1.4), o * CFrame.new(0, 0.6, 2.4), C(230, 220, 190), Enum.Material.Fabric)
	elseif id == "rain_collector" then
		part(
			model,
			V(2.4, 3.2, 3.2),
			o * CFrame.new(0, -h + 1.2, 0) * CFrame.Angles(0, 0, math.pi / 2),
			WOOD,
			Enum.Material.WoodPlanks,
			Enum.PartType.Cylinder
		)
		local water = part(
			model,
			V(0.2, 2.8, 2.8),
			o * CFrame.new(0, -h + 2.3, 0) * CFrame.Angles(0, 0, math.pi / 2),
			C(80, 170, 240),
			Enum.Material.Glass,
			Enum.PartType.Cylinder
		)
		water.Name = "Water"
		water.Transparency = 0.3
		part(
			model,
			V(4.4, 0.3, 4.4),
			o * CFrame.new(0, h - 0.4, 0) * CFrame.Angles(0, math.rad(45), math.rad(12)),
			LEAF,
			Enum.Material.Grass
		)
		for _, x in { -1.8, 1.8 } do
			part(model, V(0.3, 3, 0.3), o * CFrame.new(x, 0.9, 0), DARKWOOD, Enum.Material.Wood)
		end
	elseif id == "torch_post" then
		part(model, V(0.6, 6.4, 0.6), o * CFrame.new(0, -0.3, 0), DARKWOOD, Enum.Material.Wood)
		local head = part(model, V(1, 0.8, 1), o * CFrame.new(0, h - 0.4, 0), C(90, 60, 35), Enum.Material.Fabric)
		light(head, 20, C(255, 170, 90), true)
	elseif id == "base_totem" then
		local colors = { C(200, 160, 90), C(170, 120, 70), C(210, 90, 60) }
		for i = 0, 2 do
			part(
				model,
				V(2.6, 2.8, 2.6),
				o * CFrame.new(0, -h + 1.4 + i * 2.9, 0) * CFrame.Angles(0, i * 0.4, 0),
				colors[i + 1],
				Enum.Material.Wood
			)
			part(
				model,
				V(0.5, 0.5, 0.2),
				o * CFrame.new(-0.6, -h + 1.8 + i * 2.9, -1.35),
				C(20, 20, 20),
				Enum.Material.Neon
			)
			part(
				model,
				V(0.5, 0.5, 0.2),
				o * CFrame.new(0.6, -h + 1.8 + i * 2.9, -1.35),
				C(20, 20, 20),
				Enum.Material.Neon
			)
		end
		part(model, V(5, 0.5, 1), o * CFrame.new(0, h - 0.6, 0), C(240, 200, 110), Enum.Material.Wood)
	elseif id == "rescue_beacon" then
		for i = 0, 5 do
			local w = 9 - i * 1.1
			part(
				model,
				V(w, 4.5, w),
				o * CFrame.new(0, -h + 2.25 + i * 4.5, 0),
				i % 2 == 0 and C(235, 230, 220) or C(200, 60, 50),
				Enum.Material.Concrete
			)
		end
		local lamp = part(model, V(3.5, 3, 3.5), o * CFrame.new(0, h - 1.5, 0), C(255, 230, 140), Enum.Material.Glass)
		lamp.Name = "Lamp"
		lamp.Transparency = 0.3
	end
	model:SetAttribute("StructureId", id)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	return model
end

return StructureModels
