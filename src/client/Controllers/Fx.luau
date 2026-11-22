--!strict
-- Efeitos locais: partículas de golpe, números de dano, tremor de câmera, chuva, sons,
-- prompts de interação customizados e animação do papagaio.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Debris = game:GetService("Debris")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)

local Lib = require(script.Parent.Parent.UI.Lib)
local State = require(script.Parent.Parent.State)
local T = Lib.Theme

local Fx = {}
local player = Players.LocalPlayer
local HUD: any = nil

local SOUNDS = {
	hit = "rbxasset://sounds/action_jump_land.mp3",
	drink = "rbxasset://sounds/impact_water.mp3",
	hurt = "rbxasset://sounds/ouch.ogg",
	build = "rbxasset://sounds/action_get_up.mp3",
	big = "rbxasset://sounds/impact_explosion_03.mp3",
}

local function sfxOn(): boolean
	return not (State.data.settings and State.data.settings.sfx == false)
end
local function fxOn(): boolean
	return not (State.data.settings and State.data.settings.fx == false)
end

local function play(name: string, pos: Vector3?, volume: number?)
	if not sfxOn() then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = SOUNDS[name]
	s.Volume = volume or 0.5
	s.PlaybackSpeed = 0.9 + math.random() * 0.2
	if pos then
		local a = Instance.new("Attachment")
		a.WorldPosition = pos
		a.Parent = workspace.Terrain
		s.RollOffMaxDistance = 90
		s.Parent = a
		Debris:AddItem(a, 3)
	else
		s.Parent = workspace.CurrentCamera
		Debris:AddItem(s, 3)
	end
	s:Play()
end

local function burst(pos: Vector3, color: Color3, count: number)
	if not fxOn() then
		return
	end
	local a = Instance.new("Attachment")
	a.WorldPosition = pos
	a.Parent = workspace.Terrain
	local p = Instance.new("ParticleEmitter")
	p.Color = ColorSequence.new(color)
	p.Size = NumberSequence.new(0.5, 0)
	p.Lifetime = NumberRange.new(0.4, 0.7)
	p.Speed = NumberRange.new(10, 18)
	p.SpreadAngle = Vector2.new(180, 180)
	p.Acceleration = Vector3.new(0, -40, 0)
	p.Rate = 0
	p.Parent = a
	p:Emit(count)
	Debris:AddItem(a, 1.5)
end

-- Número flutuante (BillboardGui) que sobe e some
local function floatText(pos: Vector3, text: string, color: Color3)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Position = pos + Vector3.new(math.random(-10, 10) / 10, 2, 0)
	part.Parent = workspace.CurrentCamera
	local bb = Lib.new("BillboardGui", { Size = UDim2.fromOffset(80, 30), AlwaysOnTop = true, Parent = part })
	local label = Lib.text({
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextScaled = true,
		TextColor3 = color,
		TextStrokeTransparency = 0.3,
		Parent = bb,
	})
	Lib.tween(bb, 0.8, { StudsOffset = Vector3.new(0, 3, 0) }, Enum.EasingStyle.Quad)
	Lib.tween(
		label,
		0.8,
		{ TextTransparency = 1, TextStrokeTransparency = 1 },
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)
	Debris:AddItem(part, 0.9)
end

local function shakeModel(model: Instance?)
	if not model or not model:IsA("Model") or Lib.reducedMotion() then
		return
	end
	local m = model :: Model
	local base = m:GetPivot()
	task.spawn(function()
		for _, a in { 0.06, -0.05, 0.03, 0 } do
			if not m.Parent then
				return
			end
			m:PivotTo(base * CFrame.Angles(a, 0, a * 0.6))
			task.wait(0.04)
		end
		if m.Parent then
			m:PivotTo(base)
		end
	end)
end

local shakeAmount = 0
local function cameraShake(amount: number)
	if Lib.reducedMotion() then
		return
	end
	shakeAmount = math.max(shakeAmount, amount)
