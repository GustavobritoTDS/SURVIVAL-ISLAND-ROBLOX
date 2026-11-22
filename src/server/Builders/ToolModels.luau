--!strict
-- Monta Tools low-poly a partir de Parts (sem assets externos).
-- O Handle fica na mão; peças extras são soldadas com WeldConstraint.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Items = require(Shared.Config.Items)

local ToolModels = {}

local WOOD = Color3.fromRGB(120, 80, 45)

local function part(
	parent: Instance,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	cf: CFrame,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Material = material
	p.CFrame = cf
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

local function headMaterial(def: any): (Color3, Enum.Material)
	if def.tier == 3 then
		if def.id == "obsidian_blade" then
			return Color3.fromRGB(45, 30, 60), Enum.Material.Glass
		end
		return Color3.fromRGB(90, 220, 230), Enum.Material.Glass
	elseif def.tier == 2 then
		return Color3.fromRGB(195, 195, 205), Enum.Material.Metal
	end
	return Color3.fromRGB(135, 135, 140), Enum.Material.Slate
end

function ToolModels.build(itemId: string): Tool?
	local def = Items[itemId]
	if not def or not def.toolType then
		return nil
	end
	local tool = Instance.new("Tool")
	tool.Name = def.name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = def.name
	tool:SetAttribute("ItemId", itemId)

	local origin = CFrame.new()
	local handle = part(tool, Vector3.new(0.35, 3.2, 0.35), WOOD, Enum.Material.Wood, origin)
	handle.Name = "Handle"
	tool.Grip = CFrame.new(0, -0.9, 0)

	local color, mat = headMaterial(def)
	local top = origin * CFrame.new(0, 1.4, 0)
	local extras: { BasePart } = {}

	if def.toolType == "axe" then
		table.insert(extras, part(tool, Vector3.new(0.3, 0.9, 1.3), color, mat, top * CFrame.new(0, 0, -0.55)))
		table.insert(
			extras,
			part(
				tool,
				Vector3.new(0.4, 0.4, 0.4),
				Color3.fromRGB(110, 170, 70),
				Enum.Material.Fabric,
				top * CFrame.new(0, -0.5, 0)
			)
		)
	elseif def.toolType == "pickaxe" then
		table.insert(extras, part(tool, Vector3.new(0.3, 0.35, 2.4), color, mat, top))
		table.insert(extras, part(tool, Vector3.new(0.25, 0.5, 0.35), color, mat, top * CFrame.new(0, -0.25, 1.2)))
		table.insert(extras, part(tool, Vector3.new(0.25, 0.5, 0.35), color, mat, top * CFrame.new(0, -0.25, -1.2)))
	elseif def.toolType == "torch" then
		local head = part(tool, Vector3.new(0.6, 0.6, 0.6), Color3.fromRGB(90, 60, 35), Enum.Material.Fabric, top)
		table.insert(extras, head)
		local fire = Instance.new("Fire")
		fire.Size = 3
		fire.Heat = 6
		fire.Parent = head
		local light = Instance.new("PointLight")
		light.Range = 22
		light.Brightness = 2
		light.Color = Color3.fromRGB(255, 170, 90)
		light.Shadows = true
		light.Parent = head
	elseif def.toolType == "weapon" then
		if itemId == "wooden_spear" then
			handle.Size = Vector3.new(0.3, 5.5, 0.3)
			tool.Grip = CFrame.new(0, -1.2, 0)
			table.insert(
				extras,
				part(
					tool,
					Vector3.new(0.35, 0.9, 0.35),
					Color3.fromRGB(90, 90, 100),
					Enum.Material.Slate,
					origin * CFrame.new(0, 3.1, 0)
				)
			)
		elseif itemId == "stone_club" then
			table.insert(extras, part(tool, Vector3.new(1.1, 1.4, 1.1), color, mat, top, Enum.PartType.Ball))
		else
			-- lâminas
			handle.Size = Vector3.new(0.35, 1.2, 0.35)
			tool.Grip = CFrame.new(0, -0.2, 0)
			table.insert(
				extras,
				part(
					tool,
					Vector3.new(1.2, 0.25, 0.4),
					Color3.fromRGB(70, 50, 30),
					Enum.Material.Wood,
					origin * CFrame.new(0, 0.7, 0)
				)
			)
			local blade = part(tool, Vector3.new(0.15, 3.2, 0.55), color, mat, origin * CFrame.new(0, 2.4, 0))
			if def.tier == 3 then
				blade.Material = Enum.Material.Neon
				blade.Transparency = 0.15
			end
			table.insert(extras, blade)
		end
	end

	for _, p in extras do
		weld(handle, p)
	end

	-- anima de golpe padrão (o script Animate do Roblox toca "Slash" ao detectar isto)
	return tool
end

return ToolModels
