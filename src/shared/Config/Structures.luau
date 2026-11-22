--!strict
-- Construções colocáveis. size = tamanho em studs (X, Y, Z) da caixa de colisão.
-- O visual é gerado por server/Builders/StructureModels.

export type StructureDef = {
	id: string,
	item: string,
	name: string,
	size: Vector3,
	health: number,
	snap: number, -- passo da grade
	station: string?, -- funciona como estação de crafting
	warmth: number?, -- raio de calor
	light: number?, -- raio de luz
	repelShades: boolean?,
	storage: number?, -- slots de armazenamento
	spawnPoint: boolean?,
	claim: number?, -- raio de território protegido
	limit: number?, -- máximo por jogador
	wallLike: boolean?, -- pode ficar encostada em outras (paredes/pisos)
}

local V = Vector3.new

local Structures: { [string]: StructureDef } = {
	campfire = {
		id = "campfire",
		item = "campfire",
		name = "Fogueira",
		size = V(5, 2, 5),
		health = 150,
		snap = 1,
		station = "campfire",
		warmth = 22,
		light = 26,
		repelShades = true,
		limit = 6,
	},
	workbench = {
		id = "workbench",
		item = "workbench",
		name = "Bancada",
		size = V(7, 4, 4),
		health = 250,
		snap = 1,
		station = "workbench",
		limit = 3,
	},
	forge = {
		id = "forge",
		item = "forge",
		name = "Fornalha",
		size = V(6, 6, 6),
		health = 500,
		snap = 1,
		station = "forge",
		warmth = 14,
		light = 14,
		limit = 2,
	},
	wood_floor = {
		id = "wood_floor",
		item = "wood_floor",
		name = "Piso de Madeira",
		size = V(8, 1, 8),
		health = 300,
		snap = 4,
		wallLike = true,
	},
	wood_wall = {
		id = "wood_wall",
		item = "wood_wall",
		name = "Parede de Madeira",
		size = V(8, 8, 1),
		health = 400,
		snap = 4,
		wallLike = true,
	},
	wood_door = {
		id = "wood_door",
		item = "wood_door",
		name = "Porta de Madeira",
		size = V(8, 8, 1),
		health = 350,
		snap = 4,
		wallLike = true,
	},
	leaf_roof = {
		id = "leaf_roof",
		item = "leaf_roof",
		name = "Telhado de Folhas",
		size = V(8, 1, 8),
		health = 150,
		snap = 4,
		wallLike = true,
	},
	stone_wall = {
		id = "stone_wall",
		item = "stone_wall",
		name = "Parede de Pedra",
		size = V(8, 8, 1),
		health = 1200,
		snap = 4,
		wallLike = true,
	},
	stone_floor = {
		id = "stone_floor",
		item = "stone_floor",
		name = "Piso de Pedra",
		size = V(8, 1, 8),
		health = 1000,
		snap = 4,
		wallLike = true,
	},
	chest = {
		id = "chest",
		item = "chest",
		name = "Baú",
		size = V(4, 3, 3),
		health = 300,
		snap = 1,
		storage = 20,
		limit = 10,
	},
	leaf_bed = {
		id = "leaf_bed",
		item = "leaf_bed",
		name = "Cama de Folhas",
		size = V(4, 1.5, 7),
		health = 120,
		snap = 1,
		spawnPoint = true,
		limit = 1,
	},
	rain_collector = {
		id = "rain_collector",
		item = "rain_collector",
		name = "Coletor de Chuva",
		size = V(4, 5, 4),
		health = 200,
		snap = 1,
		limit = 4,
	},
	torch_post = {
		id = "torch_post",
		item = "torch_post",
		name = "Poste de Tocha",
		size = V(1.5, 7, 1.5),
		health = 80,
		snap = 1,
		light = 20,
		warmth = 6,
		limit = 20,
	},
	base_totem = {
		id = "base_totem",
		item = "base_totem",
		name = "Totem do Território",
		size = V(3, 9, 3),
		health = 2000,
		snap = 1,
		claim = 45,
		limit = 1,
	},
	rescue_beacon = {
		id = "rescue_beacon",
		item = "rescue_beacon",
		name = "Farol de Resgate",
		size = V(10, 30, 10),
		health = 5000,
		snap = 1,
		light = 60,
		limit = 1,
	},
}

local Config = {
	defs = Structures,
	MAX_PER_PLAYER = 180,
	PLACE_RANGE = 32,
	MIN_DISTANCE_FROM_SPAWN = 40,
}

for id, def in Structures do
	assert(def.id == id, "Estrutura inconsistente: " .. id)
end

return Config
