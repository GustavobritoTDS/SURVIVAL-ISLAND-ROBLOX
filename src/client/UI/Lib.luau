--!strict
-- Kit de UI: tema, criação de instâncias, botões e animações (TweenService).
-- Personalidade de movimento: "Playful" — entradas 250 ms com leve overshoot (Back Out),
-- saídas 160 ms (Quad In), feedback de toque 100 ms. Respeita "movimento reduzido".

local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Lib = {}

Lib.Theme = {
	bg = Color3.fromRGB(18, 28, 34),
	panel = Color3.fromRGB(24, 38, 46),
	panel2 = Color3.fromRGB(33, 52, 62),
	slot = Color3.fromRGB(40, 62, 72),
	stroke = Color3.fromRGB(90, 150, 150),
	accent = Color3.fromRGB(255, 186, 73), -- areia dourada
	accent2 = Color3.fromRGB(64, 205, 195), -- maré
	text = Color3.fromRGB(245, 240, 228),
	muted = Color3.fromRGB(160, 178, 180),
	good = Color3.fromRGB(110, 210, 120),
	bad = Color3.fromRGB(240, 95, 85),
	health = Color3.fromRGB(235, 80, 80),
	hunger = Color3.fromRGB(240, 165, 60),
	thirst = Color3.fromRGB(70, 170, 245),
	warmth = Color3.fromRGB(255, 120, 70),
	xp = Color3.fromRGB(150, 110, 255),
	font = Enum.Font.GothamBold,
	fontBody = Enum.Font.GothamMedium,
	rarity = {
		common = Color3.fromRGB(150, 160, 165),
		uncommon = Color3.fromRGB(90, 200, 110),
		rare = Color3.fromRGB(70, 160, 255),
		epic = Color3.fromRGB(180, 100, 255),
		legendary = Color3.fromRGB(255, 190, 60),
	},
}
local T = Lib.Theme
Lib.clickSound = nil :: (() -> ())? -- definido pelo Fx (som de clique)

function Lib.reducedMotion(): boolean
	local ok, v = pcall(function()
		return (GuiService :: any).ReducedMotionEnabled
	end)
	return ok and v == true
end

function Lib.isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- Cria instância com propriedades e filhos
function Lib.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	for k, v in props or {} do
		if k == "Parent" then
			parent = v
		else
			(inst :: any)[k] = v
		end
	end
	for _, c in children or {} do
		c.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function Lib.corner(r: number): UICorner
	return Lib.new("UICorner", { CornerRadius = UDim.new(0, r) })
end

function Lib.stroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return Lib.new("UIStroke", {
		Color = color or T.stroke,
		Thickness = thickness or 1.5,
		Transparency = transparency or 0.35,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Lib.pad(px: number): UIPadding
	local u = UDim.new(0, px)
	return Lib.new("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

function Lib.text(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = T.font,
		TextColor3 = T.text,
		TextScaled = false,
		TextSize = 16,
		TextWrapped = true,
	}
	for k, v in props do
		defaults[k] = v
	end
	return Lib.new("TextLabel", defaults)
end

function Lib.tween(
	inst: Instance,
	t: number,
	props: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?
): Tween
	if Lib.reducedMotion() then
		t = math.min(t, 0.05)
	end
	local tw = TweenService:Create(
		inst,
		TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		props
	)
	tw:Play()
	return tw
end

-- Painel com fundo, borda e cantos
function Lib.panel(props: { [string]: any }): Frame
	local f = Lib.new("Frame", {
		BackgroundColor3 = T.panel,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
	})
	for k, v in props do
		(f :: any)[k] = v
	end
	Lib.corner(14).Parent = f
	Lib.stroke().Parent = f
	return f
end

-- Botão com feedback de pressão (escala 0.94 em 100 ms, volta com Back)
function Lib.button(props: { [string]: any }, onClick: (() -> ())?): TextButton
	local b = Lib.new("TextButton", {
		BackgroundColor3 = T.panel2,
		AutoButtonColor = false,
		Font = T.font,
		TextColor3 = T.text,
		TextSize = 16,
		BorderSizePixel = 0,
		Text = "",
	})
	for k, v in props do
		(b :: any)[k] = v
	end
	Lib.corner(10).Parent = b
	local st = Lib.stroke(T.stroke, 1.2, 0.5)
	st.Parent = b
	local scale = Lib.new("UIScale", { Parent = b })
	local base = b.BackgroundColor3
	b.MouseEnter:Connect(function()
		Lib.tween(b, 0.08, { BackgroundColor3 = base:Lerp(Color3.new(1, 1, 1), 0.12) })
	end)
	b.MouseLeave:Connect(function()
		Lib.tween(b, 0.12, { BackgroundColor3 = base })
		Lib.tween(scale, 0.12, { Scale = 1 })
	end)
	b.MouseButton1Down:Connect(function()
		Lib.tween(scale, 0.08, { Scale = 0.94 })
	end)
	b.Activated:Connect(function()
		if Lib.clickSound then
			Lib.clickSound()
		end
	end)
	b.MouseButton1Up:Connect(function()
		Lib.tween(scale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

-- Abre painel: escala 0.9 -> 1 com Back Out (250 ms) + fade
function Lib.open(frame: GuiObject)
	local scale = frame:FindFirstChildOfClass("UIScale") or Lib.new("UIScale", { Parent = frame })
	frame.Visible = true
	scale.Scale = 0.9
	Lib.tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Fecha painel: 160 ms, acelera (Quad In)
function Lib.close(frame: GuiObject)
	local scale = frame:FindFirstChildOfClass("UIScale") or Lib.new("UIScale", { Parent = frame })
	local tw = Lib.tween(scale, 0.16, { Scale = 0.92 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tw.Completed:Once(function()
		if scale.Scale < 0.95 then
			frame.Visible = false
			scale.Scale = 1
		end
	end)
end

-- Tremida de erro (3 oscilações, 300 ms)
function Lib.shake(gui: GuiObject)
	if Lib.reducedMotion() then
		return
	end
	local origin = gui.Position
	task.spawn(function()
		for _, dx in { 10, -8, 6, -3, 0 } do
			gui.Position = origin + UDim2.fromOffset(dx, 0)
			task.wait(0.06)
		end
		gui.Position = origin
	end)
end

-- Pulso de destaque (sucesso)
function Lib.pop(gui: GuiObject)
	local scale = gui:FindFirstChildOfClass("UIScale") or Lib.new("UIScale", { Parent = gui })
	scale.Scale = 1.15
	Lib.tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
end

return Lib
