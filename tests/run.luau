-- Testes automatizados da lógica pura e da consistência das configs.
-- Rodar (na raiz do projeto):  lune run tests/run
-- Usa o Lune para carregar os módulos com os tipos reais do Roblox (Color3, Vector3, CFrame).

local load = require("./loader")

local Inventory = load("src/shared/Logic/Inventory")
local Rules = load("src/shared/Logic/Rules")
local Items = load("src/shared/Config/Items")
local Recipes = load("src/shared/Config/Recipes")
local Structures = load("src/shared/Config/Structures")
local Nodes = load("src/shared/Config/Nodes")
local Creatures = load("src/shared/Config/Creatures")
local Regions = load("src/shared/Config/Regions")
local Progression = load("src/shared/Config/Progression")
local Monetization = load("src/shared/Config/Monetization")
local Game = load("src/shared/Config/Game")

local passed, failed = 0, 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		failed += 1
		print("FALHOU: " .. name .. "\n   " .. tostring(err))
	end
end
local function eq(a, b, msg)
	if a ~= b then
		error((msg or "") .. " esperado " .. tostring(b) .. ", obtido " .. tostring(a), 2)
	end
end
local function stackOf(id)
	return Items[id] and Items[id].stack or 99
end

-- ===== Inventário =====
test("add empilha e respeita stack", function()
	local inv = Inventory.new(4)
	eq(Inventory.add(inv, "wood", 150, 99), 150)
	eq(Inventory.count(inv, "wood"), 150)
	eq(inv.slots[1].n + inv.slots[2].n, 150)
end)
test("add devolve o que não coube", function()
	local inv = Inventory.new(2)
	eq(Inventory.add(inv, "wood", 250, 99), 198)
	eq(Inventory.count(inv, "wood"), 198)
end)
test("recursos evitam a hotbar", function()
	local inv = Inventory.new(10)
	Inventory.add(inv, "stone", 5, 99, 6)
	eq(inv.slots[7].id, "stone")
	eq(inv.slots[1], nil)
end)
test("ferramentas preferem a hotbar", function()
	local inv = Inventory.new(10)
	Inventory.add(inv, "stone_axe", 1, 1, 6, true)
	eq(inv.slots[1].id, "stone_axe")
end)
test("remove é atômico", function()
	local inv = Inventory.new(4)
	Inventory.add(inv, "wood", 5, 99)
	eq(Inventory.remove(inv, "wood", 6), false)
	eq(Inventory.count(inv, "wood"), 5)
	eq(Inventory.remove(inv, "wood", 5), true)
	eq(Inventory.count(inv, "wood"), 0)
end)
test("removeAll não remove parcialmente", function()
	local inv = Inventory.new(4)
	Inventory.add(inv, "wood", 10, 99)
	eq(Inventory.removeAll(inv, { wood = 5, stone = 1 }), false)
	eq(Inventory.count(inv, "wood"), 10)
end)
test("move troca e mescla", function()
	local inv = Inventory.new(4)
	inv.slots[1] = { id = "wood", n = 90 }
	inv.slots[2] = { id = "wood", n = 20 }
	eq(Inventory.move(inv, 2, inv, 1, stackOf), true)
	eq(inv.slots[1].n, 99)
	eq(inv.slots[2].n, 11)
	inv.slots[3] = { id = "stone", n = 3 }
	Inventory.move(inv, 3, inv, 2, stackOf)
	eq(inv.slots[2].id, "stone")
	eq(inv.slots[3].id, "wood")
end)
test("move rejeita índices inválidos", function()
	local inv = Inventory.new(4)
	inv.slots[1] = { id = "wood", n = 1 }
	eq(Inventory.move(inv, 1, inv, 99, stackOf), false)
	eq(Inventory.move(inv, 0, inv, 2, stackOf), false)
end)
test("move entre inventários (baú)", function()
	local a, b = Inventory.new(4), Inventory.new(4)
	a.slots[1] = { id = "wood", n = 10 }
	Inventory.move(a, 1, b, 3, stackOf)
	eq(a.slots[1], nil)
	eq(b.slots[3].n, 10)
end)
test("serialize/deserialize ida e volta + validação", function()
	local inv = Inventory.new(6)
	Inventory.add(inv, "wood", 30, 99)
	inv.slots[6] = { id = "stone_axe", n = 1 }
	local data = Inventory.serialize(inv)
	table.insert(data, { "item_hackeado", 999, 2 })
	table.insert(data, { "wood", 99999, 3 })
	local inv2 = Inventory.deserialize(data, 6, function(id) return Items[id] ~= nil end, stackOf)
	eq(inv2.slots[6].id, "stone_axe")
	eq(Inventory.count(inv2, "item_hackeado"), 0)
	eq(Inventory.count(inv2, "wood"), 30 + 99)
end)
test("resize devolve excedente", function()
	local inv = Inventory.new(6)
	inv.slots[6] = { id = "wood", n = 5 }
	local over = Inventory.resize(inv, 4)
	eq(#over, 1)
	eq(inv.size, 4)
end)

-- ===== Crafting =====
test("craft machado de pedra", function()
	local inv = Inventory.new(24)
	Inventory.add(inv, "stick", 3, 99, 6)
	Inventory.add(inv, "stone", 2, 99, 6)
	Inventory.add(inv, "fiber", 2, 99, 6)
	local ok = Rules.craft(inv, Recipes.byId.stone_axe, 1, false, 1, 6)
	eq(ok, true)
	eq(Inventory.count(inv, "stone_axe"), 1)
	eq(Inventory.count(inv, "stick"), 0)
	eq(inv.slots[1].id, "stone_axe")
end)
test("craft exige estação, nível e materiais", function()
	local inv = Inventory.new(24)
	Inventory.add(inv, "wood", 100, 99)
	local ok, why = Rules.canCraft(inv, Recipes.byId.wood_wall, 5, false, 50)
	eq(ok, false)
	eq(why, "Precisa estar perto de: workbench")
	ok, why = Rules.canCraft(inv, Recipes.byId.wood_wall, 1, true, 50)
	eq(ok, false)
	eq(why, "Requer nível 2")
	ok = Rules.canCraft(inv, Recipes.byId.chest, 3, true, 10)
	eq(ok, false) -- falta fibra
end)
test("craft múltiplo e quantidade inválida", function()
	local inv = Inventory.new(24)
	Inventory.add(inv, "raw_meat", 5, 30)
	eq(Rules.craft(inv, Recipes.byId.cooked_meat, 1, true, 30, 6, 5), true)
	eq(Inventory.count(inv, "cooked_meat"), 5)
	eq((Rules.canCraft(inv, Recipes.byId.cooked_meat, 1, true, 30, 1.5)), false)
	eq((Rules.canCraft(inv, Recipes.byId.cooked_meat, 1, true, 30, -1)), false)
end)

-- ===== Sobrevivência =====
test("fome e sede caem e zeradas causam dano", function()
	local s = { health = 100, hunger = 0.01, thirst = 50, warmth = 100 }
	local dmg = Rules.tickSurvival(s, { dt = 1, night = false, storm = false, nearFire = false, armorWarmth = 0 }, Game)
	eq(s.hunger, 0)
	eq(dmg, Game.STARVE_DAMAGE)
end)
test("fogueira aquece à noite; armadura reduz perda", function()
	local s = { health = 100, hunger = 100, thirst = 100, warmth = 50 }
	Rules.tickSurvival(s, { dt = 1, night = true, storm = false, nearFire = true, armorWarmth = 0 }, Game)
	eq(s.warmth, 50 + Game.WARMTH_GAIN_FIRE)
	local a = { health = 100, hunger = 100, thirst = 100, warmth = 50 }
	local b = { health = 100, hunger = 100, thirst = 100, warmth = 50 }
	Rules.tickSurvival(a, { dt = 1, night = true, storm = false, nearFire = false, armorWarmth = 0 }, Game)
	Rules.tickSurvival(b, { dt = 1, night = true, storm = false, nearFire = false, armorWarmth = 0.5 }, Game)
	assert(b.warmth > a.warmth, "armadura deveria reduzir perda de calor")
end)
test("regenera bem alimentado", function()
	local s = { health = 50, hunger = 100, thirst = 100, warmth = 100 }
	local dmg, heal = Rules.tickSurvival(s, { dt = 1, night = false, storm = false, nearFire = false, armorWarmth = 0 }, Game)
	eq(dmg, 0)
	eq(heal, Game.REGEN)
end)
test("consumir comida", function()
	local s = { health = 50, hunger = 90, thirst = 10, warmth = 100 }
	local ok, heal = Rules.consume(s, Items.cooked_meat, 100)
	eq(ok, true)
	eq(s.hunger, 100)
	eq(heal, 15)
	eq((Rules.consume(s, Items.wood, 100)), false)
end)

-- ===== Progressão =====
test("XP sobe múltiplos níveis", function()
	local p = { level = 1, xp = 0 }
	local need = Progression.xpForLevel(1) + Progression.xpForLevel(2)
	local ups = Rules.addXp(p, need + 5, Progression.xpForLevel, Game.MAX_LEVEL)
	eq(#ups, 2)
	eq(p.level, 3)
	eq(p.xp, 5)
end)
test("XP para no nível máximo", function()
	local p = { level = Game.MAX_LEVEL - 1, xp = 0 }
	Rules.addXp(p, 10 ^ 9, Progression.xpForLevel, Game.MAX_LEVEL)
	eq(p.level, Game.MAX_LEVEL)
	eq(p.xp, 0)
end)
test("dano de ferramenta por tier", function()
	eq(Rules.nodeDamage(Nodes.rock, Items.stone_axe), 0)
	eq(Rules.nodeDamage(Nodes.rock, Items.stone_pickaxe), 10)
	eq(Rules.nodeDamage(Nodes.crystal_node, Items.stone_pickaxe), 0)
	eq(Rules.nodeDamage(Nodes.rock, Items.iron_pickaxe), 25)
	eq(Rules.nodeDamage(Nodes.fiber_bush, Items.stone_axe), 0)
end)
test("drops respeitam chance", function()
	local d = Rules.rollDrops(Nodes.loose_stone.drops, function(a) return a end, function() return 0.99 end)
	eq(d.stone, 1)
	eq(d.flint, nil)
end)
test("missões diárias determinísticas e sem repetição", function()
	local a = Rules.pickDaily(Progression.dailyPool, 3, 12345)
	local b = Rules.pickDaily(Progression.dailyPool, 3, 12345)
	eq(#a, 3)
	for i = 1, 3 do
		eq(a[i].id, b[i].id)
	end
	assert(a[1].id ~= a[2].id and a[2].id ~= a[3].id and a[1].id ~= a[3].id, "repetiu missão")
end)
test("sequência de login", function()
	eq(select(1, Rules.loginStreak(nil, 0, 100)), 1)
	local s, r = Rules.loginStreak(99, 3, 100)
	eq(s, 4); eq(r, true)
	s, r = Rules.loginStreak(100, 4, 100)
	eq(s, 4); eq(r, false)
	s = Rules.loginStreak(90, 4, 100)
	eq(s, 1)
end)

-- ===== Consistência das configs =====
test("receitas referenciam itens existentes", function()
	for _, r in Recipes.list do
		assert(Items[r.output], "saída inexistente: " .. r.output)
		for id in r.cost do
			assert(Items[id], r.id .. " custo inexistente: " .. id)
		end
	end
end)
test("todo item de estrutura tem estrutura e receita", function()
	for id, def in Items do
		if def.category == "structure" then
			assert(Structures.defs[def.structure], "estrutura faltando: " .. id)
			assert(Recipes.byId[id], "sem receita: " .. id)
		end
	end
end)
test("drops de nós e criaturas existem", function()
	for id, n in Nodes do
		for _, d in n.drops do assert(Items[d.item], id .. " drop: " .. d.item) end
		for _, d in n.finalDrops or {} do assert(Items[d.item], id .. " finalDrop: " .. d.item) end
		assert(Regions.byId[n.region], id .. " região inválida")
	end
	for id, c in Creatures do
		for _, d in c.drops do assert(Items[d.item], id .. " drop: " .. d.item) end
		for _, r in c.regions do assert(Regions.byId[r], id .. " região: " .. r) end
	end
end)
test("todo item obtenível (sem itens órfãos)", function()
	local obtainable = {}
	for _, r in Recipes.list do obtainable[r.output] = true end
	for _, n in Nodes do
		for _, d in n.drops do obtainable[d.item] = true end
		for _, d in n.finalDrops or {} do obtainable[d.item] = true end
	end
	for _, c in Creatures do for _, d in c.drops do obtainable[d.item] = true end end
	obtainable.fresh_water = true -- coletor de chuva
	for id in Items do
		assert(obtainable[id], "item impossível de obter: " .. id)
	end
end)
test("progressão sem bloqueio (tier de ferramentas)", function()
	-- nós de cada tier precisam de uma ferramenta craftável com tier suficiente
	for id, n in Nodes do
		if n.harvest == "tool" then
			local found = false
			for _, r in Recipes.list do
				local it = Items[r.output]
				if it.toolType == n.toolType and (it.tier or 0) >= n.tierRequired then
					found = true
				end
			end
			assert(found, "nenhuma ferramenta para " .. id)
		end
	end
end)
test("produtos de monetização têm preço e nunca IDs inventados", function()
	for k, p in Monetization.gamePasses do
		assert(p.price > 0, k)
		assert(type(p.id) == "number", k)
	end
	for k, p in Monetization.devProducts do
		assert(p.price > 0, k)
		if p.items then
			for id in p.items do assert(Items[id], k .. " item: " .. id) end
		end
	end
	for _, s in Monetization.shellShop do
		if s.items then for id in s.items do assert(Items[id], s.id) end end
	end
end)
test("recompensas de login referenciam itens", function()
	for _, r in Progression.loginRewards do
		for id in r.items do assert(Items[id], id) end
	end
end)

print(string.format("\n%d testes passaram, %d falharam", passed, failed))
if failed > 0 then
	error("Testes falharam")
end
