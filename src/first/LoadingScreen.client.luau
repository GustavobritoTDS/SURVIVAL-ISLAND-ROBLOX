--!strict
-- Tela de carregamento + menu principal (ReplicatedFirst roda antes de tudo).
-- Mostra o progresso da geração da ilha e dos dados; ao final, botão "Jogar".

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer
ReplicatedFirst:RemoveDefaultLoadingScreen()

local SAND = Color3.fromRGB(255, 186, 73)
local TIDE = Color3.fromRGB(64, 205, 195)
local TEXT = Color3.fromRGB(245, 240, 228)

local gui = Instance.new("ScreenGui")
gui.Name = "Loading"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 100
gui.Parent = player:WaitForChild("PlayerGui")

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.fromRGB(10, 32, 44)
bg.Parent = gui
local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 160, 90)),
	ColorSequenceKeypoint.new(0.45, Color3.fromRGB(30, 90, 120)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 24, 36)),
})
grad.Rotation = 90
grad.Parent = bg

local scale = Instance.new("UIScale")
scale.Parent = bg
local cam = workspace.CurrentCamera
scale.Scale = math.clamp((cam and cam.ViewportSize.Y or 720) / 720, 0.6, 1.2)

-- Sol + horizonte (ambiente: o sol "respira" devagar)
local sun = Instance.new("Frame")
sun.AnchorPoint = Vector2.new(0.5, 0.5)
sun.Position = UDim2.fromScale(0.5, 0.36)
sun.Size = UDim2.fromOffset(220, 220)
sun.BackgroundColor3 = Color3.fromRGB(255, 205, 120)
sun.BackgroundTransparency = 0.25
sun.Parent = bg
local sc = Instance.new("UICorner")
sc.CornerRadius = UDim.new(1, 0)
sc.Parent = sun

local title = Instance.new("TextLabel")
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.36)
title.Size = UDim2.fromOffset(760, 110)
title.BackgroundTransparency = 1
title.Font = Enum.Font.FredokaOne
title.Text = "SURVIVAL ISLAND"
title.TextColor3 = TEXT
title.TextSize = 84
title.TextStrokeColor3 = Color3.fromRGB(20, 40, 50)
title.TextStrokeTransparency = 0
title.Parent = bg

local subtitle = Instance.new("TextLabel")
subtitle.AnchorPoint = Vector2.new(0.5, 0)
subtitle.Position = UDim2.new(0.5, 0, 0.36, 56)
subtitle.Size = UDim2.fromOffset(600, 34)
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.GothamBold
subtitle.Text = "A MARÉ SOMBRIA"
subtitle.TextColor3 = TIDE
subtitle.TextSize = 26
subtitle.Parent = bg

local barBack = Instance.new("Frame")
barBack.AnchorPoint = Vector2.new(0.5, 0)
barBack.Position = UDim2.fromScale(0.5, 0.66)
barBack.Size = UDim2.fromOffset(420, 14)
barBack.BackgroundColor3 = Color3.fromRGB(5, 15, 20)
barBack.BackgroundTransparency = 0.3
barBack.Parent = bg
local c1 = Instance.new("UICorner")
c1.CornerRadius = UDim.new(1, 0)
c1.Parent = barBack
local bar = Instance.new("Frame")
bar.Size = UDim2.fromScale(0, 1)
bar.BackgroundColor3 = SAND
bar.Parent = barBack
local c2 = Instance.new("UICorner")
c2.CornerRadius = UDim.new(1, 0)
c2.Parent = bar

local status = Instance.new("TextLabel")
status.AnchorPoint = Vector2.new(0.5, 0)
status.Position = UDim2.new(0.5, 0, 0.66, 22)
status.Size = UDim2.fromOffset(600, 24)
status.BackgroundTransparency = 1
status.Font = Enum.Font.GothamMedium
status.TextColor3 = TEXT
status.TextSize = 16
status.Text = "Chegando à ilha..."
status.Parent = bg

