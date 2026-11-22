--!strict
-- Tutorial contextual (não bloqueia, pode ser pulado). Avança sozinho conforme o jogador faz as ações.

local Lib = require(script.Parent.Parent.UI.Lib)
local State = require(script.Parent.Parent.State)
local T = Lib.Theme

local Tutorial = {}

local STEPS = {
	{ text = "Você naufragou! Pegue Galhos 🥢 e Pedras 🪨 na areia (aproxime-se e segure E / toque).", done = function()
		return State.count("stick") >= 3 and State.count("stone") >= 2
	end },
	{ text = "Colete Fibra 🌿 nos arbustos da selva.", done = function()
		return State.count("fiber") >= 2
	end },
	{ text = "Abra 🛠️ Fabricar (C) e crie um Machado de Pedra.", done = function()
		return State.count("stone_axe") >= 1
	end },
	{ text = "Selecione o machado na barra rápida (1) e golpeie uma Palmeira 🌴.", done = function()
		return State.count("wood") >= 1
	end },
	{ text = "A noite traz as Sombras da Maré. Fabrique uma Fogueira 🔥 (precisa de Sílex 🔺 das pedras soltas).", done = function()
		return State.count("campfire") >= 1 or ((State.data.counters or {}).build or 0) >= 1
	end },
	{ text = "Abra 🏗️ Construir (B) e coloque a fogueira. Ela aquece, cozinha e afasta as Sombras!", done = function()
		return ((State.data.counters or {}).build or 0) >= 1
	end },
	{ text = "Mandou bem! Construa um 🗿 Totem para salvar sua base e confira as 📜 Missões diárias.", done = function()
		return false
	end },
}

function Tutorial.init(gui: ScreenGui)
	local card = Lib.panel({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 76), Size = UDim2.fromOffset(520, 64), BackgroundTransparency = 0.12, Visible = false, Parent = gui })
	local st = card:FindFirstChildOfClass("UIStroke") :: UIStroke
	st.Color = T.accent
	st.Transparency = 0
	local stepLabel = Lib.text({ Position = UDim2.fromOffset(12, 0), Size = UDim2.fromOffset(46, 64), Text = "1/7", TextSize = 15, TextColor3 = T.accent, Parent = card })
	local label = Lib.text({ Position = UDim2.fromOffset(58, 0), Size = UDim2.new(1, -140, 1, 0), Text = "", TextSize = 15, Font = T.fontBody, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
	local skip = Lib.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(70, 36), Text = "Pular", TextSize = 13, Parent = card })

	local step = 0
	local function show()
		if step >= #STEPS then
			Lib.close(card)
			return
		end
		local s = STEPS[step + 1]
		stepLabel.Text = ("%d/%d"):format(step + 1, #STEPS)
		label.Text = s.text
		if not card.Visible then
			Lib.open(card)
		else
			Lib.pop(card)
		end
	end
	local function check()
		if step >= #STEPS then
			return
		end
		local advanced = false
		while step < #STEPS - 1 and STEPS[step + 1].done() do
			step += 1
			advanced = true
		end
		if advanced then
			State.action("Tutorial", step)
			show()
		end
	end
	skip.Activated:Connect(function()
		step = #STEPS
		State.action("Tutorial", 99)
		show()
	end)
	local started = false
	State.on("tutorial", function(v)
		if started then
			return
		end
		started = true
		step = math.min(v or 0, #STEPS)
		if step < #STEPS then
			task.delay(2, function()
				show()
				check()
			end)
		end
	end)
	State.on("inv", check)
	State.on("counters", check)
	-- último passo some sozinho
	task.spawn(function()
		while true do
			task.wait(1)
			if step == #STEPS - 1 and card.Visible then
				task.wait(10)
				step = #STEPS
				State.action("Tutorial", #STEPS)
				show()
			end
		end
	end)
end

return Tutorial
