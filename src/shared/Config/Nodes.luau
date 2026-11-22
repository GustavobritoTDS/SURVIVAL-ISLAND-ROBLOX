--!strict
-- Nós de recurso espalhados pela ilha.
-- harvest = "tool": golpear com a ferramenta do toolType e tier >= tierRequired.
-- harvest = "prompt": coletar com as mãos via ProximityPrompt (galhos, pedras soltas, arbustos).

export type Drop = { item: string, min: number, max: number, chance: number? }

export type NodeDef = {
	id: string,
	name: string,
	harvest: string,
	toolType: string?,
	tierRequired: number,
	health: number,
	drops: { Drop }, -- por golpe (tool) ou por coleta (prompt)
	finalDrops: { Drop }?, -- ao destruir o nó
	respawn: number, -- segundos
	xp: number,
	region: string, -- região onde aparece (ver Regions)
	count: number, -- quantos existem no mapa
}

local Nodes: { [string]: NodeDef } = {
	stick_pile = {
		id = "stick_pile",
		name = "Galhos Caídos",
		harvest = "prompt",
		tierRequired = 0,
		health = 1,
		drops = { { item = "stick", min = 2, max = 3 } },
		respawn = 45,
		xp = 2,
		region = "beach",
		count = 45,
	},
	loose_stone = {
		id = "loose_stone",
		name = "Pedras Soltas",
		harvest = "prompt",
		tierRequired = 0,
		health = 1,
		drops = { { item = "stone", min = 1, max = 2 }, { item = "flint", min = 1, max = 1, chance = 0.35 } },
		respawn = 45,
		xp = 2,
		region = "beach",
		count = 40,
	},
	fiber_bush = {
		id = "fiber_bush",
		name = "Arbusto Fibroso",
		harvest = "prompt",
		tierRequired = 0,
		health = 1,
		drops = { { item = "fiber", min = 2, max = 3 }, { item = "berry", min = 1, max = 2, chance = 0.5 } },
		respawn = 60,
		xp = 2,
		region = "jungle",
		count = 70,
	},
	banana_plant = {
		id = "banana_plant",
		name = "Bananeira",
		harvest = "prompt",
		tierRequired = 0,
		health = 1,
		drops = { { item = "banana", min = 1, max = 3 }, { item = "leaf", min = 1, max = 2 } },
		respawn = 120,
		xp = 3,
		region = "jungle",
		count = 30,
	},
	palm_tree = {
		id = "palm_tree",
		name = "Palmeira",
		harvest = "tool",
		toolType = "axe",
		tierRequired = 1,
		health = 60,
		drops = { { item = "wood", min = 1, max = 2 }, { item = "leaf", min = 0, max = 1, chance = 0.5 } },
		finalDrops = { { item = "coconut", min = 1, max = 3 }, { item = "leaf", min = 2, max = 4 } },
		respawn = 150,
		xp = 8,
		region = "beach",
		count = 70,
	},
	jungle_tree = {
		id = "jungle_tree",
		name = "Árvore da Selva",
		harvest = "tool",
		toolType = "axe",
		tierRequired = 1,
		health = 100,
		drops = { { item = "wood", min = 2, max = 3 } },
		finalDrops = { { item = "wood", min = 4, max = 6 }, { item = "stick", min = 2, max = 4 } },
		respawn = 180,
		xp = 12,
		region = "jungle",
		count = 110,
	},
	rock = {
		id = "rock",
		name = "Rocha",
		harvest = "tool",
		toolType = "pickaxe",
		tierRequired = 1,
		health = 80,
		drops = { { item = "stone", min = 1, max = 3 }, { item = "flint", min = 1, max = 1, chance = 0.2 } },
		finalDrops = { { item = "stone", min = 4, max = 6 } },
		respawn = 160,
		xp = 10,
		region = "highlands",
		count = 70,
	},
	iron_rock = {
		id = "iron_rock",
		name = "Veio de Ferro",
		harvest = "tool",
		toolType = "pickaxe",
		tierRequired = 1,
		health = 140,
		drops = { { item = "iron_ore", min = 1, max = 2 }, { item = "stone", min = 0, max = 1 } },
		finalDrops = { { item = "iron_ore", min = 2, max = 4 } },
		respawn = 240,
		xp = 18,
		region = "highlands",
		count = 35,
	},
	crystal_node = {
		id = "crystal_node",
		name = "Cristal da Maré",
		harvest = "tool",
		toolType = "pickaxe",
		tierRequired = 2,
		health = 200,
		drops = { { item = "crystal", min = 1, max = 1 } },
		finalDrops = { { item = "crystal", min = 2, max = 3 } },
		respawn = 300,
		xp = 30,
		region = "cave",
		count = 24,
	},
	obsidian_rock = {
		id = "obsidian_rock",
		name = "Obsidiana",
		harvest = "tool",
		toolType = "pickaxe",
		tierRequired = 3,
		health = 320,
		drops = { { item = "obsidian", min = 1, max = 1, chance = 0.6 } },
		finalDrops = { { item = "obsidian", min = 2, max = 3 } },
		respawn = 420,
		xp = 50,
		region = "volcano",
		count = 14,
	},
}

for id, def in Nodes do
	assert(def.id == id, "Nó inconsistente: " .. id)
end

return Nodes
