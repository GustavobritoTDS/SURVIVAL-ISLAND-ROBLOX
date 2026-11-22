--!strict
-- WorldService: gera a ilha (terreno, lagos, decoração, spawn) e expõe
-- posições determinísticas de nós, modelos low-poly e consultas de chão.
--
-- Progresso: workspace:GetAttribute("WorldProgress") 0..1; "WorldReady" = true no fim.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Regions = require(ReplicatedStorage.Shared.Config.Regions)

local WorldModules = script.Parent.Parent.World
local Decor = require(WorldModules.Decor)
local Ground = require(WorldModules.Ground)
local NodeModels = require(WorldModules.NodeModels)
local Placement = require(WorldModules.Placement)
local TerrainGen = require(WorldModules.TerrainGen)

local WorldService = {}

export type NodeSpawn = { nodeId: string, cframe: CFrame }

local started = false
local nodeSpawns: { NodeSpawn }? = nil

local function setProgress(p: number)
	workspace:SetAttribute("WorldProgress", math.clamp(p, 0, 1))
end

local function getFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- workspace.World com Decor, FreshWater, Nodes, Creatures e Structures.
local function ensureFolders(): (Folder, Folder, Folder)
	local root = getFolder(workspace, "World")
	local decor = getFolder(root, "Decor")
	local fresh = getFolder(root, "FreshWater")
	decor:ClearAllChildren()
	fresh:ClearAllChildren()
	getFolder(root, "Nodes")
	getFolder(root, "Creatures")
	getFolder(root, "Structures")
	return root, decor, fresh
end

-- SpawnLocation invisível com o topo rente à areia, virada para a selva.
local function createSpawn(root: Folder)
	local old = root:FindFirstChild("IslandSpawn")
	if old then
		old:Destroy()
	end
	local cf = WorldService.GetSpawnCFrame()
	local sp = Instance.new("SpawnLocation")
	sp.Name = "IslandSpawn"
	sp.Anchored = true
	sp.Neutral = true
	sp.Duration = 0
	sp.Enabled = true
	sp.Size = Vector3.new(6, 1, 6)
	sp.CFrame = cf - Vector3.new(0, 3.5, 0)
	sp.Transparency = 1
	sp.CanCollide = false
	sp.CanQuery = false
	sp.CanTouch = false
	sp.CastShadow = false
	sp.Parent = root
end

-- Gera o mundo inteiro (yielda). Seguro chamar uma única vez.
function WorldService.Init()
	if started then
		return
	end
	started = true
	local t0 = os.clock()
	workspace:SetAttribute("WorldReady", false)
	setProgress(0)

	local root, decor, fresh = ensureFolders()
	TerrainGen.generate(function(p)
		setProgress(p * 0.8)
	end)
	local exclusions = Decor.build(decor, fresh, function(p)
		setProgress(0.8 + p * 0.15)
	end)
	createSpawn(root)
	table.insert(exclusions, { pos = Regions.SPAWN, r = 6 })
	setProgress(0.96)

	nodeSpawns = Placement.computeNodeSpawns(exclusions)
	setProgress(1)
	workspace:SetAttribute("WorldReady", true)
	print(
		string.format("[WorldService] mundo pronto em %.1fs (%d nós)", os.clock() - t0, #(nodeSpawns :: { NodeSpawn }))
	)
end

-- Posições determinísticas de todos os nós. Espera o mundo ficar pronto se preciso.
function WorldService.GetNodeSpawns(): { NodeSpawn }
	while not nodeSpawns do
		workspace:GetAttributeChangedSignal("WorldReady"):Wait()
	end
	return table.clone(nodeSpawns)
end

-- Modelo visual do nó (não parentado). Pivô na base: use model:PivotTo(cframe).
function WorldService.BuildNodeModel(nodeId: string, rng: Random?): Model
	return NodeModels.build(nodeId, rng)
end

-- Ponto aleatório de chão seco na região (para criaturas), ou nil após 20 tentativas.
function WorldService.RandomGroundPoint(regionId: string, rng: Random): Vector3?
	return Placement.randomGroundPoint(regionId, rng)
end

-- Altura do terreno em (x, z): raycast de cima para baixo só contra Terrain (ignora água).
function WorldService.GetGroundY(x: number, z: number): number?
	return Ground.groundY(x, z)
end

-- CFrame de pé no Regions.SPAWN, olhando para o norte (selva).
function WorldService.GetSpawnCFrame(): CFrame
	local s = Regions.SPAWN
	local y = Ground.groundY(s.X, s.Z)
	local pos = Vector3.new(s.X, if y then y + 3 else s.Y, s.Z)
	return CFrame.lookAt(pos, pos + Vector3.new(0, 0, -1))
end

return WorldService
