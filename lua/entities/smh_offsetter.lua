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

ENT.WantsTranslucency = true

function ENT:OnUpdateOffset() end
function ENT:OnUpdateName() end

local mapping = {
	["X"] = 1,
	["Y"] = 2,
	["Z"] = 3,
}

function ENT:SetupDataTables()
	self:NetworkVar("Float", "X", { KeyName = "x", Edit = { type = "Float", min = -1000, max = 1000 } })
	self:NetworkVar("Float", "Y", { KeyName = "y", Edit = { type = "Float", min = -1000, max = 1000 } })
	self:NetworkVar("Float", "Z", { KeyName = "z", Edit = { type = "Float", min = -1000, max = 1000 } })

	self:NetworkVar(
		"String",
		"OffsetterName",
		{ KeyName = "offsettername", Edit = { type = "String", title = "Name" } }
	)

	local function offset(self, str, old, new)
		local offset = SMHOffsetter.Data.GetOffset(self)
		if not offset then
			offset = Vector(self:GetX(), self:GetY(), self:GetZ())
			SMHOffsetter.Data.SetOffset(self, offset)
		end
		offset[mapping[str]] = tonumber(new)
		self:OnUpdateOffset(offset)
	end
	local function name(self, str, old, new)
		self:OnUpdateName(new)
	end
	self:NetworkVarNotify("X", offset)
	self:NetworkVarNotify("Y", offset)
	self:NetworkVarNotify("Z", offset)
	self:NetworkVarNotify("OffsetterName", name)
end

function ENT:Initialize()
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
end

function ENT:Draw(flags)
	self:DrawTranslucent(flags)
end

local xColor = Color(200, 32, 32, 192)
local yColor = Color(32, 200, 32, 192)
local zColor = Color(32, 32, 200, 192)
local ballColor = Color(128, 128, 255, 32)
local length = 10
local function drawArrow(pos, forward, right, arrowLength, color, headWidth)
	local shaftLength = arrowLength * 0.9
	local shaftWidth = arrowLength * 0.03
	headWidth = headWidth or arrowLength * 0.1
	local shaftEnd = pos + forward * shaftLength
	local tip = pos + forward * arrowLength
	local baseLeft = shaftEnd - right * headWidth
	local baseRight = shaftEnd + right * headWidth
	local center = shaftEnd

	render.CullMode(MATERIAL_CULLMODE_NONE)
	render.DrawQuad(
		pos - right * shaftWidth,
		shaftEnd - right * shaftWidth,
		shaftEnd + right * shaftWidth,
		pos + right * shaftWidth,
		color
	)
	render.DrawQuad(baseLeft, tip, baseRight, center, color)
end

if CLIENT then
	surface.CreateFont("SMHOffsetterFont", {
		font = "Arial",
		size = 72,
	})
end

function ENT:DrawTranslucent(flags)
	local wep = LocalPlayer():GetActiveWeapon()
	if not IsValid(wep) then
		return
	end

	local weapon_name = wep:GetClass()
	if weapon_name ~= "weapon_physgun" and weapon_name ~= "gmod_tool" then
		return
	end

	local pos = self:GetPos()
	local forward = self:GetForward()
	local left = -self:GetRight()
	local up = self:GetUp()

	local halfLength = length * 0.5
	render.SetColorMaterialIgnoreZ()
	render.DrawSphere(pos, halfLength * 0.5, 12, 12, ballColor)
	drawArrow(pos - left * halfLength, left, up, length, yColor, 0)
	drawArrow(pos - up * halfLength, up, forward, length, zColor, 0)
	drawArrow(pos - forward * halfLength, forward, self:GetRight(), length, xColor)

	local name = self:GetOffsetterName()
	local angle = (pos - EyePos()):GetNormalized():Angle()
	-- angle[1] = 0
	angle[3] = 0
	angle:RotateAroundAxis(angle:Up(), -90)
	angle:RotateAroundAxis(angle:Forward(), 90)
	cam.Start3D2D(pos, angle, 0.05)

	surface.SetFont("SMHOffsetterFont")
	local tW, tH = surface.GetTextSize(name)

	cam.IgnoreZ(true)
	draw.SimpleTextOutlined(
		name,
		"SMHOffsetterFont",
		tW,
		-tH,
		color_white,
		TEXT_ALIGN_RIGHT,
		TEXT_ALIGN_CENTER,
		1,
		color_black
	)
	cam.IgnoreZ(false)
	cam.End3D2D()

	-- self:DrawModel(flags)
end
