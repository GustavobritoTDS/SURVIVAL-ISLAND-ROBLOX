--!nonstrict
-- Jornada do Náufrago: o guia Bento conduz o jogador etapa por etapa.
-- check.type:
--   "reach"   -> chegar perto de check.pos (raio check.radius)
--   "counter" -> aumentar contadores desde o início da etapa (check.stats = { stat = n })
--   "level"   -> atingir nível check.level
-- target: dica para a seta de navegação no cliente ("node:<id>", "pos", "structure:<id>")

local V = Vector3.new

local Guide = {}

Guide.NPC = {
	name = "Velho Bento",
	title = "Sobrevivente experiente",
	-- posição relativa ao SPAWN (ao lado da fogueira do naufrágio)
	offset = V(4, 0, -16),
}

Guide.stages = {
	{
		id = "intro",
		title = "O despertar",
		objective = "Explore os destroços do navio",
		check = { type = "reach", pos = V(46, 5, 480), radius = 24 }, -- destroços do Gaivota
		target = "pos",
		intro = {
			"Ei! Ei, acorda! Graças aos céus, você está vivo...",
			"Eu sou o Bento. Fui cozinheiro do navio Gaivota... e agora somos só nós dois nesta praia.",
			"A tempestade partiu o casco ao meio. Mas já passei por um naufrágio antes, há muitos anos.",
			"Escuta: nesta ilha, quem não se prepara não vê o sol nascer de novo.",
			"Primeiro, dê uma olhada nos destroços ali na areia. Vai que sobrou algo útil.",
		},
		reward = { shells = 10, xp = 15 },
		done = { "Hum... só madeira podre e cordas encharcadas. Teremos que começar do zero." },
	},
	{
		id = "sticks",
		title = "Mãos à obra",
		objective = "Colete 5 Galhos e 3 Pedras na praia",
		check = { type = "counter", stats = { collect_stick = 5, collect_stone = 3 } },
		target = "node:stick_pile",
		intro = {
			"Toda sobrevivência começa no chão. Galhos e pedras soltas estão espalhados pela areia.",
			"Chegue perto e segure E, ou toque no cartão, para pegar.",
			"Fique de olho: às vezes as pedras escondem Sílex. É ele que acende o fogo.",
		},
		reward = { shells = 15, xp = 25, items = { fiber = 2 } },
		done = { "Bom trabalho! Toma, umas fibras que eu tinha no bolso." },
	},
	{
		id = "fiber",
		title = "Cordas de fibra",
		objective = "Colete 4 Fibras nos arbustos da selva",
		check = { type = "counter", stats = { collect_fiber = 4 } },
		target = "node:fiber_bush",
		intro = {
			"Sem corda nada fica de pé. Os arbustos da selva têm fibras resistentes.",
			"E se achar frutinhas, coma! Fome e sede matam mais que qualquer fera.",
		},
		reward = { shells = 15, xp = 25, items = { berry = 3 } },
		done = { "Isso! Agora você tem tudo para a sua primeira ferramenta." },
	},
	{
		id = "axe",
		title = "A primeira ferramenta",
		objective = "Fabrique um Machado de Pedra (botão Criar)",
		check = { type = "counter", stats = { craft_stone_axe = 1 } },
		target = "none",
		intro = {
			"Abra o menu Criar (tecla C) e faça um Machado de Pedra.",
			"Três galhos, duas pedras e duas fibras. Amarre bem!",
		},
		reward = { shells = 20, xp = 30 },
		done = { "Um machado de respeito! Meu velho mestre teria orgulho." },
	},
	{
		id = "wood",
		title = "Madeira para o fogo",
		objective = "Corte palmeiras: consiga 8 Madeiras",
		check = { type = "counter", stats = { collect_wood = 8 } },
		target = "node:palm_tree",
		intro = {
			"Selecione o machado na barra rápida e golpeie uma palmeira.",
			"Quando ela cair, ainda solta cocos: água e comida numa casca só.",
		},
		reward = { shells = 20, xp = 35, items = { flint = 1 } },
		done = { "Já dá para fazer fogo. Toma este Sílex, guardei para uma emergência." },
	},
	{
		id = "fire",
		title = "Cuidado com a noite",
		objective = "Fabrique e coloque uma Fogueira",
		check = { type = "counter", stats = { build_campfire = 1 } },
		target = "none",
		intro = {
			"Agora preste muita atenção. Quando o sol se põe, a maré sobe...",
			"E com ela vêm as Sombras da Maré. Olhos brilhando, corpo de névoa.",
			"Elas odeiam o fogo. Sem uma fogueira, você congela e vira presa.",
			"Faça uma Fogueira no Criar e coloque-a com o botão Construir (tecla B).",
		},
		reward = { shells = 25, xp = 40, items = { stick = 4 } },
		done = { "Que calor bom... Perto do fogo você se aquece, cozinha e fica protegido." },
	},
	{
		id = "night",
		title = "A primeira noite",
		objective = "Sobreviva a uma noite",
		check = { type = "counter", stats = { nights = 1 } },
		target = "none",
		intro = {
			"Agora é aguentar até o amanhecer. Fique perto do fogo quando escurecer.",
			"Se uma Sombra chegar perto, enfrente-a com sua ferramenta ou corra para a luz.",
			"Enquanto ainda é dia, aproveite para juntar mais recursos.",
		},
		reward = { shells = 40, xp = 60, items = { cooked_meat = 2 } },
		done = { "O sol nasceu e você está inteiro! Agora sim, um verdadeiro náufrago." },
	},
	{
		id = "food",
		title = "Barriga cheia",
		objective = "Cace um animal e cozinhe a carne na fogueira",
		check = { type = "counter", stats = { cook = 1 } },
		target = "none",
		intro = {
			"Frutas não seguram ninguém por muito tempo. Caranguejos andam pela praia e javalis pela selva.",
			"Cace um, depois cozinhe a carne perto da fogueira, no menu Criar, aba Cozinha.",
			"Carne crua faz mal, hein!",
		},
		reward = { shells = 30, xp = 50 },
		done = { "Hmm, que cheiro! Comida quente recupera vida também." },
	},
	{
		id = "workbench",
		title = "Oficina do náufrago",
		objective = "Construa uma Bancada",
		check = { type = "counter", stats = { build_workbench = 1 } },
		target = "none",
		intro = {
			"Para algo melhor que galhos, você precisa de uma Bancada.",
			"Com ela você faz paredes, pisos, portas, baús e muito mais.",
		},
		reward = { shells = 35, xp = 60, items = { wood = 10 } },
		done = { "Excelente! Agora você pode erguer um abrigo de verdade." },
	},
	{
		id = "totem",
		title = "Um lar na ilha",
		objective = "Construa um Totem do Território",
		check = { type = "counter", stats = { build_base_totem = 1 } },
		target = "none",
		intro = {
			"Escolha um bom lugar, longe da praia onde chegamos, e crave um Totem do Território.",
			"Tudo o que construir perto dele fica salvo e protegido de estranhos.",
			"E faça uma Cama de Folhas: se cair em combate, você acorda nela.",
		},
		reward = { shells = 50, xp = 80 },
		done = { "Agora você tem um lar. Volta e meia passo por lá para um café." },
	},
	{
		id = "explore",
		title = "Além da selva",
		objective = "Alcance o nível 4 para explorar o Planalto de Pedra",
		check = { type = "level", level = 4 },
		target = "none",
		intro = {
			"Ao norte fica o Planalto de Pedra. Lá tem ferro, mas também lobos.",
			"Fique mais forte antes de ir: colete, construa e complete as Missões diárias.",
		},
		reward = { shells = 60, xp = 0, items = { leather_armor = 1 } },
		done = { "Leve esta armadura de couro. Foi do capitão, que descanse em paz." },
	},
	{
		id = "beacon",
		title = "O Farol de Resgate",
		objective = "Construa e acenda o Farol de Resgate",
		check = { type = "counter", stats = { beacon = 1 } },
		target = "none",
		intro = {
			"Agora vou te contar o segredo desta ilha...",
			"No alto do vulcão existiu um farol. As Sombras o apagaram há muito tempo.",
			"Se alguém erguer um novo Farol, os navios vão nos ver... e seremos resgatados.",
			"Você vai precisar de cristais da caverna, obsidiana do vulcão e Essência das próprias Sombras.",
			"É uma longa jornada. Mas eu acredito em você, parceiro.",
		},
		reward = { shells = 500, xp = 0 },
		done = { "A LUZ! Olha a luz! Estamos salvos... Obrigado, parceiro. Nunca vou esquecer." },
	},
}

-- Fala do Bento quando você conversa sem objetivo novo (dicas aleatórias)
Guide.tips = {
	"Fome e sede caem com o tempo. Cocos matam as duas de uma vez.",
	"À noite, fique perto do fogo. As Sombras não suportam a luz.",
	"Tempestades esfriam rápido. Uma armadura de couro ajuda a manter o calor.",
	"Pedra contra ferro não dá. Para minerar cristal você vai precisar de uma picareta de ferro.",
	"Baús e portas só abrem para você e seus amigos.",
	"Construções fora do Totem somem quando você sai. Não esqueça!",
}

return Guide
