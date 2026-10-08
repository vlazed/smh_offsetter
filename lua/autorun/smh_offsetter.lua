if CLIENT then
	return
end

if not SMHOffsetter or not SMHOffsetter.Data then
	include("autorun/smh_offsetter_data.lua")
end

local offset
local Data = SMHOffsetter.Data
local DataAddPair = Data.AddPair
local DataClearOffsetter = Data.ClearOffsetter
local DataGetHologram = Data.GetHologram
local DataGetHologramZeroPoint = Data.GetHologramZeroPoint
local DataGetOffsetters = Data.GetOffsetters
local DataGetSources = Data.GetSources
local DataGetSourceZeroPoint = Data.GetSourceZeroPoint
local DataHasPair = Data.HasPair
local DataRemovePair = Data.RemovePair
local DataSetZeroPoints = Data.SetZeroPoints
local DataGetOffset = Data.GetOffset
local DataSetOffset = Data.SetOffset
local DataGetClassVars = Data.GetClassVars

local ENTITY = FindMetaTable("Entity")
local PHYSOBJ = FindMetaTable("PhysObj")
local opt = SMH.Optimizations
---@type fun(entity: Entity): Vector
local EntityGetPos
---@type fun(entity: Entity): Angle
local EntityGetAngles
local EntityGetPhysicsObject
local EntityGetPhysicsObjectCount, EntityGetPhysicsObjectNum
local EntityGetNWVarTable, EntityGetNW2VarTable, EntitySetNWBool, EntitySetNWInt
local EntitySetNWFloat, EntitySetNWString, EntitySetNWVector, EntitySetNWAngle
local EntitySetNWEntity, EntitySetNW2Var, EntityGetSkin, EntitySetSkin
local EntityGetColor, EntitySetColor, EntityGetEyeTarget, EntitySetEyeTarget
local EntityGetBodyGroups, EntityGetBodygroup, EntitySetBodygroup
local EntityGetFlexScale, EntitySetFlexScale, EntityGetFlexNum, EntityGetFlexWeight, EntitySetFlexWeight
local EntityGetBoneCount, EntityGetManipulateBonePosition, EntityGetManipulateBoneAngles
local EntityGetManipulateBoneScale, EntityManipulateBonePosition, EntityManipulateBoneAngles
local EntityManipulateBoneScale, EntityEntIndex, EntityCallOnRemove, EntityIsMarkedForDeletion
local EntityIsValid, PhysObjIsValid
local EntitySetCollisionGroup

