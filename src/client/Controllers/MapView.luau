--!strict
-- Mapa da Ilha: relevo sombreado (luz de noroeste), profundidade do mar, espuma na costa,
-- zoom (roda do mouse, botões, pinça) e arrastar. Clique num local ou em qualquer ponto
-- para traçar uma rota (caminho de setas no chão; ver Controllers/Route).

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lib = require(script.Parent.Parent.UI.Lib)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local State = require(script.Parent.Parent.State)
local Route = require(script.Parent.Route)
local T = Lib.Theme

local MapView = {}
local player = Players.LocalPlayer

local C = Color3.fromRGB
local LAND: { [string]: Color3 } = {
	s = C(226, 205, 148), -- areia
	g = C(112, 168, 78), -- grama
	j = C(62, 128, 64), -- selva
	m = C(132, 110, 78), -- terra
	r = C(146, 140, 132), -- rocha
	b = C(78, 68, 66), -- basalto
	l = C(214, 86, 40), -- lava
}
local SHALLOW, DEEP, FOAM, FRESH = C(96, 188, 204), C(22, 64, 112), C(214, 238, 236), C(104, 190, 228)
local ICONS = { ship = "⛵", npc = "🧔", lake = "💧", cave = "💎", volcano = "🌋" }

local VIEW = 470 -- tamanho da janela do mapa (px)
local MIN_ZOOM, MAX_ZOOM = 1, 5

local function b36(ch: string): number
	return tonumber(ch, 36) or 0
end

