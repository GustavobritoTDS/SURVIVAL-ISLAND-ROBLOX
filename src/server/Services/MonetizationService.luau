--!strict
-- Game Passes (verificação de posse), Developer Products (ProcessReceipt idempotente),
-- loja de Conchas e cosméticos (rastros, títulos, papagaio, tag VIP).

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Monetization = require(Shared.Config.Monetization)

local PlayerService = require(script.Parent.PlayerService)
local DataService = require(script.Parent.DataService)
local Actions = require(script.Parent.Parent.Util.Actions)

local MonetizationService = {}

local MAX_RECEIPTS = 60

local function ownsPass(player: Player, key: string): boolean
	local pass = Monetization.gamePasses[key]
	if not pass or pass.id == 0 then
		return false
	end
	local ok, res = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
	end)
	return ok and res == true
end

-- ===== Cosméticos =====
local function trailColor(id: string?): Color3?
	if not id then
		return nil
	end
	for _, s in Monetization.shellShop do
		if s.id == id and s.kind == "trail" then
			return s.color
		end
	end
	for _, t in Monetization.passTrails do
		if t.id == id then
			return t.color
		end
	end
	if id == "trail_vip" then
		return Color3.fromRGB(255, 205, 70)
	end
	return nil
end

local function titleText(id: string?): string?
	if not id then
		return nil
	end
	for _, s in Monetization.shellShop do
		if s.id == id and s.kind == "title" then
			return (string.gsub(s.name, "^Título: ", ""))
		end
	end
	return nil
end

local function applyCosmetics(player: Player)
	local data = DataService.get(player)
	local char = player.Character
	local head = char and char:FindFirstChild("Head") :: BasePart?
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not data or not head or not hrp or not char then
		return
	end
	for _, n in { "CosmeticTrail", "CosmeticA0", "CosmeticA1", "Nameplate", "Parrot" } do
		local old = char:FindFirstChild(n, true)
		if old then
			old:Destroy()
		end
	end
	-- Rastro
	local color = trailColor(data.cosmetics.trail)
	if color then
		local a0 = Instance.new("Attachment")
		a0.Name = "CosmeticA0"
		a0.Position = Vector3.new(0, 0.8, 0)
		a0.Parent = hrp
		local a1 = Instance.new("Attachment")
		a1.Name = "CosmeticA1"
		a1.Position = Vector3.new(0, -0.8, 0)
		a1.Parent = hrp
		local trail = Instance.new("Trail")
		trail.Name = "CosmeticTrail"
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(color)
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.Lifetime = 0.6
		trail.LightEmission = 0.6
		trail.Parent = hrp
	end
	-- Placa de nome com nível, título e VIP
	local bb = Instance.new("BillboardGui")
	bb.Name = "Nameplate"
	bb.Size = UDim2.fromOffset(220, 46)
	bb.StudsOffset = Vector3.new(0, 2.6, 0)
	bb.MaxDistance = 70
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0.55, 0)
	name.Font = Enum.Font.GothamBold
	name.TextScaled = true
	name.TextStrokeTransparency = 0.5
	local vip = player:GetAttribute("VIP") == true
	name.Text = (vip and "👑 " or "") .. player.DisplayName .. "  ·  Nv " .. data.level
	name.TextColor3 = vip and Color3.fromRGB(255, 215, 90) or Color3.new(1, 1, 1)
	name.Parent = bb
	local title = titleText(data.cosmetics.title)
	if data.rescued > 0 and not title then
		title = "Resgatado"
	end
	if title then
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Position = UDim2.fromScale(0, 0.55)
		t.Size = UDim2.new(1, 0, 0.45, 0)
		t.Font = Enum.Font.GothamMedium
		t.TextScaled = true
		t.TextStrokeTransparency = 0.6
		t.Text = title
		t.TextColor3 = Color3.fromRGB(140, 230, 220)
		t.Parent = bb
	end
	bb.Parent = head
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	-- Papagaio (puramente cosmético; o cliente anima o voo)
	if player:GetAttribute("PassParrot") then
		local parrot = Instance.new("Part")
		parrot.Name = "Parrot"
		parrot.Size = Vector3.new(0.8, 0.8, 1.2)
		parrot.Color = Color3.fromRGB(230, 60, 50)
		parrot.Material = Enum.Material.SmoothPlastic
		parrot.CanCollide = false
		parrot.CanQuery = false
		parrot.Massless = true
		parrot.CFrame = hrp.CFrame * CFrame.new(1.8, 2.2, 0)
		local wing = Instance.new("Part")
		wing.Size = Vector3.new(1.6, 0.15, 0.6)
		wing.Color = Color3.fromRGB(40, 120, 220)
		wing.CanCollide = false
		wing.Massless = true
		wing.CFrame = parrot.CFrame
		wing.Parent = parrot
		local w2 = Instance.new("WeldConstraint")
		w2.Part0 = parrot
		w2.Part1 = wing
		w2.Parent = wing
		local w = Instance.new("WeldConstraint")
		w.Part0 = hrp
		w.Part1 = parrot
		w.Parent = parrot
		parrot.Parent = char
	end
end

function MonetizationService.refreshCosmetics(player: Player)
	applyCosmetics(player)
end

