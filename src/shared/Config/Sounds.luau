--!strict
-- Efeitos sonoros licenciados para uso em experiências Roblox (biblioteca oficial:
-- criadores "ProSoundEffects" e "Roblox" no Creator Store). Volumes baixos de propósito.
-- ids = lista de variações (uma é sorteada para não soar repetitivo).

export type Sfx = { ids: { number }, volume: number, pitch: { number }? }

local Sounds: { [string]: Sfx } = {
	-- coleta e ferramentas
	collect = { ids = { 9114576507 }, volume = 0.25, pitch = { 1.05, 1.25 } }, -- folhas/arbusto
	pickup = { ids = { 15675055424 }, volume = 0.18, pitch = { 1.1, 1.3 } }, -- "pop" suave de item
	chop = { ids = { 9120808574, 9120811299, 9120809592, 9120808557 }, volume = 0.35, pitch = { 0.95, 1.08 } },
	mine = { ids = { 9125869504, 9125869495 }, volume = 0.32, pitch = { 0.95, 1.1 } },
	treeFall = { ids = { 9113225979, 9113225986 }, volume = 0.3, pitch = { 0.85, 0.95 } },
	swing = { ids = { 9120972321 }, volume = 0.22, pitch = { 0.95, 1.15 } },
	-- combate
	creatureHit = { ids = { 9125467298, 9125466463 }, volume = 0.3, pitch = { 0.9, 1.1 } },
	-- sobrevivência
	eat = { ids = { 9113959343, 9113959332 }, volume = 0.3, pitch = { 0.95, 1.1 } },
	drink = { ids = { 9114172109, 9114171960 }, volume = 0.35, pitch = { 0.95, 1.05 } },
	-- construção e interface
	build = { ids = { 9120888980 }, volume = 0.35, pitch = { 0.9, 1.05 } },
	craft = { ids = { 9116394545 }, volume = 0.3, pitch = { 1.0, 1.1 } },
	reward = { ids = { 9116395089 }, volume = 0.4, pitch = { 1.0, 1.0 } },
	click = { ids = { 15675032796 }, volume = 0.25, pitch = { 1.0, 1.1 } },
	notify = { ids = { 17208372272 }, volume = 0.2, pitch = { 1.0, 1.0 } },
	coin = { ids = { 127645268874265 }, volume = 0.25, pitch = { 1.0, 1.0 } },
	-- ambiente (loops)
	waves = { ids = { 9119677305 }, volume = 0.12 },
	jungle = { ids = { 9112801967 }, volume = 0.1 },
	night = { ids = { 9112762281 }, volume = 0.1 },
	campfire = { ids = { 9112780193 }, volume = 0.35 },
	menuMusic = { ids = { 15675069601 }, volume = 0.18 },
}

return Sounds
