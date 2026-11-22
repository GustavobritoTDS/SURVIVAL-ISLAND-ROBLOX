--!strict
-- Construção: posicionamento validado, território (Totem), portas, baús, camas, coletores,
-- Farol de Resgate e salvamento da base relativa ao Totem.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Items = require(Shared.Config.Items)
local Structures = require(Shared.Config.Structures)
local Regions = require(Shared.Config.Regions)
local Inventory = require(Shared.Logic.Inventory)
local BuildGrid = require(Shared.Logic.BuildGrid)
local Net = require(Shared.Net)

local PlayerService = require(script.Parent.PlayerService)
local DataService = require(script.Parent.DataService)
local WorldService = require(script.Parent.WorldService)
local Actions = require(script.Parent.Parent.Util.Actions)
local Env = require(script.Parent.Parent.Util.Env)
local StructureModels = require(script.Parent.Parent.Builders.StructureModels)

local BuildService = {}

type Built = { model: Model, id: string, owner: Player, chest: any?, guid: string }

local built: { [Model]: Built } = {}
local byGuid: { [string]: Built } = {}
local owned: { [Player]: { Built } } = {}
local beds: { [Player]: Built } = {}
local totems: { [Player]: Built } = {}
local openChest: { [Player]: Built } = {}
local root: Folder
local stateEvent = Net.event("State")
local fxEvent = Net.event("Fx")

local CHEST_RANGE = 12
local function stackOf(id: string): number
	return Items[id] and Items[id].stack or 1
end

local function hrpOf(p: Player): BasePart?
	local c = p.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function canUse(b: Built, p: Player): boolean
	return PlayerService.isFriend(b.owner, p)
end

-- ===== Território =====
local function claimAt(pos: Vector3): Built?
	for _, t in totems do
		local r = Structures.defs.base_totem.claim :: number
		local d = (t.model:GetPivot().Position - pos) * Vector3.new(1, 0, 1)
		if d.Magnitude <= r then
			return t
		end
	end
	return nil
end

function BuildService.claimOwner(pos: Vector3): Player?
	local t = claimAt(pos)
	return t and t.owner
end

-- ===== Estações =====
function BuildService.nearStation(pos: Vector3, station: string, range: number): boolean
	for _, b in built do
		local def = Structures.defs[b.id]
		if def.station == station and (b.model:GetPivot().Position - pos).Magnitude <= range then
			return true
		end
	end
	return false
end

function BuildService.bedOf(player: Player): CFrame?
	local b = beds[player]
	if b and b.model.Parent then
		return b.model:GetPivot() * CFrame.new(0, 3, 0)
	end
	return nil
end

-- ===== Baús =====
local function sendChest(player: Player, b: Built?)
	if b then
		stateEvent:FireClient(
			player,
			{ chest = { guid = b.guid, inv = Inventory.serialize(b.chest), size = b.chest.size } }
		)
	else
		stateEvent:FireClient(player, { chest = false })
	end
end

local function openChestFor(player: Player, b: Built)
	if not canUse(b, player) then
		PlayerService.notify(player, "Este baú pertence a " .. b.owner.DisplayName, "bad", "🔒")
		return
	end
	openChest[player] = b
	sendChest(player, b)
end

local function onChestMove(player: Player, fromKind: any, from: any, toKind: any, to: any)
	local b = openChest[player]
	local hrp = hrpOf(player)
	if
		not b
		or not hrp
		or not b.model.Parent
		or (b.model:GetPivot().Position - hrp.Position).Magnitude > CHEST_RANGE
		or not canUse(b, player)
	then
		openChest[player] = nil
		sendChest(player, nil)
		return
	end
	local inv = PlayerService.inv(player)
	local function pick(kind: any): any
		if kind == "inv" then
			return inv
		elseif kind == "chest" then
			return b.chest
		end
		return nil
	end
	local fi, ti = pick(fromKind), pick(toKind)
	if not fi or not ti then
		return
	end
	local f = Actions.int(from, 1, fi.size)
	local t = Actions.int(to, 0, ti.size)
	if not f or t == nil then
		return
	end
	if t == 0 then
		-- envio rápido: move a pilha inteira para o primeiro espaço do outro lado
		local st = fi.slots[f]
		if not st then
			return
		end
		local added = Inventory.add(ti, st.id, st.n, stackOf(st.id))
		Inventory.takeFromSlot(fi, f, added)
	else
		Inventory.move(fi, f, ti, t, stackOf)
	end
	-- notifica todos com o baú aberto
	for p, ob in openChest do
		if ob == b then
			sendChest(p, b)
		end
	end
	PlayerService.changed(player)
