--!strict
-- Crafting autoritativo: valida nível, estação próxima, materiais e espaço.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local Recipes = require(Shared.Config.Recipes)
local Game = require(Shared.Config.Game)
local Rules = require(Shared.Logic.Rules)
local Net = require(Shared.Net)

local PlayerService = require(script.Parent.PlayerService)
local BuildService = require(script.Parent.BuildService)
local Actions = require(script.Parent.Parent.Util.Actions)

local CraftingService = {}
local fxEvent = Net.event("Fx")

local function onCraft(player: Player, recipeId: any, times: any)
	local rid = Actions.str(recipeId, 40)
	local recipe = rid and Recipes.byId[rid]
	local t = Actions.int(times == nil and 1 or times, 1, 50)
	local inv = PlayerService.inv(player)
	local data = PlayerService.data(player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not recipe or not t or not inv or not data or not hrp then
		return
	end
	local hasStation = recipe.station == nil or BuildService.nearStation(hrp.Position, recipe.station, Recipes.STATION_RANGE)
	local out = Items[recipe.output]
	local ok, why = Rules.craft(inv, recipe, data.level, hasStation, out.stack, Game.HOTBAR_SLOTS, t)
	if not ok then
		PlayerService.notify(player, why or "Não foi possível fabricar", "bad", "⛔")
		return
	end
	PlayerService.changed(player)
	PlayerService.notify(player, ("Fabricou %dx %s"):format(recipe.amount * t, out.name), "good", out.icon)
	PlayerService.count(player, "craft", t)
	if recipe.station == "campfire" then
		PlayerService.count(player, "cook", t)
	end
	PlayerService.addXp(player, 3 * t)
	fxEvent:FireClient(player, { kind = "craft", icon = out.icon })
end

function CraftingService.init()
	Actions.on("Craft", onCraft, 6)
end

return CraftingService
