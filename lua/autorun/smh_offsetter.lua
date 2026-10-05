if CLIENT then
	return
end

local offset

local ENTITY = FindMetaTable("Entity")
local PHYSOBJ = FindMetaTable("PhysObj")
local opt = SMH.Optimizations
---@type fun(entity: Entity): Vector
local EntityGetPos
---@type fun(entity: Entity): Angle
local EntityGetAngles
local EntityGetPhysicsObject
local EntityGetPhysicsObjectCount, EntityGetPhysicsObjectNum, EntityGetNetworkVars
local EntityGetNWVarTable, EntityGetNW2VarTable, EntitySetNWBool, EntitySetNWInt
local EntitySetNWFloat, EntitySetNWString, EntitySetNWVector, EntitySetNWAngle
local EntitySetNWEntity, EntitySetNW2Var, EntityGetSkin, EntitySetSkin
local EntityGetColor, EntitySetColor, EntityGetEyeTarget, EntitySetEyeTarget
local EntityGetBodyGroups, EntityGetBodygroup, EntitySetBodygroup
local EntityGetFlexScale, EntitySetFlexScale, EntityGetFlexNum, EntityGetFlexWeight, EntitySetFlexWeight
local EntityGetBoneCount, EntityGetManipulateBonePosition, EntityGetManipulateBoneAngles
local EntityGetManipulateBoneScale, EntityManipulateBonePosition, EntityManipulateBoneAngles
local EntityManipulateBoneScale, EntityEntIndex, EntityCallOnRemove, EntityIsMarkedForDeletion

local PhysObjGetPos, PhysObjGetAngles, PhysObjEnableMotion, PhysObjEnableCollisions
local PhysObjSetPos, PhysObjSetAngles, PhysObjWake
local function updateEntityMethods(smh)
	opt = smh and smh.Optimizations or SMH.Optimizations
	local function method(optimizedName, entityName)
		return opt[optimizedName] or ENTITY[entityName]
	end

	EntityGetPos = ENTITY.GetPos
	EntityGetAngles = ENTITY.GetAngles
	EntityGetPhysicsObject = method("EntityGetPhysicsObject", "GetPhysicsObject")
	EntityGetPhysicsObjectCount = method("EntityGetPhysicsObjectCount", "GetPhysicsObjectCount")
	EntityGetPhysicsObjectNum = method("EntityGetPhysicsObjectNum", "GetPhysicsObjectNum")
	EntityGetNetworkVars = method("EntityGetNetworkVars", "GetNetworkVars")
	EntityGetNWVarTable = method("EntityGetNWVarTable", "GetNWVarTable")
	EntityGetNW2VarTable = method("EntityGetNW2VarTable", "GetNW2VarTable")
	EntitySetNWBool = method("EntitySetNWBool", "SetNWBool")
	EntitySetNWInt = method("EntitySetNWInt", "SetNWInt")
	EntitySetNWFloat = method("EntitySetNWFloat", "SetNWFloat")
	EntitySetNWString = method("EntitySetNWString", "SetNWString")
	EntitySetNWVector = method("EntitySetNWVector", "SetNWVector")
	EntitySetNWAngle = method("EntitySetNWAngle", "SetNWAngle")
	EntitySetNWEntity = method("EntitySetNWEntity", "SetNWEntity")
	EntitySetNW2Var = method("EntitySetNW2Var", "SetNW2Var")
	EntityGetSkin = method("EntityGetSkin", "GetSkin")
	EntitySetSkin = method("EntitySetSkin", "SetSkin")
	EntityGetColor = method("EntityGetColor", "GetColor")
	EntitySetColor = method("EntitySetColor", "SetColor")
	EntityGetEyeTarget = method("EntityGetEyeTarget", "GetEyeTarget")
	EntitySetEyeTarget = method("EntitySetEyeTarget", "SetEyeTarget")
	EntityGetBodyGroups = method("EntityGetBodyGroups", "GetBodyGroups")
	EntityGetBodygroup = method("EntityGetBodygroup", "GetBodygroup")
	EntitySetBodygroup = method("EntitySetBodygroup", "SetBodygroup")
	EntityGetFlexScale = method("EntityGetFlexScale", "GetFlexScale")
	EntitySetFlexScale = method("EntitySetFlexScale", "SetFlexScale")
	EntityGetFlexNum = method("EntityGetFlexNum", "GetFlexNum")
	EntityGetFlexWeight = method("EntityGetFlexWeight", "GetFlexWeight")
	EntitySetFlexWeight = method("EntitySetFlexWeight", "SetFlexWeight")
	EntityGetBoneCount = method("EntityGetBoneCount", "GetBoneCount")
	EntityGetManipulateBonePosition = method("EntityGetManipulateBonePosition", "GetManipulateBonePosition")
	EntityGetManipulateBoneAngles = method("EntityGetManipulateBoneAngles", "GetManipulateBoneAngles")
	EntityGetManipulateBoneScale = method("EntityGetManipulateBoneScale", "GetManipulateBoneScale")
	EntityManipulateBonePosition = method("EntityManipulateBonePosition", "ManipulateBonePosition")
	EntityManipulateBoneAngles = method("EntityManipulateBoneAngles", "ManipulateBoneAngles")
	EntityManipulateBoneScale = method("EntityManipulateBoneScale", "ManipulateBoneScale")
	EntityEntIndex = method("EntityEntIndex", "EntIndex")
	EntityCallOnRemove = method("EntityCallOnRemove", "CallOnRemove")
	EntityIsMarkedForDeletion = method("EntityIsMarkedForDeletion", "IsMarkedForDeletion")
	PhysObjGetPos = PHYSOBJ.GetPos
	PhysObjGetAngles = PHYSOBJ.GetAngles
	PhysObjEnableMotion = opt.PhysObjEnableMotion or PHYSOBJ.EnableMotion
	PhysObjEnableCollisions = PHYSOBJ.EnableCollisions
	PhysObjSetPos = opt.PhysObjSetPos or PHYSOBJ.SetPos
	PhysObjSetAngles = opt.PhysObjSetAngles or PHYSOBJ.SetAngles
	PhysObjWake = opt.PhysObjWake or PHYSOBJ.Wake
