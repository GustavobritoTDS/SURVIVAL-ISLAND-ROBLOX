--!strict
-- Raycasts somente contra o Terrain (ignora Parts de decoração, nós e jogadores).

local Ground = {}

local TOP = 400

local function makeParams(ignoreWater: boolean): RaycastParams
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Include
	p.FilterDescendantsInstances = { workspace.Terrain }
	p.IgnoreWater = ignoreWater
	return p
end

local dryParams = makeParams(true)
local wetParams = makeParams(false)

export type Hit = { position: Vector3, normal: Vector3, material: Enum.Material }

-- Altura do chão (ignora água: devolve o fundo de lagos/mar).
function Ground.groundY(x: number, z: number): number?
	local hit = workspace:Raycast(Vector3.new(x, TOP, z), Vector3.new(0, -TOP - 100, 0), dryParams)
	return if hit then hit.Position.Y else nil
end

-- Raio vertical que considera água: nil se cair em água ou não achar chão.
function Ground.castDry(x: number, z: number, fromY: number?, depth: number?): Hit?
	local y = fromY or TOP
	local hit = workspace:Raycast(Vector3.new(x, y, z), Vector3.new(0, -(depth or (y + 100)), 0), wetParams)
	if not hit or hit.Material == Enum.Material.Water then
		return nil
	end
	return { position = hit.Position, normal = hit.Normal, material = hit.Material }
end

-- Raio livre contra o terreno (paredes da caverna etc.).
function Ground.ray(origin: Vector3, dir: Vector3): RaycastResult?
	return workspace:Raycast(origin, dir, dryParams)
end

return Ground
