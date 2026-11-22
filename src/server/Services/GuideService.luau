--!strict
-- Guia "Velho Bento": NPC ao lado da fogueira do naufrágio e a Jornada do Náufrago.
-- Progresso validado no servidor (contadores/nível/posição) a partir do início de cada etapa.

local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Guide = require(Shared.Config.Guide)
local Regions = require(Shared.Config.Regions)
local Net = require(Shared.Net)

local PlayerService = require(script.Parent.PlayerService)
local DataService = require(script.Parent.DataService)
local WorldService = require(script.Parent.WorldService)
local Actions = require(script.Parent.Parent.Util.Actions)

local GuideService = {}

local stateEvent = Net.event("State")
local npc: Model? = nil

-- ===== NPC =====
local function weldTo(part: BasePart, to: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = to
	w.Part1 = part
	w.Parent = part
end

local function accessory(
	head: BasePart,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	mat: Enum.Material,
	shape: Enum.PartType?,
	name: string
)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	if shape then
		p.Shape = shape
	end
	p.Color = color
	p.Material = mat
	p.CanCollide = false
	p.CanQuery = false
	p.Massless = true
	p.CFrame = head.CFrame * offset
	weldTo(p, head)
	p.Parent = head.Parent
end

local function buildNpc(): Model?
	local desc = Instance.new("HumanoidDescription")
	local skin = Color3.fromRGB(198, 140, 100)
	desc.HeadColor = skin
	desc.LeftArmColor = skin
	desc.RightArmColor = skin
	desc.TorsoColor = Color3.fromRGB(60, 120, 150) -- camisa de marinheiro
	desc.LeftLegColor = Color3.fromRGB(110, 85, 60)
	desc.RightLegColor = Color3.fromRGB(110, 85, 60)
	desc.HeightScale = 1
	desc.BodyTypeScale = 0.2
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[Guide] Falha ao criar NPC:", model)
		return nil
	end
	local m = model :: Model
	m.Name = Guide.NPC.name
	local hum = m:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.MaxHealth = math.huge
	hum.Health = math.huge
	local animate = m:FindFirstChild("Animate")
	if animate then
		animate:Destroy() -- animação procedural feita no cliente
	end
	local head = m:WaitForChild("Head") :: BasePart
	-- chapéu de palha, barba e lenço
	accessory(
		head,
		Vector3.new(0.2, 2.5, 2.5),
		CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(222, 190, 120),
		Enum.Material.Fabric,
		Enum.PartType.Cylinder,
		"HatBrim"
	)
	accessory(
		head,
		Vector3.new(0.8, 1.35, 1.35),
		CFrame.new(0, 0.88, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(210, 175, 105),
		Enum.Material.Fabric,
		Enum.PartType.Cylinder,
		"HatTop"
	)
	accessory(
		head,
		Vector3.new(0.25, 1.4, 1.4),
		CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(170, 50, 45),
		Enum.Material.Fabric,
		Enum.PartType.Cylinder,
		"HatBand"
	)
	accessory(
		head,
		Vector3.new(1.05, 0.55, 0.4),
		CFrame.new(0, -0.45, -0.45),
		Color3.fromRGB(225, 225, 220),
		Enum.Material.Fabric,
		nil,
		"Beard"
	)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = d.Name == "HumanoidRootPart"
			d.CanCollide = false
		end
	end
	m:SetAttribute("GuideNPC", true)
	return m
end

local function placeNpc()
	local m = buildNpc()
	if not m then
		return
	end
	local pos = Regions.SPAWN + Guide.NPC.offset
	local gy = WorldService.GetGroundY(pos.X, pos.Z) or pos.Y
	local hrp = m:FindFirstChild("HumanoidRootPart") :: BasePart
	local hum = m:FindFirstChildOfClass("Humanoid") :: Humanoid
	local standY = gy + hum.HipHeight + hrp.Size.Y / 2
	-- olha para o ponto de chegada dos jogadores
	m:PivotTo(CFrame.lookAt(Vector3.new(pos.X, standY, pos.Z), Vector3.new(Regions.SPAWN.X, standY, Regions.SPAWN.Z)))
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Conversar"
	prompt.ObjectText = Guide.NPC.name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt:SetAttribute("Kind", "talk")
	prompt.Parent = hrp
	prompt.Triggered:Connect(function(player)
		GuideService.talk(player)
	end)
	m.Parent = workspace:WaitForChild("World")
	npc = m
end

-- ===== Progresso =====
local function guideData(data: any): any
	if type(data.guide) ~= "table" then
		data.guide = { stage = 1, base = {}, started = false }
	end
	return data.guide
end

local function stageDef(i: number): any
	return Guide.stages[i]
end

-- Retorna (atual, meta) da etapa
local function progressOf(player: Player, data: any, g: any): (number, number)
	local st = stageDef(g.stage)
	if not st then
		return 1, 1
	end
	local c = st.check
	if c.type == "reach" then
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local inside = hrp ~= nil and ((hrp.Position - c.pos) * Vector3.new(1, 0, 1)).Magnitude <= c.radius
		if inside then
			g.reached = true
		end
		return g.reached and 1 or 0, 1
	elseif c.type == "level" then
		return math.min(data.level, c.level), c.level
	else
		local cur, goal = 0, 0
		for stat, n in c.stats do
			local have = (data.counters[stat] or 0) - (g.base[stat] or 0)
			cur += math.clamp(have, 0, n)
			goal += n
		end
		return cur, goal
	end
end

local function snapshotBase(data: any, g: any)
	g.base = {}
	g.reached = false
	local st = stageDef(g.stage)
	if st and st.check.type == "counter" then
		for stat in st.check.stats do
			g.base[stat] = data.counters[stat] or 0
		end
	end
end

local function sendGuide(player: Player, dialogue: any?)
	local data = DataService.get(player)
	if not data then
		return
	end
	local g = guideData(data)
	local st = stageDef(g.stage)
	local payload: any = { stage = g.stage, total = #Guide.stages, started = g.started }
	if st then
		local cur, goal = progressOf(player, data, g)
		payload.title = st.title
		payload.objective = st.objective
		payload.progress = cur
		payload.goal = goal
		payload.target = st.target
		payload.targetPos = st.check.pos
		payload.stageId = st.id
	else
		payload.finished = true
	end
	stateEvent:FireClient(player, { guide = payload, dialogue = dialogue })
end

local function complete(player: Player, data: any, g: any)
	local st = stageDef(g.stage)
	local lines = table.clone(st.done or {})
	local r = st.reward or {}
	if r.shells and r.shells > 0 then
		PlayerService.addShells(player, r.shells)
	end
	if r.xp and r.xp > 0 then
		PlayerService.addXp(player, r.xp)
	end
	if r.items then
		PlayerService.giveMany(player, r.items, false)
	end
	PlayerService.notify(player, ("Etapa concluída: %s! +%d Conchas"):format(st.title, r.shells or 0), "quest", "📜")
	g.stage += 1
	snapshotBase(data, g)
	local nxt = stageDef(g.stage)
	if nxt then
		for _, l in nxt.intro do
			table.insert(lines, l)
		end
	end
	sendGuide(player, { lines = lines, stage = g.stage })
end

local function check(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local g = guideData(data)
	if not g.started or not stageDef(g.stage) then
		return
	end
	local cur, goal = progressOf(player, data, g)
	if cur >= goal then
		complete(player, data, g)
	else
		sendGuide(player)
	end
end

-- Jogador conversou com o Bento
function GuideService.talk(player: Player)
	local data = DataService.get(player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not data or not hrp or not npc or (npc:GetPivot().Position - hrp.Position).Magnitude > 16 then
		return
	end
	local g = guideData(data)
	local st = stageDef(g.stage)
	local lines: { string }
	if not g.started then
		g.started = true
		snapshotBase(data, g)
		lines = table.clone(st.intro)
	elseif st then
		lines = { "Lembre-se: " .. st.objective .. ".", Guide.tips[math.random(1, #Guide.tips)] }
	else
		lines = { "Você é uma lenda desta ilha, parceiro!", Guide.tips[math.random(1, #Guide.tips)] }
	end
	sendGuide(player, { lines = lines, stage = g.stage, npc = true })
	task.defer(check, player)
end

function GuideService.init()
	placeNpc()
	PlayerService.onReady(function(player, data)
		local g = guideData(data)
		if g.started then
			sendGuide(player)
		else
			-- dica para novatos: mostrar objetivo de falar com o Bento
			stateEvent:FireClient(
				player,
				{
					guide = {
						stage = 0,
						total = #Guide.stages,
						objective = "Fale com o Velho Bento perto da fogueira",
						title = "Náufrago",
						target = "npc",
					},
				}
			)
		end
	end)
	PlayerService.onCounter(function(player)
		check(player)
	end)
	PlayerService.onInventoryChanged(function(player)
		check(player)
	end)
	-- etapas de "chegar em" e "nível" são verificadas periodicamente
	task.spawn(function()
		while true do
			task.wait(1.5)
			for _, p in Players:GetPlayers() do
				local data = DataService.get(p)
				local g = data and guideData(data)
				local st = g and g.started and stageDef(g.stage)
				if st and (st.check.type == "reach" or st.check.type == "level") then
					check(p)
				end
			end
		end
	end)
	Actions.on("GuideTalk", function(player)
		GuideService.talk(player)
	end, 2)
end

function GuideService.npc(): Model?
	return npc
end

return GuideService
