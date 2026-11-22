-- Inicia um teste em modo Play (com jogador e cliente reais) a partir do plugin do run-in-roblox.
-- Uso:
--   rojo build test.project.json -o build/SurvivalIslandTest.rbxlx
--   run-in-roblox --place build/SurvivalIslandTest.rbxlx --script tests/studio_play.luau

local StudioTestService = game:GetService("StudioTestService")
print("[play] iniciando teste em modo Play...")
local ok, result = pcall(function()
	return StudioTestService:ExecutePlayModeAsync({})
end)
if not ok then
	print("[play] ExecutePlayModeAsync falhou: " .. tostring(result))
	return
end
if type(result) == "table" then
	print("[play] RELATÓRIO\n" .. tostring(result.report))
	print("[play] falhas: " .. tostring(result.failures))
else
	print("[play] resultado: " .. tostring(result))
end