local PhysObjGetPos, PhysObjGetAngles, PhysObjEnableMotion, PhysObjEnableCollisions
local PhysObjSetPos, PhysObjSetAngles, PhysObjWake
local function updateEntityMethods(smh)
	opt = smh and smh.Optimizations or SMH.Optimizations
	local function entityMethod(optimizedName, entityName)
		return opt[optimizedName] or ENTITY[entityName]
	end

	local function physObjMethod(optimizedName, entityName)
		return opt[optimizedName] or PHYSOBJ[entityName]
	end

	EntityGetPos = ENTITY.GetPos
	EntityGetAngles = ENTITY.GetAngles
	EntitySetCollisionGroup = ENTITY.SetCollisionGroup
	EntityGetPhysicsObject = entityMethod("EntityGetPhysicsObject", "GetPhysicsObject")
	EntityGetPhysicsObjectCount = entityMethod("EntityGetPhysicsObjectCount", "GetPhysicsObjectCount")
	EntityGetPhysicsObjectNum = entityMethod("EntityGetPhysicsObjectNum", "GetPhysicsObjectNum")
	EntityGetNWVarTable = entityMethod("EntityGetNWVarTable", "GetNWVarTable")
	EntityGetNW2VarTable = entityMethod("EntityGetNW2VarTable", "GetNW2VarTable")
	EntitySetNWBool = entityMethod("EntitySetNWBool", "SetNWBool")
	EntitySetNWInt = entityMethod("EntitySetNWInt", "SetNWInt")
	EntitySetNWFloat = entityMethod("EntitySetNWFloat", "SetNWFloat")
	EntitySetNWString = entityMethod("EntitySetNWString", "SetNWString")
	EntitySetNWVector = entityMethod("EntitySetNWVector", "SetNWVector")
	EntitySetNWAngle = entityMethod("EntitySetNWAngle", "SetNWAngle")
	EntitySetNWEntity = entityMethod("EntitySetNWEntity", "SetNWEntity")
	EntitySetNW2Var = entityMethod("EntitySetNW2Var", "SetNW2Var")
	EntityGetSkin = entityMethod("EntityGetSkin", "GetSkin")
	EntitySetSkin = entityMethod("EntitySetSkin", "SetSkin")
	EntityGetColor = entityMethod("EntityGetColor", "GetColor")
	EntitySetColor = entityMethod("EntitySetColor", "SetColor")
	EntityGetEyeTarget = entityMethod("EntityGetEyeTarget", "GetEyeTarget")
	EntitySetEyeTarget = entityMethod("EntitySetEyeTarget", "SetEyeTarget")
	EntityGetBodyGroups = entityMethod("EntityGetBodyGroups", "GetBodyGroups")
	EntityGetBodygroup = entityMethod("EntityGetBodygroup", "GetBodygroup")
	EntitySetBodygroup = entityMethod("EntitySetBodygroup", "SetBodygroup")
	EntityGetFlexScale = entityMethod("EntityGetFlexScale", "GetFlexScale")
	EntitySetFlexScale = entityMethod("EntitySetFlexScale", "SetFlexScale")
	EntityGetFlexNum = entityMethod("EntityGetFlexNum", "GetFlexNum")
	EntityGetFlexWeight = entityMethod("EntityGetFlexWeight", "GetFlexWeight")
	EntitySetFlexWeight = entityMethod("EntitySetFlexWeight", "SetFlexWeight")
	EntityGetBoneCount = entityMethod("EntityGetBoneCount", "GetBoneCount")
	EntityGetManipulateBonePosition = entityMethod("EntityGetManipulateBonePosition", "GetManipulateBonePosition")
	EntityGetManipulateBoneAngles = entityMethod("EntityGetManipulateBoneAngles", "GetManipulateBoneAngles")
	EntityGetManipulateBoneScale = entityMethod("EntityGetManipulateBoneScale", "GetManipulateBoneScale")
	EntityManipulateBonePosition = entityMethod("EntityManipulateBonePosition", "ManipulateBonePosition")
	EntityManipulateBoneAngles = entityMethod("EntityManipulateBoneAngles", "ManipulateBoneAngles")
	EntityManipulateBoneScale = entityMethod("EntityManipulateBoneScale", "ManipulateBoneScale")
	EntityEntIndex = entityMethod("EntityEntIndex", "EntIndex")
	EntityCallOnRemove = entityMethod("EntityCallOnRemove", "CallOnRemove")
	EntityIsMarkedForDeletion = entityMethod("EntityIsMarkedForDeletion", "IsMarkedForDeletion")
	EntityIsValid = ENTITY.IsValid
	PhysObjGetPos = PHYSOBJ.GetPos
	PhysObjGetAngles = PHYSOBJ.GetAngles
	PhysObjEnableMotion = physObjMethod("PhysObjEnableMotion", "EnableMotion")
	PhysObjEnableCollisions = PHYSOBJ.EnableCollisions
	PhysObjSetPos = physObjMethod("PhysObjSetPos", "SetPos")
	PhysObjSetAngles = physObjMethod("PhysObjSetAngles", "SetAngles")
	PhysObjWake = physObjMethod("PhysObjWake", "Wake")
	PhysObjIsValid = PHYSOBJ.IsValid
end

updateEntityMethods(SMH)
hook.Add("PostSMHLoaded", "smh_offsetter", updateEntityMethods)

local function storeDupeState(offsetter)
	if not IsValid(offsetter) then
		return
	end

	local data = {
		offset = Vector(0, 0, 0),
		pairs = {},
	}
	local sources = DataGetSources(offsetter)
	for i = 1, #sources do
		local source = sources[i]
		if IsValid(source) then
			local hologram = DataGetHologram(offsetter, source)
			local sourceZero = DataGetSourceZeroPoint(offsetter, source)
			local hologramZero = DataGetHologramZeroPoint(offsetter, source)
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
	-- PhysObjEnableCollisions(phys, false)
	PhysObjSetPos(phys, pos, true)
	PhysObjSetAngles(phys, ang)
	PhysObjWake(phys)
end

---@param origin smh_offsetter
local function getOriginTransform(origin)
	local phys = EntityGetPhysicsObject(origin)
	local pos, ang = PhysObjGetPos(phys), PhysObjGetAngles(phys)
	local offset = DataGetOffset(origin)
	local offsetPos = LocalToWorld(offset, angle_zero, pos, ang)
	return offsetPos, ang
end

