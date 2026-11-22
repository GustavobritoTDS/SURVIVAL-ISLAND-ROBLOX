--!strict
-- Diálogo com o Velho Bento + rastreador da Jornada do Náufrago + marcador de destino.
-- Diálogo: câmera cinematográfica, retrato 3D (ViewportFrame), texto digitado letra a letra,
-- balão "..." sobre o NPC. Avança com clique/toque, E, Enter ou botão A do controle.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Guide = require(Shared.Config.Guide)

local Lib = require(script.Parent.Parent.UI.Lib)
local State = require(script.Parent.Parent.State)
local Animations = require(script.Parent.Animations)
local T = Lib.Theme

local Dialogue = {}
local player = Players.LocalPlayer

local function findNpc(): Model?
	local world = workspace:FindFirstChild("World")
	if not world then
		return nil
	end
	for _, c in world:GetChildren() do
		if c:IsA("Model") and c:GetAttribute("GuideNPC") then
			return c
		end
	end
	return nil
end

function Dialogue.init(gui: ScreenGui)
	-- ===== Painel de diálogo =====
	local panel = Lib.panel({
		Name = "Dialogue",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -96),
		Size = UDim2.fromOffset(760, 168),
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	})
	local st = panel:FindFirstChildOfClass("UIStroke") :: UIStroke
	st.Color = T.accent
	st.Transparency = 0.1
	local portrait = Lib.new("ViewportFrame", {
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.fromOffset(120, 140),
		BackgroundColor3 = T.panel2,
		Ambient = Color3.fromRGB(200, 190, 170),
		LightColor = Color3.fromRGB(255, 230, 190),
		Parent = panel,
	})
	Lib.corner(12).Parent = portrait
	local fallback = Lib.text({ Size = UDim2.fromScale(1, 1), Text = "🧔", TextSize = 64, Parent = portrait })
	local name = Lib.text({
		Position = UDim2.fromOffset(150, 12),
		Size = UDim2.new(1, -170, 0, 26),
		Text = Guide.NPC.name,
		TextSize = 20,
		TextColor3 = T.accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})
	Lib.text({
		Position = UDim2.fromOffset(150, 36),
		Size = UDim2.new(1, -170, 0, 16),
		Text = Guide.NPC.title,
		TextSize = 12,
		Font = T.fontBody,
		TextColor3 = T.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})
	local body = Lib.text({
		Position = UDim2.fromOffset(150, 58),
		Size = UDim2.new(1, -170, 0, 70),
		Text = "",
		TextSize = 18,
		Font = T.fontBody,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = panel,
	})
	local hint = Lib.text({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -10),
		Size = UDim2.fromOffset(260, 20),
		Text = "▶ Toque para continuar",
		TextSize = 13,
		TextColor3 = T.accent2,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = panel,
	})
	local pageLabel = Lib.text({
		Position = UDim2.new(0, 150, 1, -30),
		Size = UDim2.fromOffset(80, 20),
		Text = "",
		TextSize = 12,
		TextColor3 = T.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})
	local click = Lib.new(
		"TextButton",
		{ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 30, Parent = panel }
	)

	-- Balão de fala sobre o NPC
	local bubble = Lib.new("BillboardGui", {
		Name = "TalkBubble",
		Size = UDim2.fromOffset(70, 40),
		StudsOffset = Vector3.new(0, 3.2, 0),
		AlwaysOnTop = true,
		Enabled = false,
		Parent = gui,
	})
	local bubbleCard =
		Lib.panel({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 250, 238), Parent = bubble })
	local dots = Lib.text({
		Size = UDim2.fromScale(1, 1),
		Text = "...",
		TextSize = 26,
		TextColor3 = Color3.fromRGB(40, 40, 40),
		Parent = bubbleCard,
	})

	-- Marcador sobre o NPC (❗ quando há algo novo para conversar)
	local npcMark = Lib.new("BillboardGui", {
		Name = "NpcMark",
		Size = UDim2.fromOffset(150, 60),
		StudsOffset = Vector3.new(0, 4.6, 0),
		AlwaysOnTop = true,
		MaxDistance = 220,
		Parent = gui,
	})
	local markIcon = Lib.text({ Size = UDim2.new(1, 0, 0, 36), Text = "❗", TextSize = 34, Parent = npcMark })
	local markText = Lib.text({
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 20),
		Text = "Fale comigo!",
		TextSize = 14,
		TextStrokeTransparency = 0.3,
		Parent = npcMark,
	})

	-- ===== Rastreador da jornada (abaixo dos status) =====
	local tracker = Lib.panel({
		Position = UDim2.fromOffset(16, 152),
		Size = UDim2.fromOffset(240, 84),
		BackgroundTransparency = 0.2,
		Parent = gui,
	})
	local tst = tracker:FindFirstChildOfClass("UIStroke") :: UIStroke
	tst.Color = T.accent
	local tTitle = Lib.text({
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -20, 0, 18),
		Text = "📍 Jornada",
		TextSize = 14,
		TextColor3 = T.accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = tracker,
	})
	local tObj = Lib.text({
		Position = UDim2.fromOffset(10, 26),
		Size = UDim2.new(1, -20, 0, 34),
		Text = "",
		TextSize = 13,
		Font = T.fontBody,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = tracker,
	})
	local tBack = Lib.new("Frame", {
		Position = UDim2.new(0, 10, 1, -16),
		Size = UDim2.new(1, -60, 0, 8),
		BackgroundColor3 = Color3.fromRGB(10, 16, 20),
		Parent = tracker,
	})
	Lib.corner(4).Parent = tBack
	local tFill = Lib.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.accent, Parent = tBack })
	Lib.corner(4).Parent = tFill
	local tCount = Lib.text({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -10),
		Size = UDim2.fromOffset(46, 16),
		Text = "",
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = tracker,
	})

	-- Itens necessários para a receita da etapa (aparece embaixo do rastreador)
	local Recipes = require(Shared.Config.Recipes)
	local Items = require(Shared.Config.Items)
	local needs = Lib.panel({
		Position = UDim2.fromOffset(16, 242),
		Size = UDim2.fromOffset(240, 40),
		BackgroundTransparency = 0.25,
		Visible = false,
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = gui,
	})
	Lib.pad(8).Parent = needs
	Lib.new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder, Parent = needs })
	local STATION = {
		workbench = "🛠️ Perto da Bancada",
		campfire = "🔥 Perto da Fogueira",
		forge = "🏭 Perto da Fornalha",
	}
	local function refreshNeeds()
		for _, c in needs:GetChildren() do
			if c:IsA("TextLabel") then
				c:Destroy()
			end
		end
		local g = State.data.guide
		local r = g and g.recipe and Recipes.byId[g.recipe]
		if not r or g.finished then
			needs.Visible = false
			return
		end
		needs.Visible = true
		local out = Items[r.output]
		Lib.text({
			Size = UDim2.new(1, 0, 0, 18),
			LayoutOrder = 0,
			Text = "Para fabricar " .. out.icon .. " " .. out.name .. ":",
			TextSize = 13,
			TextColor3 = T.accent,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = needs,
		})
		local i = 1
		local allOk = true
		for id, n in r.cost do
			local have = State.count(id)
			local d = Items[id]
			allOk = allOk and have >= n
			Lib.text({
				Size = UDim2.new(1, 0, 0, 18),
				LayoutOrder = i,
				Text = ("%s %s  %d/%d %s"):format(d.icon, d.name, math.min(have, n), n, have >= n and "✔" or ""),
				TextSize = 13,
				Font = T.fontBody,
				TextColor3 = have >= n and T.good or T.text,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = needs,
			})
			i += 1
		end
		if r.station then
			Lib.text({
				Size = UDim2.new(1, 0, 0, 18),
				LayoutOrder = 98,
				Text = STATION[r.station] or r.station,
				TextSize = 12,
				Font = T.fontBody,
				TextColor3 = T.muted,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = needs,
			})
		end
		if allOk then
			Lib.text({
				Size = UDim2.new(1, 0, 0, 18),
				LayoutOrder = 99,
				Text = State.count(r.output) > 0 and "✅ Pronto! Abra Construir (B)"
					or "✅ Tudo certo! Abra Criar (C)",
				TextSize = 13,
				TextColor3 = T.good,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = needs,
			})
		end
	end
	State.on("inv", refreshNeeds)

	-- Marcador de destino (no mundo)
	local waypoint = Lib.new("BillboardGui", {
		Name = "Waypoint",
		Size = UDim2.fromOffset(90, 54),
		StudsOffset = Vector3.new(0, 6, 0),
		AlwaysOnTop = true,
		Enabled = false,
		Parent = gui,
	})
	Lib.text({ Size = UDim2.new(1, 0, 0, 30), Text = "⬇️", TextSize = 28, Parent = waypoint })
	local wpDist = Lib.text({
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 0, 20),
		Text = "",
		TextSize = 14,
		TextColor3 = T.accent,
		TextStrokeTransparency = 0.2,
		Parent = waypoint,
	})
	local wpAnchor = Instance.new("Part")
	wpAnchor.Anchored = true
	wpAnchor.CanCollide = false
	wpAnchor.CanQuery = false
	wpAnchor.Transparency = 1
	wpAnchor.Size = Vector3.new(0.2, 0.2, 0.2)
	wpAnchor.Parent = workspace.CurrentCamera
	waypoint.Adornee = wpAnchor

	-- ===== Estado da jornada =====
	local guide: any = nil
	State.on("guide", function(g)
		guide = g
		if not g then
			return
		end
		if g.finished then
			tTitle.Text = "🏆 Jornada completa!"
			tObj.Text = "Você foi resgatado. Ajude outros náufragos!"
			tFill.Size = UDim2.fromScale(1, 1)
			tCount.Text = ""
			return
		end
		tTitle.Text = g.stage > 0 and ("📍 %d/%d · %s"):format(g.stage, g.total, g.title or "") or "📍 Comece aqui"
		tObj.Text = g.objective or ""
		local frac = (g.goal and g.goal > 0) and math.clamp((g.progress or 0) / g.goal, 0, 1) or 0
		Lib.tween(tFill, 0.35, { Size = UDim2.fromScale(frac, 1) })
		tCount.Text = g.goal and ("%d/%d"):format(g.progress or 0, g.goal) or ""
		Lib.pop(tracker)
		refreshNeeds()
	end)

	-- ===== Fluxo do diálogo =====
	local lines: { string } = {}
	local index = 0
	local typing = false
	local skip = false
	local savedCam: { type: Enum.CameraType, cf: CFrame }? = nil

	local function setPortrait(npc: Model?)
		for _, c in portrait:GetChildren() do
			if c:IsA("Model") or c:IsA("Camera") then
				c:Destroy()
			end
		end
		fallback.Visible = true
		if not npc then
			return
		end
		local head = npc:FindFirstChild("Head") :: BasePart?
		if not head then
			return
		end
		npc.Archivable = true
		local ok, clone = pcall(function()
			return npc:Clone()
		end)
		if not ok or not clone then
			return
		end
		for _, d in clone:GetDescendants() do
			if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ProximityPrompt") then
				d:Destroy()
			end
		end
		clone.Parent = portrait
		local cam = Instance.new("Camera")
		local h = clone:FindFirstChild("Head") :: BasePart
		cam.CFrame = CFrame.lookAt((h.CFrame * CFrame.new(0, 0.2, -3.4)).Position, h.Position)
		cam.FieldOfView = 40
		cam.Parent = portrait
		portrait.CurrentCamera = cam
		fallback.Visible = false
	end

	local function cinematic(npc: Model?)
		local cam = workspace.CurrentCamera
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local head = npc and npc:FindFirstChild("Head") :: BasePart?
		if not head or not hrp or (head.Position - hrp.Position).Magnitude > 20 then
			return
		end
		savedCam = { type = cam.CameraType, cf = cam.CFrame }
		cam.CameraType = Enum.CameraType.Scriptable
		-- de frente para o Bento, na altura do rosto, levemente de lado (plano de conversa)
		local root = (npc :: Model):FindFirstChild("HumanoidRootPart") :: BasePart
		local facing = root.CFrame
		local from = head.Position + facing.LookVector * 7.5 + facing.RightVector * 2.6 + Vector3.new(0, 0.4, 0)
		local target = CFrame.lookAt(from, head.Position - Vector3.new(0, 0.6, 0) + facing.RightVector * 0.8)
		TweenService:Create(
			cam,
			TweenInfo.new(Lib.reducedMotion() and 0.05 or 0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
			{ CFrame = target }
		):Play()
	end

	local function restoreCam()
		if savedCam then
			local cam = workspace.CurrentCamera
			cam.CameraType = Enum.CameraType.Custom
			savedCam = nil
		end
	end

	local PromptService = game:GetService("ProximityPromptService")
	local function close()
		PromptService.Enabled = true
		Animations.setTalking(false)
		bubble.Enabled = false
		restoreCam()
		Lib.close(panel)
		lines = {}
		index = 0
	end

	local function typeLine(text: string)
		typing = true
		skip = false
		body.Text = text
		body.MaxVisibleGraphemes = 0
		Animations.setTalking(true)
		bubble.Enabled = true
		local total = utf8.len(text) or #text
		local shown = 0
		while shown < total and not skip do
			shown += 1
			body.MaxVisibleGraphemes = shown
			task.wait(0.022)
		end
		body.MaxVisibleGraphemes = -1
		typing = false
		Animations.setTalking(false)
		dots.Text = "💬"
		hint.Text = index < #lines and "▶ Toque para continuar" or "✔ Toque para fechar"
	end

	local function nextLine()
		if typing then
			skip = true
			return
		end
		index += 1
		if index > #lines then
			close()
			return
		end
		pageLabel.Text = ("%d/%d"):format(index, #lines)
		dots.Text = "..."
		task.spawn(typeLine, lines[index])
	end

	local function open(d: any)
		lines = d.lines or {}
		if #lines == 0 then
			return
		end
		index = 0
		local npc = findNpc()
		bubble.Adornee = npc and npc:FindFirstChild("Head") or nil
		setPortrait(npc)
		name.Text = Guide.NPC.name
		if d.npc then
			cinematic(npc)
		end
		-- E/X avançam o diálogo: desliga os prompts para não reabrir a conversa
		PromptService.Enabled = false
		Lib.open(panel)
		nextLine()
	end

	State.on("dialogue", function(d)
		if d and d.lines then
			State.data.dialogue = nil
			-- espera o jogador sair da tela de carregamento
			local pg = player:WaitForChild("PlayerGui")
			while pg:FindFirstChild("Loading") do
				task.wait(0.3)
			end
			open(d)
		end
	end)

	click.Activated:Connect(nextLine)
	UserInputService.InputBegan:Connect(function(input)
		if not panel.Visible then
			return
		end
		local kc = input.KeyCode
		if
			kc == Enum.KeyCode.E
			or kc == Enum.KeyCode.Return
			or kc == Enum.KeyCode.Space
			or kc == Enum.KeyCode.ButtonA
		then
			nextLine()
		elseif kc == Enum.KeyCode.Escape or kc == Enum.KeyCode.ButtonB then
			close()
		end
	end)

	-- ===== Marcadores a cada quadro =====
	local lastScan = 0
	local cachedTarget: Vector3? = nil
	RunService.RenderStepped:Connect(function()
		local npc = findNpc()
		local head = npc and npc:FindFirstChild("Head")
		npcMark.Adornee = head
		local isNew = guide ~= nil and (guide.stage == 0)
		npcMark.Enabled = head ~= nil and not panel.Visible
		markIcon.Text = isNew and "❗" or "💬"
		markText.Text = isNew and "Fale comigo!" or Guide.NPC.name
		markIcon.Position = UDim2.fromOffset(0, math.sin(os.clock() * 3) * 4)

		-- destino da etapa atual
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not guide or not hrp or guide.finished then
			waypoint.Enabled = false
			return
		end
		local now = os.clock()
		if now - lastScan > 0.5 then
			lastScan = now
			cachedTarget = nil
			local t = guide.target or "none"
			if t == "npc" and head then
				cachedTarget = (head :: BasePart).Position
			elseif t == "pos" and guide.targetPos then
				cachedTarget = guide.targetPos
			elseif string.sub(t, 1, 5) == "node:" then
				local id = string.sub(t, 6)
				local nodes = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Nodes")
				local best, bestD = nil, math.huge
				for _, m in (nodes and nodes:GetChildren() or {}) do
					if m:GetAttribute("NodeId") == id and m:IsA("Model") then
						local d = (m:GetPivot().Position - hrp.Position).Magnitude
						if d < bestD then
							best, bestD = m:GetPivot().Position, d
						end
					end
				end
				cachedTarget = best
			end
		end
		if cachedTarget then
			local d = (cachedTarget - hrp.Position).Magnitude
			waypoint.Enabled = d > 8 and not panel.Visible
			wpAnchor.Position = cachedTarget
			wpDist.Text = ("%d m"):format(math.floor(d))
		else
			waypoint.Enabled = false
		end
	end)
end

return Dialogue
