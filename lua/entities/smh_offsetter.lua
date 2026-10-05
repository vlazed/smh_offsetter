AddCSLuaFile()

---@class smh_offsetter: ENT
---@field Offset Vector
local ENT = ENT

ENT.Type = "anim"
ENT.Base = "base_edit"

ENT.PrintName = "Offsetter"
ENT.Author = "vlazed"

ENT.Category = "Stop Motion Helper"
ENT.Editable = true
ENT.Spawnable = false

function ENT:OnUpdateOffset(x, y, z) end

local mapping = {
	["X"] = 1,
	["Y"] = 2,
	["Z"] = 3,
}

function ENT:SetupDataTables()
	self:NetworkVar("Float", "X", { KeyName = "x", Edit = { type = "Float", min = -1000, max = 1000 } })
	self:NetworkVar("Float", "Y", { KeyName = "y", Edit = { type = "Float", min = -1000, max = 1000 } })
	self:NetworkVar("Float", "Z", { KeyName = "z", Edit = { type = "Float", min = -1000, max = 1000 } })

	local function offset(self, str, old, new)
		local offset = SMHOffsetter.Data.GetOffset(self)
		if not offset then
			offset = Vector(self:GetX(), self:GetY(), self:GetZ())
			SMHOffsetter.Data.SetOffset(self, offset)
		end
		offset[mapping[str]] = tonumber(new)
		self:OnUpdateOffset(offset)
	end
	self:NetworkVarNotify("X", offset)
	self:NetworkVarNotify("Y", offset)
	self:NetworkVarNotify("Z", offset)
end

function ENT:Initialize()
	local Radius = 6
	local mins = Vector(1, 1, 1) * Radius * -0.5
	local maxs = Vector(1, 1, 1) * Radius * 0.5

	if SERVER then
		self:SetModel("models/maxofs2d/cube_tool.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetBodygroup(1, 1)

		local phys = self:GetPhysicsObject()
		if phys:IsValid() then
			phys:EnableDrag(false)
			phys:Wake()
		end

		self:DrawShadow(false)
		self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	end

	self:SetCollisionBounds(mins, maxs)
end
