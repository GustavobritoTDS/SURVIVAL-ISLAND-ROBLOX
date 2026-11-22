--!strict
-- Geografia da ilha (coordenadas em studs; centro da ilha em X=0, Z=0; nível do mar Y=0).
-- Regiões são testadas em ordem de prioridade (a primeira que contém a posição vence).

export type Region = {
	id: string,
	name: string,
	level: number, -- nível mínimo para entrar
	center: Vector3, -- centro aproximado (Y = referência)
	radius: number, -- raio horizontal
	minY: number?,
	maxY: number?,
	color: Color3,
	danger: number, -- 1..5, escala de criaturas
}

local V = Vector3.new
local C = Color3.fromRGB

local order: { Region } = {
	{ id = "cave", name = "Caverna de Cristal", level = 6, center = V(40, 18, -250), radius = 80, minY = -10, maxY = 45, color = C(90, 220, 230), danger = 4 },
	{ id = "volcano", name = "Cratera do Vulcão", level = 9, center = V(260, 120, -230), radius = 110, minY = 60, color = C(230, 90, 50), danger = 5 },
	{ id = "highlands", name = "Planalto de Pedra", level = 4, center = V(-60, 60, -240), radius = 230, color = C(160, 160, 170), danger = 3 },
	{ id = "jungle", name = "Selva Esmeralda", level = 1, center = V(0, 20, 60), radius = 330, color = C(60, 170, 90), danger = 2 },
	{ id = "beach", name = "Praia do Naufrágio", level = 1, center = V(0, 3, 380), radius = 9999, color = C(240, 215, 150), danger = 1 },
}

local Regions = {
	order = order,
	byId = {} :: { [string]: Region },
	ISLAND_RADIUS = 560,
	SEA_LEVEL = 0,
	SPAWN = V(0, 8, 430),
	WORLD_SEED = 7342,
}

for _, r in order do
	Regions.byId[r.id] = r
end

function Regions.at(pos: Vector3): Region
	for _, r in order do
		local dx, dz = pos.X - r.center.X, pos.Z - r.center.Z
		if dx * dx + dz * dz <= r.radius * r.radius then
			if (r.minY == nil or pos.Y >= r.minY) and (r.maxY == nil or pos.Y <= r.maxY) then
				return r
			end
		end
	end
	return order[#order]
end

return Regions