end

local function onFx(fx: any)
	local kind = fx.kind
	if kind == "hit" then
		burst(fx.pos, Color3.fromRGB(190, 150, 100), 8)
		play("hit", fx.pos, 0.4)
		if fx.damage then
			floatText(fx.pos, "-" .. fx.damage, T.accent)
		end
		shakeModel(fx.model)
	elseif kind == "hitFail" then
		floatText(fx.pos, "✖", T.bad)
	elseif kind == "nodeBreak" then
		burst(fx.pos + Vector3.new(0, 2, 0), Color3.fromRGB(140, 200, 110), 20)
		play("big", fx.pos, 0.25)
	elseif kind == "creatureHit" then
		burst(fx.pos, T.bad, 10)
		floatText(fx.pos, "-" .. tostring(fx.damage), T.bad)
		play("hit", fx.pos, 0.5)
	elseif kind == "creatureDie" then
		burst(fx.pos, Color3.fromRGB(240, 240, 240), 24)
	elseif kind == "hurt" then
		play("hurt", nil, 0.5)
		cameraShake(0.35)
		if HUD and HUD.flash then
			HUD.flash()
		end
	elseif kind == "eat" or kind == "drink" then
		play("drink", nil, 0.4)
		local char = player.Character
		if char then
			floatText(char:GetPivot().Position + Vector3.new(0, 2, 0), fx.icon or "💧", T.good)
		end
	elseif kind == "build" then
		burst(fx.pos, Color3.fromRGB(200, 170, 120), 14)
		play("build", fx.pos, 0.5)
	elseif kind == "craft" then
		play("build", nil, 0.35)
	elseif kind == "rescue" then
		play("big", nil, 0.8)
		cameraShake(0.5)
	end
end

-- ===== Chuva (partículas presas à câmera) =====
local function setupRain()
	local part = Instance.new("Part")
	part.Name = "RainEmitter"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.new(80, 1, 80)
	part.Parent = workspace.CurrentCamera
	local rain = Instance.new("ParticleEmitter")
	rain.Color = ColorSequence.new(Color3.fromRGB(190, 210, 230))
	rain.Transparency = NumberSequence.new(0.3)
	rain.Size = NumberSequence.new(0.12)
	rain.Lifetime = NumberRange.new(1, 1.2)
	rain.Speed = NumberRange.new(70, 90)
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
	rain.Squash = NumberSequence.new(4)
	rain.Rate = 0
	rain.Parent = part
	RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		part.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, 40, 0))
		local w = workspace:GetAttribute("Weather")
		local inCave = player:GetAttribute("Region") == "cave"
		local target = 0
		if fxOn() and not inCave then
			target = w == "storm" and 900 or (w == "rain" and 450 or 0)
		end
		rain.Rate = target
		-- tremor de câmera decai
		if shakeAmount > 0.01 then
			cam.CFrame *= CFrame.Angles(
				(math.random() - 0.5) * shakeAmount * 0.1,
				(math.random() - 0.5) * shakeAmount * 0.1,
				0
			)
			shakeAmount *= 0.85
		end
	end)
	-- Relâmpagos na tempestade
	task.spawn(function()
		local Lighting = game:GetService("Lighting")
		while true do
			task.wait(math.random(6, 14))
			if workspace:GetAttribute("Weather") == "storm" and fxOn() then
				local cc = Lighting:FindFirstChild("Grade") :: ColorCorrectionEffect?
				if cc then
					local b = cc.Brightness
					cc.Brightness = b + 0.5
					task.wait(0.08)
					cc.Brightness = b
				end
				play("big", nil, 0.3)
			end
		end
	end)
end