local function checkPasses(player: Player)
	local vip = ownsPass(player, "vip")
	local big = ownsPass(player, "big_backpack")
	player:SetAttribute("PassParrot", ownsPass(player, "parrot"))
	player:SetAttribute("PassTrails", ownsPass(player, "trails"))
	PlayerService.setPasses(player, vip, big)
	local data = DataService.get(player)
	if data and vip then
		data.cosmetics.owned.trail_vip = true
	end
	applyCosmetics(player)
end

-- ===== Developer Products =====
local function grantProduct(player: Player, key: string, product: any): boolean
	local data = DataService.get(player)
	if not data then
		return false
	end
	if product.shells then
		data.shells += product.shells
	end
	if product.items then
		-- itens que não cabem ficam guardados para entregar depois? Simples: entrega o que couber e avisa.
		PlayerService.giveMany(player, product.items, true)
	end
	if key == "keep_items" then
		data.keepItems += 1
	end
	PlayerService.notify(player, "Obrigado pela compra: " .. product.name .. "!", "level", product.icon)
	PlayerService.sync(player, "progress", "passes")
	return true
end

local function processReceipt(info: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = DataService.get(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- Idempotência: a mesma compra nunca é entregue duas vezes
	if table.find(data.receipts, info.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local key, product = Monetization.productById(info.ProductId)
	if not key or not product then
		warn("[Monetization] Produto desconhecido:", info.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not grantProduct(player, key, product) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	table.insert(data.receipts, info.PurchaseId)
	while #data.receipts > MAX_RECEIPTS do
		table.remove(data.receipts, 1)
	end
	-- salva imediatamente; se falhar, o Roblox tenta de novo e a idempotência evita duplicar
	if not DataService.save(player, false) and not DataService.memoryMode then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- ===== Ações do cliente =====
local function onPrompt(player: Player, kind: any, key: any)
	local k = Actions.str(key, 40)
	if not k then
		return
	end
	if kind == "pass" then
		local pass = Monetization.gamePasses[k]
		if pass and pass.id ~= 0 then
			MarketplaceService:PromptGamePassPurchase(player, pass.id)
		else
			PlayerService.notify(player, "Disponível em breve!", "info", "🛒")
		end
	elseif kind == "product" then
		local p = Monetization.devProducts[k]
		if p and p.id ~= 0 then
			MarketplaceService:PromptProductPurchase(player, p.id)
		else
			PlayerService.notify(player, "Disponível em breve!", "info", "🛒")
		end
	end
end

local function onShellBuy(player: Player, id: any)
	local data = DataService.get(player)
	local sid = Actions.str(id, 40)
	if not data or not sid then
		return
	end
	local entry
	for _, s in Monetization.shellShop do
		if s.id == sid then
			entry = s
		end
	end
	if not entry then
		return
	end
	if entry.kind ~= "items" and data.cosmetics.owned[sid] then
		PlayerService.notify(player, "Você já possui este item", "info", entry.icon)
		return
	end
	if not PlayerService.spendShells(player, entry.price) then
		PlayerService.notify(player, "Conchas insuficientes", "bad", "🐚")
		return
	end
	if entry.kind == "items" then
		PlayerService.giveMany(player, entry.items)
	else
		data.cosmetics.owned[sid] = true
		if entry.kind == "trail" then
			data.cosmetics.trail = sid
		elseif entry.kind == "title" then
			data.cosmetics.title = sid
		end
		applyCosmetics(player)
	end
	PlayerService.notify(player, "Comprou " .. entry.name, "good", entry.icon)
	PlayerService.sync(player, "cosmetics", "progress")
end

local function onEquipCosmetic(player: Player, kind: any, id: any)
	local data = DataService.get(player)
	if not data or (kind ~= "trail" and kind ~= "title") then
		return
	end
	if id == false or id == nil then
		data.cosmetics[kind] = nil
	else
		local sid = Actions.str(id, 40)
		if not sid then
			return
		end
		local isPassTrail = false
		for _, t in Monetization.passTrails do
			if t.id == sid then
				isPassTrail = true
			end
		end
		local allowed = data.cosmetics.owned[sid] or (isPassTrail and player:GetAttribute("PassTrails") == true)
		if not allowed then
			return
		end
		data.cosmetics[kind] = sid
	end
	applyCosmetics(player)
	PlayerService.sync(player, "cosmetics")
end

-- Exposto para testes automatizados (harness de Studio)
MonetizationService.processReceipt = processReceipt

function MonetizationService.init()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased then
			for _, pass in Monetization.gamePasses do
				if pass.id == passId then
					PlayerService.notify(player, "Game Pass ativado: " .. pass.name .. "!", "level", pass.icon)
				end
			end
			checkPasses(player)
		end
	end)
	PlayerService.onReady(function(player)
		checkPasses(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			applyCosmetics(player)
		end)
		if player.Character then
			applyCosmetics(player)
		end
		-- Atualiza o nível na placa de nome
		player:GetAttributeChangedSignal("Level"):Connect(function()
			applyCosmetics(player)
		end)
	end)
	Actions.on("Prompt", onPrompt, 2)
	Actions.on("ShellBuy", onShellBuy, 3)
	Actions.on("EquipCosmetic", onEquipCosmetic, 3)
end

return MonetizationService
