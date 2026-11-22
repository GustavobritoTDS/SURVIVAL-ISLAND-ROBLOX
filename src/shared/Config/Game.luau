--!strict
-- Parâmetros gerais de balanceamento.

return {
	-- Inventário
	INVENTORY_SLOTS = 24,
	BIG_BACKPACK_BONUS = 12, -- Game Pass "Mochila do Explorador"
	HOTBAR_SLOTS = 6,

	-- Sobrevivência (por segundo)
	MAX_STAT = 100,
	HUNGER_DECAY = 100 / 900, -- 15 min de 100 a 0
	THIRST_DECAY = 100 / 660, -- 11 min
	STARVE_DAMAGE = 1.5, -- dano/s com fome ou sede zerada
	COLD_DAMAGE = 1.0, -- dano/s com calor zerado
	REGEN = 0.6, -- vida/s quando fome e sede > 60
	WARMTH_LOSS_NIGHT = 0.9,
	WARMTH_LOSS_STORM = 1.4,
	WARMTH_GAIN_FIRE = 6,
	WARMTH_GAIN_DAY = 2,
	SURVIVAL_TICK = 1,

	-- Morte
	DEATH_DROP_FRACTION = 0.5, -- fração dos recursos (não ferramentas) deixada na bolsa
	DEATH_BAG_LIFETIME = 300,
	RESPAWN_PROTECTION = 6, -- segundos de invulnerabilidade

	-- Dia/noite (segundos reais)
	DAY_LENGTH = 600, -- dia completo (dia + noite)
	NIGHT_START = 18, -- ClockTime
	NIGHT_END = 6,

	-- Clima
	WEATHER_MIN = 180,
	WEATHER_MAX = 420,

	-- Progressão
	MAX_LEVEL = 30,
	VIP_XP_BONUS = 0.1,

	-- Anti-exploit
	MAX_REMOTE_RATE = 20, -- chamadas/s por remote por jogador
	HIT_RANGE_TOLERANCE = 4,

	-- Salvamento
	AUTOSAVE_INTERVAL = 120,
	DATA_VERSION = 1,
	DATASTORE_NAME = "SurvivalIsland_PlayerData_v1",
}
