--!strict
-- Modo construção: prévia translúcida com encaixe na grade, rotação, cor verde/vermelha,
-- confirmar (clique/toque/botão) e modo desmontar. Funciona em PC, celular e controle.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local Structures = require(Shared.Config.Structures)
local BuildGrid = require(Shared.Logic.BuildGrid)

local Lib = require(script.Parent.Parent.UI.Lib)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local State = require(script.Parent.Parent.State)
local T = Lib.Theme

local Build = {}

local player = Players.LocalPlayer
local active: string? = nil -- id do item/estrutura
local demolish = false
local rot = 0
local ghost: Part? = nil
local conn: RBXScriptConnection? = nil
local valid = false
local lastCF: CFrame? = nil
local toolbar: Frame
local hint: TextLabel
local hovered: Model? = nil
local highlight: Highlight

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function aimRay(): (Vector3, Vector3)
	local cam = workspace.CurrentCamera
	local pos: Vector2
	if Lib.isTouch() or UserInputService.GamepadEnabled and not UserInputService.MouseEnabled then
		pos = cam.ViewportSize / 2 -- mira no centro da tela
	else
		pos = UserInputService:GetMouseLocation()
	end
	local ray = cam:ViewportPointToRay(pos.X, pos.Y)
	return ray.Origin, ray.Direction
end

local function stop()
	active = nil
	demolish = false
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
	if conn then
		conn:Disconnect()
		conn = nil
	end
	highlight.Adornee = nil
	hovered = nil
	toolbar.Visible = false
end