end

updateEntityMethods(SMH)
hook.Add("PostSMHLoaded", "smh_offsetter", updateEntityMethods)

local function storeDupeState(offsetter)
	if not IsValid(offsetter) then
		return
	end

	local data = {
		offset = Vector(offsetter:GetX(), offsetter:GetY(), offsetter:GetZ()),
		pairs = {},
	}
	for source in pairs(offsetter.sources or {}) do
		if IsValid(source) then
			local hologram = offsetter.holograms and offsetter.holograms[source]
			local sourceZero = offsetter.zeroPoints and offsetter.zeroPoints[source]
			local hologramZero = IsValid(hologram) and hologram.zeroPoint
			if not IsValid(hologram) or not sourceZero or not hologramZero then
				continue
			end

			local sourcePos, sourceAng = EntityGetPos(source), EntityGetAngles(source)
			local sourceBones = {}
			for bone, pose in pairs(sourceZero.bones) do
				local pos, ang = WorldToLocal(pose.pos, pose.ang, sourcePos, sourceAng)
				sourceBones[bone] = { pos = pos, ang = ang }
			end
			table.insert(data.pairs, {
				source = EntityEntIndex(source),
				hologram = EntityEntIndex(hologram),
				sourceBones = sourceBones,
				hologramBones = table.Copy(hologramZero.bones),
			})
		end
	end

	duplicator.ClearEntityModifier(offsetter, "SMHOffsetter")
	if #data.pairs > 0 then
		duplicator.StoreEntityModifier(offsetter, "SMHOffsetter", data)
	end
end

local function setPhysicsPose(phys, pos, ang)
	PhysObjEnableMotion(phys, false)
	PhysObjEnableCollisions(phys, false)
	PhysObjSetPos(phys, pos, true)
	PhysObjSetAngles(phys, ang)
	PhysObjWake(phys)
end

local function getOriginTransform(origin)
	local phys = EntityGetPhysicsObject(origin)
	local pos, ang = PhysObjGetPos(phys), PhysObjGetAngles(phys)
	local offset = origin.Offset or Vector(origin:GetX(), origin:GetY(), origin:GetZ())
	local offsetPos = LocalToWorld(offset, angle_zero, pos, ang)
	return offsetPos, ang
end

---@param source Entity
---@param hologram Entity
local function copyNetworkVars(source, hologram)
	if isfunction(EntityGetNetworkVars) then
		for key, value in pairs(EntityGetNetworkVars(source) or {}) do
			local setter = hologram["Set" .. key]
			if isfunction(setter) and value ~= nil then
				setter(hologram, value)
			end
		end
	end
end

