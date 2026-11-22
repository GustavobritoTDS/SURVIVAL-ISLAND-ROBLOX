--!strict
-- Persistência com DataStoreService.
-- - Trava de sessão (session lock) via UpdateAsync: impede duplicação de itens entre servidores.
-- - Tentativas com espera exponencial; autosave periódico; salvamento no BindToClose.
-- - Sem acesso a DataStore (ex.: Studio sem "API Services") -> modo memória com aviso, sem salvar.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Game = require(Shared.Config.Game)

local DataService = {}

local LOCK_EXPIRE = 60 * 10 -- trava considerada morta após 10 min sem renovação
local JOB = game.JobId ~= "" and game.JobId or ("studio-" .. HttpService:GenerateGUID(false))

local store: DataStore? = nil
local profiles: { [Player]: any } = {}
local loadedSignal = Instance.new("BindableEvent")
local saving: { [Player]: boolean } = {}
local lastWrite: { [Player]: number } = {}
DataService.memoryMode = false

function DataService.template(): any
	return {
		v = Game.DATA_VERSION,
		inv = {},
		armor = nil,
		stats = { health = 100, hunger = 100, thirst = 100, warmth = 100 },
		level = 1,
		xp = 0,
		shells = 0,
		base = nil, -- { totem = {x,y,z}, list = { {id, dx,dy,dz, rotY, extra} } }
		counters = {},
		daily = { day = 0, quests = {} },
		achievements = {},
		login = { lastDay = nil, streak = 0 },
		cosmetics = { owned = {}, trail = nil, title = nil },
		settings = { music = true, sfx = true, quality = "auto" },
		tutorial = 0,
		keepItems = 0,
		receipts = {}, -- últimos PurchaseIds processados (idempotência)
		rescued = 0,
		joined = os.time(),
		playtime = 0,
	}
end

-- Garante que perfis antigos ganham campos novos
local function reconcile(data: any): any
	local t = DataService.template()
	for k, v in t do
		if data[k] == nil then
			data[k] = v
		end
	end
	for k, v in t.stats do
		if type(data.stats[k]) ~= "number" then
			data.stats[k] = v
		end
	end
	data.v = Game.DATA_VERSION
	return data
end

local function retry<T>(fn: () -> T, tries: number): (boolean, any)
	local lastErr
	for i = 1, tries do
		local ok, res = pcall(fn)
		if ok then
			return true, res
		end
		lastErr = res
		task.wait(math.min(2 ^ i, 8))
	end
	return false, lastErr
end

local function key(player: Player): string
	return "p_" .. player.UserId
end

local function load(player: Player)
	if DataService.memoryMode or not store then
		profiles[player] = DataService.template()
		loadedSignal:Fire(player)
		return
	end
	local ds = store :: DataStore
	local data
	for attempt = 1, 6 do
		local locked = false
		local ok, err = pcall(function()
			ds:UpdateAsync(key(player), function(old: any)
				old = old or { data = nil, lock = nil }
				local lock = old.lock
				if lock and lock.job ~= JOB and os.time() - (lock.t or 0) < LOCK_EXPIRE then
					locked = true
					return nil -- não altera
				end
				old.lock = { job = JOB, t = os.time() }
				data = old.data
				return old
			end)
		end)
		if ok and not locked then
			profiles[player] = reconcile(data or DataService.template())
			lastWrite[player] = os.clock() -- o carregamento também grava (trava de sessão)
			loadedSignal:Fire(player)
			return
		end
		if not ok then
			warn("[Data] Falha ao carregar", player.Name, err)
		end
		task.wait(attempt * 2)
		if not player.Parent then
			return
		end
	end
	player:Kick("Não foi possível carregar seus dados com segurança. Tente novamente em alguns minutos.")
end