end

-- ===== Criação de estruturas =====
local function registerHeat(b: Built)
	local def = Structures.defs[b.id]
	if def.warmth or def.light then
		Env.heat[b.model] = {
			pos = b.model:GetPivot().Position,
			warmth = def.warmth or 0,
			light = def.light or 0,
			repel = def.repelShades == true or b.id == "torch_post" or b.id == "rescue_beacon",
		}
	end
end

local function addPrompt(b: Built, action: string, kind: string, hold: number?): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = Structures.defs[b.id].name .. " de " .. b.owner.DisplayName
	p.HoldDuration = hold or 0
	p.MaxActivationDistance = 10
	p.RequiresLineOfSight = false
	p.Style = Enum.ProximityPromptStyle.Custom
	p:SetAttribute("Kind", kind)
	p.Parent = b.model.PrimaryPart
	return p
end

local function setupInteractions(b: Built)
	local id = b.id
	if id == "chest" then
		addPrompt(b, "Abrir", "chest").Triggered:Connect(function(p)
			openChestFor(p, b)
		end)
	elseif id == "wood_door" then
		local panel = b.model:FindFirstChild("DoorPanel") :: BasePart
		local knob = b.model:FindFirstChild("Knob") :: BasePart
		local closedCF = panel.CFrame
		local knobCF = knob.CFrame
		local open = false
		addPrompt(b, "Abrir/Fechar", "door").Triggered:Connect(function(p)
			if not canUse(b, p) then
				PlayerService.notify(p, "Porta trancada", "bad", "🔒")
				return
			end
			open = not open
			local hinge = closedCF * CFrame.new(-2, 0, 0)
			local rot = open and CFrame.Angles(0, math.rad(95), 0) or CFrame.new()
			panel.CFrame = hinge * rot * CFrame.new(2, 0, 0)
			knob.CFrame = hinge * rot * hinge:Inverse() * knobCF
			fxEvent:FireAllClients({ kind = "door", pos = closedCF.Position })
		end)
	elseif id == "leaf_bed" then
		addPrompt(b, "Definir renascimento", "bed").Triggered:Connect(function(p)
			if p == b.owner then
				beds[p] = b
				PlayerService.notify(p, "Você renascerá nesta cama", "good", "🛏️")
			end
		end)
	elseif id == "rain_collector" then
		b.model:SetAttribute("Water", 0)
		addPrompt(b, "Coletar água", "water").Triggered:Connect(function(p)
			local w = b.model:GetAttribute("Water") :: number
			if not canUse(b, p) then
				return
			end
			if w <= 0 then
				PlayerService.notify(p, "Vazio. Espere a chuva!", "info", "🌧️")
				return
			end
			local got = PlayerService.give(p, "fresh_water", w)
			b.model:SetAttribute("Water", w - got)
		end)
	elseif id == "rescue_beacon" then
		addPrompt(b, "Acender o Farol", "beacon", 2).Triggered:Connect(function(p)
			if p ~= b.owner or b.model:GetAttribute("Lit") then
				return
			end
			b.model:SetAttribute("Lit", true)
			local lamp = b.model:FindFirstChild("Lamp") :: BasePart
			lamp.Material = Enum.Material.Neon
			local l = Instance.new("SpotLight")
			l.Range = 60
			l.Angle = 50
			l.Brightness = 6
			l.Face = Enum.NormalId.Front
			l.Parent = lamp
			local data = DataService.get(p)
			if data then
				data.rescued += 1
			end
			PlayerService.count(p, "beacon", 1)
			PlayerService.addShells(p, 500)
			PlayerService.addXp(p, 2000)
			fxEvent:FireAllClients({ kind = "rescue", name = p.DisplayName })
			for _, other in Players:GetPlayers() do
				PlayerService.notify(other, p.DisplayName .. " acendeu o Farol de Resgate!", "level", "🗼")
			end
		end)
	elseif id == "base_totem" then
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(200, 40)
		bb.StudsOffset = Vector3.new(0, 6, 0)
		bb.MaxDistance = 80
		bb.AlwaysOnTop = false
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Text = "🗿 Base de " .. b.owner.DisplayName
		t.TextColor3 = Color3.fromRGB(255, 235, 190)
		t.TextStrokeTransparency = 0.4
		t.Font = Enum.Font.GothamBold
		t.TextScaled = true
		t.Parent = bb
		bb.Parent = b.model.PrimaryPart
	end
