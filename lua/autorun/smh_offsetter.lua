if CLIENT then
	return
end

local offset

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
			local sourceZero = source.zeroPoint
			local hologramZero = IsValid(hologram) and hologram.zeroPoint
			if not IsValid(hologram) or not sourceZero or not hologramZero then
				continue
			end

			local sourcePos, sourceAng = source:GetPos(), source:GetAngles()
			local sourceBones = {}
			for bone, pose in pairs(sourceZero.bones) do
				local pos, ang = WorldToLocal(pose.pos, pose.ang, sourcePos, sourceAng)
				sourceBones[bone] = { pos = pos, ang = ang }
			end
			table.insert(data.pairs, {
				source = source:EntIndex(),
				hologram = hologram:EntIndex(),
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
	phys:EnableMotion(false)
	phys:EnableCollisions(false)
	phys:SetPos(pos, true)
	phys:SetAngles(ang)
	phys:Wake()
end

local function getOriginTransform(origin)
	local pos, ang = origin:GetPhysicsObject():GetPos(), origin:GetPhysicsObject():GetAngles()
	local offset = origin.Offset or Vector(origin:GetX(), origin:GetY(), origin:GetZ())
	local offsetPos = LocalToWorld(offset, angle_zero, pos, ang)
	return offsetPos, ang
end

---@param source Entity
---@param hologram Entity
local function copyNetworkVars(source, hologram)
	if isfunction(source.GetNetworkVars) then
		for key, value in pairs(source:GetNetworkVars() or {}) do
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
	for key, value in pairs(source:GetNWVarTable() or {}) do
		if istable(value) and value.type ~= nil then
			value = value.value
		end

		if isbool(value) then
			hologram:SetNWBool(key, value)
		elseif isnumber(value) then
			if value % 1 == 0 then
				hologram:SetNWInt(key, value)
			else
				hologram:SetNWFloat(key, value)
			end
		elseif isstring(value) then
			hologram:SetNWString(key, value)
		elseif isvector(value) then
			hologram:SetNWVector(key, value)
		elseif isangle(value) then
			hologram:SetNWAngle(key, value)
		elseif isentity(value) then
			hologram:SetNWEntity(key, value)
		end
	end
end

---@param source Entity
---@param hologram Entity
local function copyNW2Vars(source, hologram)
	for key, entry in pairs(source:GetNW2VarTable() or {}) do
		if istable(entry) and entry.type ~= nil and entry.value ~= nil then
			hologram:SetNW2Var(key, entry.value)
		end
	end
end

---@param source Entity
---@param hologram Entity
local function copyVisualState(source, hologram)
	copyNetworkVars(source, hologram)
	copyNWVars(source, hologram)
	copyNW2Vars(source, hologram)

	hologram:SetSkin(source:GetSkin())
	hologram:SetColor(source:GetColor())
	hologram:SetEyeTarget(source:GetEyeTarget())

	for _, bodyGroup in ipairs(source:GetBodyGroups()) do
		hologram:SetBodygroup(bodyGroup.id, source:GetBodygroup(bodyGroup.id))
	end

	hologram:SetFlexScale(source:GetFlexScale())
	for i = 0, math.min(source:GetFlexNum(), hologram:GetFlexNum()) - 1 do
		hologram:SetFlexWeight(i, source:GetFlexWeight(i))
	end

	for bone = 0, math.min(source:GetBoneCount(), hologram:GetBoneCount()) - 1 do
		hologram:ManipulateBonePosition(bone, source:GetManipulateBonePosition(bone))
		hologram:ManipulateBoneAngles(bone, source:GetManipulateBoneAngles(bone))
		hologram:ManipulateBoneScale(bone, source:GetManipulateBoneScale(bone))
	end
end

---@param newOrigin Entity
---@param source Entity
---@param hologram Entity
local function alignPose(newOrigin, source, hologram)
	local sourcePos, sourceAng = source:GetPos(), source:GetAngles()
	local originPos, originAng = getOriginTransform(newOrigin)
	for i = 0, math.min(source:GetPhysicsObjectCount(), hologram:GetPhysicsObjectCount()) - 1 do
		local sourcePhys, hologramPhys = source:GetPhysicsObjectNum(i), hologram:GetPhysicsObjectNum(i)
		if not IsValid(sourcePhys) or not IsValid(hologramPhys) then
			continue
		end

		local localPos, localAng = WorldToLocal(sourcePhys:GetPos(), sourcePhys:GetAngles(), sourcePos, sourceAng)
		local alignedPos, alignedAng = LocalToWorld(localPos, localAng, originPos, originAng)
		setPhysicsPose(hologramPhys, alignedPos, alignedAng)
	end
end

local function bindPair(newOrigin, source, hologram)
	newOrigin.sources = newOrigin.sources or {}
	newOrigin.holograms = newOrigin.holograms or {}
	newOrigin.sources[source] = true
	newOrigin.holograms[source] = hologram
	source.offsetter = newOrigin
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
		if IsValid(newOrigin) and not newOrigin:IsMarkedForDeletion() then
			newOrigin.sources[source] = nil
			newOrigin.holograms[source] = nil
			storeDupeState(newOrigin)
		end
		if IsValid(source) then
			source.offsetter = nil
			source.zeroPoint = nil
		end
	end

	source:CallOnRemove("smh_offsetter", cleanup)
	hologram:CallOnRemove("smh_offsetter", cleanup)
end

---@param source Entity
---@param newOrigin smh_offsetter
---@param hologram Entity
local function captureZeroPoint(source, newOrigin, hologram)
	local originPos, originAng = getOriginTransform(newOrigin)
	local sourceZero, hologramZero =
		{ bones = {}, origin = newOrigin, hologram = hologram }, { bones = {}, origin = newOrigin }
	for i = 0, math.min(source:GetPhysicsObjectCount(), hologram:GetPhysicsObjectCount()) - 1 do
		local sourcePhys, hologramPhys = source:GetPhysicsObjectNum(i), hologram:GetPhysicsObjectNum(i)
		if not IsValid(sourcePhys) or not IsValid(hologramPhys) then
			continue
		end

		sourceZero.bones[i] = { pos = sourcePhys:GetPos(), ang = sourcePhys:GetAngles() }
		local baselinePos, baselineAng =
			WorldToLocal(hologramPhys:GetPos(), hologramPhys:GetAngles(), originPos, originAng)
		hologramZero.bones[i] = { pos = baselinePos, ang = baselineAng }
	end

	source.zeroPoint = sourceZero
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
	for _, pair in ipairs(data.pairs or {}) do
		local source = createdEntities[pair.source]
		local hologram = createdEntities[pair.hologram]
		if not IsValid(source) or not IsValid(hologram) then
			continue
		end

		local sourcePos, sourceAng = source:GetPos(), source:GetAngles()
		local sourceBones = {}
		for bone, pose in pairs(pair.sourceBones or {}) do
			local pos, ang = LocalToWorld(pose.pos, pose.ang, sourcePos, sourceAng)
			sourceBones[bone] = { pos = pos, ang = ang }
		end
		source.zeroPoint = { bones = sourceBones, origin = offsetter, hologram = hologram }
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
	if not IsValid(source) then
		return
	end

	local offsetter = source.offsetter
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

	local sourceZero = source.zeroPoint
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
	for i = 0, math.min(source:GetPhysicsObjectCount(), hologram:GetPhysicsObjectCount()) - 1 do
		local sourcePhys, hologramPhys = source:GetPhysicsObjectNum(i), hologram:GetPhysicsObjectNum(i)
		local sourceBaseline, hologramBaseline = sourceZero.bones[i], hologramZero.bones[i]
		if not IsValid(sourcePhys) or not IsValid(hologramPhys) or not sourceBaseline or not hologramBaseline then
			continue
		end

		local deltaPos, deltaAng =
			WorldToLocal(sourcePhys:GetPos(), sourcePhys:GetAngles(), sourceBaseline.pos, sourceBaseline.ang)
		local baselinePos, baselineAng = LocalToWorld(hologramBaseline.pos, hologramBaseline.ang, originPos, originAng)
		local targetPos, targetAng = LocalToWorld(deltaPos, deltaAng, baselinePos, baselineAng)
		setPhysicsPose(hologramPhys, targetPos, targetAng)
	end
end

local function process(entity)
	local offsetter = entity.offsetter
	local holograms = entity.holograms
	if IsValid(offsetter) then
		local hologram = offsetter.holograms and offsetter.holograms[entity]
		if IsValid(hologram) then
			---@cast hologram Entity
			offset(offsetter, entity, hologram)
		elseif offsetter.sources then
			offsetter.sources[entity] = nil
			entity.offsetter = nil
		end
	elseif istable(holograms) then
		local sources = entity.sources
		for source, _ in pairs(sources) do
			local hologram = holograms[source]
			offset(entity, source, hologram)
		end
	end
end
-- This sets the frame position immediately after an entity moves
hook.Add("SMH_PostFrameEntity", "SMH_OffsetEntity", process)
