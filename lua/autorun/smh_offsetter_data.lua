SMHOffsetter = SMHOffsetter or {}

local ENTITY = FindMetaTable("Entity")
local EntityGetClass = ENTITY.GetClass
local EntityIsScripted = ENTITY.IsScripted

---@class SMHOffsetterData
local Data = SMHOffsetter.Data or {}
SMHOffsetter.Data = Data

Data._offsetters = Data._offsetters or {}
Data._sources = Data._sources or {}
Data._empty = Data._empty or {}
Data._classes = {}
local function getOffsetterState(offsetter, create)
	local state = Data._offsetters[offsetter]
	if not state and create then
		state = {
			sources = {},
			sourceIndices = {},
			holograms = {},
			sourceZeroPoints = {},
			hologramZeroPoints = {},
			offset = Vector(),
		}
		Data._offsetters[offsetter] = state
	end
	return state
end

---@param source Entity
---@param class string
---@param create boolean
local function getClassVars(source, class, create)
	local classVars = Data._classes[class]
	if not classVars and create then
		classVars = { names = {}, sent = false }
		if EntityIsScripted(source) then
			local values = source:GetNetworkVars() or {}
			classVars.sent = true
			for name in pairs(values) do
				table.insert(classVars.names, name)
			end
		end
		Data._classes[class] = classVars
	end
	return classVars
end

local function getSourceState(source, create)
	local state = Data._sources[source]
	if not state and create then
		state = { offsetters = {}, offsetterIndices = {}, class = EntityGetClass(source) }
		Data._sources[source] = state
	end
	return state
end

local function removeIndexed(array, indices, item)
	local index = indices[item]
	if not index then
		return
	end

	local lastIndex = #array
	local lastItem = array[lastIndex]
	array[index] = lastItem
	array[lastIndex] = nil
	indices[item] = nil
	if index < lastIndex then
		indices[lastItem] = index
	end
end

---@param offsetter smh_offsetter
---@return Entity[]
function Data.GetSources(offsetter)
	local state = getOffsetterState(offsetter, false)
	return state and state.sources or Data._empty
end

---@param source Entity
---@return Entity[]
function Data.GetOffsetters(source)
	local state = getSourceState(source, false)
	return state and state.offsetters or Data._empty
end

---@param offsetter smh_offsetter
---@param source Entity
---@return Entity?
function Data.GetHologram(offsetter, source)
	local state = getOffsetterState(offsetter, false)
	return state and state.holograms[source]
end

---@param offsetter smh_offsetter
---@param source Entity
---@return table?
function Data.GetSourceZeroPoint(offsetter, source)
	local state = getOffsetterState(offsetter, false)
	return state and state.sourceZeroPoints[source]
end

---@param offsetter smh_offsetter
---@param source Entity
---@return table?
function Data.GetHologramZeroPoint(offsetter, source)
	local state = getOffsetterState(offsetter, false)
	return state and state.hologramZeroPoints[source]
end

---@param offsetter smh_offsetter
---@param source Entity
---@param hologram Entity
function Data.AddPair(offsetter, source, hologram)
	local offsetterState = getOffsetterState(offsetter, true)
	if not offsetterState.sourceIndices[source] then
		table.insert(offsetterState.sources, source)
		offsetterState.sourceIndices[source] = #offsetterState.sources
	end
	offsetterState.holograms[source] = hologram

	local sourceState = getSourceState(source, true)
	if not sourceState.offsetterIndices[offsetter] then
		table.insert(sourceState.offsetters, offsetter)
		sourceState.offsetterIndices[offsetter] = #sourceState.offsetters
	end
end

---@param offsetter smh_offsetter
---@param source Entity
---@param sourceZeroPoint table
---@param hologramZeroPoint table
function Data.SetZeroPoints(offsetter, source, sourceZeroPoint, hologramZeroPoint)
	local state = getOffsetterState(offsetter, true)
	state.sourceZeroPoints[source] = sourceZeroPoint
	state.hologramZeroPoints[source] = hologramZeroPoint
end

---@param offsetter smh_offsetter
---@param offset Vector
function Data.SetOffset(offsetter, offset)
	local state = getOffsetterState(offsetter, true)
	state.offset = offset
end

---@param offsetter smh_offsetter
function Data.GetOffset(offsetter)
	local state = getOffsetterState(offsetter, false)
	return state and state.offset or Vector()
end

---@param offsetter smh_offsetter
---@param source Entity
---@return boolean
function Data.HasPair(offsetter, source)
	local state = getOffsetterState(offsetter, false)
	return state ~= nil and state.sourceIndices[source] ~= nil
end

function Data.GetClassVars(source)
	local state = getSourceState(source, false)
	local classVars = getClassVars(source, state.class, true)
	return classVars
end

---@param offsetter smh_offsetter
---@param source Entity
---@return Entity? hologram
function Data.RemovePair(offsetter, source)
	local state = getOffsetterState(offsetter, false)
	if not state then
		return nil
	end

	local hologram = state.holograms[source]
	removeIndexed(state.sources, state.sourceIndices, source)
	state.holograms[source] = nil
	state.sourceZeroPoints[source] = nil
	state.hologramZeroPoints[source] = nil

	local sourceState = getSourceState(source, false)
	if sourceState then
		removeIndexed(sourceState.offsetters, sourceState.offsetterIndices, offsetter)
		if #sourceState.offsetters == 0 then
			Data._sources[source] = nil
		end
	end
	if #state.sources == 0 then
		Data._offsetters[offsetter] = nil
	end
	return hologram
end

---@param offsetter smh_offsetter
function Data.ClearOffsetter(offsetter)
	local state = getOffsetterState(offsetter, false)
	if not state then
		return
	end

	while #state.sources > 0 do
		Data.RemovePair(offsetter, state.sources[#state.sources])
	end
end
