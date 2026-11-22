--!strict
-- Rotas: guia o jogador até um destino escolhido no mapa.
-- No mundo: trilha de setas brilhantes no chão (à frente do jogador, seguindo o terreno),
-- coluna de luz no destino com nome e distância. Na tela: painel "Indo para..." com cancelar.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Lib = require(script.Parent.Parent.UI.Lib)
local T = Lib.Theme

local Route = {}
local player = Players.LocalPlayer

local STEP = 7 -- distância entre setas
local COUNT = 12 -- setas visíveis à frente
local ARRIVE = 14

local target: Vector3? = nil
local label = ""
local arrows: { Part } = {}
local beacon: Part
local beaconGui: BillboardGui
local beaconText: TextLabel
local panel: Frame
local panelText: TextLabel
local notify: ((any) -> ())? = nil

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { workspace.Terrain }
rayParams.IgnoreWater = false

function Route.target(): Vector3?
	return target
end

function Route.clear()
	target = nil
	for _, a in arrows do
		a.Transparency = 1
	end
	beacon.Transparency = 1
	beaconGui.Enabled = false
	panel.Visible = false
end

function Route.set(name: string, pos: Vector3)
	target = pos
	label = name
	panel.Visible = true
	Lib.open(panel)
	if notify then
		notify({ text = "Rota traçada: " .. name, kind = "info", icon = "🧭" })
	end
end

local function groundY(x: number, z: number): number?
	local hit = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), rayParams)
	return hit and hit.Position.Y or nil
end

function Route.init(gui: ScreenGui, notifyFn: (any) -> ())
	notify = notifyFn
	-- setas no chão
	for i = 1, COUNT do
		local a = Instance.new("Part")
		a.Name = "RouteArrow"
		a.Shape = Enum.PartType.Block
		a.Size = Vector3.new(2.2, 0.2, 2.2)
		a.Material = Enum.Material.Neon
		a.Color = Color3.fromRGB(255, 196, 70)
		a.Anchored = true
		a.CanCollide = false
		a.CanQuery = false
		a.CanTouch = false
		a.CastShadow = false
		a.Transparency = 1
		-- formato de seta (chevron) com decalque de texto
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Top
		sg.LightInfluence = 0
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Text = "▲"
		t.TextScaled = true
		t.TextColor3 = Color3.fromRGB(255, 255, 255)
		t.Parent = sg
		sg.Parent = a
		a.Parent = workspace.CurrentCamera
		arrows[i] = a
	end
	-- coluna de luz no destino
	beacon = Instance.new("Part")
	beacon.Shape = Enum.PartType.Cylinder
	beacon.Size = Vector3.new(80, 3, 3)
	beacon.Material = Enum.Material.Neon
	beacon.Color = Color3.fromRGB(255, 200, 80)
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.CanQuery = false
	beacon.CastShadow = false
	beacon.Transparency = 1
	beacon.Parent = workspace.CurrentCamera
	beaconGui = Lib.new(
		"BillboardGui",
		{
			Size = UDim2.fromOffset(200, 50),
			StudsOffset = Vector3.new(0, 4, 0),
			AlwaysOnTop = true,
			Enabled = false,
			Adornee = beacon,
			Parent = gui,
		}
	)
	beaconText = Lib.text({
		Size = UDim2.fromScale(1, 1),
		Text = "",
		TextSize = 16,
		TextStrokeTransparency = 0.2,
		TextColor3 = T.accent,
		Parent = beaconGui,
	})

	-- painel "Indo para"
	panel = Lib.panel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 74),
		Size = UDim2.fromOffset(340, 40),
		Visible = false,
		BackgroundTransparency = 0.15,
		Parent = gui,
	})
	local st = panel:FindFirstChildOfClass("UIStroke") :: UIStroke
	st.Color = T.accent
	panelText = Lib.text({
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -60, 1, 0),
		Text = "",
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})
	Lib.button(
		{
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -6, 0.5, 0),
			Size = UDim2.fromOffset(32, 30),
			Text = "X",
			TextSize = 14,
			BackgroundColor3 = T.bad:Lerp(T.panel, 0.5),
			Parent = panel,
		},
		Route.clear
	)

	local last = 0
	RunService.RenderStepped:Connect(function()
		local tgt = target
		if not tgt then
			return
		end
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp then
			return
		end
		local flat = (tgt - hrp.Position) * Vector3.new(1, 0, 1)
		local dist = flat.Magnitude
		panelText.Text = ("🧭 Indo para: %s  ·  %d m"):format(label, math.floor(dist))
		if dist < ARRIVE then
			if notify then
				notify({ text = "Você chegou: " .. label, kind = "good", icon = "🏁" })
			end
			Route.clear()
			return
		end
		local now = os.clock()
		-- coluna de luz no destino (altura do chão se carregado)
		local gy = groundY(tgt.X, tgt.Z) or hrp.Position.Y
		beacon.CFrame = CFrame.new(tgt.X, gy + 40, tgt.Z) * CFrame.Angles(0, 0, math.pi / 2)
		beacon.Transparency = 0.55 + math.sin(now * 3) * 0.1
		beaconGui.Enabled = true
		beaconText.Text = ("🚩 %s\n%d m"):format(label, math.floor(dist))
		if now - last < 0.15 then
			return
		end
		last = now
		-- trilha: setas a partir de 5 studs à frente, na direção do destino, seguindo o terreno
		local dir = flat.Unit
		local yaw = math.atan2(-dir.X, -dir.Z)
		for i, a in arrows do
			local d = 5 + (i - 1) * STEP
			if d > dist - 2 then
				a.Transparency = 1
			else
				local p = hrp.Position + dir * d
				local y = groundY(p.X, p.Z)
				if y then
					a.CFrame = CFrame.new(p.X, y + 0.25, p.Z) * CFrame.Angles(0, yaw, 0)
					-- pulso correndo para frente (dá sensação de fluxo)
					local wave = (math.sin(now * 6 - i * 0.7) + 1) / 2
					a.Transparency = 0.15 + wave * 0.45 + (i / COUNT) * 0.25
				else
					a.Transparency = 1
				end
			end
		end
	end)
end

return Route
