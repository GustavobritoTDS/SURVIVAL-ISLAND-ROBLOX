--!strict
-- Modelos low-poly das criaturas, montados com Parts soldadas ao HumanoidRootPart.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)

local CreatureModels = {}

type Spec = {
	size: Vector3,
	offset: Vector3,
	color: Color3?,
	material: Enum.Material?,
	shape: Enum.PartType?,
	transparency: number?,
	neon: boolean?,
	name: string?,
}

local function build(id: string, rootSize: Vector3, hip: number, specs: { Spec }): Model
	local def = Creatures[id]
	local s = def.scale
	local model = Instance.new("Model")
	model.Name = def.name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = rootSize * s
	root.Transparency = 1
	root.CanCollide = true
	root.Parent = model
	model.PrimaryPart = root
	for _, sp in specs do
		local p = Instance.new("Part")
		p.Name = sp.name or "Body"
		p.Size = sp.size * s
		p.Color = sp.color or def.color
		p.Material = sp.neon and Enum.Material.Neon or (sp.material or Enum.Material.SmoothPlastic)
		p.Transparency = sp.transparency or 0
		if sp.shape then
			p.Shape = sp.shape
		end
		p.CanCollide = false
		p.CanQuery = true
		p.Massless = true
		p.CastShadow = sp.size.Magnitude > 2
		p.CFrame = root.CFrame * CFrame.new(sp.offset * s)
		local w = Instance.new("WeldConstraint")
		w.Part0 = root
		w.Part1 = p
		w.Parent = p
		p.Parent = model
	end
	local hum = Instance.new("Humanoid")
	hum.HipHeight = hip * s
	hum.MaxHealth = def.health
	hum.Health = def.health
	hum.WalkSpeed = def.walkSpeed
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.BreakJointsOnDeath = false
	hum.Parent = model
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	return model
end

local V = Vector3.new
local C = Color3.fromRGB
local EYE = C(20, 20, 20)

