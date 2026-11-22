-- Roteiro de teste do cliente (só no build de teste). Usa os remotes reais, como um jogador faria,
-- e também envia ações maliciosas para conferir que o servidor as rejeita.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local report = ReplicatedStorage:WaitForChild("TestReport", 60) :: RemoteEvent
local Client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local State = require(Client:WaitForChild("State"))
local Widgets = require(Client:WaitForChild("UI"):WaitForChild("Widgets"))
local Action = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Action") :: RemoteEvent

local function step(ok: boolean, msg: string)
	report:FireServer("step", ok, msg)
end

local function waitFor(cond: () -> boolean, timeout: number): boolean
	local t0 = os.clock()
	while os.clock() - t0 < timeout do
		if cond() then
			return true
		end
		task.wait(0.2)
	end
	return false
end

local function slotOf(id: string): number?
	for i, s in State.slots do
		if s.id == id then
			return i
		end
	end
	return nil
end

-- Repassa avisos negativos do jogo para o relatório (ex.: motivo de construção recusada)
ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify").OnClientEvent:Connect(function(n)
	if n.kind == "bad" then
		report:FireServer("info", true, "aviso do jogo: " .. tostring(n.text))
	end
end)

local function placeOnGround(id: string, offset: Vector3)
	local char = player.Character :: Model
	local hrp = char:WaitForChild("HumanoidRootPart") :: BasePart
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { char }
	local at = hrp.Position + offset
	local hit = workspace:Raycast(at + Vector3.new(0, 50, 0), Vector3.new(0, -120, 0), params)
	if hit then
		local Structures = require(ReplicatedStorage.Shared.Config.Structures)
		local h = Structures.defs[id].size.Y / 2
		Action:FireServer("Place", id, hit.Position.X, hit.Position.Y + h, hit.Position.Z, 0)
	end
end

