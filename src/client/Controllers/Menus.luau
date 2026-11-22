--!strict
-- Janelas de Missões (diárias + conquistas + login), Loja (Game Passes, produtos, Conchas) e Configurações.

local Lighting = game:GetService("Lighting")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Progression = require(Shared.Config.Progression)
local Monetization = require(Shared.Config.Monetization)

local Lib = require(script.Parent.Parent.UI.Lib)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local State = require(script.Parent.Parent.State)
local T = Lib.Theme

local Menus = {}

local function clear(f: Instance)
	for _, c in f:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local function list(parent: Instance): ScrollingFrame
	local s = Lib.new(
		"ScrollingFrame",
		{
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			Parent = parent,
		}
	)
	Lib.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = s })
	Lib.new("UIPadding", { PaddingRight = UDim.new(0, 8), Parent = s })
	return s
end

local function section(parent: Instance, text: string, order: number)
	Lib.text({
		Size = UDim2.new(1, 0, 0, 26),
		Text = text,
		TextSize = 17,
		TextColor3 = T.accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
		Parent = parent,
	})
end

-- ===== Missões =====
local function buildQuests(gui: ScreenGui)
	local _, body = Widgets.window(gui, "Quests", "📜 Missões e Conquistas", Vector2.new(640, 520))
	local s = list(body)
	local function rebuild()
		clear(s)
		local login = State.data.login or {}
		section(s, ("🎁 Bônus diário — sequência de %d dia(s)"):format(login.streak or 0), 1)
		local row =
			Lib.new("Frame", { Size = UDim2.new(1, 0, 0, 64), BackgroundTransparency = 1, LayoutOrder = 2, Parent = s })
		Lib.new(
			"UIListLayout",
			{ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = row }
		)
		for i, r in Progression.loginRewards do
			local done = ((login.streak or 0) - 1) % #Progression.loginRewards + 1 >= i and (login.streak or 0) > 0
			local cell = Lib.panel({
				Size = UDim2.fromOffset(78, 62),
				BackgroundColor3 = done and T.accent:Lerp(T.panel, 0.55) or T.panel2,
				Parent = row,
			})
			Lib.text({ Size = UDim2.new(1, 0, 0.5, 0), Text = "Dia " .. i, TextSize = 13, Parent = cell })
			Lib.text({
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.new(1, 0, 0.5, 0),
				Text = "🐚" .. r.shells,
				TextSize = 14,
				Font = T.fontBody,
				Parent = cell,
			})
		end
		section(s, "📅 Missões de hoje", 3)
		local daily = State.data.daily and State.data.daily.quests or {}
		for i, q in daily do
			local def
			for _, d in Progression.dailyPool do
				if d.id == q.id then
					def = d
				end
			end
			if def then
				local card = Lib.panel({
					Size = UDim2.new(1, 0, 0, 64),
					BackgroundColor3 = T.panel2,
					LayoutOrder = 3 + i,
					Parent = s,
				})
				Lib.text({
					Position = UDim2.fromOffset(14, 6),
					Size = UDim2.new(1, -170, 0, 24),
					Text = def.text,
					TextSize = 16,
					TextXAlignment = Enum.TextXAlignment.Left,
					Parent = card,
				})
				local back = Lib.new(
					"Frame",
					{
						Position = UDim2.fromOffset(14, 38),
						Size = UDim2.new(1, -180, 0, 12),
						BackgroundColor3 = Color3.fromRGB(10, 16, 20),
						Parent = card,
					}
				)
				Lib.corner(6).Parent = back
				local fill = Lib.new(
					"Frame",
					{
						Size = UDim2.fromScale(math.clamp(q.progress / def.goal, 0, 1), 1),
						BackgroundColor3 = T.xp,
						Parent = back,
					}
				)
				Lib.corner(6).Parent = fill
				local complete = q.progress >= def.goal
				local btn = Lib.button(
					{
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -10, 0.5, 0),
						Size = UDim2.fromOffset(140, 44),
						TextSize = 14,
						Parent = card,
					},
					function()
						State.action("ClaimQuest", i)
					end
				)
				if q.claimed then
					btn.Text = "✅ Resgatado"
					btn.TextColor3 = T.muted
				elseif complete then
					btn.Text = ("Resgatar 🐚%d"):format(def.shells)
					btn.BackgroundColor3 = T.good:Lerp(T.panel, 0.3)
				else
					btn.Text = ("%d/%d  ·  🐚%d"):format(q.progress, def.goal, def.shells)
					btn.TextColor3 = T.muted
				end
			end
		end
		section(s, "🏆 Conquistas", 20)
		local counters = State.data.counters or {}
		for i, a in Progression.achievements do
			local got = State.data.achievements and State.data.achievements[a.id]
			local card = Lib.panel({
				Size = UDim2.new(1, 0, 0, 48),
				BackgroundColor3 = got and T.accent:Lerp(T.panel, 0.7) or T.panel2,
				LayoutOrder = 20 + i,
				Parent = s,
			})
			Lib.text({
				Position = UDim2.fromOffset(14, 0),
				Size = UDim2.new(0.6, 0, 1, 0),
				Text = (got and "🏆 " or "🔒 ") .. a.text .. " — " .. a.desc,
				TextSize = 14,
				Font = T.fontBody,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = card,
			})
			Lib.text({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -14, 0, 0),
				Size = UDim2.new(0.35, 0, 1, 0),
				Text = got and "Concluída"
					or ("%d/%d · 🐚%d"):format(math.min(counters[a.stat] or 0, a.goal), a.goal, a.shells),
				TextSize = 13,
				TextColor3 = T.muted,
				TextXAlignment = Enum.TextXAlignment.Right,
				Parent = card,
			})
		end
	end
	Widgets.onWindow("Quests", rebuild)
	State.on("daily", function()
		if Widgets.current == "Quests" then
			rebuild()
		end
	end)