---@param source Entity
---@param hologram Entity
local function copyNWVars(source, hologram)
	for key, value in pairs(EntityGetNWVarTable(source) or {}) do
		if istable(value) and value.type ~= nil then
			value = value.value
		end

		if isbool(value) then
			EntitySetNWBool(hologram, key, value)
		elseif isnumber(value) then
			if value % 1 == 0 then
				EntitySetNWInt(hologram, key, value)
			else
				EntitySetNWFloat(hologram, key, value)
			end
		elseif isstring(value) then
			EntitySetNWString(hologram, key, value)
		elseif isvector(value) then
			EntitySetNWVector(hologram, key, value)
		elseif isangle(value) then
			EntitySetNWAngle(hologram, key, value)
		elseif isentity(value) then
			EntitySetNWEntity(hologram, key, value)
		end
	end
end

---@param source Entity
---@param hologram Entity
local function copyNW2Vars(source, hologram)
	for key, entry in pairs(EntityGetNW2VarTable(source) or {}) do
		if istable(entry) and entry.type ~= nil and entry.value ~= nil then
			EntitySetNW2Var(hologram, key, entry.value)
		end
	end
end

---@param source Entity
---@param hologram Entity
local function copyVisualState(source, hologram)
	copyNetworkVars(source, hologram)
	copyNWVars(source, hologram)
	copyNW2Vars(source, hologram)

	EntitySetSkin(hologram, EntityGetSkin(source))
	EntitySetColor(hologram, EntityGetColor(source))
	EntitySetEyeTarget(hologram, EntityGetEyeTarget(source))

	for _, bodyGroup in ipairs(EntityGetBodyGroups(source)) do
		EntitySetBodygroup(hologram, bodyGroup.id, EntityGetBodygroup(source, bodyGroup.id))
	end

	EntitySetFlexScale(hologram, EntityGetFlexScale(source))
	for i = 0, math.min(EntityGetFlexNum(source), EntityGetFlexNum(hologram)) - 1 do
		EntitySetFlexWeight(hologram, i, EntityGetFlexWeight(source, i))
	end

	for bone = 0, math.min(EntityGetBoneCount(source), EntityGetBoneCount(hologram)) - 1 do
		EntityManipulateBonePosition(hologram, bone, EntityGetManipulateBonePosition(source, bone))
		EntityManipulateBoneAngles(hologram, bone, EntityGetManipulateBoneAngles(source, bone))
		EntityManipulateBoneScale(hologram, bone, EntityGetManipulateBoneScale(source, bone))
	end
end

---@param newOrigin Entity
---@param source Entity
---@param hologram Entity
local function alignPose(newOrigin, source, hologram)
	local sourcePos, sourceAng = EntityGetPos(source), EntityGetAngles(source)
	local originPos, originAng = getOriginTransform(newOrigin)
	for i = 0, math.min(EntityGetPhysicsObjectCount(source), EntityGetPhysicsObjectCount(hologram)) - 1 do
		local sourcePhys, hologramPhys = EntityGetPhysicsObjectNum(source, i), EntityGetPhysicsObjectNum(hologram, i)
		if not sourcePhys or not hologramPhys or not IsValid(sourcePhys) or not IsValid(hologramPhys) then
			continue
		end
		---@cast sourcePhys PhysObj
		---@cast hologramPhys PhysObj

		local localPos, localAng =
			WorldToLocal(PhysObjGetPos(sourcePhys), PhysObjGetAngles(sourcePhys), sourcePos, sourceAng)
		local alignedPos, alignedAng = LocalToWorld(localPos, localAng, originPos, originAng)
		setPhysicsPose(hologramPhys, alignedPos, alignedAng)
	end
end

local function bindPair(newOrigin, source, hologram)
	newOrigin.sources = newOrigin.sources or {}
	newOrigin.holograms = newOrigin.holograms or {}
	newOrigin.zeroPoints = newOrigin.zeroPoints or {}
	source.offsetters = source.offsetters or {}
	newOrigin.sources[source] = true
	newOrigin.holograms[source] = hologram
	source.offsetters[newOrigin] = true
	newOrigin.OnUpdateOffset = function(self)
		for attachedSource in pairs(self.sources or {}) do
			local attachedHologram = self.holograms and self.holograms[attachedSource]
			if IsValid(attachedSource) and IsValid(attachedHologram) then
				offset(self, attachedSource, attachedHologram)
			end
		end
		storeDupeState(self)
	end

	local function cleanup()
		if IsValid(newOrigin) and not EntityIsMarkedForDeletion(newOrigin) then
			newOrigin.sources[source] = nil
			newOrigin.holograms[source] = nil
			newOrigin.zeroPoints[source] = nil
			if IsValid(source) and source.offsetters then
				source.offsetters[newOrigin] = nil
				if not next(source.offsetters) then
					source.offsetters = nil
				end
			end
			storeDupeState(newOrigin)
		end
	end

	EntityCallOnRemove(source, "smh_offsetter", cleanup)
	EntityCallOnRemove(hologram, "smh_offsetter", cleanup)