local TIPS = {
	"Dica: fogueiras afastam as Sombras da Maré à noite.",
	"Dica: pedras soltas às vezes trazem Sílex 🔺.",
	"Dica: construa um Totem 🗿 para salvar sua base.",
	"Dica: a Cama de Folhas vira seu ponto de renascimento.",
	"Dica: tempestades esfriam — use roupas e fique perto do fogo.",
	"Dica: a Caverna de Cristal guarda o material mais brilhante da ilha.",
}
local tip = Instance.new("TextLabel")
tip.AnchorPoint = Vector2.new(0.5, 1)
tip.Position = UDim2.new(0.5, 0, 1, -30)
tip.Size = UDim2.fromOffset(700, 24)
tip.BackgroundTransparency = 1
tip.Font = Enum.Font.GothamMedium
tip.TextColor3 = Color3.fromRGB(200, 220, 225)
tip.TextSize = 15
tip.Text = TIPS[math.random(1, #TIPS)]
tip.Parent = bg

local play = Instance.new("TextButton")
play.AnchorPoint = Vector2.new(0.5, 0)
play.Position = UDim2.fromScale(0.5, 0.64)
play.Size = UDim2.fromOffset(240, 64)
play.BackgroundColor3 = SAND
play.Font = Enum.Font.FredokaOne
play.Text = "JOGAR"
play.TextColor3 = Color3.fromRGB(40, 30, 20)
play.TextSize = 32
play.Visible = false
play.AutoButtonColor = true
play.Parent = bg
local c3 = Instance.new("UICorner")
c3.CornerRadius = UDim.new(0, 16)
c3.Parent = play
local ps = Instance.new("UIScale")
ps.Parent = play

local reduced = false
pcall(function()
	reduced = (game:GetService("GuiService") :: any).ReducedMotionEnabled == true
end)

-- Entrada do título: sobe e cresce com leve overshoot
local ts = Instance.new("UIScale")
ts.Scale = reduced and 1 or 0.8
ts.Parent = title
TweenService:Create(ts, TweenInfo.new(0.6, Enum.EasingStyle.Back), { Scale = 1 }):Play()
if not reduced then
	TweenService:Create(sun, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Size = UDim2.fromOffset(240, 240) }):Play()
end

task.spawn(function()
	pcall(function()
		ContentProvider:PreloadAsync({ gui })
	end)
end)

-- Progresso: mundo (80%) + dados (20%)
local t0 = os.clock()
while true do
	local world = (workspace:GetAttribute("WorldProgress") :: number?) or 0
	local ready = workspace:GetAttribute("WorldReady") == true
	local data = player:GetAttribute("DataReady") == true
	local p = (ready and 0.8 or world * 0.8) + (data and 0.2 or 0)
	TweenService:Create(bar, TweenInfo.new(0.3), { Size = UDim2.fromScale(math.clamp(p, 0.02, 1), 1) }):Play()
	status.Text = (not ready and ("Moldando a ilha... %d%%"):format(world * 100)) or (not data and "Recuperando seus suprimentos...") or "Pronto!"
	if (ready and data) or os.clock() - t0 > 90 then
		break
	end
	task.wait(0.2)
end

barBack.Visible = false
status.Visible = false
play.Visible = true
ps.Scale = 0.6
TweenService:Create(ps, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()

play.Activated:Wait()
TweenService:Create(ps, TweenInfo.new(0.1), { Scale = 0.92 }):Play()
task.wait(0.1)
local fade = TweenInfo.new(reduced and 0.05 or 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
TweenService:Create(bg, fade, { BackgroundTransparency = 1 }):Play()
for _, d in bg:GetDescendants() do
	if d:IsA("TextLabel") or d:IsA("TextButton") then
		TweenService:Create(d, fade, { TextTransparency = 1, TextStrokeTransparency = 1, BackgroundTransparency = 1 }):Play()
	elseif d:IsA("Frame") then
		TweenService:Create(d, fade, { BackgroundTransparency = 1 }):Play()
	end
end
task.wait(0.65)
gui:Destroy()