end

local function create(owner: Player, id: string, cf: CFrame, extra: any?): Built
	local model = StructureModels.build(id)
	model:PivotTo(cf)
	model:SetAttribute("Owner", owner.UserId)
	local b: Built = { model = model, id = id, owner = owner, chest = nil, guid = HttpService:GenerateGUID(false) }
	model:SetAttribute("Guid", b.guid)
	local def = Structures.defs[id]
	if def.storage then
		b.chest = Inventory.deserialize(extra, def.storage, function(i)
			return Items[i] ~= nil
		end, stackOf)
	end
	local folder = root:FindFirstChild(tostring(owner.UserId))
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = tostring(owner.UserId)
		folder.Parent = root
	end
	model.Parent = folder
	built[model] = b
	byGuid[b.guid] = b
	local list = owned[owner] or {}
	owned[owner] = list
	table.insert(list, b)
	if id == "base_totem" then
		totems[owner] = b
	end
	registerHeat(b)
	setupInteractions(b)
	return b
end

local function destroy(b: Built)
	built[b.model] = nil
	byGuid[b.guid] = nil
	Env.heat[b.model] = nil
	local list = owned[b.owner]
	if list then
		local i = table.find(list, b)
		if i then
			table.remove(list, i)
		end
	end
	if totems[b.owner] == b then
		totems[b.owner] = nil
	end
	if beds[b.owner] == b then
		beds[b.owner] = nil
	end
	for p, ob in openChest do
		if ob == b then
			openChest[p] = nil
			sendChest(p, nil)
		end
	end
	b.model:Destroy()
end

local function countOf(owner: Player, id: string): number
	local n = 0
	for _, b in owned[owner] or {} do
		if b.id == id then
			n += 1
		end
	end
	return n
end

-- ===== Validação de posicionamento =====
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
local boxParams = OverlapParams.new()
boxParams.FilterType = Enum.RaycastFilterType.Include

-- Retorna (ok, motivo, cframe final)
function BuildService.validate(player: Player, id: string, pos: Vector3, rot: number): (boolean, string?, CFrame?)
	local def = Structures.defs[id]
	local hrp = hrpOf(player)
	if not def or not hrp then
		return false, "Inválido", nil
	end
	local cf = BuildGrid.snap(pos, def.snap, rot)
	local p = cf.Position
	if (p - hrp.Position).Magnitude > Structures.PLACE_RANGE then
		return false, "Muito longe", nil
	end
	if p.Y - def.size.Y / 2 < Regions.SEA_LEVEL + 0.5 then
		return false, "Não dá para construir na água", nil
	end
	local spawnFlat = (p - Regions.SPAWN) * Vector3.new(1, 0, 1)
	if spawnFlat.Magnitude < Structures.MIN_DISTANCE_FROM_SPAWN then
		return false, "Muito perto do ponto de chegada", nil
	end
	local region = Regions.at(p)
	if region.id == "cave" or region.id == "volcano" then
		return false, "Não é possível construir aqui", nil
	end
	-- Território de outro jogador
	local claim = claimAt(p)
	if claim and not PlayerService.isFriend(claim.owner, player) then
		return false, "Território de " .. claim.owner.DisplayName, nil
	end
	if id == "base_totem" then
		local r = def.claim :: number
		for owner, t in totems do
			if owner ~= player and ((t.model:GetPivot().Position - p) * Vector3.new(1, 0, 1)).Magnitude < r * 2 then
				return false, "Muito perto da base de " .. owner.DisplayName, nil
			end
		end
	end
	-- Limites
	local list = owned[player] or {}
	if #list >= Structures.MAX_PER_PLAYER then
		return false, "Limite de construções atingido", nil
	end
	if def.limit and countOf(player, id) >= def.limit then
		return false, ("Máximo de %d %s"):format(def.limit, def.name), nil
	end
	-- Sobreposição (caixa levemente menor para permitir encostar)
	local shrink = Vector3.new(0.5, 0.5, 0.5)
	local inside = workspace:GetPartBoundsInBox(cf, def.size - shrink, boxParams)
	if #inside > 0 then
		return false, "Espaço ocupado", nil
	end
	-- Não pode prender/encobrir jogadores
	for _, other in Players:GetPlayers() do
		local ohrp = hrpOf(other)
		if ohrp then
			local rel = cf:PointToObjectSpace(ohrp.Position)
			local half = def.size / 2 + Vector3.new(1.5, 3, 1.5)
			if math.abs(rel.X) < half.X and math.abs(rel.Y) < half.Y and math.abs(rel.Z) < half.Z then
				return false, "Há um jogador no caminho", nil
			end
		end
	end
	-- Apoio: chão (terreno) abaixo ou encostado em outra construção
	local down = workspace:Raycast(p, Vector3.new(0, -(def.size.Y / 2 + 2.5), 0), rayParams)
	local supported = down ~= nil
	if not supported then
		local touching = workspace:GetPartBoundsInBox(cf, def.size + Vector3.new(0.6, 0.6, 0.6), boxParams)
		for _, part in touching do
			if part:IsDescendantOf(root) then
				supported = true
				break
			end
		end
	end
	if not supported then
		return false, "Precisa de apoio", nil
	end
	return true, nil, cf
