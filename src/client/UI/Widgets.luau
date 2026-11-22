--!strict
-- Componentes reutilizáveis: slot de item, barra de status, gerenciador de janelas, tooltip.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local Lib = require(script.Parent.Lib)
local T = Lib.Theme

local Widgets = {}

export type Slot = { frame: TextButton, set: (stack: any?) -> (), setSelected: (boolean) -> () }

function Widgets.slot(parent: Instance, size: number, index: number?): Slot
	local b = Lib.button({
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = T.slot,
		BackgroundTransparency = 0.15,
		LayoutOrder = index or 0,
		Parent = parent,
	})
	local icon = Lib.text({ Size = UDim2.fromScale(1, 1), Text = "", TextScaled = true, Parent = b })
	Lib.new(
		"UIPadding",
		{
			PaddingTop = UDim.new(0.16, 0),
			PaddingBottom = UDim.new(0.2, 0),
			PaddingLeft = UDim.new(0.16, 0),
			PaddingRight = UDim.new(0.16, 0),
			Parent = icon,
		}
	)
	local count = Lib.text({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -4, 1, -2),
		Size = UDim2.fromOffset(40, 16),
		Text = "",
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextStrokeTransparency = 0.4,
		Parent = b,
	})
	local key = Lib.text({
		Position = UDim2.fromOffset(4, 2),
		Size = UDim2.fromOffset(14, 14),
		Text = "",
		TextSize = 11,
		TextColor3 = T.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = b,
	})
	if index and index <= 6 and parent.Name == "Hotbar" then
		key.Text = tostring(index)
	end
	local stroke = b:FindFirstChildOfClass("UIStroke") :: UIStroke
	local selected = false
	local current: any? = nil
	local function set(stack: any?)
		current = stack
		local def = stack and Items[stack.id]
		if def then
			icon.Text = def.icon
			count.Text = stack.n > 1 and tostring(stack.n) or ""
			stroke.Color = selected and T.accent or (T.rarity[def.rarity or "common"] or T.stroke)
			stroke.Transparency = selected and 0 or 0.25
			b:SetAttribute("ItemId", stack.id)
		else
			icon.Text = ""
			count.Text = ""
			stroke.Color = selected and T.accent or T.stroke
			stroke.Transparency = selected and 0 or 0.6
			b:SetAttribute("ItemId", nil)
		end
	end
	local function setSelected(v: boolean)
		selected = v
		stroke.Thickness = v and 3 or 1.2
		set(current)
		if v then
			Lib.pop(b)
		end
	end
	return { frame = b, set = set, setSelected = setSelected }
end

-- Barra horizontal com ícone e valor
function Widgets.bar(parent: Instance, icon: string, color: Color3, order: number): (number) -> ()
	local row = Lib.new(
		"Frame",
		{ Size = UDim2.fromOffset(210, 22), BackgroundTransparency = 1, LayoutOrder = order, Parent = parent }
	)
	Lib.text({ Size = UDim2.fromOffset(22, 22), Text = icon, TextScaled = true, Parent = row })
	local back = Lib.new(
		"Frame",
		{
			Position = UDim2.fromOffset(28, 4),
			Size = UDim2.new(1, -28, 0, 14),
			BackgroundColor3 = Color3.fromRGB(10, 16, 20),
			BackgroundTransparency = 0.2,
			Parent = row,
		}
	)
	Lib.corner(7).Parent = back
	local fill = Lib.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, Parent = back })
	Lib.corner(7).Parent = fill
	Lib.new(
		"UIGradient",
		{ Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.25), color), Rotation = 90, Parent = fill }
	)
	local label = Lib.text({
		Size = UDim2.fromScale(1, 1),
		Text = "100",
		TextSize = 11,
		TextStrokeTransparency = 0.5,
		Parent = back,
	})
	local last = 100
	return function(v: number)
		v = math.clamp(v, 0, 100)
		Lib.tween(fill, 0.3, { Size = UDim2.fromScale(math.max(v / 100, 0.001), 1) })
		label.Text = tostring(math.floor(v + 0.5))
		-- alerta quando crítico
		if v < 20 and last >= 20 then
			Lib.shake(row)
		end
		fill.BackgroundColor3 = v < 20 and T.bad or color
		last = v
	end
end

-- ===== Gerenciador de janelas (uma aberta por vez) =====
local windows: { [string]: { frame: Frame, onOpen: (() -> ())?, onClose: (() -> ())? } } = {}
Widgets.current = nil :: string?

function Widgets.window(gui: ScreenGui, name: string, title: string, size: Vector2): (Frame, Frame)
	local f = Lib.panel({
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		Visible = false,
		Parent = gui,
	})
	Lib.new("UISizeConstraint", { MaxSize = Vector2.new(size.X, size.Y), Parent = f })
	local header = Lib.new("Frame", { Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, Parent = f })
	Lib.text({
		Position = UDim2.fromOffset(18, 0),
		Size = UDim2.new(1, -80, 1, 0),
		Text = title,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = T.accent,
		Parent = header,
	})
	Lib.button(
		{
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(34, 34),
			Text = "X",
			TextSize = 18,
			Parent = header,
		},
		function()
			Widgets.toggle(name, false)
		end
	)
	local body = Lib.new(
		"Frame",
		{
			Name = "Body",
			Position = UDim2.fromOffset(14, 50),
			Size = UDim2.new(1, -28, 1, -64),
			BackgroundTransparency = 1,
			Parent = f,
		}
	)
	windows[name] = { frame = f }
	return f, body
end

function Widgets.onWindow(name: string, onOpen: (() -> ())?, onClose: (() -> ())?)
	local w = windows[name]
	w.onOpen = onOpen
	w.onClose = onClose
end

function Widgets.toggle(name: string, force: boolean?)
	local w = windows[name]
	if not w then
		return
	end
	local open = if force ~= nil then force else not w.frame.Visible
	if open then
		if Widgets.current and Widgets.current ~= name then
			Widgets.toggle(Widgets.current, false)
		end
		Widgets.current = name
		Lib.open(w.frame)
		if w.onOpen then
			w.onOpen()
		end
	elseif w.frame.Visible then
		if Widgets.current == name then
			Widgets.current = nil
		end
		Lib.close(w.frame)
		if w.onClose then
			w.onClose()
		end
	end
end

function Widgets.closeAll()
	if Widgets.current then
		Widgets.toggle(Widgets.current, false)
	end
end

-- Lista rolável com grade
function Widgets.scroll(parent: Instance, cell: Vector2, pad: number): ScrollingFrame
	local s = Lib.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = T.stroke,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = parent,
	})
	Lib.new(
		"UIGridLayout",
		{
			CellSize = UDim2.fromOffset(cell.X, cell.Y),
			CellPadding = UDim2.fromOffset(pad, pad),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = s,
		}
	)
	Lib.new(
		"UIPadding",
		{ PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8), Parent = s }
	)
	return s
end

return Widgets
