-- Harness de teste de ponta a ponta (só entra no build de teste: test.project.json).
-- Em Play no Studio: espera o jogador, dá materiais e coordena o TestClient; o resultado
-- volta para quem iniciou o teste via StudioTestService:EndTest.

local Players = game:GetService("Players")
local LogService = game:GetService("LogService")
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end

local results: { string } = {}
local failures = 0
local function log(ok: boolean, msg: string)
	if not ok then
		failures += 1
	end
	table.insert(results, (ok and "PASSOU " or "FALHOU ") .. msg)
end
local errors: { string } = {}
LogService.MessageOut:Connect(function(msg, kind)
	if kind == Enum.MessageType.MessageError then
		table.insert(errors, msg)
	end
end)

local report = Instance.new("RemoteEvent")
report.Name = "TestReport"
report.Parent = game:GetService("ReplicatedStorage")

local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local PlayerService = require(Services.PlayerService)
local Inventory = require(game:GetService("ReplicatedStorage").Shared.Logic.Inventory)

local function finish()
	table.insert(results, ("Erros no log do servidor: %d"):format(#errors))
	for i, e in errors do
		if i <= 10 then
			table.insert(results, "  erro: " .. e)
		end
	end
	-- Uma linha por resultado (o log do Studio corta linhas longas); o Play continua aberto
	for _, line in results do
		print("[e2e] " .. line)
	end
	print(("[e2e] FIM — falhas: %d"):format(failures + #errors))
end

task.spawn(function()
	local t0 = os.clock()
	while #Players:GetPlayers() == 0 and os.clock() - t0 < 90 do
		task.wait(0.5)
	end
	local player = Players:GetPlayers()[1]
	if not player then
		log(false, "nenhum jogador entrou")
		return finish()
	end
	while not player:GetAttribute("DataReady") and os.clock() - t0 < 120 do
		task.wait(0.5)
	end
	log(player:GetAttribute("DataReady") == true, "perfil carregado (jogador entrou durante a geração do mundo)")
	log(PlayerService.inv(player) ~= nil, "sessão de inventário criada")
	if not PlayerService.inv(player) then
		return finish()
	end
	local char = player.Character or player.CharacterAdded:Wait()
	local hrp = char:WaitForChild("HumanoidRootPart", 20) :: BasePart
	log(hrp ~= nil, "personagem nasceu")
	task.wait(2)
	log(hrp.Position.Y > 2 and hrp.Position.Y < 60, ("personagem no chão da praia (Y=%.1f)"):format(hrp.Position.Y))

	-- Materiais iniciais para o fluxo do cliente
	PlayerService.give(player, "stick", 10, true)
	PlayerService.give(player, "stone", 10, true)
	PlayerService.give(player, "fiber", 10, true)
	PlayerService.give(player, "flint", 3, true)
	local inv = PlayerService.inv(player)
	log(Inventory.count(inv, "stick") == 10, "servidor entregou materiais")

	-- O cliente executa o roteiro e responde
	local done = false
	report.OnServerEvent:Connect(function(p, kind, ok, msg)
		if p ~= player then
			return
		end
		if kind == "info" then
			table.insert(results, "INFO " .. tostring(msg))
		elseif kind == "step" then
			log(ok == true, "[cliente] " .. tostring(msg))
		elseif kind == "done" then
			done = true
		end
	end)
	report:FireClient(player, "start")
	local t1 = os.clock()
	while not done and os.clock() - t1 < 90 do
		task.wait(0.5)
	end
	log(done, "roteiro do cliente terminou")

	-- Verificações do lado do servidor
	log(Inventory.count(inv, "stone_axe") == 1, "machado fabricado existe no inventário do servidor")
	local structures = workspace.World.Structures:FindFirstChild(tostring(player.UserId))
	local campfire = structures and structures:FindFirstChild("campfire")
	log(campfire ~= nil, "fogueira colocada no mundo pelo servidor")

	-- Anti-exploit: ações maliciosas não devem ter efeito
	log(Inventory.count(inv, "obsidian_blade") == 0, "exploit: nenhum item de alto nível foi criado")
	local data = PlayerService.data(player)
	log(data.shells < 1000, "exploit: Conchas não foram infladas pelo cliente (" .. data.shells .. ")")

	-- ===== Compras (simulação de recibos; nenhuma compra real) =====
	local Monetization = require(game:GetService("ReplicatedStorage").Shared.Config.Monetization)
	local MonetizationService = require(Services.MonetizationService)
	local fakeId = 123456789
	Monetization.devProducts.shells_small.id = fakeId -- só neste teste, em memória
	local shells0 = data.shells
	local Granted = Enum.ProductPurchaseDecision.PurchaseGranted
	local NotYet = Enum.ProductPurchaseDecision.NotProcessedYet
	local r1 = MonetizationService.processReceipt({ PlayerId = player.UserId, ProductId = fakeId, PurchaseId = "teste-1", CurrencySpent = 25 })
	log(r1 == Granted and data.shells == shells0 + 100, "compra: produto entregue uma vez (+100 Conchas)")
	local r2 = MonetizationService.processReceipt({ PlayerId = player.UserId, ProductId = fakeId, PurchaseId = "teste-1", CurrencySpent = 25 })
	log(r2 == Granted and data.shells == shells0 + 100, "compra: recibo repetido NÃO entrega de novo")
	local r3 = MonetizationService.processReceipt({ PlayerId = player.UserId, ProductId = 999, PurchaseId = "teste-2", CurrencySpent = 25 })
	log(r3 == NotYet, "compra: produto desconhecido não é concedido")
	local r4 = MonetizationService.processReceipt({ PlayerId = 1, ProductId = fakeId, PurchaseId = "teste-3", CurrencySpent = 25 })
	log(r4 == NotYet, "compra: jogador ausente fica pendente (Roblox tenta de novo)")
	Monetization.devProducts.shells_small.id = 0
	log(player:GetAttribute("VIP") ~= true, "pass: VIP não concedido sem posse real")

	-- ===== Salvamento da base relativa ao Totem =====
	PlayerService.give(player, "base_totem", 1, true)
	PlayerService.give(player, "chest", 1, true)
	local BuildService = require(Services.BuildService)
	local okT, whyT = BuildService.validate(player, "base_totem", hrp.Position + Vector3.new(10, 3, 0), 0)
	log(okT, "construção: Totem válido perto do jogador " .. tostring(whyT))
	-- coloca via a mesma rotina do servidor (simula a ação do cliente)
	local Actions = require(game:GetService("ServerScriptService").Server.Util.Actions)
	local _ = Actions
	report:FireClient(player, "placeBase")
	local t2 = os.clock()
	while Inventory.count(inv, "chest") > 0 and os.clock() - t2 < 15 do
		task.wait(0.3)
	end
	local DataService = require(Services.DataService)
	DataService.runBeforeSave(player)
	local base = data.base
	log(base ~= nil and base.list ~= nil, "salvamento: base serializada com Totem")
	local hasChest = false
	for _, e in (base and base.list or {}) do
		if e[1] == "chest" then
			hasChest = true
		end
	end
	log(hasChest, "salvamento: baú dentro do território entrou no save")
	local okSize, enc = pcall(function()
		return game:GetService("HttpService"):JSONEncode(data)
	end)
	log(okSize and #enc < 3_000_000, ("salvamento: perfil serializável (%d bytes, limite 4 MB)"):format(okSize and #enc or -1))

	-- ===== Guia Bento e Jornada =====
	local GuideService = require(Services.GuideService)
	local SurvivalService = require(Services.SurvivalService)
	local bento = GuideService.npc()
	log(bento ~= nil and bento.Parent ~= nil, "guia: NPC Bento existe no mundo")
	if bento then
		SurvivalService.grace(player)
		char:PivotTo(bento:GetPivot() * CFrame.new(0, 0, -5))
		task.wait(1)
		GuideService.talk(player)
		log(data.guide and data.guide.started == true and data.guide.stage == 1, "guia: conversa inicia a Jornada (etapa 1)")
		SurvivalService.grace(player)
		local Guide = require(game:GetService("ReplicatedStorage").Shared.Config.Guide)
		char:PivotTo(CFrame.new(Guide.stages[1].check.pos + Vector3.new(0, 6, 0)))
		local t4 = os.clock()
		while data.guide.stage < 2 and os.clock() - t4 < 8 do
			task.wait(0.5)
		end
		log(data.guide.stage >= 2, "guia: explorar os destroços concluiu a etapa 1 (etapa atual " .. tostring(data.guide.stage) .. ")")
	end

	-- ===== Desempenho =====
	local Stats = game:GetService("Stats")
	local parts, instances = 0, 0
	for _, d in workspace:GetDescendants() do
		instances += 1
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	local frames, t3 = 0, os.clock()
	local conn = game:GetService("RunService").Heartbeat:Connect(function()
		frames += 1
	end)
	task.wait(3)
	conn:Disconnect()
	local fps = frames / (os.clock() - t3)
	table.insert(results, ("DESEMPENHO memória servidor: %.0f MB | instâncias workspace: %d | BaseParts: %d | Heartbeat: %.1f/s"):format(Stats:GetTotalMemoryUsageMb(), instances, parts, fps))
	log(fps > 40, "desempenho: servidor acima de 40 ticks/s")
	finish()
end)
