local function setPhysicsPose(phys, pos, ang)
	phys:EnableMotion(false)
	phys:EnableCollisions(false)
	phys:SetPos(pos, true)
	phys:SetAngles(ang)
	phys:Wake()
end

local function getOriginTransform(origin)
	local pos, ang = origin:GetPos(), origin:GetAngles()
	local offset = origin.Offset or Vector(origin:GetX(), origin:GetY(), origin:GetZ())
	local offsetPos = LocalToWorld(offset, angle_zero, pos, ang)
	return offsetPos, ang
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

---@param source Entity
---@param newOrigin Entity
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
end

SMHOffsetter = SMHOffsetter or {}
SMHOffsetter.CaptureZeroPoint = captureZeroPoint

---@param newOrigin Entity The entity that acts as our origin point
---@param source Entity The entity whose per-physbone motion is applied
---@param hologram Entity The entity receiving the offset pose
local function offset(newOrigin, source, hologram)
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

	if IsValid(offsetter) then
		local holograms = offsetter.holograms
		local hologram = holograms and holograms[entity]

		if IsValid(hologram) then
			---@cast hologram Entity

			offset(offsetter, entity, hologram)
		elseif holograms then
			holograms[entity] = nil
			if offsetter.sources then
				offsetter.sources[entity] = nil
			end
			entity.offsetter = nil
		end
	end
end
-- This sets the frame position immediately after an entity moves
hook.Add("SMH_PostFrameEntity", "SMH_OffsetEntity", process)