end

---@param source Entity
---@param newOrigin Entity
---@param hologram Entity
local function captureZeroPoint(source, newOrigin, hologram)
	local originPos, originAng = getOriginTransform(newOrigin)
	local sourceZero, hologramZero =
		{ bones = {}, origin = newOrigin, hologram = hologram }, { bones = {}, origin = newOrigin }
	for i = 0, math.min(EntityGetPhysicsObjectCount(source), EntityGetPhysicsObjectCount(hologram)) - 1 do
		local sourcePhys, hologramPhys = EntityGetPhysicsObjectNum(source, i), EntityGetPhysicsObjectNum(hologram, i)
		if not sourcePhys or not hologramPhys or not IsValid(sourcePhys) or not IsValid(hologramPhys) then
			continue
		end
		---@cast sourcePhys PhysObj
		---@cast hologramPhys PhysObj

		sourceZero.bones[i] = { pos = PhysObjGetPos(sourcePhys), ang = PhysObjGetAngles(sourcePhys) }
		local baselinePos, baselineAng =
			WorldToLocal(PhysObjGetPos(hologramPhys), PhysObjGetAngles(hologramPhys), originPos, originAng)
		hologramZero.bones[i] = { pos = baselinePos, ang = baselineAng }
	end

	newOrigin.zeroPoints = newOrigin.zeroPoints or {}
	newOrigin.zeroPoints[source] = sourceZero
	hologram.zeroPoint = hologramZero
	bindPair(newOrigin, source, hologram)
	storeDupeState(newOrigin)
end

---Provides a parenting utility before SMH Beta gets it
---
---@class SMHOffsetter
SMHOffsetter = SMHOffsetter or {}
SMHOffsetter.CaptureZeroPoint = captureZeroPoint
SMHOffsetter.StoreDupeState = storeDupeState

local function restoreDupeState(offsetter, data, createdEntities)
	local savedOffset = data.offset
	if isvector(savedOffset) then
		offsetter:SetX(savedOffset.x)
		offsetter:SetY(savedOffset.y)
		offsetter:SetZ(savedOffset.z)
	end

	offsetter.sources = {}
	offsetter.holograms = {}
	offsetter.zeroPoints = {}
	for _, pair in ipairs(data.pairs or {}) do
		local source = createdEntities[pair.source]
		local hologram = createdEntities[pair.hologram]
		if not IsValid(source) or not IsValid(hologram) then
			continue
		end

		local sourcePos, sourceAng = EntityGetPos(source), EntityGetAngles(source)
		local sourceBones = {}
		for bone, pose in pairs(pair.sourceBones or {}) do
			local pos, ang = LocalToWorld(pose.pos, pose.ang, sourcePos, sourceAng)
			sourceBones[bone] = { pos = pos, ang = ang }
		end
		offsetter.zeroPoints[source] = { bones = sourceBones, origin = offsetter, hologram = hologram }
		hologram.zeroPoint = { bones = table.Copy(pair.hologramBones), origin = offsetter }
		captureZeroPoint(source, offsetter, hologram)
		bindPair(offsetter, source, hologram)
	end

	storeDupeState(offsetter)
end

duplicator.RegisterEntityModifier("SMHOffsetter", function(_, offsetter, data)
	local previousPostEntityPaste = offsetter.PostEntityPaste
	offsetter.PostEntityPaste = function(self, player, pastedEntity, createdEntities)
		if isfunction(previousPostEntityPaste) then
			previousPostEntityPaste(self, player, pastedEntity, createdEntities)
		end
		restoreDupeState(self, data, createdEntities)
	end
end)

util.AddNetworkString("smh_offsetter_request_list")
util.AddNetworkString("smh_offsetter_send_list")
util.AddNetworkString("smh_offsetter_recapture")