end

local function onPlace(player: Player, id: any, x: any, y: any, z: any, rot: any)
	local sid = Actions.str(id, 32)
	if not sid or not Structures.defs[sid] then
		return
	end
	if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" or x ~= x or y ~= y or z ~= z then
		return
	end
	local r = Actions.int(rot, 0, 3)
	if r == nil then
		return
	end
	local def = Structures.defs[sid]
	if not PlayerService.has(player, { [def.item] = 1 }) then
		PlayerService.notify(player, "Você não tem " .. Items[def.item].name, "bad", "⛔")
		return
	end
	local ok, why, cf = BuildService.validate(player, sid, Vector3.new(x, y, z), r)
	if not ok or not cf then
		PlayerService.notify(player, why or "Não pode construir aqui", "bad", "⛔")
		return
	end
	if not PlayerService.take(player, { [def.item] = 1 }) then
		return
	end
	create(player, sid, cf, nil)
	PlayerService.count(player, "build", 1)
	PlayerService.count(player, "build_" .. sid, 1)
	PlayerService.addXp(player, 4)
	fxEvent:FireAllClients({ kind = "build", pos = cf.Position })
	local mine = totems[player]
	if sid ~= "base_totem" and (not mine or claimAt(cf.Position) ~= mine) then
		PlayerService.notify(player, "Fora do seu Totem: esta construção não será salva", "info", "🗿")
	elseif sid == "base_totem" then
		PlayerService.notify(
			player,
			"Território criado! Construções num raio de 45 studs serão salvas.",
			"good",
			"🗿"
		)
	end
end

local function onDemolish(player: Player, guid: any)
	local g = Actions.str(guid, 64)
	local b = g and byGuid[g]
	local hrp = hrpOf(player)
	if not b or not hrp or b.owner ~= player then
		return
	end
	if (b.model:GetPivot().Position - hrp.Position).Magnitude > Structures.PLACE_RANGE + 6 then
		return
	end
	if b.chest and next(b.chest.slots) ~= nil then
		PlayerService.notify(player, "Esvazie o baú antes de desmontar", "bad", "📦")
		return
	end
	if b.id == "rescue_beacon" and b.model:GetAttribute("Lit") then
		PlayerService.notify(player, "O Farol aceso é permanente", "info", "🗼")
		return
	end
	local item = Structures.defs[b.id].item
	if PlayerService.give(player, item, 1, true) == 0 then
		return
	end
	destroy(b)
	PlayerService.notify(player, "Desmontado: " .. Items[item].name .. " devolvido", "info", Items[item].icon)
end

-- ===== Salvamento da base =====
local function serializeBase(player: Player, data: any)
	local t = totems[player]
	if not t then
		data.base = nil
		return
	end
	local origin = t.model:GetPivot()
	local list = {}
	for _, b in owned[player] or {} do
		if b ~= t and claimAt(b.model:GetPivot().Position) == t then
			local rel = origin:ToObjectSpace(b.model:GetPivot())
			local _, ry, _ = rel:ToOrientation()
			local entry = {
				b.id,
				math.floor(rel.X * 100) / 100,
				math.floor(rel.Y * 100) / 100,
				math.floor(rel.Z * 100) / 100,
				math.round(ry / (math.pi / 2)) % 4,
			}
			if b.chest then
				entry[6] = Inventory.serialize(b.chest)
			end
			if beds[player] == b then
				entry[7] = true
			end
			if b.model:GetAttribute("Lit") then
				entry[8] = true
			end
			table.insert(list, entry)
		end
	end
	local p = origin.Position
	data.base = { totem = { p.X, p.Y, p.Z }, list = list }