local builders: { [string]: () -> Model } = {
	crab = function()
		local specs: { Spec } = {
			{ size = V(2.4, 0.9, 1.8), offset = V(0, 0, 0), shape = Enum.PartType.Ball },
			{ size = V(0.7, 0.7, 0.7), offset = V(-1.4, 0.1, -0.9), shape = Enum.PartType.Ball },
			{ size = V(0.7, 0.7, 0.7), offset = V(1.4, 0.1, -0.9), shape = Enum.PartType.Ball },
			{ size = V(0.2, 0.2, 0.2), offset = V(-0.35, 0.6, -0.7), color = EYE },
			{ size = V(0.2, 0.2, 0.2), offset = V(0.35, 0.6, -0.7), color = EYE },
		}
		for i = -1, 1 do
			table.insert(specs, { size = V(1.2, 0.2, 0.2), offset = V(-1.2, -0.3, i * 0.5) })
			table.insert(specs, { size = V(1.2, 0.2, 0.2), offset = V(1.2, -0.3, i * 0.5) })
		end
		return build("crab", V(2.4, 1, 1.8), 0.6, specs)
	end,
	boar = function()
		local tusk = C(240, 235, 220)
		local specs: { Spec } = {
			{ size = V(2.6, 2.4, 4.2), offset = V(0, 0, 0) },
			{ size = V(2, 1.9, 1.6), offset = V(0, 0.2, -2.6) },
			{ size = V(1, 0.8, 0.5), offset = V(0, -0.1, -3.55), color = C(170, 110, 100) },
			{ size = V(0.2, 0.7, 0.2), offset = V(-0.6, -0.2, -3.4), color = tusk },
			{ size = V(0.2, 0.7, 0.2), offset = V(0.6, -0.2, -3.4), color = tusk },
			{ size = V(0.3, 0.3, 0.2), offset = V(-0.55, 0.6, -3.4), color = EYE },
			{ size = V(0.3, 0.3, 0.2), offset = V(0.55, 0.6, -3.4), color = EYE },
			{ size = V(0.4, 1.4, 1.6), offset = V(0, 1.4, -0.4), color = C(70, 50, 40) },
		}
		for _, x in { -0.9, 0.9 } do
			for _, z in { -1.4, 1.4 } do
				table.insert(specs, { size = V(0.6, 1.4, 0.6), offset = V(x, -1.6, z) })
			end
		end
		return build("boar", V(2.6, 2.4, 4.2), 1.6, specs)
	end,
	wolf = function()
		local specs: { Spec } = {
			{ size = V(2, 2, 4.4), offset = V(0, 0, 0) },
			{ size = V(1.7, 1.7, 1.9), offset = V(0, 0.7, -2.7) },
			{ size = V(1, 0.8, 1.2), offset = V(0, 0.3, -3.9), color = C(90, 90, 100) },
			{ size = V(0.4, 0.8, 0.3), offset = V(-0.5, 1.8, -2.5) },
			{ size = V(0.4, 0.8, 0.3), offset = V(0.5, 1.8, -2.5) },
			{ size = V(0.25, 0.25, 0.1), offset = V(-0.45, 0.9, -3.66), color = C(255, 200, 60), neon = true },
			{ size = V(0.25, 0.25, 0.1), offset = V(0.45, 0.9, -3.66), color = C(255, 200, 60), neon = true },
			{ size = V(0.5, 0.5, 2), offset = V(0, 0.5, 2.8) },
		}
		for _, x in { -0.65, 0.65 } do
			for _, z in { -1.5, 1.5 } do
				table.insert(specs, { size = V(0.5, 1.8, 0.5), offset = V(x, -1.8, z) })
			end
		end
		return build("wolf", V(2, 2, 4.4), 1.9, specs)
	end,
	cave_spider = function()
		local specs: { Spec } = {
			{
				size = V(2.6, 1.8, 3),
				offset = V(0, 0, 0.6),
				shape = Enum.PartType.Ball,
				material = Enum.Material.Glass,
			},
			{ size = V(1.6, 1.2, 1.6), offset = V(0, 0, -1.4), shape = Enum.PartType.Ball },
			{ size = V(0.3, 0.3, 0.2), offset = V(-0.35, 0.3, -2.2), color = C(120, 255, 255), neon = true },
			{ size = V(0.3, 0.3, 0.2), offset = V(0.35, 0.3, -2.2), color = C(120, 255, 255), neon = true },
		}
		for i = 0, 3 do
			local z = -1 + i * 0.7
			table.insert(specs, { size = V(2.6, 0.25, 0.25), offset = V(-1.9, -0.5, z), color = C(40, 60, 70) })
			table.insert(specs, { size = V(2.6, 0.25, 0.25), offset = V(1.9, -0.5, z), color = C(40, 60, 70) })
		end
		return build("cave_spider", V(2.6, 1.8, 3), 1, specs)
	end,
	tide_shade = function()
		local specs: { Spec } = {
			{ size = V(2, 3.6, 1.4), offset = V(0, 0, 0), material = Enum.Material.Glass, transparency = 0.25 },
			{
				size = V(1.6, 1.6, 1.6),
				offset = V(0, 2.6, 0),
				shape = Enum.PartType.Ball,
				material = Enum.Material.Glass,
				transparency = 0.2,
			},
			{
				size = V(0.35, 0.2, 0.1),
				offset = V(-0.35, 2.7, -0.78),
				color = C(120, 255, 240),
				neon = true,
				name = "Eye",
			},
			{
				size = V(0.35, 0.2, 0.1),
				offset = V(0.35, 2.7, -0.78),
				color = C(120, 255, 240),
				neon = true,
				name = "Eye",
			},
			{
				size = V(0.6, 3, 0.6),
				offset = V(-1.4, -0.2, -0.3),
				material = Enum.Material.Glass,
				transparency = 0.35,
			},
			{ size = V(0.6, 3, 0.6), offset = V(1.4, -0.2, -0.3), material = Enum.Material.Glass, transparency = 0.35 },
			{ size = V(1.6, 1.8, 1.2), offset = V(0, -2.6, 0), material = Enum.Material.Glass, transparency = 0.55 },
		}
		local m = build("tide_shade", V(2, 3.6, 1.4), 2.4, specs)
		local smoke = Instance.new("ParticleEmitter")
		smoke.Color = ColorSequence.new(C(60, 40, 110), C(20, 10, 40))
		smoke.Transparency = NumberSequence.new(0.4, 1)
		smoke.Size = NumberSequence.new(1.5, 3)
		smoke.Lifetime = NumberRange.new(0.8, 1.4)
		smoke.Rate = 12
		smoke.Speed = NumberRange.new(0.5, 1.5)
		smoke.LightEmission = 0.2
		smoke.Parent = m.PrimaryPart
		local light = Instance.new("PointLight")
		light.Color = C(120, 255, 240)
		light.Range = 10
		light.Brightness = 1.2
		light.Parent = m.PrimaryPart
		return m
	end,
	magma_golem = function()
		local lava = C(255, 110, 30)
		local specs: { Spec } = {
			{ size = V(4, 4, 3), offset = V(0, 0, 0), material = Enum.Material.Basalt },
			{ size = V(2.4, 2.2, 2.2), offset = V(0, 3, 0), material = Enum.Material.Basalt },
			{ size = V(1.8, 0.3, 0.1), offset = V(0, 3.2, -1.15), color = lava, neon = true },
			{ size = V(1.4, 4, 1.4), offset = V(-2.8, -0.4, 0), material = Enum.Material.Basalt },
			{ size = V(1.4, 4, 1.4), offset = V(2.8, -0.4, 0), material = Enum.Material.Basalt },
			{ size = V(1.6, 2.8, 1.6), offset = V(-1, -3.3, 0), material = Enum.Material.Basalt },
			{ size = V(1.6, 2.8, 1.6), offset = V(1, -3.3, 0), material = Enum.Material.Basalt },
			{ size = V(0.4, 3, 0.1), offset = V(0.6, 0, -1.55), color = lava, neon = true },
			{ size = V(2, 0.4, 0.1), offset = V(-0.2, 0.8, -1.55), color = lava, neon = true },
		}
		local m = build("magma_golem", V(4, 4, 3), 4.6, specs)
		local light = Instance.new("PointLight")
		light.Color = lava
		light.Range = 16
		light.Brightness = 2
		light.Parent = m.PrimaryPart
		return m
	end,
}

function CreatureModels.build(id: string): Model
	return builders[id]()
end

return CreatureModels
