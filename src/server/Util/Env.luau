--!strict
-- Estado ambiental compartilhado entre serviços (evita dependências circulares).
-- DayNightService/WeatherService escrevem; Survival/Creature/Build leem.

export type HeatSource = { pos: Vector3, warmth: number, light: number, repel: boolean }

local Env = {
	night = false,
	storm = false,
	raining = false,
	nightCount = 0, -- noites passadas neste servidor
	heat = {} :: { [Instance]: HeatSource },
}

-- Fonte de calor mais próxima que cobre a posição
function Env.isWarm(pos: Vector3): boolean
	for _, h in Env.heat do
		if h.warmth > 0 and (h.pos - pos).Magnitude <= h.warmth then
			return true
		end
	end
	return false
end

function Env.isRepelled(pos: Vector3): boolean
	for _, h in Env.heat do
		if h.repel and (h.pos - pos).Magnitude <= h.light then
			return true
		end
	end
	return false
end

return Env