end

-- Acha um local livre para o Totem (posição salva pode estar ocupada por outra base)
local function findTotemSpot(player: Player, want: Vector3): Vector3?
	local r = Structures.defs.base_totem.claim :: number
	local function free(pos: Vector3): boolean
		for owner, t in totems do
			if owner ~= player and ((t.model:GetPivot().Position - pos) * Vector3.new(1, 0, 1)).Magnitude < r * 2 then
				return false
			end
		end
		local region = Regions.at(pos)
		return region.id ~= "cave"
			and region.id ~= "volcano"
			and ((pos - Regions.SPAWN) * Vector3.new(1, 0, 1)).Magnitude > Structures.MIN_DISTANCE_FROM_SPAWN + r
	end
	if free(want) then
		return want
	end
	for ring = 1, 8 do
		for i = 0, 11 do
			local a = i / 12 * math.pi * 2
			local x = want.X + math.cos(a) * ring * r * 1.1
			local z = want.Z + math.sin(a) * ring * r * 1.1
			local gy = WorldService.GetGroundY(x, z)
			if gy and gy > 2 then
				local pos = Vector3.new(x, gy + Structures.defs.base_totem.size.Y / 2, z)
				if free(pos) then
					return pos
				end
			end
		end
	end
	return nil
end

local function restoreBase(player: Player, data: any)
	local base = data.base
	if type(base) ~= "table" or type(base.totem) ~= "table" then
		return
	end
	local want = Vector3.new(base.totem[1], base.totem[2], base.totem[3])
	local spot = findTotemSpot(player, want)
	if not spot then
		PlayerService.notify(
			player,
			"Não foi possível posicionar sua base; Totem devolvido ao inventário",
			"bad",
			"🗿"
		)
		PlayerService.give(player, "base_totem", 1, true)
		return
	end
	local moved = (spot - want).Magnitude > 1
	local gy = WorldService.GetGroundY(spot.X, spot.Z)
	if moved and gy then
		spot = Vector3.new(spot.X, gy + Structures.defs.base_totem.size.Y / 2, spot.Z)
	end
	local origin = CFrame.new(spot)
	create(player, "base_totem", origin, nil)
	local count = 0
	for _, e in base.list or {} do
		local id = e[1]
		if type(id) == "string" and Structures.defs[id] and count < Structures.MAX_PER_PLAYER then
			local rel = CFrame.new(e[2] or 0, e[3] or 0, e[4] or 0) * CFrame.Angles(0, (e[5] or 0) * math.pi / 2, 0)
			local b = create(player, id, origin * rel, e[6])
			if e[7] then
				beds[player] = b
			end
			if e[8] then
				b.model:SetAttribute("Lit", true)
			end
			count += 1
		end
	end
	if moved then
		PlayerService.notify(player, "Seu terreno estava ocupado: sua base foi movida para perto", "info", "🗿")
	end
end

function BuildService.init()
	root = workspace:WaitForChild("World"):WaitForChild("Structures") :: Folder
	local world = workspace:WaitForChild("World")
	rayParams.FilterDescendantsInstances = { workspace.Terrain, root }
	boxParams.FilterDescendantsInstances = { root, world:WaitForChild("Nodes") }

	Actions.on("Place", onPlace, 6)
	Actions.on("Demolish", onDemolish, 6)
	Actions.on("ChestMove", onChestMove, 15)
	Actions.on("ChestClose", function(player)
		openChest[player] = nil
	end, 5)

	PlayerService.onReady(function(player, data)
		local ok, err = pcall(restoreBase, player, data)
		if not ok then
			warn("[Build] restore:", err)
		end
	end)
	DataService.onBeforeSave(serializeBase)

	Players.PlayerRemoving:Connect(function(player)
		task.defer(function()
			for _, b in table.clone(owned[player] or {}) do
				destroy(b)
			end
			owned[player] = nil
			openChest[player] = nil
			local f = root:FindFirstChild(tostring(player.UserId))
			if f then
				f:Destroy()
			end
		end)
	end)

	-- Coletores de chuva enchem quando chove
	task.spawn(function()
		while true do
			task.wait(20)
			if Env.raining then
				for _, b in built do
					if b.id == "rain_collector" then
						local w = (b.model:GetAttribute("Water") :: number?) or 0
						if w < 5 then
							b.model:SetAttribute("Water", w + 1)
						end
					end
				end
			end
		end
	end)
end

return BuildService
