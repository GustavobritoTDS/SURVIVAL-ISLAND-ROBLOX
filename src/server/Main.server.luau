--!strict
-- Ponto de entrada do servidor: inicializa os serviços na ordem certa.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Items = require(Shared.Config.Items)

local Services = script.Parent:WaitForChild("Services")
local Actions = require(script.Parent.Util.Actions)

local DataService = require(Services.DataService)
local WorldService = require(Services.WorldService)
local PlayerService = require(Services.PlayerService)
local EquipService = require(Services.EquipService)
local ResourceService = require(Services.ResourceService)
local CreatureService = require(Services.CreatureService)
local BuildService = require(Services.BuildService)
local CraftingService = require(Services.CraftingService)
local EnvironmentService = require(Services.EnvironmentService)
local SurvivalService = require(Services.SurvivalService)
local QuestService = require(Services.QuestService)
local MonetizationService = require(Services.MonetizationService)

local t0 = os.clock()
local function step(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if not ok then
		warn(("[Main] Falha ao iniciar %s: %s"):format(name, tostring(err)))
	end
end

-- Jogadores esperam o mundo: personagens só nascem depois da geração
game:GetService("Players").CharacterAutoLoads = false

step("Actions", Actions.init)
step("World", WorldService.Init)
step("Environment", EnvironmentService.init)
step("Data", DataService.init)
step("Player", PlayerService.init)
step("Equip", EquipService.init)
step("Resource", ResourceService.init)
step("Creature", CreatureService.init)
step("Build", BuildService.init)
step("Crafting", CraftingService.init)
step("Survival", SurvivalService.init)
step("Quest", QuestService.init)
step("Monetization", MonetizationService.init)

-- Golpes: armas priorizam criaturas; machados/picaretas priorizam nós de recurso
EquipService.onActivated(function(player, itemId)
	local def = Items[itemId]
	if def.toolType == "axe" or def.toolType == "pickaxe" then
		if not ResourceService.tryHit(player, itemId) then
			CreatureService.tryHit(player, def)
		end
	else
		CreatureService.tryHit(player, def)
	end
end)

-- Personagens: nascem quando os dados estiverem prontos; renascem 4 s após morrer
local Players = game:GetService("Players")
local function spawnLoop(player: Player)
	DataService.await(player)
	if not player.Parent then
		return
	end
	player:LoadCharacter()
	player.CharacterAdded:Connect(function(char)
		local hum = char:WaitForChild("Humanoid") :: Humanoid
		hum.Died:Connect(function()
			task.wait(4)
			if player.Parent then
				player:LoadCharacter()
			end
		end)
	end)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Died:Connect(function()
			task.wait(4)
			if player.Parent then
				player:LoadCharacter()
			end
		end)
	end
end
Players.PlayerAdded:Connect(spawnLoop)
for _, p in Players:GetPlayers() do
	task.spawn(spawnLoop, p)
end

workspace:SetAttribute("ServerReady", true)
print(("[Survival Island] Servidor pronto em %.1f s"):format(os.clock() - t0))
