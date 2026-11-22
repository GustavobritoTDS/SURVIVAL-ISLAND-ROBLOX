--!strict
-- Seleção da hotbar, ferramentas na mão, uso de consumíveis e armadura.

local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Items = require(Shared.Config.Items)
local Game = require(Shared.Config.Game)
local Rules = require(Shared.Logic.Rules)
local Net = require(Shared.Net)

local PlayerService = require(script.Parent.PlayerService)
local Actions = require(script.Parent.Parent.Util.Actions)
local ToolModels = require(script.Parent.Parent.Builders.ToolModels)

local EquipService = {}

local fxEvent = Net.event("Fx")
local activatedHandlers: { (Player, string, Tool) -> () } = {}
local lastSwing: { [Player]: number } = {}
Players.PlayerRemoving:Connect(function(p)
	lastSwing[p] = nil
end)

-- Outros serviços (Resource/Combat) registram o que acontece ao golpear
function EquipService.onActivated(fn: (Player, string, Tool) -> ())
	table.insert(activatedHandlers, fn)
end

local function currentTool(character: Model): Tool?
	return character:FindFirstChildOfClass("Tool")
end

local function clearTools(player: Player)
	local char = player.Character
	if char then
		for _, t in char:GetChildren() do
			if t:IsA("Tool") then
				t:Destroy()
			end
		end
	end
	local bp = player:FindFirstChildOfClass("Backpack")
	if bp then
		bp:ClearAllChildren()
	end
end

-- Garante que a Tool na mão corresponde ao slot selecionado
function EquipService.refresh(player: Player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not hum or hum.Health <= 0 then
		return
	end
	local itemId = PlayerService.equippedItem(player)
	local def = itemId and Items[itemId]
	local tool = currentTool(char)
	if def and def.toolType then
		if tool and tool:GetAttribute("ItemId") == itemId then
			return
		end
		clearTools(player)
		local newTool = ToolModels.build(itemId :: string)
		if newTool then
			newTool.Activated:Connect(function()
				-- cooldown por jogador (não por Tool): trocar de slot não zera o tempo
				local now = os.clock()
				if now - (lastSwing[player] or 0) < (def.cooldown or 0.6) then
					return
				end
				lastSwing[player] = now
				-- animação de golpe padrão do Roblox
				local anim = Instance.new("StringValue")
				anim.Name = "toolanim"
				anim.Value = "Slash"
				anim.Parent = newTool
				game:GetService("Debris"):AddItem(anim, 0.5)
				for _, fn in activatedHandlers do
					task.spawn(fn, player, itemId :: string, newTool)
				end
			end)
			newTool.Parent = char
		end
	elseif tool then
		clearTools(player)
	end
end

local function onSelect(player: Player, slot: any)
	local sl = slot == 0 and 0 or Actions.int(slot, 1, Game.HOTBAR_SLOTS)
	if sl == nil then
		return
	end
	local _, cur = PlayerService.equippedItem(player)
	if sl == 0 or cur == sl then
		PlayerService.setEquipped(player, nil)
	else
		PlayerService.setEquipped(player, sl)
	end
	EquipService.refresh(player)
end

-- Usar item de um slot: comer/beber ou vestir armadura
local function onUse(player: Player, slot: any)
	local inv = PlayerService.inv(player)
	local data = PlayerService.data(player)
	local sl = inv and Actions.int(slot, 1, inv.size)
	if not inv or not data or not sl then
		return
	end
	local st = inv.slots[sl]
	if not st then
		return
	end
	local def = Items[st.id]
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return
	end
	if def.category == "food" then
		local ok, heal = Rules.consume(data.stats, def, Game.MAX_STAT)
		if ok and PlayerService.takeFromSlot(player, sl, 1) then
			if heal ~= 0 then
				hum.Health = math.clamp(hum.Health + heal, 1, hum.MaxHealth)
			end
			if st.id == "cooked_meat" or st.id == "cooked_crab" or st.id == "tropical_stew" then
				PlayerService.count(player, "eat_cooked", 1)
			end
			fxEvent:FireClient(player, { kind = "eat", icon = def.icon })
			PlayerService.sync(player, "stats")
		end
	elseif def.category == "armor" then
		local previous = data.armor
		if PlayerService.takeFromSlot(player, sl, 1) then
			data.armor = st.id
			if previous then
				PlayerService.give(player, previous, 1, true)
			end
			EquipService.applyArmorVisual(player)
			PlayerService.notify(player, "Equipou " .. def.name, "good", def.icon)
			PlayerService.sync(player, "inv")
		end
	elseif def.toolType then
		onSelect(player, sl <= Game.HOTBAR_SLOTS and sl or 0)
	end
end

local function onUnequipArmor(player: Player)
	local data = PlayerService.data(player)
	if data and data.armor then
		local id = data.armor
		data.armor = nil
		if PlayerService.give(player, id, 1, true) == 0 then
			data.armor = id -- sem espaço: mantém
			return
		end
		EquipService.applyArmorVisual(player)
		PlayerService.sync(player, "inv")
	end
end

-- Visual simples da armadura: cor no torso + atributo para defesa
function EquipService.applyArmorVisual(player: Player)
	local data = PlayerService.data(player)
	local char = player.Character
	if not data or not char then
		return
	end
	local old = char:FindFirstChild("ArmorVisual")
	if old then
		old:Destroy()
	end
	local def = data.armor and Items[data.armor]
	player:SetAttribute("ArmorDefense", def and def.defense or 0)
	player:SetAttribute("ArmorWarmth", def and def.warmth or 0)
	local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	if def and torso and torso:IsA("BasePart") then
		local plate = Instance.new("Part")
		plate.Name = "ArmorVisual"
		plate.Size = torso.Size + Vector3.new(0.15, 0.1, 0.15)
		plate.Color = def.color
		plate.Material = def.id == "crystal_armor" and Enum.Material.Glass or (def.id == "iron_armor" and Enum.Material.Metal or Enum.Material.Fabric)
		plate.Transparency = def.id == "crystal_armor" and 0.3 or 0
		plate.CanCollide = false
		plate.CanQuery = false
		plate.CanTouch = false
		plate.Massless = true
		plate.CFrame = torso.CFrame
		local w = Instance.new("WeldConstraint")
		w.Part0 = torso
		w.Part1 = plate
		w.Parent = plate
		plate.Parent = char
	end
end

-- Remove a Tool quando o item sai da hotbar
PlayerService.onInventoryChanged(function(player)
	EquipService.refresh(player)
end)

function EquipService.init()
	Actions.on("Select", onSelect, 12)
	Actions.on("Use", onUse, 8)
	Actions.on("UnequipArmor", onUnequipArmor, 3)

	local function onCharacter(player: Player, char: Model)
		local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
		if hum then
			task.wait(0.2)
			EquipService.applyArmorVisual(player)
			EquipService.refresh(player)
		end
	end
	Players.PlayerAdded:Connect(function(p)
		p.CharacterAdded:Connect(function(c)
			onCharacter(p, c)
		end)
	end)
	for _, p in Players:GetPlayers() do
		p.CharacterAdded:Connect(function(c)
			onCharacter(p, c)
		end)
	end
end

return EquipService