local function update()
	local char = player.Character
	if not char then
		return
	end
	rayParams.FilterDescendantsInstances = { char, ghost :: Instance, workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Creatures") or nil }
	local origin, dir = aimRay()
	local hit = workspace:Raycast(origin, dir * 120, rayParams)
	if demolish then
		local m = hit and hit.Instance:FindFirstAncestorOfClass("Model")
		while m and m:GetAttribute("Guid") == nil do
			m = m:FindFirstAncestorOfClass("Model")
		end
		if m and m:GetAttribute("Owner") == player.UserId then
			hovered = m
			highlight.Adornee = m
			highlight.FillColor = T.bad
		else
			hovered = nil
			highlight.Adornee = nil
		end
		return
	end
	if not active or not ghost then
		return
	end
	local def = Structures.defs[Items[active].structure :: string]
	if not hit then
		ghost.Transparency = 1
		valid = false
		return
	end
	local ground = hit.Position
	-- em cima de outra construção: usa o topo dela
	local center = BuildGrid.centerFromGround(ground, def.size)
	local cf = BuildGrid.snap(center, def.snap, rot)
	ghost.CFrame = cf
	ghost.Transparency = 0.45
	lastCF = cf
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local inRange = hrp ~= nil and (cf.Position - hrp.Position).Magnitude <= Structures.PLACE_RANGE
	local above = cf.Position.Y - def.size.Y / 2 > 0.5
	valid = inRange and above
	ghost.Color = valid and T.good or T.bad
end

local function confirm()
	if demolish then
		if hovered then
			State.action("Demolish", hovered:GetAttribute("Guid"))
		end
		return
	end
	if active and lastCF and valid then
		local def = Structures.defs[Items[active].structure :: string]
		local p = lastCF.Position
		State.action("Place", def.id, p.X, p.Y, p.Z, rot)
		task.delay(0.15, function()
			if active and State.count(active) <= 0 then
				stop()
			end
		end)
	elseif ghost then
		hint.Text = "Local inválido (longe ou na água)"
	end
end

function Build.start(itemId: string)
	local def = Items[itemId]
	if not def or not def.structure or State.count(itemId) <= 0 then
		return
	end
	stop()
	Widgets.closeAll()
	active = itemId
	local sdef = Structures.defs[def.structure]
	local g = Instance.new("Part")
	g.Name = "BuildGhost"
	g.Anchored = true
	g.CanCollide = false
	g.CanQuery = false
	g.CanTouch = false
	g.Material = Enum.Material.ForceField
	g.Size = sdef.size
	g.Parent = workspace
	ghost = g
	toolbar.Visible = true
	hint.Text = ("%s %s  ·  R girar · Clique colocar · Q sair"):format(def.icon, def.name)
	if Lib.isTouch() then
		hint.Text = def.icon .. " " .. def.name .. " — mire no centro e toque Colocar"
	end
	conn = RunService.RenderStepped:Connect(update)
end

function Build.startDemolish()
	stop()
	Widgets.closeAll()
	demolish = true
	toolbar.Visible = true
	hint.Text = "Modo desmontar: mire numa construção sua"
	conn = RunService.RenderStepped:Connect(update)
end

function Build.isActive(): boolean
	return active ~= nil or demolish
end

function Build.init(gui: ScreenGui)
	highlight = Lib.new("Highlight", { FillTransparency = 0.6, OutlineColor = T.bad, Parent = gui })
	-- Mira central para celular/controle
	local cross = Lib.text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(30, 30), Text = "+", TextSize = 30, TextStrokeTransparency = 0.3, Visible = false, Parent = gui })
	task.spawn(function()
		while true do
			cross.Visible = Build.isActive() and (Lib.isTouch() or not UserInputService.MouseEnabled)
			task.wait(0.2)
		end
	end)

	-- Barra de ferramentas de construção (aparece no modo construção)
	toolbar = Lib.panel({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -100), Size = UDim2.fromOffset(520, 96), Visible = false, Parent = gui })
	hint = Lib.text({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 26), Text = "", TextSize = 15, Parent = toolbar })
	local row = Lib.new("Frame", { Position = UDim2.fromOffset(10, 36), Size = UDim2.new(1, -20, 0, 50), BackgroundTransparency = 1, Parent = toolbar })
	Lib.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = row })
	Lib.button({ Size = UDim2.fromOffset(150, 48), Text = "✅ Colocar", BackgroundColor3 = T.good:Lerp(T.panel, 0.4), Parent = row }, confirm)
	Lib.button({ Size = UDim2.fromOffset(110, 48), Text = "🔄 Girar", Parent = row }, function()
		rot = (rot + 1) % 4
	end)
	Lib.button({ Size = UDim2.fromOffset(110, 48), Text = "❌ Sair", BackgroundColor3 = T.bad:Lerp(T.panel, 0.5), Parent = row }, stop)

	-- Janela "Construir": lista de construções no inventário + desmontar
	local _, body = Widgets.window(gui, "Build", "🏗️ Construir", Vector2.new(640, 440))
	local grid = Widgets.scroll(body, Vector2.new(140, 110), 10)
	local function rebuild()
		for _, c in grid:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local d = Lib.button({ LayoutOrder = 0, BackgroundColor3 = T.bad:Lerp(T.panel, 0.6), Parent = grid }, Build.startDemolish)
		Lib.text({ Size = UDim2.new(1, 0, 0.6, 0), Text = "🔨", TextSize = 36, Parent = d })
		Lib.text({ Position = UDim2.fromScale(0, 0.6), Size = UDim2.new(1, 0, 0.4, 0), Text = "Desmontar", TextSize = 14, Parent = d })
		local any = false
		for id, def in Items do
			if def.category == "structure" then
				local n = State.count(id)
				if n > 0 then
					any = true
					local b = Lib.button({ LayoutOrder = 1, BackgroundColor3 = T.slot, Parent = grid }, function()
						Build.start(id)
					end)
					Lib.text({ Size = UDim2.new(1, 0, 0.6, 0), Text = def.icon, TextSize = 36, Parent = b })
					Lib.text({ Position = UDim2.fromScale(0, 0.6), Size = UDim2.new(1, 0, 0.4, 0), Text = ("%s x%d"):format(def.name, n), TextSize = 13, Parent = b })
				end
			end
		end
		if not any then
			local tip = Lib.panel({ LayoutOrder = 2, BackgroundColor3 = T.panel2, Parent = grid })
			Lib.text({ Size = UDim2.fromScale(1, 1), Text = "Fabrique construções na aba 🏗️ do Crafting", TextSize = 13, Font = T.fontBody, Parent = tip })
		end
	end
	Widgets.onWindow("Build", rebuild)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not Build.isActive() then
			return
		end
		if input.KeyCode == Enum.KeyCode.R or input.KeyCode == Enum.KeyCode.ButtonX then
			rot = (rot + 1) % 4
		elseif input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonB then
			stop()
		elseif not processed and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2) then
			confirm()
		end
	end)
	player.CharacterRemoving:Connect(stop)
end

return Build