---@param source Entity
---@param hologram Entity
local function copyNetworkVars(source, hologram)
	local classVars = DataGetClassVars(source)
	if classVars.sent then
		for _, name in ipairs(classVars.names) do
			local getter = source["Get" .. name]
			local setter = hologram["Set" .. name]
			if isfunction(getter) and isfunction(setter) then
				local value = getter(source)
				if value == nil then
					continue
				end
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
	DataAddPair(newOrigin, source, hologram)
	EntityCallOnRemove(newOrigin, "smh_offsetter_data", function()
		DataClearOffsetter(newOrigin)
	end)
	newOrigin.OnUpdateOffset = function(self)
		local sources = DataGetSources(self)
		for i = 1, #sources do
			local attachedSource = sources[i]
			local attachedHologram = DataGetHologram(self, attachedSource)
			if IsValid(attachedSource) and IsValid(attachedHologram) then
				offset(self, attachedSource, attachedHologram)
			end
		end
		storeDupeState(self)
	end

	local function cleanup()
		if IsValid(newOrigin) and not EntityIsMarkedForDeletion(newOrigin) then
			DataRemovePair(newOrigin, source)
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
	EntitySetCollisionGroup(hologram, COLLISION_GROUP_WORLD)
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

	DataSetZeroPoints(newOrigin, source, sourceZero, hologramZero)
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
		DataSetZeroPoints(
			offsetter,
			source,
			{ bones = sourceBones, origin = offsetter, hologram = hologram },
			{ bones = table.Copy(pair.hologramBones), origin = offsetter }
		)
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
util.AddNetworkString("smh_offsetter_unlink")

local function sendAttachedPairs(player)
	local pairsToSend = {}
	for _, offsetter in ipairs(ents.FindByClass("smh_offsetter")) do
		local sources = DataGetSources(offsetter)
		for i = 1, #sources do
			local source = sources[i]
			local hologram = DataGetHologram(offsetter, source)
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

	local hologram = IsValid(offsetter) and DataGetHologram(offsetter, source)
	if not IsValid(offsetter) or not DataHasPair(offsetter, source) or not IsValid(hologram) then
		return
	end

	captureZeroPoint(source, offsetter, hologram)
	sendAttachedPairs(player)
end)

net.Receive("smh_offsetter_unlink", function(_, player)
	local source = net.ReadEntity()
	local offsetter = net.ReadEntity()
	if not IsValid(source) or not IsValid(offsetter) or not DataHasPair(offsetter, source) then
		return
	end

	DataRemovePair(offsetter, source)
	storeDupeState(offsetter)
	sendAttachedPairs(player)
end)

---@param newOrigin Entity The entity that acts as our origin point
---@param source Entity The entity whose per-physbone motion is applied
---@param hologram Entity The entity receiving the offset pose
offset = function(newOrigin, source, hologram)
	copyVisualState(source, hologram)

	local sourceZero = DataGetSourceZeroPoint(newOrigin, source)
	local hologramZero = DataGetHologramZeroPoint(newOrigin, source)
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
	---@cast sourceZero table
	---@cast hologramZero table

	local originPos, originAng = getOriginTransform(newOrigin)
	local sourceBones, hologramBones = sourceZero.bones or {}, hologramZero.bones or {}
	for i = 0, math.min(EntityGetPhysicsObjectCount(source), EntityGetPhysicsObjectCount(hologram)) - 1 do
		local sourcePhys, hologramPhys = EntityGetPhysicsObjectNum(source, i), EntityGetPhysicsObjectNum(hologram, i)
		local sourceBaseline, hologramBaseline = sourceBones[i], hologramBones[i]
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

---@param entities Entity[]
local function process(entities)
	for _, entity in ipairs(entities) do
		local offsetters = DataGetOffsetters(entity)
		local staleOffsetters = {}
		for i = 1, #offsetters do
			local offsetter = offsetters[i]
			local hologram = EntityIsValid(offsetter) and DataGetHologram(offsetter, entity)
			if EntityIsValid(offsetter) and EntityIsValid(hologram) then
				---@cast hologram Entity
				offset(offsetter, entity, hologram)
			else
				table.insert(staleOffsetters, offsetter)
			end
		end
		for i = 1, #staleOffsetters do
			local offsetter = staleOffsetters[i]
			DataRemovePair(offsetter, entity)
			if EntityIsValid(offsetter) then
				storeDupeState(offsetter)
			end
		end

		local sources = DataGetSources(entity)
		for i = 1, #sources do
			local source = sources[i]
			local hologram = DataGetHologram(entity, source)
			if EntityIsValid(source) and EntityIsValid(hologram) then
				offset(entity, source, hologram)
			end
		end
	end
end
-- This sets the frame position immediately after an entity moves
hook.Add("SMH_PostFrameEntity", "SMH_OffsetEntity", process)