-- Salva o perfil; release=true libera a trava (saída do jogador)
function DataService.save(player: Player, release: boolean?): boolean
	local data = profiles[player]
	if not data or DataService.memoryMode or not store then
		return true
	end
	if saving[player] and not release then
		return false
	end
	saving[player] = true
	-- O Roblox aceita 1 gravação por chave a cada ~6 s; espera o intervalo para não enfileirar
	local since = os.clock() - (lastWrite[player] or 0)
	if since < 6.5 then
		task.wait(6.5 - since)
	end
	lastWrite[player] = os.clock()
	local ds = store :: DataStore
	local ok, err = retry(function()
		ds:UpdateAsync(key(player), function(old: any)
			old = old or {}
			if old.lock and old.lock.job ~= JOB then
				-- outro servidor assumiu: não sobrescreve
				return nil
			end
			old.data = data
			old.lock = if release then nil else { job = JOB, t = os.time() }
			return old
		end)
		return true
	end, 4)
	saving[player] = nil
	if not ok then
		warn("[Data] Falha ao salvar", player.Name, err)
	end
	return ok
end

function DataService.get(player: Player): any
	return profiles[player]
end

-- Espera o perfil (até 30 s)
function DataService.await(player: Player): any
	local t0 = os.clock()
	while not profiles[player] and player.Parent and os.clock() - t0 < 30 do
		task.wait(0.1)
	end
	return profiles[player]
end

DataService.loaded = loadedSignal.Event
local removingCallbacks: { (Player, any) -> () } = {}

-- Callbacks chamados antes do salvamento final (ex.: serializar base)
function DataService.onBeforeSave(fn: (Player, any) -> ())
	table.insert(removingCallbacks, fn)
end

local function beforeSave(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	for _, fn in removingCallbacks do
		local ok, err = pcall(fn, player, data)
		if not ok then
			warn("[Data] onBeforeSave falhou:", err)
		end
	end
end

-- Executa fn com limite de tempo; retorna (concluiu, ok, resultado)
local function withTimeout(seconds: number, fn: () -> any): (boolean, boolean, any)
	local done, ok, res = false, false, nil
	task.spawn(function()
		ok, res = pcall(fn)
		done = true
	end)
	local t0 = os.clock()
	while not done and os.clock() - t0 < seconds do
		task.wait(0.1)
	end
	return done, ok, res
end

DataService.runBeforeSave = beforeSave -- exposto para testes

function DataService.init()
	-- Place não publicado (PlaceId 0) não tem DataStore: usa memória direto
	if game.PlaceId ~= 0 then
		local ok, res = pcall(function()
			return DataStoreService:GetDataStore(Game.DATASTORE_NAME)
		end)
		if ok then
			store = res
			-- teste rápido de acesso (no Studio sem API Services isso falha ou trava)
			local finished, okRead = withTimeout(8, function()
				return (res :: DataStore):GetAsync("__probe")
			end)
			if not finished or not okRead then
				store = nil
			end
		end
	end
	if not store then
		DataService.memoryMode = true
		warn(
			"[Data] DataStore indisponível: modo memória (nada será salvo). Publique o place e, no Studio, ative Game Settings > Security > Enable Studio Access to API Services."
		)
	end

	Players.PlayerAdded:Connect(load)
	for _, p in Players:GetPlayers() do
		task.spawn(load, p)
	end

	Players.PlayerRemoving:Connect(function(player)
		beforeSave(player)
		DataService.save(player, true)
		profiles[player] = nil
	end)

	-- Autosave
	task.spawn(function()
		while true do
			task.wait(Game.AUTOSAVE_INTERVAL)
			for _, p in Players:GetPlayers() do
				if profiles[p] then
					beforeSave(p)
					task.spawn(DataService.save, p, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() and DataService.memoryMode then
			return
		end
		local pending = 0
		for _, p in Players:GetPlayers() do
			pending += 1
			task.spawn(function()
				beforeSave(p)
				DataService.save(p, true)
				pending -= 1
			end)
		end
		local t0 = os.clock()
		while pending > 0 and os.clock() - t0 < 25 do
			task.wait(0.2)
		end
	end)
end

return DataService
