--!strict
-- Estado local espelhado do servidor (somente leitura para a UI) + sinais de mudança.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)

local State = {
	data = {
		inv = {},
		invSize = 24,
		stats = { health = 100, hunger = 100, thirst = 100, warmth = 100 },
		level = 1,
		xp = 0,
		xpNeed = 100,
		shells = 0,
		daily = { quests = {} },
		achievements = {},
		counters = {},
		cosmetics = { owned = {} },
		settings = { music = true, sfx = true, quality = "auto" },
		tutorial = 0,
		passes = {},
		equipped = nil,
		armor = nil,
		chest = nil,
		keepItems = 0,
	} :: { [string]: any },
	slots = {} :: { [number]: { id: string, n: number } },
}

local listeners: { [string]: { (any) -> () } } = {}

-- fn é chamado quando a chave muda (e imediatamente com o valor atual se `now`)
function State.on(key: string, fn: (any) -> (), now: boolean?)
	listeners[key] = listeners[key] or {}
	table.insert(listeners[key], fn)
	if now then
		task.spawn(fn, State.data[key])
	end
end

local function fire(key: string)
	for _, fn in listeners[key] or {} do
		task.spawn(fn, State.data[key])
	end
end

function State.count(id: string): number
	local n = 0
	for _, s in State.slots do
		if s.id == id then
			n += s.n
		end
	end
	return n
end

function State.action(name: string, ...: any)
	Net.event("Action"):FireServer(name, ...)
end

function State.init()
	Net.event("State").OnClientEvent:Connect(function(patch: any)
		for k, v in patch do
			State.data[k] = v
			if k == "inv" then
				local slots = {}
				for _, e in v do
					slots[e[3]] = { id = e[1], n = e[2] }
				end
				State.slots = slots
			end
		end
		for k in patch do
			fire(k)
		end
		fire("*")
	end)
	State.action("RequestSync")
end

return State