end

-- ===== Loja =====
local function buildShop(gui: ScreenGui)
	local _, body = Widgets.window(gui, "Shop", "🛒 Loja", Vector2.new(760, 520))
	local s = list(body)
	local function card(
		parent: Instance,
		order: number,
		icon: string,
		name: string,
		desc: string,
		price: string,
		owned: boolean,
		onBuy: () -> ()
	)
		local c = Lib.panel({
			Size = UDim2.new(1, 0, 0, 72),
			BackgroundColor3 = T.panel2,
			LayoutOrder = order,
			Parent = parent,
		})
		Lib.text({
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.fromOffset(56, 72),
			Text = icon,
			TextSize = 36,
			Parent = c,
		})
		Lib.text({
			Position = UDim2.fromOffset(72, 8),
			Size = UDim2.new(1, -250, 0, 24),
			Text = name,
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = c,
		})
		Lib.text({
			Position = UDim2.fromOffset(72, 32),
			Size = UDim2.new(1, -250, 0, 34),
			Text = desc,
			TextSize = 12,
			Font = T.fontBody,
			TextColor3 = T.muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = c,
		})
		local b = Lib.button(
			{
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.fromOffset(150, 46),
				Text = owned and "✅ Possui" or price,
				TextSize = 15,
				BackgroundColor3 = owned and T.panel or T.accent:Lerp(T.panel, 0.3),
				Parent = c,
			},
			function()
				if not owned then
					onBuy()
				end
			end
		)
		return b
	end
	local function rebuild()
		clear(s)
		local passes = State.data.passes or {}
		local owned =
			{ vip = passes.vip, big_backpack = passes.bigBackpack, parrot = passes.parrot, trails = passes.trails }
		section(s, "⭐ Game Passes (permanentes)", 1)
		local order = 2
		for key, p in Monetization.gamePasses do
			card(
				s,
				order,
				p.icon,
				p.name,
				p.description,
				p.id == 0 and "Em breve" or ("R$ " .. p.price),
				owned[key] == true,
				function()
					State.action("Prompt", "pass", key)
				end
			)
			order += 1
		end
		section(s, "💎 Produtos", 20)
		order = 21
		for key, p in Monetization.devProducts do
			card(
				s,
				order,
				p.icon,
				p.name,
				p.description,
				p.id == 0 and "Em breve" or ("R$ " .. p.price),
				false,
				function()
					State.action("Prompt", "product", key)
				end
			)
			order += 1
		end
		section(s, ("🐚 Loja de Conchas — você tem %d"):format(State.data.shells or 0), 40)
		order = 41
		local cos = State.data.cosmetics or { owned = {} }
		for _, e in Monetization.shellShop do
			local has = e.kind ~= "items" and cos.owned and cos.owned[e.id] == true
			local b = card(
				s,
				order,
				e.icon,
				e.name,
				e.kind == "trail" and "Rastro cosmético" or (e.kind == "title" and "Título acima do nome" or "Itens"),
				"🐚 " .. e.price,
				false,
				function()
					if has then
						State.action("EquipCosmetic", e.kind, if cos[e.kind] == e.id then false else e.id)
					else
						State.action("ShellBuy", e.id)
					end
				end
			)
			if has then
				b.Text = cos[e.kind] == e.id and "Desequipar" or "Equipar"
				b.BackgroundColor3 = T.accent2:Lerp(T.panel, 0.4)
			end
			order += 1
		end
		if passes.trails then
			section(s, "✨ Rastros Lendários", 80)
			order = 81
			for _, t in Monetization.passTrails do
				local b = card(s, order, "✨", "Rastro " .. t.name, "Exclusivo do Game Pass", "", false, function()
					State.action("EquipCosmetic", "trail", if cos.trail == t.id then false else t.id)
				end)
				b.Text = cos.trail == t.id and "Desequipar" or "Equipar"
				b.BackgroundColor3 = T.accent2:Lerp(T.panel, 0.4)
				order += 1
			end
		end
	end
	Widgets.onWindow("Shop", rebuild)
	for _, k in { "shells", "cosmetics", "passes" } do
		State.on(k, function()
			if Widgets.current == "Shop" then
				rebuild()
			end
		end)
	end
