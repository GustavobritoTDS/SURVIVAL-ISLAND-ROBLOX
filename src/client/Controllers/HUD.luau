--!strict
-- HUD: barras de status, nível/XP, Conchas, relógio/clima/região, hotbar, botões de menu e notificações.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local Regions = require(Shared.Config.Regions)
local Game = require(Shared.Config.Game)
local Net = require(Shared.Net)

local Lib = require(script.Parent.Parent.UI.Lib)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local State = require(script.Parent.Parent.State)
local T = Lib.Theme

local HUD = {}
HUD.gui = nil :: ScreenGui?
HUD.hotbar = {} :: { Widgets.Slot }
HUD.menuButtons = {} :: { [string]: TextButton }

local player = Players.LocalPlayer

local function makeGui(): ScreenGui
	local gui = Lib.new("ScreenGui", {
		Name = "SurvivalHUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	-- Escala responsiva: projeta para 720 px de altura
	local scale = Lib.new("UIScale", { Parent = gui })
	local function rescale()
		local cam = workspace.CurrentCamera
		local vh = cam and cam.ViewportSize.Y or 720
		scale.Scale = math.clamp(vh / 720, 0.62, 1.15)
	end
	rescale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end
	return gui
end

-- ===== Notificações (toast com stagger, entrada pela direita) =====
local toastHolder: Frame
local function notify(n: any)
	local color = ({ good = T.good, bad = T.bad, item = T.accent2, level = T.accent, quest = T.xp })[n.kind] or T.muted
	local card = Lib.panel({ Size = UDim2.fromOffset(300, 42), BackgroundColor3 = T.panel, Parent = toastHolder })
	local st = card:FindFirstChildOfClass("UIStroke") :: UIStroke
	st.Color = color
	st.Transparency = 0.1
	Lib.text({ Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(30, 42), Text = n.icon or "•", TextSize = 22, Parent = card })
	local label = Lib.text({ Position = UDim2.fromOffset(42, 0), Size = UDim2.new(1, -50, 1, 0), Text = n.text, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Font = T.fontBody, Parent = card })
	label.TextTruncate = Enum.TextTruncate.AtEnd
	local inner = Lib.new("UIScale", { Scale = 0.85, Parent = card })
	Lib.tween(inner, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	if n.kind == "bad" then
		Lib.shake(card)
	end
	local children = toastHolder:GetChildren()
	local cards = 0
	for _, c in children do
		if c:IsA("Frame") then
			cards += 1
		end
	end
	if cards > 5 then
		for _, c in children do
			if c:IsA("Frame") and c ~= card then
				c:Destroy()
				break
			end
		end
	end
	task.delay(n.kind == "level" and 5 or 3.2, function()
		if card.Parent then
			Lib.tween(inner, 0.16, { Scale = 0.8 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Wait()
			card:Destroy()
		end
	end)
end
HUD.notify = notify

-- ===== Construção do HUD =====
function HUD.init()
	local gui = makeGui()
	HUD.gui = gui

	-- Status (canto superior esquerdo)
	local stats = Lib.panel({ Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(240, 128), BackgroundTransparency = 0.25, Parent = gui })
	Lib.pad(10).Parent = stats
	Lib.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = stats })
	local setHealth = Widgets.bar(stats, "❤️", T.health, 1)
	local setHunger = Widgets.bar(stats, "🍖", T.hunger, 2)
	local setThirst = Widgets.bar(stats, "💧", T.thirst, 3)
	local setWarmth = Widgets.bar(stats, "🔥", T.warmth, 4)
	State.on("stats", function(s)
		if not s then
			return
		end
		setHunger(s.hunger)
		setThirst(s.thirst)
		setWarmth(s.warmth)
	end, true)
	-- Vida vem do Humanoid (mais responsivo)
	local function bindHumanoid(char: Model)
		local hum = char:WaitForChild("Humanoid") :: Humanoid
		setHealth(hum.Health / hum.MaxHealth * 100)
		hum.HealthChanged:Connect(function(h)
			setHealth(h / hum.MaxHealth * 100)
		end)
	end
	if player.Character then
		task.spawn(bindHumanoid, player.Character)
	end
	player.CharacterAdded:Connect(bindHumanoid)

	-- Nível + XP + Conchas (topo central)
	local top = Lib.panel({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(360, 52), BackgroundTransparency = 0.25, Parent = gui })
	local lvl = Lib.text({ Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(70, 52), Text = "Nv 1", TextSize = 20, TextColor3 = T.accent, Parent = top })
	local xpBack = Lib.new("Frame", { Position = UDim2.fromOffset(84, 20), Size = UDim2.fromOffset(150, 12), BackgroundColor3 = Color3.fromRGB(10, 16, 20), Parent = top })
	Lib.corner(6).Parent = xpBack
	local xpFill = Lib.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.xp, Parent = xpBack })
	Lib.corner(6).Parent = xpFill
	local shells = Lib.text({ Position = UDim2.fromOffset(240, 0), Size = UDim2.fromOffset(110, 52), Text = "🐚 0", TextSize = 18, Parent = top })
	State.on("level", function(v)
		lvl.Text = "Nv " .. tostring(v or 1)
		Lib.pop(lvl)
	end, true)
	State.on("xp", function()
		local need = State.data.xpNeed or 100
		Lib.tween(xpFill, 0.4, { Size = UDim2.fromScale(math.clamp((State.data.xp or 0) / need, 0, 1), 1) })
	end, true)
	State.on("shells", function(v)
		shells.Text = "🐚 " .. tostring(v or 0)
		Lib.pop(shells)
	end, true)

	-- Relógio, clima e região (canto superior direito)
	local info = Lib.panel({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 16), Size = UDim2.fromOffset(210, 52), BackgroundTransparency = 0.25, Parent = gui })
	local clock = Lib.text({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 22), Text = "☀️ 08:00", TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, Parent = info })
	local region = Lib.text({ Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -20, 0, 20), Text = "Praia do Naufrágio", TextSize = 13, Font = T.fontBody, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = info })
	task.spawn(function()
		while true do
			local t = Lighting.ClockTime
			local h = math.floor(t)
			local m = math.floor((t - h) * 60)
			local night = workspace:GetAttribute("Night") == true
			local w = workspace:GetAttribute("Weather")
			local icon = night and "🌙" or "☀️"
			if w == "rain" then
				icon ..= "🌧️"
			elseif w == "storm" then
				icon ..= "⛈️"
			end
			clock.Text = ("%s %02d:%02d  ·  Noite %d"):format(icon, h, m, ((workspace:GetAttribute("NightCount") :: number?) or 0) + 1)
			local rid = player:GetAttribute("Region")
			local r = rid and Regions.byId[rid :: string]
			region.Text = r and r.name or "Ilha"
			region.TextColor3 = r and r.color or T.muted
			task.wait(0.5)
		end
	end)

	-- Hotbar (base central)
	local hotbar = Lib.new("Frame", { Name = "Hotbar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(Game.HOTBAR_SLOTS * 72, 66), BackgroundTransparency = 1, Parent = gui })
	Lib.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = hotbar })
	for i = 1, Game.HOTBAR_SLOTS do
		local s = Widgets.slot(hotbar, 64, i)
		HUD.hotbar[i] = s
		s.frame.Activated:Connect(function()
			HUD.useHotbar(i)
		end)
	end
	local armorLabel = Lib.text({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -86), Size = UDim2.fromOffset(300, 18), Text = "", TextSize = 13, Font = T.fontBody, TextColor3 = T.muted, Parent = gui })
	local function refreshHotbar()
		for i, s in HUD.hotbar do
			s.set(State.slots[i])
			s.setSelected(State.data.equipped == i)
		end
		local a = State.data.armor and Items[State.data.armor]
		armorLabel.Text = a and (a.icon .. " " .. a.name) or ""
	end
	State.on("inv", refreshHotbar, true)

	-- Botões de menu (lado direito)
	local menu = Lib.new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(64, 6 * 70), BackgroundTransparency = 1, Parent = gui })
	Lib.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center, Parent = menu })
	local entries = {
		{ "Inventory", "🎒", "Tab" },
		{ "Crafting", "🛠️", "C" },
		{ "Build", "🏗️", "B" },
		{ "Quests", "📜", "J" },
		{ "Shop", "🛒", "M" },
		{ "Settings", "⚙️", "" },
	}
	for i, e in entries do
		local b = Lib.button({ Size = UDim2.fromOffset(62, 62), LayoutOrder = i, Text = "", BackgroundColor3 = T.panel, Parent = menu })
		Lib.text({ Size = UDim2.new(1, 0, 0.75, 0), Text = e[2], TextSize = 28, Parent = b })
		if not Lib.isTouch() and e[3] ~= "" then
			Lib.text({ Position = UDim2.fromScale(0, 0.68), Size = UDim2.new(1, 0, 0.3, 0), Text = e[3], TextSize = 11, TextColor3 = T.muted, Parent = b })
		end
		b.Activated:Connect(function()
			Widgets.toggle(e[1])
		end)
		HUD.menuButtons[e[1]] = b
	end

	-- Notificações
	toastHolder = Lib.new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -96, 0, 84), Size = UDim2.fromOffset(300, 300), BackgroundTransparency = 1, Parent = gui })
	Lib.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right, Parent = toastHolder })
	Net.event("Notify").OnClientEvent:Connect(notify)

	-- Indicadores de perigo (vinheta vermelha ao tomar dano / frio)
	local vignette = Lib.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.bad, BackgroundTransparency = 1, ZIndex = 0, Parent = gui })
	Lib.new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.5, 1), NumberSequenceKeypoint.new(1, 0.2) }), Parent = vignette })
	HUD.flash = function()
		vignette.BackgroundTransparency = 0.55
		Lib.tween(vignette, 0.6, { BackgroundTransparency = 1 })
	end
end

-- Seleciona ou usa o item do slot (comida é consumida; ferramenta é equipada)
function HUD.useHotbar(i: number)
	local st = State.slots[i]
	local def = st and Items[st.id]
	if def and (def.category == "food" or def.category == "armor") then
		State.action("Use", i)
	elseif def and def.category == "structure" then
		local Build = require(script.Parent.Build)
		Build.start(st.id)
	else
		State.action("Select", i)
	end
end

return HUD
