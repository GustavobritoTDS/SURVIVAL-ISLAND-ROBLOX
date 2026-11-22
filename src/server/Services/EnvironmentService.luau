--!strict
-- Ciclo de dia/noite, clima (sol, chuva, tempestade) e iluminação.
-- Clima é replicado via atributos em workspace ("Weather", "Night") para efeitos no cliente.

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Game = require(Shared.Config.Game)

local PlayerService = require(script.Parent.PlayerService)
local Env = require(script.Parent.Parent.Util.Env)

local EnvironmentService = {}

local atmosphere: Atmosphere
local color: ColorCorrectionEffect
local rng = Random.new()

local function ensure<T>(className: string, name: string): any
	local inst = Lighting:FindFirstChild(name)
	if not inst then
		inst = Instance.new(className)
		inst.Name = name
		inst.Parent = Lighting
	end
	return inst
end

local function setupLighting()
	Lighting.Brightness = 2.4
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 120, 110)
	Lighting.Ambient = Color3.fromRGB(40, 40, 50)
	Lighting.ShadowSoftness = 0.25
	Lighting.GeographicLatitude = 12
	Lighting.ClockTime = 8

	atmosphere = ensure("Atmosphere", "Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(199, 214, 225)
	atmosphere.Decay = Color3.fromRGB(106, 130, 150)
	atmosphere.Glare = 0.4
	atmosphere.Haze = 1.2

	local sky = ensure("Sky", "Sky")
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 9
	sky.StarCount = 3000

	local bloom = ensure("BloomEffect", "Bloom")
	bloom.Intensity = 0.6
	bloom.Size = 28
	bloom.Threshold = 1.6

	local rays = ensure("SunRaysEffect", "SunRays")
	rays.Intensity = 0.06
	rays.Spread = 0.6

	color = ensure("ColorCorrectionEffect", "Grade")
	color.Saturation = 0.12
	color.Contrast = 0.06
	color.TintColor = Color3.fromRGB(255, 250, 242)

	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.45
	clouds.Density = 0.6
	clouds.Parent = workspace.Terrain

	workspace.Terrain.WaterColor = Color3.fromRGB(20, 140, 160)
	workspace.Terrain.WaterTransparency = 0.6
	workspace.Terrain.WaterReflectance = 0.6
	workspace.Terrain.WaterWaveSize = 0.18
	workspace.Terrain.WaterWaveSpeed = 9
end

local function tween(inst: Instance, props: { [string]: any }, t: number)
	TweenService:Create(inst, TweenInfo.new(t, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), props):Play()
end

-- weather: "clear" | "rain" | "storm"
local function setWeather(weather: string)
	workspace:SetAttribute("Weather", weather)
	Env.raining = weather ~= "clear"
	Env.storm = weather == "storm"
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds") :: Clouds
	if weather == "clear" then
		tween(clouds, { Cover = 0.45, Density = 0.6, Color = Color3.fromRGB(255, 255, 255) }, 20)
		tween(atmosphere, { Density = 0.28, Haze = 1.2 }, 20)
		tween(color, { Saturation = 0.12, Brightness = 0 }, 20)
	elseif weather == "rain" then
		tween(clouds, { Cover = 0.8, Density = 0.75, Color = Color3.fromRGB(180, 185, 195) }, 20)
		tween(atmosphere, { Density = 0.38, Haze = 2 }, 20)
		tween(color, { Saturation = -0.05, Brightness = -0.03 }, 20)
	else
		tween(clouds, { Cover = 0.95, Density = 0.9, Color = Color3.fromRGB(110, 115, 125) }, 15)
		tween(atmosphere, { Density = 0.5, Haze = 3 }, 15)
		tween(color, { Saturation = -0.2, Brightness = -0.06 }, 15)
		for _, p in Players:GetPlayers() do
			PlayerService.notify(p, "Uma tempestade se aproxima! Procure abrigo e fogo.", "bad", "⛈️")
		end
	end
end

local function isNight(clock: number): boolean
	return clock >= Game.NIGHT_START or clock < Game.NIGHT_END
end

function EnvironmentService.init()
	setupLighting()
	setWeather("clear")
	workspace:SetAttribute("Night", false)

	-- Relógio: 24h de jogo em DAY_LENGTH segundos (noite ~ 1/3 do ciclo, um pouco mais curta)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.1)
			local now = os.clock()
			local dt = now - last
			last = now
			local clock = Lighting.ClockTime
			local speed = 24 / Game.DAY_LENGTH
			if isNight(clock) then
				speed *= 1.25 -- noites um pouco mais rápidas
			end
			clock = (clock + dt * speed) % 24
			Lighting.ClockTime = clock
			local night = isNight(clock)
			if night ~= Env.night then
				Env.night = night
				workspace:SetAttribute("Night", night)
				if night then
					tween(Lighting, { OutdoorAmbient = Color3.fromRGB(60, 70, 105), Brightness = 1.2 }, 8)
					for _, p in Players:GetPlayers() do
						PlayerService.notify(p, "A noite caiu. As Sombras da Maré despertam...", "bad", "🌙")
					end
				else
					Env.nightCount += 1
					workspace:SetAttribute("NightCount", Env.nightCount)
					tween(Lighting, { OutdoorAmbient = Color3.fromRGB(128, 120, 110), Brightness = 2.4 }, 8)
					for _, p in Players:GetPlayers() do
						local char = p.Character
						local hum = char and char:FindFirstChildOfClass("Humanoid")
						if hum and hum.Health > 0 then
							PlayerService.count(p, "nights", 1)
							PlayerService.notify(p, "Você sobreviveu à noite! ☀️", "good", "🌅")
							PlayerService.addXp(p, 40)
						end
					end
				end
			end
		end
	end)

	-- Clima aleatório
	task.spawn(function()
		while true do
			task.wait(rng:NextNumber(Game.WEATHER_MIN, Game.WEATHER_MAX))
			local roll = rng:NextNumber()
			local w = roll < 0.55 and "clear" or (roll < 0.85 and "rain" or "storm")
			setWeather(w)
		end
	end)
end

return EnvironmentService
