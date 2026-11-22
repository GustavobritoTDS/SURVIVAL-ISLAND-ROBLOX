--!strict
-- Lógica pura de inventário (sem APIs do Roblox -> testável com o CLI `luau`).
-- Um inventário é { size = n, slots = { [i] = { id = string, n = number } | nil } }.
-- Os índices 1..HOTBAR_SLOTS são a barra de atalhos.

export type Stack = { id: string, n: number }
export type Inv = { size: number, slots: { [number]: Stack } }

local Inventory = {}

function Inventory.new(size: number): Inv
	return { size = size, slots = {} }
end

-- Retorna quantos itens `id` existem no inventário
function Inventory.count(inv: Inv, id: string): number
	local total = 0
	for i = 1, inv.size do
		local s = inv.slots[i]
		if s and s.id == id then
			total += s.n
		end
	end
	return total
end

-- Quantos itens `id` ainda cabem
function Inventory.space(inv: Inv, id: string, stackMax: number): number
	local free = 0
	for i = 1, inv.size do
		local s = inv.slots[i]
		if s == nil then
			free += stackMax
		elseif s.id == id then
			free += math.max(0, stackMax - s.n)
		end
	end
	return free
end

-- Adiciona até `n` itens; retorna quantos foram adicionados (o resto não coube).
-- Preenche primeiro pilhas existentes, depois slots vazios (começando fora da hotbar
-- para recursos, a não ser que `preferHotbar` seja true).
function Inventory.add(inv: Inv, id: string, n: number, stackMax: number, hotbarSize: number?, preferHotbar: boolean?): number
	if n <= 0 then
		return 0
	end
	local remaining = n
	for i = 1, inv.size do
		local s = inv.slots[i]
		if s and s.id == id and s.n < stackMax then
			local put = math.min(stackMax - s.n, remaining)
			s.n += put
			remaining -= put
			if remaining == 0 then
				return n
			end
		end
	end
	local hb = hotbarSize or 0
	local order = {}
	if preferHotbar then
		for i = 1, inv.size do
			table.insert(order, i)
		end
	else
		for i = hb + 1, inv.size do
			table.insert(order, i)
		end
		for i = 1, math.min(hb, inv.size) do
			table.insert(order, i)
		end
	end
	for _, i in order do
		if inv.slots[i] == nil then
			local put = math.min(stackMax, remaining)
			inv.slots[i] = { id = id, n = put }
			remaining -= put
			if remaining == 0 then
				return n
			end
		end
	end
	return n - remaining
end

-- Remove `n` itens `id`; retorna true se havia o suficiente (senão não altera nada).
function Inventory.remove(inv: Inv, id: string, n: number): boolean
	if n <= 0 then
		return true
	end
	if Inventory.count(inv, id) < n then
		return false
	end
	local remaining = n
	-- remove de trás para frente para preservar a hotbar
	for i = inv.size, 1, -1 do
		local s = inv.slots[i]
		if s and s.id == id then
			local take = math.min(s.n, remaining)
			s.n -= take
			remaining -= take
			if s.n <= 0 then
				inv.slots[i] = nil
			end
			if remaining == 0 then
				break
			end
		end
	end
	return true
end

-- Remove itens de um slot específico; retorna o id removido e a quantidade
function Inventory.takeFromSlot(inv: Inv, slot: number, n: number): (string?, number)
	local s = inv.slots[slot]
	if s == nil or n <= 0 then
		return nil, 0
	end
	local take = math.min(n, s.n)
	s.n -= take
	local id = s.id
	if s.n <= 0 then
		inv.slots[slot] = nil
	end
	return id, take
end

-- Move/troca/mescla entre dois slots (podem ser de inventários diferentes)
function Inventory.move(fromInv: Inv, from: number, toInv: Inv, to: number, stackMaxOf: (string) -> number): boolean
	if from < 1 or from > fromInv.size or to < 1 or to > toInv.size then
		return false
	end
	if fromInv == toInv and from == to then
		return false
	end
	local a = fromInv.slots[from]
	if a == nil then
		return false
	end
	local b = toInv.slots[to]
	if b and b.id == a.id then
		local max = stackMaxOf(a.id)
		local put = math.min(max - b.n, a.n)
		if put <= 0 then
			-- pilha cheia: troca
			fromInv.slots[from], toInv.slots[to] = b, a
			return true
		end
		b.n += put
		a.n -= put
		if a.n <= 0 then
			fromInv.slots[from] = nil
		end
		return true
	end
	fromInv.slots[from], toInv.slots[to] = b, a
	return true
end

-- Ao reduzir o tamanho (ex.: perdeu um pass), devolve as pilhas que ficaram fora
function Inventory.resize(inv: Inv, newSize: number): { Stack }
	local overflow = {}
	for i = newSize + 1, inv.size do
		local s = inv.slots[i]
		if s then
			table.insert(overflow, s)
			inv.slots[i] = nil
		end
	end
	inv.size = newSize
	return overflow
end

-- Verifica se o inventário tem todos os custos
function Inventory.hasAll(inv: Inv, cost: { [string]: number }): boolean
	for id, n in cost do
		if Inventory.count(inv, id) < n then
			return false
		end
	end
	return true
end

-- Remove todos os custos de forma atômica
function Inventory.removeAll(inv: Inv, cost: { [string]: number }): boolean
	if not Inventory.hasAll(inv, cost) then
		return false
	end
	for id, n in cost do
		Inventory.remove(inv, id, n)
	end
	return true
end

-- Serialização compacta para DataStore: { {id, n, slot}, ... }
function Inventory.serialize(inv: Inv): { any }
	local out = {}
	for i = 1, inv.size do
		local s = inv.slots[i]
		if s then
			table.insert(out, { s.id, s.n, i })
		end
	end
	return out
end

-- Desserializa validando ids e limites (dados podem estar corrompidos/antigos)
function Inventory.deserialize(data: any, size: number, isValid: (string) -> boolean, stackMaxOf: (string) -> number): Inv
	local inv = Inventory.new(size)
	if type(data) ~= "table" then
		return inv
	end
	local leftovers = {}
	for _, e in data do
		if type(e) == "table" and type(e[1]) == "string" and type(e[2]) == "number" and isValid(e[1]) then
			local id, n, slot = e[1], math.floor(e[2]), e[3]
			n = math.clamp(n, 0, stackMaxOf(id))
			if n > 0 then
				if type(slot) == "number" and slot >= 1 and slot <= size and inv.slots[slot] == nil then
					inv.slots[slot] = { id = id, n = n }
				else
					table.insert(leftovers, { id = id, n = n })
				end
			end
		end
	end
	for _, s in leftovers do
		Inventory.add(inv, s.id, s.n, stackMaxOf(s.id))
	end
	return inv
end

return Inventory