end

-- ===== Configurações =====
local function buildSettings(gui: ScreenGui)
	local _, body = Widgets.window(gui, "Settings", "⚙️ Configurações", Vector2.new(520, 420))
	local s = list(body)
	local function toggle(order: number, label: string, key: string, apply: ((boolean) -> ())?)
		local row =
			Lib.panel({ Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = T.panel2, LayoutOrder = order, Parent = s })
		Lib.text({
			Position = UDim2.fromOffset(14, 0),
			Size = UDim2.new(1, -150, 1, 0),
			Text = label,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		local b = Lib.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(110, 40),
			TextSize = 15,
			Parent = row,
		})
		local function refresh()
			local on = State.data.settings and State.data.settings[key] ~= false
			b.Text = on and "Ligado" or "Desligado"
			b.BackgroundColor3 = on and T.good:Lerp(T.panel, 0.4) or T.panel
			if apply then
				apply(on)
			end
		end
		b.Activated:Connect(function()
			local st = State.data.settings or {}
			st[key] = not (st[key] ~= false)
			State.data.settings = st
			State.action("Settings", { [key] = st[key] })
			refresh()
		end)
		State.on("settings", refresh, true)
	end
	toggle(1, "🔊 Efeitos sonoros", "sfx")
	toggle(2, "🌫️ Efeitos visuais (chuva, partículas)", "fx")
	toggle(3, "☀️ Sombras e brilho (desligue em PCs fracos)", "shadows", function(on)
		local bloom = Lighting:FindFirstChild("Bloom") :: BloomEffect?
		local rays = Lighting:FindFirstChild("SunRays") :: SunRaysEffect?
		if bloom then
			bloom.Enabled = on
		end
		if rays then
			rays.Enabled = on
		end
	end)
	local help =
		Lib.panel({ Size = UDim2.new(1, 0, 0, 150), BackgroundColor3 = T.panel2, LayoutOrder = 10, Parent = s })
	Lib.pad(12).Parent = help
	Lib.text({
		Size = UDim2.fromScale(1, 1),
		Text = "Controles (PC): 1–6 barra rápida · Tab inventário · C fabricar · B construir · J missões · M loja · R girar · Q sair do modo construção · E interagir\nControle: LB/RB troca de slot · Y inventário · X girar · B voltar · RT golpear/colocar\nCelular: toque na barra rápida e nos botões laterais",
		TextSize = 13,
		Font = T.fontBody,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = help,
	})
end

function Menus.init(gui: ScreenGui)
	buildQuests(gui)
	buildShop(gui)
	buildSettings(gui)
end

return Menus
