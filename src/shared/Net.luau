--!strict
-- Remotes centralizados. O servidor cria; o cliente espera.
-- Cliente -> servidor: "Action" (nome da ação + argumentos), sempre validado no servidor.
-- Servidor -> cliente: "State" (estado parcial), "Notify" (mensagens), "Fx" (efeitos visuais/sons).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

local NAMES = { "Action", "State", "Notify", "Fx" }
local folder: Folder

if RunService:IsServer() then
	local f = ReplicatedStorage:FindFirstChild("Remotes")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Remotes"
		f.Parent = ReplicatedStorage
	end
	folder = f :: Folder
	for _, name in NAMES do
		if not folder:FindFirstChild(name) then
			local r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Net.event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

return Net