local function sendAttachedPairs(player)
	local pairsToSend = {}
	for _, offsetter in ipairs(ents.FindByClass("smh_offsetter")) do
		for source in pairs(offsetter.sources or {}) do
			local hologram = offsetter.holograms and offsetter.holograms[source]
			if IsValid(source) and IsValid(hologram) then
				table.insert(pairsToSend, { offsetter = offsetter, source = source, hologram = hologram })
			end
		end
	end

	net.Start("smh_offsetter_send_list")
	net.WriteUInt(#pairsToSend, 16)
	for _, pair in ipairs(pairsToSend) do
		net.WriteEntity(pair.offsetter)
		net.WriteEntity(pair.source)
		net.WriteEntity(pair.hologram)
	end
	net.Send(player)
end

SMHOffsetter.SendAttachedPairs = sendAttachedPairs

net.Receive("smh_offsetter_request_list", function(_, player)
	sendAttachedPairs(player)
end)

net.Receive("smh_offsetter_recapture", function(_, player)
	local source = net.ReadEntity()
	local offsetter = net.ReadEntity()
	if not IsValid(source) or not IsValid(offsetter) then
		return
	end

	local hologram = IsValid(offsetter) and offsetter.holograms and offsetter.holograms[source]
	if not IsValid(offsetter) or not offsetter.sources or not offsetter.sources[source] or not IsValid(hologram) then
		return
	end

	captureZeroPoint(source, offsetter, hologram)
	sendAttachedPairs(player)
end)

---@param newOrigin Entity The entity that acts as our origin point
---@param source Entity The entity whose per-physbone motion is applied
---@param hologram Entity The entity receiving the offset pose
offset = function(newOrigin, source, hologram)
	copyVisualState(source, hologram)

	local sourceZero = newOrigin.zeroPoints and newOrigin.zeroPoints[source]
	local hologramZero = hologram.zeroPoint
	if
		not sourceZero
		or sourceZero.origin ~= newOrigin
		or sourceZero.hologram ~= hologram
		or not hologramZero
		or hologramZero.origin ~= newOrigin
	then
		alignPose(newOrigin, source, hologram)
		captureZeroPoint(source, newOrigin, hologram)
		return
	end

	local originPos, originAng = getOriginTransform(newOrigin)
	for i = 0, math.min(EntityGetPhysicsObjectCount(source), EntityGetPhysicsObjectCount(hologram)) - 1 do
		local sourcePhys, hologramPhys = EntityGetPhysicsObjectNum(source, i), EntityGetPhysicsObjectNum(hologram, i)
		local sourceBaseline, hologramBaseline = sourceZero.bones[i], hologramZero.bones[i]
		if
			not sourcePhys
			or not hologramPhys
			or not IsValid(sourcePhys)
			or not IsValid(hologramPhys)
			or not sourceBaseline
			or not hologramBaseline
		then
			continue
		end

		local deltaPos, deltaAng = WorldToLocal(
			PhysObjGetPos(sourcePhys),
			PhysObjGetAngles(sourcePhys),
			sourceBaseline.pos,
			sourceBaseline.ang
		)
		local baselinePos, baselineAng = LocalToWorld(hologramBaseline.pos, hologramBaseline.ang, originPos, originAng)
		local targetPos, targetAng = LocalToWorld(deltaPos, deltaAng, baselinePos, baselineAng)
		setPhysicsPose(hologramPhys, targetPos, targetAng)
	end
end

local function process(entity)
	local holograms = entity.holograms
	local offsetters = entity.offsetters
	if istable(offsetters) then
		for offsetter in pairs(offsetters) do
			if not IsValid(offsetter) then
				offsetters[offsetter] = nil
				continue
			end
			local hologram = offsetter.holograms and offsetter.holograms[entity]
			if IsValid(hologram) then
				---@cast hologram Entity
				offset(offsetter, entity, hologram)
			elseif offsetter.sources then
				offsetter.sources[entity] = nil
				offsetter.holograms[entity] = nil
				if offsetter.zeroPoints then
					offsetter.zeroPoints[entity] = nil
				end
				offsetters[offsetter] = nil
				storeDupeState(offsetter)
			end
		end
	elseif istable(holograms) then
		local sources = entity.sources
		for source in pairs(sources or {}) do
			local hologram = holograms[source]
			if IsValid(source) and IsValid(hologram) then
				offset(entity, source, hologram)
			end
		end
	end
end
-- This sets the frame position immediately after an entity moves
hook.Add("SMH_PostFrameEntity", "SMH_OffsetEntity", process)
