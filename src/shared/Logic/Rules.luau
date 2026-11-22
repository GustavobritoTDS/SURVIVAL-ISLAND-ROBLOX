--!strict
-- Regras puras de jogo (crafting, sobrevivência, XP, sorteios).
-- Sem APIs do Roblox: tudo recebe dados por parâmetro -> testável fora do Studio.

local Inventory = require(script and script.Parent and script.Parent.Inventory or "./Inventory")

local Rules = {}

-- ===== Crafting =====
-- Retorna (ok, motivo)
function Rules.canCraft(
	inv: any,
	recipe: any,
	level: number,
	hasStation: boolean,
	stackMax: number,
	times: number?
): (boolean, string?)
	local t = times or 1
	if t < 1 or t > 50 or t ~= math.floor(t) then
		return false, "Quantidade inválida"
	end
	if level < recipe.level then
		return false, "Requer nível " .. recipe.level
	end
	if recipe.station and not hasStation then
		return false, "Precisa estar perto de: " .. recipe.station
	end
	for id, n in recipe.cost do
		if Inventory.count(inv, id) < n * t then
			return false, "Faltam materiais"
		end
	end
	-- espaço: considera que os custos liberam espaço só se esvaziarem pilhas (conservador)
	if Inventory.space(inv, recipe.output, stackMax) < recipe.amount * t then
		return false, "Inventário cheio"
	end
	return true, nil
end

function Rules.craft(
	inv: any,
	recipe: any,
	level: number,
	hasStation: boolean,
	stackMax: number,
	hotbar: number,
	times: number?
): (boolean, string?)
	local t = times or 1
	local ok, why = Rules.canCraft(inv, recipe, level, hasStation, stackMax, t)
	if not ok then
		return false, why
	end
	local total: { [string]: number } = {}
	for id, n in recipe.cost do
		total[id] = n * t
	end
	Inventory.removeAll(inv, total)
	Inventory.add(inv, recipe.output, recipe.amount * t, stackMax, hotbar, stackMax == 1)
	return true, nil
end

-- ===== Sobrevivência =====
export type Stats = { health: number, hunger: number, thirst: number, warmth: number }
export type Env = {
	dt: number,
	night: boolean,
	storm: boolean,
	nearFire: boolean,
	armorWarmth: number, -- 0..1
	vip: boolean?,
}

-- Aplica um passo de simulação; retorna dano sofrido (>=0) e cura (>=0)
function Rules.tickSurvival(s: Stats, env: Env, cfg: any): (number, number)
	local dt = env.dt
	s.hunger = math.max(0, s.hunger - cfg.HUNGER_DECAY * dt)
	s.thirst = math.max(0, s.thirst - cfg.THIRST_DECAY * dt * (env.storm and 0.6 or 1))

	if env.nearFire then
		s.warmth = math.min(cfg.MAX_STAT, s.warmth + cfg.WARMTH_GAIN_FIRE * dt)
	elseif env.night or env.storm then
		local loss = env.storm and cfg.WARMTH_LOSS_STORM or cfg.WARMTH_LOSS_NIGHT
		loss *= (1 - math.clamp(env.armorWarmth, 0, 0.9))
		s.warmth = math.max(0, s.warmth - loss * dt)
	else
		s.warmth = math.min(cfg.MAX_STAT, s.warmth + cfg.WARMTH_GAIN_DAY * dt)
	end

	local damage = 0
	if s.hunger <= 0 then
		damage += cfg.STARVE_DAMAGE * dt
	end
	if s.thirst <= 0 then
		damage += cfg.STARVE_DAMAGE * dt
	end
	if s.warmth <= 0 then
		damage += cfg.COLD_DAMAGE * dt
	end
	local heal = 0
	if damage == 0 and s.hunger > 60 and s.thirst > 60 then
		heal = cfg.REGEN * dt
	end
	return damage, heal
end

-- Aplica um consumível; retorna false se não for comestível
function Rules.consume(s: Stats, def: any, maxStat: number): (boolean, number)
	if def.category ~= "food" then
		return false, 0
	end
	s.hunger = math.clamp(s.hunger + (def.hunger or 0), 0, maxStat)
	s.thirst = math.clamp(s.thirst + (def.thirst or 0), 0, maxStat)
	return true, def.heal or 0
end

-- ===== Progressão =====
-- Soma XP e retorna lista de níveis alcançados
function Rules.addXp(
	p: { level: number, xp: number },
	amount: number,
	xpFor: (number) -> number,
	maxLevel: number
): { number }
	local ups = {}
	if amount <= 0 or p.level >= maxLevel then
		return ups
	end
	p.xp += math.floor(amount)
	while p.level < maxLevel and p.xp >= xpFor(p.level) do
		p.xp -= xpFor(p.level)
		p.level += 1
		table.insert(ups, p.level)
	end
	if p.level >= maxLevel then
		p.xp = 0
	end
	return ups
end

-- ===== Drops =====
-- rand(min, max) -> inteiro; rand0() -> [0,1)
function Rules.rollDrops(
	drops: { any },
	randInt: (number, number) -> number,
	rand01: () -> number
): { [string]: number }
	local out: { [string]: number } = {}
	for _, d in drops do
		if d.chance == nil or rand01() < d.chance then
			local n = randInt(d.min, d.max)
			if n > 0 then
				out[d.item] = (out[d.item] or 0) + n
			end
		end
	end
	return out
end

-- Dano de uma ferramenta num nó (0 se ferramenta errada / tier baixo)
function Rules.nodeDamage(node: any, tool: any?): number
	if node.harvest ~= "tool" then
		return 0
	end
	if tool == nil or tool.toolType ~= node.toolType or (tool.tier or 0) < node.tierRequired then
		return 0
	end
	-- tiers acima do exigido batem mais forte
	local bonus = 1 + 0.25 * ((tool.tier or 0) - node.tierRequired)
	return (tool.damage or 1) * bonus
end

-- ===== Missões diárias =====
-- Sorteio determinístico de `count` missões a partir de uma semente
function Rules.pickDaily(pool: { any }, count: number, seed: number): { any }
	local idx = {}
	for i = 1, #pool do
		idx[i] = i
	end
	local state = seed % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	local function nextRand()
		state = (state * 16807) % 2147483647
		return state
	end
	for i = #idx, 2, -1 do
		local j = (nextRand() % i) + 1
		idx[i], idx[j] = idx[j], idx[i]
	end
	local out = {}
	for i = 1, math.min(count, #idx) do
		table.insert(out, pool[idx[i]])
	end
	return out
end

-- Calcula sequência de login: retorna (novaSequencia, deveRecompensar)
function Rules.loginStreak(lastDay: number?, streak: number, today: number): (number, boolean)
	if lastDay == today then
		return streak, false
	end
	if lastDay == today - 1 then
		return streak + 1, true
	end
	return 1, true
end

return Rules