function MapView.init(gui: ScreenGui)
	local _, body = Widgets.window(gui, "Map", "🗺️ Mapa da Ilha", Vector2.new(VIEW + 230, VIEW + 74))

	-- Viewport com recorte; o "canvas" dentro dele é o mapa (cresce com o zoom)
	local viewport = Lib.panel({
		Size = UDim2.fromOffset(VIEW, VIEW),
		BackgroundColor3 = DEEP,
		ClipsDescendants = true,
		Active = true,
		Parent = body,
	})
	local canvas =
		Lib.new("Frame", { Size = UDim2.fromOffset(VIEW, VIEW), BackgroundTransparency = 1, Parent = viewport })
	local terrain = Lib.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = canvas })
	local overlay =
		Lib.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 4, Parent = canvas })
	local markers =
		Lib.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 6, Parent = canvas })
	local routeDots =
		Lib.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 7, Parent = canvas })
	local me = Lib.text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(26, 26),
		Text = "▲",
		TextSize = 24,
		TextColor3 = C(230, 40, 40),
		TextStrokeTransparency = 0,
		TextStrokeColor3 = C(255, 255, 255),
		ZIndex = 10,
		Parent = canvas,
	})
	local baseMark = Lib.text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(26, 26),
		Text = "🗿",
		TextSize = 20,
		Visible = false,
		ZIndex = 9,
		Parent = canvas,
	})
	local goalMark = Lib.text({
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(26, 26),
		Text = "📍",
		TextSize = 22,
		Visible = false,
		ZIndex = 9,
		Parent = canvas,
	})
	local pinMark = Lib.text({
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(26, 26),
		Text = "🚩",
		TextSize = 22,
		Visible = false,
		ZIndex = 9,
		Parent = canvas,
	})

	-- Bússola e escala (fixas, fora do canvas)
	local compass = Lib.panel({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = C(245, 232, 200),
		ZIndex = 12,
		Parent = viewport,
	})
	Lib.text({
		Size = UDim2.fromScale(1, 1),
		Text = "N\n▲",
		TextSize = 14,
		TextColor3 = C(150, 40, 30),
		ZIndex = 13,
		Parent = compass,
	})
	Lib.new( -- barra da escala (60 px)
		"Frame",
		{
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 10, 1, -12),
			Size = UDim2.fromOffset(60, 4),
			BackgroundColor3 = C(250, 245, 230),
			BorderSizePixel = 0,
			ZIndex = 12,
			Parent = viewport,
		}
	)
	local scaleText = Lib.text({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 10, 1, -18),
		Size = UDim2.fromOffset(120, 16),
		Text = "",
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 0.3,
		ZIndex = 12,
		Parent = viewport,
	})

	-- Painel lateral: zoom, centralizar, legenda e dica
	local side = Lib.panel({
		Position = UDim2.fromOffset(VIEW + 12, 0),
		Size = UDim2.new(0, 200, 0, VIEW),
		BackgroundColor3 = T.panel2,
		Parent = body,
	})
	Lib.pad(10).Parent = side
	Lib.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = side })
	local zoomRow =
		Lib.new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 1, Parent = side })
	Lib.new(
		"UIListLayout",
		{ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = zoomRow }
	)
	local zIn = Lib.button({ Size = UDim2.fromOffset(52, 40), Text = "+", TextSize = 24, Parent = zoomRow })
	local zOut = Lib.button({ Size = UDim2.fromOffset(52, 40), Text = "−", TextSize = 24, Parent = zoomRow })
	local center = Lib.button({ Size = UDim2.fromOffset(66, 40), Text = "📍 Eu", TextSize = 14, Parent = zoomRow })
	local clearBtn = Lib.button({
		Size = UDim2.new(1, 0, 0, 34),
		Text = "✖ Cancelar rota",
		TextSize = 13,
		BackgroundColor3 = T.bad:Lerp(T.panel, 0.55),
		LayoutOrder = 2,
		Visible = false,
		Parent = side,
	})
	Lib.text({
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = 3,
		Text = "Clique num local ou em qualquer ponto para traçar uma rota. Arraste para mover.",
		TextSize = 12,
		Font = T.fontBody,
		TextColor3 = T.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = side,
	})
	for i, e in
		{
			{ "▲", "Você" },
			{ "🗿", "Sua base" },
			{ "📍", "Objetivo da jornada" },
			{ "🚩", "Rota marcada" },
			{ "🧔", "Velho Bento" },
			{ "⛵", "Destroços do navio" },
			{ "💧", "Água doce" },
			{ "💎", "Caverna de Cristal" },
			{ "🌋", "Cratera do Vulcão" },
		}
	do
		Lib.text({
			Size = UDim2.new(1, 0, 0, 20),
			LayoutOrder = 10 + i,
			Text = e[1] .. "  " .. e[2],
			TextSize = 13,
			Font = T.fontBody,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = side,
		})
	end

	local data: any = nil
	local built = false
	local zoom = 1
	local pan = Vector2.new(0, 0) -- posição do canto do canvas dentro do viewport (px)

	local function worldToUV(x: number, z: number): Vector2
		local ext = data.extent
		return Vector2.new((x + ext) / (2 * ext), (z + ext) / (2 * ext))
	end
	local function uvToWorld(u: number, v: number): Vector3
		local ext = data.extent
		return Vector3.new(u * 2 * ext - ext, 0, v * 2 * ext - ext)
	end
	local function scalePos(x: number, z: number): UDim2
		local uv = worldToUV(x, z)
		return UDim2.fromScale(uv.X, uv.Y)
	end

	local function applyView()
		local size = VIEW * zoom
		pan = Vector2.new(math.clamp(pan.X, VIEW - size, 0), math.clamp(pan.Y, VIEW - size, 0))
		canvas.Size = UDim2.fromOffset(size, size)
		canvas.Position = UDim2.fromOffset(pan.X, pan.Y)
		if data then
			local metersPer60 = 60 / size * (2 * data.extent)
			scaleText.Text = ("%d m"):format(math.floor(metersPer60 + 0.5))
		end
	end

	-- Zoom mantendo o ponto `at` (coordenada no viewport) fixo
	local function setZoom(z: number, at: Vector2?)
		local focus = at or Vector2.new(VIEW / 2, VIEW / 2)
		local old = zoom
		zoom = math.clamp(z, MIN_ZOOM, MAX_ZOOM)
		local k = zoom / old
		pan = focus - (focus - pan) * k
		applyView()
	end

	local function centerOn(x: number, z: number)
		local uv = worldToUV(x, z)
		local size = VIEW * zoom
		pan = Vector2.new(VIEW / 2 - uv.X * size, VIEW / 2 - uv.Y * size)
		applyView()
	end

	local function build()
		if built then
			return
		end
		local sv = ReplicatedStorage:FindFirstChild("MapData") :: StringValue?
		if not sv or sv.Value == "" then
			return
		end
		data = HttpService:JSONDecode(sv.Value)
		local n = data.grid
		local cells = data.cells
		local function codeAt(r: number, c: number): (string, number)
			r = math.clamp(r, 0, n - 1)
			c = math.clamp(c, 0, n - 1)
			local i = (r * n + c) * 2 + 1
			return string.sub(cells, i, i), b36(string.sub(cells, i + 1, i + 1))
		end
		local function colorAt(r: number, c: number): Color3
			local code, h = codeAt(r, c)
			local y = h * 6 - 30
			if code == "w" then
				-- espuma onde o mar encosta na terra
				for _, d in { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } } do
					local nc = codeAt(r + d[1], c + d[2])
					if nc ~= "w" and nc ~= "f" then
						return FOAM
					end
				end
				return SHALLOW:Lerp(DEEP, math.clamp(-y / 30, 0, 1))
			elseif code == "f" then
				return FRESH
			end
			-- relevo: luz vinda do noroeste
			local _, hNW = codeAt(r - 1, c - 1)
			local _, hSE = codeAt(r + 1, c + 1)
			local shade = math.clamp(1 + (hNW - hSE) * -0.07, 0.62, 1.32)
			shade = math.floor(shade * 20 + 0.5) / 20 -- quantiza para juntar células iguais
			local base = LAND[code] or LAND.g
			base = base:Lerp(Color3.new(1, 1, 1), math.clamp(y / 160, 0, 0.25)) -- alto = mais claro
			return Color3.new(math.min(base.R * shade, 1), math.min(base.G * shade, 1), math.min(base.B * shade, 1))
		end
		-- Desenha cada linha juntando células vizinhas de mesma cor (menos objetos)
		local cellW = 1 / n
		for r = 0, n - 1 do
			local runStart, runColor = 0, colorAt(r, 0)
			for c = 1, n do
				local col = if c < n then colorAt(r, c) else nil
				if col == nil or col ~= runColor then
					Lib.new(
						"Frame",
						{
							BorderSizePixel = 0,
							BackgroundColor3 = runColor,
							Position = UDim2.fromScale(runStart * cellW, r * cellW),
							Size = UDim2.new((c - runStart) * cellW, 1, cellW, 1),
							Parent = terrain,
						}
					)
					if col then
						runStart, runColor = c, col
					end
				end
			end
			if r % 10 == 0 then
				task.wait()
			end
		end
		-- linhas de grade (estilo carta náutica)
		for i = 1, 7 do
			Lib.new(
				"Frame",
				{
					BorderSizePixel = 0,
					BackgroundColor3 = C(255, 255, 255),
					BackgroundTransparency = 0.88,
					Position = UDim2.fromScale(i / 8, 0),
					Size = UDim2.new(0, 1, 1, 0),
					Parent = overlay,
				}
			)
			Lib.new(
				"Frame",
				{
					BorderSizePixel = 0,
					BackgroundColor3 = C(255, 255, 255),
					BackgroundTransparency = 0.88,
					Position = UDim2.fromScale(0, i / 8),
					Size = UDim2.new(1, 0, 0, 1),
					Parent = overlay,
				}
			)
		end
		-- marcadores clicáveis (tamanho fixo na tela)
		for _, p in data.pois do
			local pos = Vector3.new(p.x, 0, p.z)
			if p.kind == "region" then
				local b = Lib.new(
					"TextButton",
					{
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = scalePos(p.x, p.z),
						Size = UDim2.fromOffset(160, 20),
						BackgroundTransparency = 1,
						Font = T.font,
						Text = p.label,
						TextSize = 14,
						TextColor3 = C(255, 250, 235),
						TextStrokeColor3 = C(40, 30, 20),
						TextStrokeTransparency = 0.1,
						ZIndex = 8,
						Parent = markers,
					}
				)
				b.Activated:Connect(function()
					Route.set(p.label, pos)
				end)
			else
				local b = Lib.new(
					"TextButton",
					{
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = scalePos(p.x, p.z),
						Size = UDim2.fromOffset(28, 28),
						BackgroundColor3 = C(250, 240, 215),
						BackgroundTransparency = 0.15,
						Font = T.font,
						Text = ICONS[p.kind] or "•",
						TextSize = 18,
						ZIndex = 8,
						Parent = markers,
					}
				)
				Lib.corner(14).Parent = b
				b.Activated:Connect(function()
					Route.set(p.label, pos)
				end)
			end
		end
		built = true
		applyView()
	end

	-- ===== Entrada: arrastar, clicar, roda e pinça =====
	local dragging: InputObject? = nil
	local dragStart = Vector2.zero
	local panStart = Vector2.zero
	local moved = false
	viewport.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = input
			dragStart = Vector2.new(input.Position.X, input.Position.Y)
			panStart = pan
			moved = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input == dragging) then
			local d = Vector2.new(input.Position.X, input.Position.Y) - dragStart
			if d.Magnitude > 6 then
				moved = true
			end
			-- converte pixels da tela para pixels do layout (a UI tem escala responsiva)
			local s = viewport.AbsoluteSize.X > 0 and viewport.AbsoluteSize.X / VIEW or 1
			pan = panStart + d / s
			applyView()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input == dragging or input.UserInputType == Enum.UserInputType.MouseButton1) then
			if not moved and data then
				-- clique simples: marca rota no ponto
				local local2 = (Vector2.new(input.Position.X, input.Position.Y) - viewport.AbsolutePosition)
					/ ((viewport.AbsoluteSize.X > 0) and (viewport.AbsoluteSize.X / VIEW) or 1)
				local size = VIEW * zoom
				local uv = (local2 - pan) / size
				if uv.X >= 0 and uv.X <= 1 and uv.Y >= 0 and uv.Y <= 1 then
					local w = uvToWorld(uv.X, uv.Y)
					Route.set("Ponto marcado", w)
				end
			end
			dragging = nil
		end
	end)
	viewport.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			local s = viewport.AbsoluteSize.X / VIEW
			local at = (Vector2.new(input.Position.X, input.Position.Y) - viewport.AbsolutePosition) / s
			setZoom(zoom * (input.Position.Z > 0 and 1.25 or 0.8), at)
		end
	end)
	UserInputService.TouchPinch:Connect(function(_, scale, _, state)
		if Widgets.current == "Map" and state == Enum.UserInputState.Change then
			setZoom(zoom * (1 + (scale - 1) * 0.08))
		end
	end)
	zIn.Activated:Connect(function()
		setZoom(zoom * 1.4)
	end)
	zOut.Activated:Connect(function()
		setZoom(zoom / 1.4)
	end)
	center.Activated:Connect(function()
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp and data then
			if zoom < 2 then
				zoom = 2.5
			end
			centerOn(hrp.Position.X, hrp.Position.Z)
		end
	end)
	clearBtn.Activated:Connect(function()
		Route.clear()
	end)

	-- ===== Atualização contínua enquanto o mapa está aberto =====
	local dots: { Frame } = {}
	for i = 1, 18 do
		dots[i] = Lib.new(
			"Frame",
			{
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(5, 5),
				BackgroundColor3 = C(255, 70, 60),
				BorderSizePixel = 0,
				Visible = false,
				ZIndex = 7,
				Parent = routeDots,
			}
		)
		Lib.corner(3).Parent = dots[i]
	end

	local conn: RBXScriptConnection? = nil
	Widgets.onWindow("Map", function()
		build()
		conn = RunService.RenderStepped:Connect(function()
			if not data then
				return
			end
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp then
				me.Position = scalePos(hrp.Position.X, hrp.Position.Z)
				local look = hrp.CFrame.LookVector
				me.Rotation = math.deg(math.atan2(look.X, -look.Z))
			end
			local bp = player:GetAttribute("BasePos") :: Vector3?
			baseMark.Visible = bp ~= nil
			if bp then
				baseMark.Position = scalePos(bp.X, bp.Z)
			end
			local g = State.data.guide
			local tp = g and g.targetPos
			goalMark.Visible = typeof(tp) == "Vector3"
			if typeof(tp) == "Vector3" then
				goalMark.Position = scalePos(tp.X, tp.Z)
			end
			-- rota ativa: bandeira + pontilhado de você até o destino
			local target = Route.target()
			clearBtn.Visible = target ~= nil
			pinMark.Visible = target ~= nil
			for i, dot in dots do
				dot.Visible = target ~= nil and hrp ~= nil
				if target and hrp then
					local t = i / (#dots + 1)
					local p = hrp.Position:Lerp(target, t)
					dot.Position = scalePos(p.X, p.Z)
				end
			end
			if target then
				pinMark.Position = scalePos(target.X, target.Z)
			end
		end)
		-- abre centralizado no jogador com zoom médio
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp and data and zoom == 1 then
			zoom = 1.8
			centerOn(hrp.Position.X, hrp.Position.Z)
		end
	end, function()
		if conn then
			conn:Disconnect()
			conn = nil
		end
	end)
end

return MapView
