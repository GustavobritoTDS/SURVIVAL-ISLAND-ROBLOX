--!strict
-- Animações procedurais (sem assets): movem as juntas Motor6D do rig R15 por C0.
-- Golpe: antecipação (0,12 s) -> impacto (0,09 s) -> recuperação (0,25 s, Back).
-- Coletar: inclina o tronco e leva as mãos ao chão. Comer: mão à boca duas vezes.
-- Bento (NPC): respira, vira a cabeça para o jogador, acena e gesticula ao falar.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)

local Lib = require(script.Parent.Parent.UI.Lib)

local Animations = {}
local rad = math.rad
local player = Players.LocalPlayer

-- C0 original de cada junta (para sempre voltar ao repouso)
local baseC0: { [Motor6D]: CFrame } = {}
local busy: { [Model]: boolean } = {}

local function joint(char: Model, partName: string, jointName: string): Motor6D?
	local part = char:FindFirstChild(partName)
	local j = part and part:FindFirstChild(jointName)
	if j and j:IsA("Motor6D") then
		if not baseC0[j] then
			baseC0[j] = j.C0
		end
		return j
	end
	return nil
end

local function pose(j: Motor6D?, rot: CFrame, t: number, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween?
	if not j then
		return nil
	end
	local tw = TweenService:Create(
		j,
		TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		{ C0 = baseC0[j] * rot }
	)
	tw:Play()
	return tw
end

local function rest(char: Model, t: number)
	for _, pair in
		{
			{ "RightUpperArm", "RightShoulder" },
			{ "LeftUpperArm", "LeftShoulder" },
			{ "UpperTorso", "Waist" },
			{ "Head", "Neck" },
		}
	do
		pose(joint(char, pair[1], pair[2]), CFrame.new(), t, Enum.EasingStyle.Back)
	end
end

local function play(char: Model?, anim: string)
	if not char or not char.Parent or busy[char] or Lib.reducedMotion() then
		return
	end
	busy[char] = true
	local rs = joint(char, "RightUpperArm", "RightShoulder")
	local ls = joint(char, "LeftUpperArm", "LeftShoulder")
	local waist = joint(char, "UpperTorso", "Waist")
	task.spawn(function()
		if anim == "swing" then
			-- antecipação: braço sobe atrás da cabeça, tronco gira
			pose(rs, CFrame.Angles(rad(150), 0, rad(-15)), 0.12)
			pose(waist, CFrame.Angles(rad(-6), rad(-22), 0), 0.12)
			task.wait(0.12)
			-- impacto: desce rápido e o tronco acompanha
			pose(rs, CFrame.Angles(rad(35), 0, rad(10)), 0.09, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
			pose(waist, CFrame.Angles(rad(12), rad(20), 0), 0.09, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
			task.wait(0.12)
			rest(char, 0.25)
			task.wait(0.2)
		elseif anim == "gather" then
			pose(waist, CFrame.Angles(rad(38), 0, 0), 0.15)
			pose(rs, CFrame.Angles(rad(55), 0, 0), 0.15)
			pose(ls, CFrame.Angles(rad(55), 0, 0), 0.15)
			task.wait(0.28)
			rest(char, 0.25)
			task.wait(0.2)
		elseif anim == "eat" then
			for _ = 1, 2 do
				pose(rs, CFrame.Angles(rad(115), 0, rad(35)), 0.14)
				task.wait(0.18)
				pose(rs, CFrame.Angles(rad(85), 0, rad(30)), 0.12)
				task.wait(0.12)
			end
			rest(char, 0.25)
			task.wait(0.2)
		end
		busy[char] = nil
	end)
end
Animations.play = play

-- ===== NPC: Bento =====
local talking = false
function Animations.setTalking(v: boolean)
	talking = v
end

local function animateNpc(npc: Model)
	local neck = joint(npc, "Head", "Neck")
	local waist = joint(npc, "UpperTorso", "Waist")
	local rs = joint(npc, "RightUpperArm", "RightShoulder")
	local ls = joint(npc, "LeftUpperArm", "LeftShoulder")
	local waved = false
	local waving = false
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		if not npc.Parent then
			conn:Disconnect()
			return
		end
		local t = os.clock() - t0
		local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart?
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		-- respiração
		if waist then
			waist.C0 = baseC0[waist] * CFrame.Angles(rad(math.sin(t * 1.6) * 1.5), 0, 0)
		end
		-- olhar para o jogador próximo
		if neck and root and hrp then
			local rel = root.CFrame:PointToObjectSpace(hrp.Position)
			local dist = rel.Magnitude
			local yaw = 0
			if dist < 30 then
				yaw = math.clamp(math.atan2(-rel.X, -rel.Z), rad(-65), rad(65))
			end
			local nod = talking and math.sin(t * 7) * rad(4) or 0
			local target = baseC0[neck] * CFrame.Angles(nod, yaw, 0)
			neck.C0 = neck.C0:Lerp(target, 0.12)
			-- aceno quando o jogador chega perto pela primeira vez
			if not waved and dist < 18 and rs then
				waved = true
				waving = true
				task.spawn(function()
					for _ = 1, 3 do
						pose(rs, CFrame.Angles(rad(160), 0, rad(-25)), 0.18)
						task.wait(0.2)
						pose(rs, CFrame.Angles(rad(160), 0, rad(15)), 0.18)
						task.wait(0.2)
					end
					pose(rs, CFrame.new(), 0.3, Enum.EasingStyle.Back)
					task.wait(0.3)
					waving = false
				end)
			elseif dist > 40 then
				waved = false
			end
		end
		-- gestos ao falar
		if talking and rs and ls then
			rs.C0 = rs.C0:Lerp(baseC0[rs] * CFrame.Angles(rad(35 + math.sin(t * 3.1) * 20), 0, rad(-10)), 0.15)
			ls.C0 = ls.C0:Lerp(baseC0[ls] * CFrame.Angles(rad(25 + math.sin(t * 2.3 + 1) * 15), 0, rad(10)), 0.15)
		elseif rs and ls and not waving then
			rs.C0 = rs.C0:Lerp(baseC0[rs], 0.1)
			ls.C0 = ls.C0:Lerp(baseC0[ls], 0.1)
		end
	end)
end

function Animations.init()
	Net.event("Fx").OnClientEvent:Connect(function(fx)
		if fx.kind == "anim" and typeof(fx.char) == "Instance" then
			play(fx.char :: Model, fx.anim)
		end
	end)
	-- Bento pode chegar depois por causa do streaming
	task.spawn(function()
		local world = workspace:WaitForChild("World")
		local function watch(m: Instance)
			if m:IsA("Model") and m:GetAttribute("GuideNPC") then
				m:WaitForChild("Head", 10)
				animateNpc(m)
			end
		end
		for _, c in world:GetChildren() do
			watch(c)
		end
		world.ChildAdded:Connect(watch)
	end)
end

return Animations
