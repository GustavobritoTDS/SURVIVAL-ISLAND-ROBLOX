--!nonstrict
-- Game Passes, Developer Products e loja de Conchas (moeda do jogo).
--
-- IMPORTANTE: os campos `id` ficam 0 até os produtos serem criados no Creator Dashboard.
-- Com id = 0 o item aparece na loja como "Em breve" e nenhuma compra é iniciada.
-- Depois de criar cada produto, cole aqui o ID REAL gerado pela plataforma.

local Monetization = {}

Monetization.gamePasses = {
	vip = {
		id = 0,
		name = "VIP do Náufrago",
		price = 299,
		icon = "👑",
		description = "Tag VIP dourada, +10% de XP, +25 Conchas por dia e trilha dourada. Sem vantagem em combate.",
	},
	big_backpack = {
		id = 0,
		name = "Mochila do Explorador",
		price = 149,
		icon = "🎒",
		description = "+12 espaços no inventário (24 → 36).",
	},
	parrot = {
		id = 0,
		name = "Papagaio Companheiro",
		price = 99,
		icon = "🦜",
		description = "Um papagaio colorido que voa ao seu lado. Puramente cosmético.",
	},
	trails = {
		id = 0,
		name = "Rastros Lendários",
		price = 79,
		icon = "✨",
		description = "Libera 4 rastros exclusivos (Maré, Brasa, Cristal, Aurora).",
	},
}

Monetization.devProducts = {
	shells_small = { id = 0, name = "Saco de Conchas", price = 25, icon = "🐚", shells = 100, description = "+100 Conchas" },
	shells_medium = { id = 0, name = "Baú de Conchas", price = 99, icon = "🐚", shells = 450, description = "+450 Conchas (+12% bônus)" },
	shells_large = { id = 0, name = "Tesouro de Conchas", price = 299, icon = "🐚", shells = 1500, description = "+1500 Conchas (+25% bônus)" },
	supply_crate = { id = 0, name = "Caixa de Suprimentos", price = 49, icon = "📦", items = { wood = 40, stone = 40, fiber = 20, cooked_meat = 5, coconut = 5 }, description = "Recursos para acelerar sua base" },
	keep_items = { id = 0, name = "Amuleto da Maré", price = 35, icon = "🧿", description = "Na próxima morte você não perde recursos." },
}

-- Loja de Conchas (moeda ganha jogando). Somente cosméticos e conveniências leves.
Monetization.shellShop = {
	{ id = "trail_sand", kind = "trail", name = "Rastro de Areia", price = 150, icon = "🏖️", color = Color3.fromRGB(240, 215, 150) },
	{ id = "trail_leaf", kind = "trail", name = "Rastro de Folhas", price = 250, icon = "🍃", color = Color3.fromRGB(90, 200, 100) },
	{ id = "trail_ocean", kind = "trail", name = "Rastro do Oceano", price = 400, icon = "🌊", color = Color3.fromRGB(60, 160, 240) },
	{ id = "title_survivor", kind = "title", name = "Título: Sobrevivente", price = 300, icon = "🏷️" },
	{ id = "title_explorer", kind = "title", name = "Título: Explorador", price = 600, icon = "🧭" },
	{ id = "title_legend", kind = "title", name = "Título: Lenda da Ilha", price = 1500, icon = "🌟" },
	{ id = "food_pack", kind = "items", name = "Cesta de Frutas", price = 60, icon = "🧺", items = { banana = 5, coconut = 5 } },
}

-- Rastros exclusivos do Game Pass "Rastros Lendários"
Monetization.passTrails = {
	{ id = "trail_tide", name = "Maré", color = Color3.fromRGB(70, 220, 230) },
	{ id = "trail_ember", name = "Brasa", color = Color3.fromRGB(255, 120, 40) },
	{ id = "trail_crystal", name = "Cristal", color = Color3.fromRGB(160, 240, 255) },
	{ id = "trail_aurora", name = "Aurora", color = Color3.fromRGB(180, 120, 255) },
}

function Monetization.productById(productId: number): (string?, any)
	if productId == 0 then
		return nil, nil
	end
	for key, p in Monetization.devProducts do
		if p.id == productId then
			return key, p
		end
	end
	return nil, nil
end

return Monetization
