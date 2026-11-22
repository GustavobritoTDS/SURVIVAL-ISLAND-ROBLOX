--!strict
-- Janela de inventário: grade, detalhes do item, armadura e baú.
-- Toque/clique: seleciona; segundo toque em outro slot: move/troca. Com baú aberto: toque transfere.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Items = require(Shared.Config.Items)

local Lib = require(script.Parent.Parent.UI.Lib)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local State = require(script.Parent.Parent.State)
local T = Lib.Theme

local Inventory = {}

local CATEGORY = {
	resource = "Recurso",
	food = "Comida",
	tool = "Ferramenta",
	weapon = "Arma",
	armor = "Armadura",
	structure = "Construção",
	special = "Especial",
}

function Inventory.init(gui: ScreenGui)
	local win, body = Widgets.window(gui, "Inventory", "🎒 Inventário", Vector2.new(820, 520))

	local left = Lib.new("Frame", { Size = UDim2.new(0, 500, 1, 0), BackgroundTransparency = 1, Parent = body })
	local grid = Widgets.scroll(left, Vector2.new(70, 70), 8)
	local right = Lib.panel({
		Position = UDim2.new(0, 512, 0, 0),
		Size = UDim2.new(1, -512, 1, 0),
		BackgroundColor3 = T.panel2,
		Parent = body,
	})
	Lib.pad(12).Parent = right

	-- Detalhes
	local details = Lib.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = right })
	local bigIcon = Lib.text({ Size = UDim2.new(1, 0, 0, 70), Text = "🎒", TextSize = 54, Parent = details })
	local name = Lib.text({
		Position = UDim2.fromOffset(0, 74),
		Size = UDim2.new(1, 0, 0, 26),
		Text = "Selecione um item",
		TextSize = 19,
		Parent = details,
	})
	local cat = Lib.text({
		Position = UDim2.fromOffset(0, 100),
		Size = UDim2.new(1, 0, 0, 18),
		Text = "",
		TextSize = 13,
		TextColor3 = T.muted,
		Font = T.fontBody,
		Parent = details,
	})
	local desc = Lib.text({
		Position = UDim2.fromOffset(0, 124),
		Size = UDim2.new(1, 0, 0, 84),
		Text = "Toque num item para ver detalhes. Toque em outro espaço para mover.",
		TextSize = 14,
		Font = T.fontBody,
		TextColor3 = T.text,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = details,
	})
	local actions = Lib.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 150),
		BackgroundTransparency = 1,
		Parent = details,
	})
	Lib.new(
		"UIListLayout",
		{ Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Bottom, Parent = actions }
	)

	local armorRow = Lib.text({
		Position = UDim2.fromOffset(0, 212),
		Size = UDim2.new(1, 0, 0, 20),
		Text = "",
		TextSize = 14,
		TextColor3 = T.accent2,
		Parent = details,
	})

	-- Baú
	local chestView =
		Lib.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = right })
	Lib.text({
		Size = UDim2.new(1, 0, 0, 24),
		Text = "📦 Baú (toque para transferir)",
		TextSize = 16,
		TextColor3 = T.accent,
		Parent = chestView,
	})
	local chestGridHolder = Lib.new("Frame", {
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 1, -30),
		BackgroundTransparency = 1,
		Parent = chestView,
	})
	local chestGrid = Widgets.scroll(chestGridHolder, Vector2.new(58, 58), 6)

	local selected: number? = nil
	local slotWidgets: { Widgets.Slot } = {}
	local chestWidgets: { Widgets.Slot } = {}

	local function actionButton(text: string, color: Color3, fn: () -> ())
		local b =
			Lib.button({ Size = UDim2.new(1, 0, 0, 40), Text = text, BackgroundColor3 = color, TextSize = 16 }, fn)
		b.Parent = actions
	end

	local function showDetails()
		for _, c in actions:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local st = selected and State.slots[selected]
		local def = st and Items[st.id]
		local armor = State.data.armor and Items[State.data.armor]
		armorRow.Text = armor and ("Vestindo: " .. armor.icon .. " " .. armor.name) or "Sem armadura"
		if armor then
			actionButton("Tirar armadura", T.panel, function()
				State.action("UnequipArmor")
			end)
		end
		if not def or not selected then
			bigIcon.Text = "🎒"
			name.Text = "Selecione um item"
			cat.Text = ""
			desc.Text =
				"Toque num item para ver detalhes. Toque em outro espaço para mover. Espaços 1–6 são a barra rápida."
			return
		end
		local slot = selected :: number
		bigIcon.Text = def.icon
		name.Text = def.name
		name.TextColor3 = T.rarity[def.rarity or "common"] or T.text
		cat.Text = (CATEGORY[def.category] or def.category) .. "  ·  x" .. st.n
		local extra = ""
		if def.hunger or def.thirst then
			extra = ("\n🍖 +%d   💧 +%d"):format(def.hunger or 0, def.thirst or 0)
		elseif def.damage then
			extra = ("\n⚔️ Dano %d   ⏱️ %.1fs"):format(def.damage, def.cooldown or 0.6)
		elseif def.defense then
			extra = ("\n🛡️ Defesa %d%%   🔥 Calor %d%%"):format(def.defense * 100, (def.warmth or 0) * 100)
		end
		desc.Text = def.description .. extra
		if def.id == "island_map" then
			actionButton("🗺️ Abrir mapa (N)", T.accent2:Lerp(T.panel, 0.4), function()
				Widgets.toggle("Map", true)
			end)
			return
		end
		if def.category == "food" then
			actionButton("Comer / Beber", T.good:Lerp(T.panel, 0.4), function()
				State.action("Use", slot)
			end)
		elseif def.category == "armor" then
			actionButton("Vestir", T.accent2:Lerp(T.panel, 0.4), function()
				State.action("Use", slot)
			end)
		elseif def.category == "structure" then
			actionButton("Construir", T.accent:Lerp(T.panel, 0.4), function()
				Widgets.closeAll()
				require(script.Parent.Build).start(def.id)
			end)
		end
		actionButton("Descartar", T.bad:Lerp(T.panel, 0.5), function()
			State.action("Drop", slot)
			selected = nil
		end)
	end

	local function rebuild()
		local size = State.data.invSize or 24
		while #slotWidgets < size do
			local i = #slotWidgets + 1
			local s = Widgets.slot(grid, 70, i)
			slotWidgets[i] = s
			s.frame.Activated:Connect(function()
				if State.data.chest and State.slots[i] then
					State.action("ChestMove", "inv", i, "chest", 0)
					return
				end
				if selected and selected ~= i then
					State.action("Move", selected, i)
					selected = nil
				elseif State.slots[i] then
					selected = if selected == i then nil else i
				end
				for j, w in slotWidgets do
					w.setSelected(j == selected)
				end
				showDetails()
			end)
		end
		for i, s in slotWidgets do
			s.frame.Visible = i <= size
			s.set(State.slots[i])
			s.setSelected(i == selected)
		end
		if selected and not State.slots[selected] then
			selected = nil
		end
		showDetails()
	end
	State.on("inv", rebuild, true)

	local function rebuildChest(chest: any)
		if not chest then
			chestView.Visible = false
			details.Visible = true
			return
		end
		chestView.Visible = true
		details.Visible = false
		local slots = {}
		for _, e in chest.inv do
			slots[e[3]] = { id = e[1], n = e[2] }
		end
		while #chestWidgets < chest.size do
			local i = #chestWidgets + 1
			local s = Widgets.slot(chestGrid, 58, i)
			chestWidgets[i] = s
			s.frame.Activated:Connect(function()
				State.action("ChestMove", "chest", i, "inv", 0)
			end)
		end
		for i, s in chestWidgets do
			s.set(slots[i])
		end
	end
	State.on("chest", function(chest)
		rebuildChest(chest)
		if chest then
			Widgets.toggle("Inventory", true)
		end
	end)

	Widgets.onWindow("Inventory", nil, function()
		if State.data.chest then
			State.action("ChestClose")
			State.data.chest = nil
			rebuildChest(nil)
		end
		selected = nil
	end)
	local _ = win
end

return Inventory
