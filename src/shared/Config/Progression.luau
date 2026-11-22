--!nonstrict
-- Níveis, missões diárias, conquistas e recompensa de login.

local Progression = {}

-- XP necessário para ir do nível n para n+1
function Progression.xpForLevel(level: number): number
	return math.floor(60 + 40 * level ^ 1.5)
end

-- Missões diárias: 3 sorteadas por dia (determinístico pelo dia + userId)
Progression.dailyPool = {
	{ id = "chop_wood", text = "Colete 40 Madeira", stat = "collect_wood", goal = 40, shells = 30, xp = 60 },
	{ id = "mine_stone", text = "Colete 40 Pedra", stat = "collect_stone", goal = 40, shells = 30, xp = 60 },
	{ id = "gather_fiber", text = "Colete 30 Fibra", stat = "collect_fiber", goal = 30, shells = 25, xp = 50 },
	{ id = "craft_items", text = "Fabrique 8 itens", stat = "craft", goal = 8, shells = 35, xp = 70 },
	{ id = "build_things", text = "Construa 10 estruturas", stat = "build", goal = 10, shells = 40, xp = 80 },
	{ id = "hunt", text = "Derrote 6 criaturas", stat = "kill", goal = 6, shells = 40, xp = 90 },
	{ id = "survive_night", text = "Sobreviva a uma noite", stat = "nights", goal = 1, shells = 50, xp = 100 },
	{ id = "cook_food", text = "Cozinhe 5 refeições", stat = "cook", goal = 5, shells = 30, xp = 60 },
	{
		id = "iron_ore",
		text = "Colete 15 Minério de Ferro",
		stat = "collect_iron_ore",
		goal = 15,
		shells = 45,
		xp = 90,
	},
}
Progression.DAILY_COUNT = 3

-- Conquistas permanentes
Progression.achievements = {
	{
		id = "first_tool",
		text = "Primeira Ferramenta",
		desc = "Fabrique um item",
		stat = "craft",
		goal = 1,
		shells = 20,
	},
	{
		id = "lumberjack",
		text = "Lenhador",
		desc = "Colete 500 Madeira",
		stat = "collect_wood",
		goal = 500,
		shells = 100,
	},
	{ id = "miner", text = "Mineiro", desc = "Colete 500 Pedra", stat = "collect_stone", goal = 500, shells = 100 },
	{
		id = "architect",
		text = "Arquiteto",
		desc = "Construa 100 estruturas",
		stat = "build",
		goal = 100,
		shells = 150,
	},
	{ id = "hunter", text = "Caçador", desc = "Derrote 50 criaturas", stat = "kill", goal = 50, shells = 150 },
	{ id = "night_owl", text = "Coruja", desc = "Sobreviva a 10 noites", stat = "nights", goal = 10, shells = 200 },
	{
		id = "crystal_hunter",
		text = "Caçador de Cristais",
		desc = "Colete 25 Cristais",
		stat = "collect_crystal",
		goal = 25,
		shells = 200,
	},
	{
		id = "shade_slayer",
		text = "Caça-Sombras",
		desc = "Derrote 25 Sombras da Maré",
		stat = "kill_tide_shade",
		goal = 25,
		shells = 250,
	},
	{
		id = "rescued",
		text = "Resgatado!",
		desc = "Acenda o Farol de Resgate",
		stat = "beacon",
		goal = 1,
		shells = 1000,
	},
}

-- Recompensa por dias seguidos de login (ciclo de 7)
Progression.loginRewards = {
	{ shells = 20, items = { berry = 5 } },
	{ shells = 30, items = { cooked_meat = 2 } },
	{ shells = 40, items = { wood = 20 } },
	{ shells = 50, items = { stone = 20, flint = 3 } },
	{ shells = 60, items = { iron_ore = 6 } },
	{ shells = 80, items = { tropical_stew = 1 } },
	{ shells = 150, items = { crystal = 2 } },
}

-- Recompensa ao subir de nível
function Progression.levelReward(level: number): number
	return 10 + level * 5
end

return Progression