report.OnClientEvent:Connect(function(kind)
	if kind == "placeBase" then
		-- Tenta alguns pontos (árvores/rochas podem ocupar o primeiro)
		local base: Vector3? = nil
		for _, off in { Vector3.new(12, 0, 0), Vector3.new(-12, 0, 0), Vector3.new(0, 0, 14), Vector3.new(0, 0, -14), Vector3.new(18, 0, 18) } do
			placeOnGround("base_totem", off)
			if waitFor(function()
				return State.count("base_totem") == 0
			end, 2) then
				base = off
				break
			end
		end
		report:FireServer("info", true, "Totem colocado em offset " .. tostring(base))
		if base then
			for _, d in { Vector3.new(6, 0, 0), Vector3.new(-6, 0, 0), Vector3.new(0, 0, 6), Vector3.new(0, 0, -6) } do
				placeOnGround("chest", base + d)
				if waitFor(function()
					return State.count("chest") == 0
				end, 2) then
					break
				end
			end
		end
		return
	end
	if kind ~= "start" then
		return
	end
	local ok, err = pcall(function()
		local pg = player:WaitForChild("PlayerGui")
		step(pg:FindFirstChild("SurvivalHUD") ~= nil, "HUD criado")
		local loading = pg:FindFirstChild("Loading")
		if loading then
			local play = loading:FindFirstChildWhichIsA("TextButton", true)
			step(waitFor(function()
				return play ~= nil and play.Visible
			end, 30), "tela de carregamento chegou ao botão JOGAR")
			loading:Destroy()
		end
		step(waitFor(function()
			return State.count("stick") >= 10
		end, 15), "cliente recebeu o inventário sincronizado")

		-- Exploits: nada disso pode ter efeito nem derrubar o servidor
		Action:FireServer("Craft", "obsidian_blade", 1)
		Action:FireServer("Craft", { "lixo" }, 0 / 0)
		Action:FireServer("Move", 1e9, -5)
		Action:FireServer("Place", "rescue_beacon", 0, 10, 0, 0)
		Action:FireServer("Use", "x")
		Action:FireServer("AcaoInexistente", 1, 2, 3)
		Action:FireServer(nil)
		for _ = 1, 150 do
			Action:FireServer("Select", 1)
		end
		task.wait(1.5)
		step(State.count("obsidian_blade") == 0, "craft sem materiais foi rejeitado")
		step(State.count("stick") >= 10, "ações inválidas não alteraram o inventário")

		-- Fluxo real de jogo
		Action:FireServer("Craft", "stone_axe", 1)
		step(waitFor(function()
			return State.count("stone_axe") == 1
		end, 5), "fabricou Machado de Pedra")
		local axe = slotOf("stone_axe")
		step(axe ~= nil and axe <= 6, "machado foi para a barra rápida (slot " .. tostring(axe) .. ")")
		if axe then
			Action:FireServer("Select", 0)
			task.wait(0.5)
			Action:FireServer("Select", axe)
			step(waitFor(function()
				local c = player.Character
				return c ~= nil and c:FindFirstChildOfClass("Tool") ~= nil
			end, 5), "machado apareceu na mão do personagem")
		end

		Action:FireServer("Craft", "campfire", 1)
		step(waitFor(function()
			return State.count("campfire") == 1
		end, 5), "fabricou Fogueira")

		-- Perto do spawn a construção deve ser recusada
		local char = player.Character :: Model
		local hrp = char:WaitForChild("HumanoidRootPart") :: BasePart
		local p = hrp.Position + hrp.CFrame.LookVector * 6
		Action:FireServer("Place", "campfire", p.X, p.Y - 2, p.Z, 0)
		task.wait(1)
		step(State.count("campfire") == 1, "construção perto do spawn foi recusada")

		-- Vai para um lugar válido e constrói
		local target = Vector3.new(30, 0, 360)
		local params = RaycastParams.new()
		params.FilterDescendantsInstances = { char }
		local hit = workspace:Raycast(Vector3.new(target.X, 300, target.Z), Vector3.new(0, -600, 0), params)
		step(hit ~= nil, "achou chão em (30, 360): " .. (hit and tostring(hit.Material) or "nada"))
		if hit then
			-- Exploit: teleporte de 300 studs deve ser revertido pelo servidor
			local origin = hrp.Position
			char:PivotTo(CFrame.new(origin + Vector3.new(300, 40, 0)))
			task.wait(2.5)
			step((hrp.Position - origin).Magnitude < 60, ("anti-teleporte reverteu a posição (distância final %.0f)"):format((hrp.Position - origin).Magnitude))
			-- Caminha até o local (movimento legítimo)
			local hum = char:FindFirstChildOfClass("Humanoid") :: Humanoid
			hum:MoveTo(hit.Position + Vector3.new(0, 0, 6))
			waitFor(function()
				return ((hrp.Position - hit.Position) * Vector3.new(1, 0, 1)).Magnitude < 12
			end, 15)
			task.wait(1)
			Action:FireServer("Place", "campfire", hit.Position.X, hit.Position.Y + 1, hit.Position.Z, 0)
			step(waitFor(function()
				return State.count("campfire") == 0
			end, 5), "fogueira colocada (item consumido)")
		end

		-- Janelas abrem e fecham
		for _, w in { "Inventory", "Crafting", "Build", "Quests", "Shop", "Settings" } do
			Widgets.toggle(w, true)
			task.wait(0.4)
			local f = pg.SurvivalHUD:FindFirstChild(w)
			step(f ~= nil and f.Visible, "janela " .. w .. " abriu")
			Widgets.toggle(w, false)
			task.wait(0.3)
		end
		step((State.data.daily and #State.data.daily.quests or 0) == 3, "3 missões diárias geradas")
		step((State.data.level or 0) >= 1, "nível sincronizado: " .. tostring(State.data.level))
	end)
	if not ok then
		step(false, "erro no roteiro do cliente: " .. tostring(err))
	end
	report:FireServer("done")
end)
