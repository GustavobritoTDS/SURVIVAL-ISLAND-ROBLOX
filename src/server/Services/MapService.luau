--!strict
-- Gera os dados do Mapa da Ilha uma vez: grade do terreno (material + altura) e pontos de interesse.
-- Publicado em ReplicatedStorage.MapData (JSON) para o cliente desenhar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Regions = require(Shared.Config.Regions)
local Guide = require(Shared.Config.Guide)

local MapService = {}

MapService.GRID = 56
MapService.EXTENT = 620 -- metade do lado do mapa em studs

-- código de cor por material
local CODES: { [Enum.Material]: string } = {
	[Enum.Material.Sand] = "s",
	[Enum.Material.Grass] = "g",
	[Enum.Material.LeafyGrass] = "j",
	[Enum.Material.Mud] = "m",
	[Enum.Material.Ground] = "m",
	[Enum.Material.Rock] = "r",
	[Enum.Material.Slate] = "r",
	[Enum.Material.Limestone] = "r",
	[Enum.Material.Basalt] = "b",
	[Enum.Material.CrackedLava] = "l",
}

function MapService.init()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	params.IgnoreWater = false
	local n, ext = MapService.GRID, MapService.EXTENT
	local cells = table.create(n * n)
	for row = 0, n - 1 do
		for col = 0, n - 1 do
			local x = -ext + (col + 0.5) * (2 * ext / n)
			local z = -ext + (row + 0.5) * (2 * ext / n)
			local hit = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -500, 0), params)
			local code = "w"
			local h = 0
			if hit then
				if hit.Material == Enum.Material.Water then
					code = hit.Position.Y > 2 and "f" or "w" -- f = água doce (lagos acima do mar)
				else
					code = CODES[hit.Material] or "g"
				end
				h = math.clamp(math.floor(hit.Position.Y / 16), 0, 9)
			end
			cells[row * n + col + 1] = code .. tostring(h)
		end
		if row % 8 == 0 then
			task.wait()
		end
	end

	-- pontos de interesse
	local pois = {}
	local function poi(kind: string, label: string, pos: Vector3)
		table.insert(pois, { kind = kind, label = label, x = pos.X, z = pos.Z })
	end
	poi("ship", "Destroços do Gaivota", Guide.stages[1].check.pos)
	poi("npc", "Velho Bento", Regions.SPAWN + Guide.NPC.offset)
	for _, r in Regions.order do
		if r.id ~= "beach" then
			poi("region", r.name, r.center)
		end
	end
	poi("region", "Praia do Naufrágio", Regions.SPAWN + Vector3.new(0, 0, -40))
	local fresh = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("FreshWater")
	for _, p in (fresh and fresh:GetChildren() or {}) do
		if p:IsA("BasePart") then
			poi("lake", "Água doce", p.Position)
		end
	end
	poi("cave", "Entrada da Caverna", Vector3.new(40, 0, -416))
	poi("volcano", "Cratera", Regions.byId.volcano.center)

	local data = { grid = n, extent = ext, cells = table.concat(cells, ""), pois = pois }
	local existing = ReplicatedStorage:FindFirstChild("MapData")
	local sv: StringValue = if existing and existing:IsA("StringValue") then existing else Instance.new("StringValue")
	sv.Name = "MapData"
	sv.Value = HttpService:JSONEncode(data)
	sv.Parent = ReplicatedStorage
	print(("[Map] mapa gerado (%dx%d, %d pontos)"):format(n, n, #pois))
end

return MapService
