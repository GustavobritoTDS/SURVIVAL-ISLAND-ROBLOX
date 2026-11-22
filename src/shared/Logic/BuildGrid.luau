--!strict
-- Encaixe de construção compartilhado por cliente (prévia) e servidor (validação).

local BuildGrid = {}

-- Arredonda X/Z para a grade; rot = 0..3 (múltiplos de 90°). Y é o centro já calculado.
function BuildGrid.snap(center: Vector3, snap: number, rot: number): CFrame
	local x = math.round(center.X / snap) * snap
	local z = math.round(center.Z / snap) * snap
	return CFrame.new(x, center.Y, z) * CFrame.Angles(0, rot * math.pi / 2, 0)
end

-- Centro a partir do ponto de apoio (chão) e altura da peça
function BuildGrid.centerFromGround(ground: Vector3, size: Vector3): Vector3
	return ground + Vector3.new(0, size.Y / 2, 0)
end

return BuildGrid
