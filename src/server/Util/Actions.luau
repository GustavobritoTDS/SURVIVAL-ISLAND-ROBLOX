--!strict
-- Roteador seguro de ações do cliente.
-- Cada ação registrada recebe (player, ...) somente se: o nome existe, o jogador não excedeu
-- o limite de chamadas, e o handler não lança erro (erros são registrados, não derrubam o servidor).

local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Game = require(Shared.Config.Game)

local Actions = {}

type Handler = (Player, ...any) -> ()
local handlers: { [string]: { fn: Handler, rate: number } } = {}
local buckets: { [Player]: { [string]: { tokens: number, last: number } } } = {}

-- rate = chamadas por segundo permitidas (rajada = 2x)
function Actions.on(name: string, fn: Handler, rate: number?)
	handlers[name] = { fn = fn, rate = rate or Game.MAX_REMOTE_RATE }
end

local function allow(player: Player, name: string, rate: number): boolean
	local pb = buckets[player]
	if not pb then
		pb = {}
		buckets[player] = pb
	end
	local now = os.clock()
	local b = pb[name]
	if not b then
		b = { tokens = rate * 2, last = now }
		pb[name] = b
	end
	b.tokens = math.min(rate * 2, b.tokens + (now - b.last) * rate)
	b.last = now
	if b.tokens < 1 then
		return false
	end
	b.tokens -= 1
	return true
end

function Actions.init()
	Net.event("Action").OnServerEvent:Connect(function(player: Player, name: any, ...: any)
		if type(name) ~= "string" then
			return
		end
		local h = handlers[name]
		if not h or not allow(player, name, h.rate) then
			return
		end
		local ok, err = pcall(h.fn, player, ...)
		if not ok then
			warn(("[Actions] %s falhou para %s: %s"):format(name, player.Name, tostring(err)))
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		buckets[p] = nil
	end)
end

-- Helpers de validação de argumentos
function Actions.int(v: any, min: number, max: number): number?
	if type(v) ~= "number" or v ~= v or v ~= math.floor(v) or v < min or v > max then
		return nil
	end
	return v
end

function Actions.str(v: any, maxLen: number): string?
	if type(v) ~= "string" or #v == 0 or #v > maxLen then
		return nil
	end
	return v
end

return Actions
