--!strict
-- Mapa da Ilha (estilo pergaminho): terreno real em grade colorida com relevo,
-- marcadores (navio, Bento, lagos, caverna, vulcão, regiões, sua base, objetivo) e você (seta).

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lib = require(script.Parent.Parent.UI.Lib)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local State = require(script.Parent.Parent.State)
local T = Lib.Theme

local MapView = {}
local player = Players.LocalPlayer

local C = Color3.fromRGB
local PALETTE: { [string]: Color3 } = {
	w = C(52, 120, 160), -- mar
	f = C(90, 170, 210), -- água doce
	s = C(233, 210, 150), -- areia
	g = C(118, 170, 84), -- grama
	j = C(70, 140, 70), -- selva
	m = C(130, 110, 80), -- terra
	r = C(150, 146, 140), -- rocha
	b = C(80, 70, 70), -- basalto
	l = C(200, 80, 40), -- lava
}
local ICONS = { ship = "⛵", npc = "🧔", lake = "💧", cave = "💎", volcano = "🌋", region = "" }

local SIZE = 440

function MapView.init(gui: ScreenGui)
	local win, body = Widgets.window(gui, "Map", "🗺️ Mapa da Ilha", Vector2.new(SIZE + 220, SIZE + 74))
	local _ = win
	local paper = Lib.panel({
		Size = UDim2.fromOffset(SIZE, SIZE),
		BackgroundColor3 = C(236, 220, 180),
		ClipsDescendants = true,
		Parent = body,
	})
	local grid = Lib.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = paper })
	local markers =
		Lib.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5, Parent = paper })
	local me = Lib.text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(26, 26),
		Text = "▲",
		TextSize = 24,
		TextColor3 = C(220, 40, 40),
		TextStrokeTransparency = 0,
		TextStrokeColor3 = C(255, 255, 255),
		ZIndex = 9,
		Parent = paper,
	})
	local baseMark = Lib.text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(26, 26),
		Text = "🗿",
		TextSize = 20,
		Visible = false,
		ZIndex = 8,
		Parent = paper,
	})
	local goalMark = Lib.text({
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(26, 26),
		Text = "📍",
		TextSize = 22,
		Visible = false,
		ZIndex = 8,
		Parent = paper,
	})

	-- legenda
	local legend = Lib.panel({
		Position = UDim2.fromOffset(SIZE + 12, 0),
		Size = UDim2.new(0, 190, 0, SIZE),
		BackgroundColor3 = T.panel2,
		Parent = body,
	})
	Lib.pad(10).Parent = legend
	Lib.new("UIListLayout", { Padding = UDim.new(0, 5), Parent = legend })
	for _, e in
		{
			{ "▲", "Você" },
			{ "🗿", "Sua base" },
			{ "📍", "Objetivo atual" },
			{ "🧔", "Velho Bento" },
			{ "⛵", "Destroços do navio" },
			{ "💧", "Água doce (beber)" },
			{ "💎", "Caverna de Cristal" },
			{ "🌋", "Cratera do Vulcão" },
		}
	do
		Lib.text({
			Size = UDim2.new(1, 0, 0, 20),
			Text = e[1] .. "  " .. e[2],
			TextSize = 14,
			Font = T.fontBody,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = legend,
		})
	end
	local coords = Lib.text({
		Size = UDim2.new(1, 0, 0, 36),
		Text = "",
		TextSize = 12,
		TextColor3 = T.muted,
		Font = T.fontBody,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = legend,
	})

	local data: any = nil
	local built = false

	local function toMap(x: number, z: number): UDim2
		local ext = data.extent
		return UDim2.fromOffset((x + ext) / (2 * ext) * SIZE, (z + ext) / (2 * ext) * SIZE)
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
		local cell = SIZE / n
		local cells = data.cells
		for row = 0, n - 1 do
			for col = 0, n - 1 do
				local i = (row * n + col) * 2 + 1
				local code = string.sub(cells, i, i)
				local h = tonumber(string.sub(cells, i + 1, i + 1)) or 0
				local col3 = PALETTE[code] or PALETTE.g
				if code ~= "w" and code ~= "f" then
					col3 = col3:Lerp(Color3.new(1, 1, 1), math.min(h, 9) * 0.035) -- mais alto = mais claro
				end
				Lib.new(
					"Frame",
					{
						BorderSizePixel = 0,
						BackgroundColor3 = col3,
						Position = UDim2.fromOffset(col * cell, row * cell),
						Size = UDim2.fromOffset(cell + 1, cell + 1),
						Parent = grid,
					}
				)
			end
		end
		-- vinheta de pergaminho
		Lib.new(
			"UIGradient",
			{ Color = ColorSequence.new(C(255, 245, 225), C(225, 205, 160)), Rotation = 45, Parent = grid }
		)
		for _, p in data.pois do
			if p.kind == "region" then
				Lib.text({
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = toMap(p.x, p.z),
					Size = UDim2.fromOffset(150, 18),
					Text = p.label,
					TextSize = 13,
					TextColor3 = C(60, 40, 20),
					TextStrokeColor3 = C(250, 240, 215),
					TextStrokeTransparency = 0.2,
					ZIndex = 6,
					Parent = markers,
				})
			else
				Lib.text({
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = toMap(p.x, p.z),
					Size = UDim2.fromOffset(24, 24),
					Text = ICONS[p.kind] or "•",
					TextSize = 18,
					ZIndex = 7,
					Parent = markers,
				})
			end
		end
		built = true
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
				me.Position = toMap(hrp.Position.X, hrp.Position.Z)
				local look = hrp.CFrame.LookVector
				me.Rotation = math.deg(math.atan2(look.X, -look.Z))
				coords.Text = ("Posição: %d, %d"):format(math.floor(hrp.Position.X), math.floor(hrp.Position.Z))
			end
			local bp = player:GetAttribute("BasePos") :: Vector3?
			baseMark.Visible = bp ~= nil
			if bp then
				baseMark.Position = toMap(bp.X, bp.Z)
			end
			local g = State.data.guide
			local tp = g and g.targetPos
			goalMark.Visible = typeof(tp) == "Vector3"
			if typeof(tp) == "Vector3" then
				goalMark.Position = toMap(tp.X, tp.Z)
			end
		end)
	end, function()
		if conn then
			conn:Disconnect()
			conn = nil
		end
	end)
end

return MapView
