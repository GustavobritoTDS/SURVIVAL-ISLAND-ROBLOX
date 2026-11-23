-- Monta cenas reais do jogo no Studio (modo Edit) para capturar thumbnails.
-- Uso: run-in-roblox --place build/SurvivalIsland.rbxlx --script tests/thumbnail_scenes.luau
-- Imprime "[thumb] cena N" quando cada cena está pronta (um script externo tira o print da tela).

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local SSS = game:GetService("ServerScriptService")

task.spawn(require(SSS.Server.Boot))
local t0 = os.clock()
while not workspace:GetAttribute("ServerReady") and os.clock() - t0 < 120 do
	task.wait(1)
end
task.wait(3)

local Regions = require(game.ReplicatedStorage.Shared.Config.Regions)
local Guide = require(game.ReplicatedStorage.Shared.Config.Guide)
local WorldService = require(SSS.Server.Services.WorldService)
local CreatureModels = require(SSS.Server.Builders.CreatureModels)
local ToolModels = require(SSS.Server.Builders.ToolModels)

local cam = workspace.CurrentCamera
cam.CameraType = Enum.CameraType.Scriptable
cam.FieldOfView = 60

local function ground(x: number, z: number): number
	return WorldService.GetGroundY(x, z) or 6
end

-- "Jogador" de exemplo (avatar padrão R15) segurando uma ferramenta
local function hero(pos: Vector3, lookAt: Vector3, toolId: string?): Model
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = Color3.fromRGB(234, 184, 146)
	desc.LeftArmColor = desc.HeadColor
	desc.RightArmColor = desc.HeadColor
	desc.TorsoColor = Color3.fromRGB(220, 120, 60)
	desc.LeftLegColor = Color3.fromRGB(60, 80, 120)
	desc.RightLegColor = Color3.fromRGB(60, 80, 120)
	local m = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	local hum = m:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local hrp = m:FindFirstChild("HumanoidRootPart") :: BasePart
	hrp.Anchored = true
	local y = ground(pos.X, pos.Z) + hum.HipHeight + hrp.Size.Y / 2
	m:PivotTo(CFrame.lookAt(Vector3.new(pos.X, y, pos.Z), Vector3.new(lookAt.X, y, lookAt.Z)))
	m.Parent = workspace
	if toolId then
		local tool = ToolModels.build(toolId)
		local hand = m:FindFirstChild("RightHand") :: BasePart
		if tool and hand then
			local handle = tool:FindFirstChild("Handle") :: BasePart
			for _, p in tool:GetDescendants() do
				if p:IsA("BasePart") then
					p.Anchored = false
				end
			end
			handle.CFrame = hand.CFrame * CFrame.new(0, -0.3, -0.4) * CFrame.Angles(math.rad(-80), 0, 0)
			local w = Instance.new("WeldConstraint")
			w.Part0 = hand
			w.Part1 = handle
			w.Parent = handle
			tool.Parent = m
		end
		-- braço levantado (pose de ação)
		pcall(function()
			local rs = (m:FindFirstChild("RightUpperArm") :: BasePart):FindFirstChild("RightShoulder") :: Motor6D
			rs.Transform = CFrame.Angles(math.rad(70), 0, 0)
		end)
	end
	return m
end

local function shot(n: number, clock: number, camCF: CFrame)
	Lighting.ClockTime = clock
	cam.CFrame = camCF
	task.wait(4) -- streaming/sombras assentarem
	print(("[thumb] cena %d"):format(n))
	task.wait(6) -- tempo para a captura externa
end

local S = Regions.SPAWN
-- Cena 1: praia com os destroços do Gaivota ao fundo
local wreck = Guide.stages[1].check.pos
local h1 = hero(S + Vector3.new(14, 0, 22), wreck, "stone_axe")
shot(1, 16.6, CFrame.lookAt(S + Vector3.new(-4, ground(S.X, S.Z) + 6, 6), wreck + Vector3.new(0, 4, 0)))
h1:Destroy()

-- Cena 2: o jogador conversando com o Velho Bento ao pôr do sol (perto da fogueira)
local bentoPos = S + Guide.NPC.offset
local by = ground(bentoPos.X, bentoPos.Z)
local bento2 = workspace.World:FindFirstChild(Guide.NPC.name)
local face = bento2 and (bento2 :: Model):GetPivot() or CFrame.new(bentoPos)
local heroPos = (face * CFrame.new(0, 0, -6)).Position
local h2 = hero(heroPos, face.Position, "stone_axe")
local mid2 = face.Position:Lerp(heroPos, 0.5)
local side = face.RightVector
shot(2, 17.7, CFrame.lookAt(Vector3.new(mid2.X, by + 4.5, mid2.Z) + side * 11, Vector3.new(mid2.X, by + 3, mid2.Z)))
h2:Destroy()

-- Cena 3: vista aérea da ilha (selva, planalto e vulcão)
shot(3, 14.5, CFrame.lookAt(Vector3.new(-90, 150, 470), Vector3.new(80, 40, -120)))

-- Cena 4: a noite e as Sombras da Maré cercando a luz da fogueira (Bento fora de quadro)
local bento = workspace.World:FindFirstChild(Guide.NPC.name)
if bento then
	bento.Parent = nil
end
local fire = S + Vector3.new(10, 0, -12)
local fy = ground(fire.X, fire.Z)
local h3 = hero(fire + Vector3.new(4, 0, 6), fire + Vector3.new(4, 0, 30), "torch")
for _, off in { Vector3.new(14, 0, 24), Vector3.new(-8, 0, 26), Vector3.new(4, 0, 32) } do
	local m = CreatureModels.build("tide_shade")
	local gy = ground(fire.X + off.X, fire.Z + off.Z)
	m:PivotTo(CFrame.lookAt(Vector3.new(fire.X + off.X, gy + 4.5, fire.Z + off.Z), Vector3.new(fire.X, gy + 4.5, fire.Z)))
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
		end
	end
	m.Parent = workspace
end
shot(4, 21.5, CFrame.lookAt(fire + Vector3.new(-6, fy - fire.Y + 6, -8), fire + Vector3.new(4, fy - fire.Y + 3, 24)))
local _ = h3

print("[thumb] fim")
