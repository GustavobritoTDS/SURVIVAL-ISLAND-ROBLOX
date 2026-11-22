--!strict
-- Fábrica de Parts low-poly: sempre Anchored, sem colisão nem consulta por padrão.
-- Nada de MeshId/TextureId: só formas e materiais nativos.

local PartKit = {}

export type Props = {
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?,
	transparency: number?,
	reflectance: number?,
	shadow: boolean?,
	name: string?,
	parent: Instance?,
}

local function apply(p: BasePart, props: Props)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Size = props.size
	p.CFrame = props.cframe
	p.Color = props.color
	p.Material = props.material or Enum.Material.SmoothPlastic
	p.Transparency = props.transparency or 0
	p.Reflectance = props.reflectance or 0
	p.CastShadow = props.shadow == true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Name = props.name or p.ClassName
	p.Parent = props.parent
end

function PartKit.block(props: Props): Part
	local p = Instance.new("Part")
	if props.shape then
		p.Shape = props.shape -- forma antes do tamanho (bolas exigem tamanho uniforme)
	end
	apply(p, props)
	return p
end

function PartKit.wedge(props: Props): WedgePart
	local p = Instance.new("WedgePart")
	apply(p, props)
	return p
end

-- CFrame centrado entre a e b com o eixo X apontando de a para b (cilindros).
function PartKit.axis(a: Vector3, b: Vector3): CFrame
	local dir = (b - a).Unit
	local ref = if math.abs(dir.Y) > 0.98 then Vector3.xAxis else Vector3.yAxis
	local back = dir:Cross(ref).Unit
	local up = back:Cross(dir).Unit
	return CFrame.fromMatrix((a + b) / 2, dir, up, back)
end

-- CFrame com o eixo Y alinhado a `up` (objetos presos em paredes/tetos).
function PartKit.alignUp(pos: Vector3, up: Vector3, spin: number): CFrame
	local ref = if math.abs(up.Y) > 0.95 then Vector3.xAxis else Vector3.yAxis
	local right = ref:Cross(up).Unit
	local back = right:Cross(up).Unit
	return CFrame.fromMatrix(pos, right, up, back) * CFrame.Angles(0, spin, 0)
end

function PartKit.cylinder(
	a: Vector3,
	b: Vector3,
	diameter: number,
	color: Color3,
	material: Enum.Material,
	parent: Instance?,
	shadow: boolean?
): Part
	if (b - a).Magnitude < 0.05 then
		b = a + Vector3.new(0, 0.05, 0)
	end
	return PartKit.block({
		shape = Enum.PartType.Cylinder,
		size = Vector3.new((b - a).Magnitude, diameter, diameter),
		cframe = PartKit.axis(a, b),
		color = color,
		material = material,
		parent = parent,
		shadow = shadow,
	})
end

function PartKit.ball(
	pos: Vector3,
	diameter: number,
	color: Color3,
	material: Enum.Material,
	parent: Instance?,
	shadow: boolean?
): Part
	return PartKit.block({
		shape = Enum.PartType.Ball,
		size = Vector3.new(diameter, diameter, diameter),
		cframe = CFrame.new(pos),
		color = color,
		material = material,
		parent = parent,
		shadow = shadow,
	})
end

-- Luz pontual sem sombras (barata em celulares).
function PartKit.light(parent: BasePart, color: Color3, range: number, brightness: number): PointLight
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
	return l
end

-- Escolhe um item aleatório da lista.
function PartKit.pick<T>(rng: Random, list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

return PartKit
