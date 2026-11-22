--!strict
-- Nós de recurso: spawn, coleta (golpe ou prompt), drops e respawn. Tudo validado no servidor.

local CollectionService = game:GetService("CollectionService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Nodes = require(Shared.Config.Nodes)
local Items = require(Shared.Config.Items)
local Rules = require(Shared.Logic.Rules)
local Net = require(Shared.Net)

local PlayerService = require(script.Parent.PlayerService)
local WorldService = require(script.Parent.WorldService)

local ResourceService = {}

local fxEvent = Net.event("Fx")
local rng = Random.new()
local nodesFolder: Folder
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include

local function randInt(a: number, b: number): number
	return rng:NextInteger(a, b)
end
local function rand01(): number
	return rng:NextNumber()
end

local function fxNear(pos: Vector3, payload: any)
	payload.pos = pos
	for _, p in game:GetService("Players"):GetPlayers() do
		local char = p.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp and (hrp.Position - pos).Magnitude < 200 then
			fxEvent:FireClient(p, payload)
		end
	end
end

local function giveDrops(player: Player, drops: { any }?, xp: number)
	if not drops then
		return
	end
	local got = Rules.rollDrops(drops, randInt, rand01)
	for id, n in got do
		local added = PlayerService.give(player, id, n)
		if added > 0 then
			PlayerService.count(player, "collect_" .. id, added)
		end
	end
	if xp > 0 then
		PlayerService.addXp(player, xp)
	end
end

local spawnNode: (nodeId: string, cf: CFrame) -> ()

local function depleteNode(model: Model, nodeId: string, cf: CFrame)
	local def = Nodes[nodeId]
	model:SetAttribute("Depleted", true)
	CollectionService:RemoveTag(model, "ResourceNode")
	fxNear(cf.Position, { kind = "nodeBreak", nodeId = nodeId })
	task.delay(0.35, function()
		model:Destroy()
	end)
	task.delay(def.respawn, function()
		spawnNode(nodeId, cf)
	end)
end

local function onPrompt(model: Model, nodeId: string, cf: CFrame, player: Player)
	if model:GetAttribute("Depleted") then
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp or (hrp.Position - cf.Position).Magnitude > 14 then
		return
	end
	local def = Nodes[nodeId]
	fxEvent:FireAllClients({ kind = "anim", anim = "gather", char = player.Character })
	giveDrops(player, def.drops, def.xp)
	depleteNode(model, nodeId, cf)
end

spawnNode = function(nodeId: string, cf: CFrame)
	local def = Nodes[nodeId]
	local model = WorldService.BuildNodeModel(nodeId, rng)
	model:PivotTo(cf)
	model.Name = nodeId
	model:SetAttribute("NodeId", nodeId)
	model:SetAttribute("Health", def.health)
	model:SetAttribute("MaxHealth", def.health)
	CollectionService:AddTag(model, "ResourceNode")
	if def.harvest == "prompt" then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Coletar"
		prompt.ObjectText = def.name
		prompt.HoldDuration = 0.35
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Style = Enum.ProximityPromptStyle.Custom
		prompt:SetAttribute("Kind", "collect")
		prompt.Parent = model.PrimaryPart
		prompt.Triggered:Connect(function(player)
			onPrompt(model, nodeId, cf, player)
		end)
	end
	model.Parent = nodesFolder
end

-- Tenta golpear um nó à frente do jogador. Retorna true se acertou algo.
function ResourceService.tryHit(player: Player, itemId: string): boolean
	local tool = Items[itemId]
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp or not tool then
		return false
	end
	local range = (tool.range or 8)
	local center = hrp.Position + hrp.CFrame.LookVector * (range * 0.5)
	local parts = workspace:GetPartBoundsInRadius(center, range * 0.75, overlap)
	local best: Model? = nil
	local bestDist = math.huge
	for _, p in parts do
		local m = p:FindFirstAncestorOfClass("Model")
		while m and m.Parent ~= nodesFolder do
			m = m:FindFirstAncestorOfClass("Model")
		end
		if m and not m:GetAttribute("Depleted") then
			local d = (m:GetPivot().Position - hrp.Position).Magnitude
			if d < bestDist then
				best, bestDist = m, d
			end
		end
	end
	if not best then
		return false
	end
	local model = best :: Model
	local nodeId = model:GetAttribute("NodeId") :: string
	local def = Nodes[nodeId]
	if def.harvest ~= "tool" then
		return false
	end
	local dmg = Rules.nodeDamage(def, tool)
	local pos = model:GetPivot().Position
	if dmg <= 0 then
		local need = def.toolType == "axe" and "Machado" or "Picareta"
		local tierName = ({ "de Pedra", "de Ferro", "de Cristal" })[def.tierRequired] or ""
		PlayerService.notify(player, ("Precisa de %s %s"):format(need, tierName), "bad", "⛔")
		fxNear(pos, { kind = "hitFail" })
		return true
	end
	local hp = (model:GetAttribute("Health") :: number) - dmg
	model:SetAttribute("Health", hp)
	fxNear(pos, { kind = "hit", nodeId = nodeId, model = model, damage = math.floor(dmg) })
	giveDrops(player, def.drops, 0)
	if hp <= 0 then
		giveDrops(player, def.finalDrops, def.xp)
		depleteNode(model, nodeId, model:GetPivot())
	end
	return true
end

function ResourceService.init()
	local world = workspace:WaitForChild("World")
	nodesFolder = world:WaitForChild("Nodes") :: Folder
	overlap.FilterDescendantsInstances = { nodesFolder }
	local spawns = WorldService.GetNodeSpawns()
	for i, s in spawns do
		spawnNode(s.nodeId, s.cframe)
		if i % 40 == 0 then
			task.wait()
		end
	end
	print(("[Resource] %d nós criados"):format(#spawns))
end

return ResourceService
