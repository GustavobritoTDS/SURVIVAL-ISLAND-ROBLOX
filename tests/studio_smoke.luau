-- Teste de fumaça dentro do Roblox Studio (via run-in-roblox).
-- Verifica se o servidor inicia sem erros, gera o mundo e cria nós, criaturas-pasta e remotes.
-- Uso: run-in-roblox --place build/SurvivalIsland.rbxlx --script tests/studio_smoke.luau

local LogService = game:GetService("LogService")
local RunService = game:GetService("RunService")

local errors = {}
LogService.MessageOut:Connect(function(msg, kind)
	if kind == Enum.MessageType.MessageError or kind == Enum.MessageType.MessageWarning then
		table.insert(errors, (kind == Enum.MessageType.MessageError and "ERRO " or "AVISO ") .. msg)
	end
end)

print("[smoke] IsRunning:", RunService:IsRunning(), "IsServer:", RunService:IsServer(), "IsEdit:", RunService:IsEdit())
-- Em modo Edit os Scripts não rodam: iniciamos o servidor pelo módulo Boot
task.spawn(function()
	local ok, err = pcall(require(game:GetService("ServerScriptService").Server.Boot))
	if not ok then
		warn("[smoke] Boot falhou: " .. tostring(err))
	end
end)

local t0 = os.clock()
while not workspace:GetAttribute("ServerReady") and os.clock() - t0 < 120 do
	task.wait(1)
end

local world = workspace:FindFirstChild("World")
local function count(folder)
	return folder and #folder:GetChildren() or -1
end
print("[smoke] ServerReady:", workspace:GetAttribute("ServerReady"), "em", math.floor(os.clock() - t0), "s")
print("[smoke] WorldReady:", workspace:GetAttribute("WorldReady"))
print("[smoke] Nodes:", count(world and world:FindFirstChild("Nodes")))
print("[smoke] Decor:", count(world and world:FindFirstChild("Decor")))
print("[smoke] FreshWater:", count(world and world:FindFirstChild("FreshWater")))
print("[smoke] Remotes:", count(game.ReplicatedStorage:FindFirstChild("Remotes")))
print("[smoke] Lighting.ClockTime:", game.Lighting.ClockTime)

local parts = 0
for _, d in workspace:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	end
end
print("[smoke] BaseParts no workspace:", parts)

-- Sonda de terreno: altura no spawn, na selva e no vulcão
for _, p in { { "spawn", 0, 430 }, { "selva", 0, 60 }, { "planalto", -60, -240 }, { "vulcao", 260, -230 } } do
	local hit = workspace:Raycast(Vector3.new(p[2], 400, p[3]), Vector3.new(0, -800, 0))
	print(("[smoke] chão %s: %s %s"):format(p[1], hit and string.format("%.1f", hit.Position.Y) or "nil", hit and tostring(hit.Material) or ""))
end

print("[smoke] Erros capturados:", #errors)
for i, e in errors do
	if i <= 15 then
		print("[smoke][erro] " .. e)
	end
end
print("[smoke] FIM")