-- ===== Prompts de interação customizados =====
local KIND_ICON = {
	collect = "✋",
	chest = "📦",
	door = "🚪",
	bed = "🛏️",
	water = "🌧️",
	drink = "💧",
	beacon = "🗼",
	bag = "🎒",
	talk = "💬",
}
local function setupPrompts(gui: ScreenGui)
	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt, inputType)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
			return
		end
		local bb = Lib.new(
			"BillboardGui",
			{
				Name = "PromptUI",
				Size = UDim2.fromOffset(190, 64),
				AlwaysOnTop = true,
				Adornee = prompt.Parent,
				StudsOffset = Vector3.new(0, 2.5, 0),
				Active = true,
				Parent = gui,
			}
		)
		local card = Lib.button({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.panel, Parent = bb })
		local keyText = inputType == Enum.ProximityPromptInputType.Gamepad and "X"
			or (
				inputType == Enum.ProximityPromptInputType.Touch
					and (KIND_ICON[prompt:GetAttribute("Kind") :: string] or "👆")
				or "E"
			)
		local key = Lib.panel({
			Position = UDim2.fromOffset(8, 10),
			Size = UDim2.fromOffset(44, 44),
			BackgroundColor3 = T.accent:Lerp(T.panel, 0.3),
			Parent = card,
		})
		Lib.text({ Size = UDim2.fromScale(1, 1), Text = keyText, TextSize = 22, Parent = key })
		local fill = Lib.new(
			"Frame",
			{ Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.accent, BackgroundTransparency = 0.5, Parent = key }
		)
		Lib.corner(14).Parent = fill
		Lib.text({
			Position = UDim2.fromOffset(60, 8),
			Size = UDim2.new(1, -66, 0, 24),
			Text = prompt.ActionText,
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		})
		Lib.text({
			Position = UDim2.fromOffset(60, 32),
			Size = UDim2.new(1, -66, 0, 20),
			Text = prompt.ObjectText,
			TextSize = 12,
			Font = T.fontBody,
			TextColor3 = T.muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = card,
		})
		local sc = Lib.new("UIScale", { Scale = 0.7, Parent = card })
		Lib.tween(sc, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
		-- Toque: segurar o cartão aciona o prompt
		card.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
			then
				prompt:InputHoldBegin()
			end
		end)
		card.InputEnded:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
			then
				prompt:InputHoldEnd()
			end
		end)
		local c1 = prompt.PromptButtonHoldBegan:Connect(function()
			fill.Size = UDim2.fromScale(0, 1)
			Lib.tween(fill, prompt.HoldDuration, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Linear)
		end)
		local c2 = prompt.PromptButtonHoldEnded:Connect(function()
			fill.Size = UDim2.fromScale(0, 1)
		end)
		local c3 = prompt.Triggered:Connect(function()
			Lib.pop(card)
		end)
		prompt.PromptHidden:Once(function()
			c1:Disconnect()
			c2:Disconnect()
			c3:Disconnect()
			bb:Destroy()
		end)
	end)
end

-- ===== Papagaio: oscila perto do ombro =====
local function animateParrot()
	RunService.RenderStepped:Connect(function()
		for _, p in Players:GetPlayers() do
			local char = p.Character
			local parrot = char and char:FindFirstChild("Parrot")
			if parrot and parrot:IsA("BasePart") then
				local w = parrot:FindFirstChildOfClass("WeldConstraint")
				if w then
					w.Enabled = false
				end
				local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if hrp then
					local t = os.clock()
					parrot.CFrame = hrp.CFrame
						* CFrame.new(2 + math.sin(t * 1.3) * 0.4, 2.6 + math.sin(t * 3) * 0.3, math.cos(t * 1.1) * 0.5)
					parrot.Anchored = true
				end
			end
		end
	end)
end

function Fx.init(gui: ScreenGui, hud: any)
	HUD = hud
	Net.event("Fx").OnClientEvent:Connect(function(fx)
		local ok, err = pcall(onFx, fx)
		if not ok then
			warn("[Fx]", err)
		end
	end)
	setupRain()
	setupPrompts(gui)
	animateParrot()
end

return Fx
