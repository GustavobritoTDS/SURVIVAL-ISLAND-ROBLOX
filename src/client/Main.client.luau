--!strict
-- Ponto de entrada do cliente: cria a UI e registra os atalhos (teclado, controle e toque).

local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Game = require(Shared.Config.Game)

local State = require(script.Parent.State)
local Widgets = require(script.Parent.UI.Widgets)
local HUD = require(script.Parent.Controllers.HUD)
local Inventory = require(script.Parent.Controllers.Inventory)
local Crafting = require(script.Parent.Controllers.Crafting)
local Build = require(script.Parent.Controllers.Build)
local Menus = require(script.Parent.Controllers.Menus)
local Fx = require(script.Parent.Controllers.Fx)
local Tutorial = require(script.Parent.Controllers.Tutorial)

-- Esconde a mochila padrão do Roblox (usamos a nossa barra)
task.spawn(function()
	for _ = 1, 20 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false) -- usamos a nossa barra de vida
		end)
		if ok then
			break
		end
		task.wait(0.5)
	end
end)

HUD.init()
local gui = HUD.gui :: ScreenGui
Inventory.init(gui)
Crafting.init(gui)
Build.init(gui)
Menus.init(gui)
Fx.init(gui, HUD)
Tutorial.init(gui)
State.init()

-- Atalhos
local KEYS: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.Tab] = "Inventory",
	[Enum.KeyCode.I] = "Inventory",
	[Enum.KeyCode.C] = "Crafting",
	[Enum.KeyCode.B] = "Build",
	[Enum.KeyCode.J] = "Quests",
	[Enum.KeyCode.M] = "Shop",
	[Enum.KeyCode.ButtonY] = "Inventory",
	[Enum.KeyCode.DPadUp] = "Crafting",
	[Enum.KeyCode.DPadRight] = "Build",
	[Enum.KeyCode.DPadDown] = "Quests",
}
local NUMBERS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six }

local gamepadSlot = 1
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local kc = input.KeyCode
	local win = KEYS[kc]
	if win then
		Widgets.toggle(win)
		return
	end
	if kc == Enum.KeyCode.Escape or kc == Enum.KeyCode.ButtonB then
		Widgets.closeAll()
		return
	end
	for i, k in NUMBERS do
		if kc == k and i <= Game.HOTBAR_SLOTS then
			HUD.useHotbar(i)
			return
		end
	end
	-- Controle: LB/RB percorrem a barra rápida
	if kc == Enum.KeyCode.ButtonL1 or kc == Enum.KeyCode.ButtonR1 then
		gamepadSlot = (gamepadSlot - 1 + (kc == Enum.KeyCode.ButtonR1 and 1 or -1)) % Game.HOTBAR_SLOTS + 1
		HUD.useHotbar(gamepadSlot)
	end
end)

-- Fecha o inventário automaticamente ao entrar em modo construção (evita sobreposição)
local _ = Build
print("[Survival Island] Cliente iniciado")
