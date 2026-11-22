-- Carrega um ModuleScript do projeto fora do Roblox, com Color3/Vector3/CFrame reais (@lune/roblox).
-- Suporta require("./X") relativo; require por Instance não é suportado (módulos testáveis são puros).

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox") :: any

local cache: { [string]: any } = {}

local function load(path: string): any
	if cache[path] ~= nil then
		return cache[path]
	end
	local file = path .. ".luau"
	local source = fs.readFile(file)
	local dir = string.match(path, "^(.*)/") or "."
	local env = {
		Color3 = roblox.Color3,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		script = nil,
		require = function(p: any)
			assert(type(p) == "string", "require por Instance não suportado nos testes")
			return load(dir .. "/" .. string.gsub(p, "^%./", ""))
		end,
	}
	local fn = luau.load(source, { debugName = file, environment = env })
	local result = fn()
	cache[path] = result
	return result
end

return load
