--!strict
-- Janela de crafting com abas, custo colorido (tem/falta), estação exigida e quantidade.

local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local Recipes = require(Shared.Config.Recipes)

local Lib = require(script.Parent.Parent.UI.Lib)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local State = require(script.Parent.Parent.State)
local T = Lib.Theme

local Crafting = {}

local TABS = {
	{ "tools", "⛏️ Ferramentas" },
	{ "weapons", "⚔️ Armas" },
	{ "armor", "🛡️ Armaduras" },
	{ "build", "🏗️ Construções" },
	{ "food", "🍖 Cozinha" },
	{ "materials", "🔩 Materiais" },
}
local STATION_NAME = { workbench = "Bancada 🛠️", campfire = "Fogueira 🔥", forge = "Fornalha 🏭" }

-- Estação próxima (checagem visual; o servidor valida de verdade)
local function nearStation(station: string): boolean
	local char = Players.LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local folder = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Structures")
	if not hrp or not folder then
		return false
	end
	for _, m in folder:GetDescendants() do
		if m:IsA("Model") and m:GetAttribute("StructureId") == station then
			if (m:GetPivot().Position - hrp.Position).Magnitude <= Recipes.STATION_RANGE then
				return true
			end
		end
	end
	return false
end

function Crafting.init(gui: ScreenGui)
	local _, body = Widgets.window(gui, "Crafting", "🔨 Criar", Vector2.new(820, 520))
	local tabBar = Lib.new("Frame", { Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, Parent = body })
	Lib.new(
		"UIListLayout",
		{ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = tabBar }
	)
	local listHolder = Lib.new(
		"Frame",
		{
			Position = UDim2.fromOffset(0, 46),
			Size = UDim2.new(0, 470, 1, -46),
			BackgroundTransparency = 1,
			Parent = body,
		}
	)
	local list = Lib.new(
		"ScrollingFrame",
		{
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			Parent = listHolder,
		}
	)
	Lib.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	local detail = Lib.panel({
		Position = UDim2.new(0, 482, 0, 46),
		Size = UDim2.new(1, -482, 1, -46),
		BackgroundColor3 = T.panel2,
		Parent = body,
	})
	Lib.pad(12).Parent = detail

	local icon = Lib.text({ Size = UDim2.new(1, 0, 0, 60), Text = "🛠️", TextSize = 48, Parent = detail })
	local title = Lib.text({
		Position = UDim2.fromOffset(0, 62),
		Size = UDim2.new(1, 0, 0, 24),
		Text = "",
		TextSize = 19,
		Parent = detail,
	})
	local desc = Lib.text({
		Position = UDim2.fromOffset(0, 88),
		Size = UDim2.new(1, 0, 0, 40),
		Text = "",
		TextSize = 13,
		Font = T.fontBody,
		TextColor3 = T.muted,
		Parent = detail,
	})
	local costs = Lib.new(
		"Frame",
		{
			Position = UDim2.fromOffset(0, 132),
			Size = UDim2.new(1, 0, 0, 130),
			BackgroundTransparency = 1,
			Parent = detail,
		}
	)
	Lib.new("UIListLayout", { Padding = UDim.new(0, 4), Parent = costs })
	local req = Lib.text({
		Position = UDim2.fromOffset(0, 266),
		Size = UDim2.new(1, 0, 0, 40),
		Text = "",
		TextSize = 13,
		Font = T.fontBody,
		Parent = detail,
	})
	local craftBtn = Lib.button({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(0.62, -4, 0, 46),
		Text = "Fabricar",
		TextSize = 18,
		BackgroundColor3 = T.accent:Lerp(T.panel, 0.35),
		Parent = detail,
	})
	local craft5 = Lib.button({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 0),
		Size = UDim2.new(0.38, -4, 0, 46),
		Text = "x5",
		TextSize = 18,
		Parent = detail,
	})

	local tab = "tools"
	local current: any = nil

	local function haveAll(r: any, times: number): boolean
		for id, n in r.cost do
			if State.count(id) < n * times then
				return false
			end
		end
		return true
	end

	local function showRecipe(r: any)
		current = r
		local out = Items[r.output]
		icon.Text = out.icon
		title.Text = out.name .. (r.amount > 1 and (" x" .. r.amount) or "")
		title.TextColor3 = T.rarity[out.rarity or "common"] or T.text
		desc.Text = out.description
		for _, c in costs:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for id, n in r.cost do
			local have = State.count(id)
			local def = Items[id]
			Lib.text({
				Size = UDim2.new(1, 0, 0, 22),
				Text = ("%s %s  %d/%d"):format(def.icon, def.name, have, n),
				TextSize = 15,
				Font = T.fontBody,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = have >= n and T.good or T.bad,
				Parent = costs,
			})
		end
		local lines = {}
		local blocked = false
		local level = State.data.level or 1
		if level < r.level then
			table.insert(lines, ("🔒 Requer nível %d"):format(r.level))
			blocked = true
		end
		if r.station then
			local ok = nearStation(r.station)
			blocked = blocked or not ok
			table.insert(lines, (ok and "✅ " or "📍 Perto de: ") .. STATION_NAME[r.station])
		end
		req.Text = table.concat(lines, "\n")
		req.TextColor3 = blocked and T.bad or T.good
		local can = level >= r.level and haveAll(r, 1) and (r.station == nil or nearStation(r.station))
		craftBtn.BackgroundColor3 = can and T.accent:Lerp(T.panel, 0.25) or T.panel
		craftBtn.TextColor3 = can and T.text or T.muted
		craft5.Visible = Items[r.output].stack > 1
	end

	local function rebuild()
		for _, c in list:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local level = State.data.level or 1
		local firstShown = nil
		for i, r in Recipes.list do
			if r.tab == tab then
				local out = Items[r.output]
				local locked = level < r.level
				local can = not locked and haveAll(r, 1)
				local row = Lib.button(
					{
						Size = UDim2.new(1, -10, 0, 54),
						LayoutOrder = (locked and 1000 or 0) + i,
						BackgroundColor3 = can and T.slot or T.panel2,
						Parent = list,
					},
					function()
						showRecipe(r)
					end
				)
				Lib.text({
					Position = UDim2.fromOffset(8, 0),
					Size = UDim2.fromOffset(44, 54),
					Text = out.icon,
					TextSize = 30,
					Parent = row,
				})
				Lib.text({
					Position = UDim2.fromOffset(60, 6),
					Size = UDim2.new(1, -70, 0, 22),
					Text = out.name,
					TextSize = 16,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = locked and T.muted or T.text,
					Parent = row,
				})
				local sub = locked and ("🔒 Nível " .. r.level)
					or (r.station and STATION_NAME[r.station] or "Com as mãos")
				Lib.text({
					Position = UDim2.fromOffset(60, 28),
					Size = UDim2.new(1, -70, 0, 18),
					Text = sub,
					TextSize = 12,
					Font = T.fontBody,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = can and T.good or T.muted,
					Parent = row,
				})
				firstShown = firstShown or r
			end
		end
		if current == nil or current.tab ~= tab then
			current = firstShown
		end
		if current then
			showRecipe(current)
		end
	end

	for i, t in TABS do
		local b = Lib.button({
			Size = UDim2.fromOffset(126, 36),
			Text = t[2],
			TextSize = 13,
			LayoutOrder = i,
			Parent = tabBar,
		})
		b.Activated:Connect(function()
			tab = t[1]
			current = nil
			for _, other in tabBar:GetChildren() do
				if other:IsA("TextButton") then
					other.BackgroundColor3 = other == b and T.accent2:Lerp(T.panel, 0.5) or T.panel2
				end
			end
			rebuild()
		end)
		if i == 1 then
			b.BackgroundColor3 = T.accent2:Lerp(T.panel, 0.5)
		end
	end

	craftBtn.Activated:Connect(function()
		if current then
			State.action("Craft", current.id, 1)
		end
	end)
	craft5.Activated:Connect(function()
		if current then
			State.action("Craft", current.id, 5)
		end
	end)

	State.on("inv", function()
		if Widgets.current == "Crafting" then
			rebuild()
		end
	end)
	Widgets.onWindow("Crafting", rebuild)
end

return Crafting
