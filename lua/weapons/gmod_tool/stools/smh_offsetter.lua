local TOOL = TOOL

TOOL.Category = "Stop Motion Helper"
TOOL.Name = "#tool.smh_offsetter.name"
TOOL.Command = nil
TOOL.ConfigName = ""

local firstReload = true
function TOOL:Think()
	if CLIENT and firstReload then
		self:RebuildControlPanel()
		firstReload = false
	end
end

local down = -vector_up
local function createOffsetter(source, player)
	local mins, maxs = source:WorldSpaceAABB()
	local spawnPos = Vector((mins.x + maxs.x) * 0.5, (mins.y + maxs.y) * 0.5, mins.z)
	local trace = util.TraceLine({
		start = Vector(spawnPos.x, spawnPos.y, maxs.z + 32768),
		endpos = Vector(spawnPos.x, spawnPos.y, mins.z - 32768),
		filter = { source, player },
		mask = MASK_SOLID_BRUSHONLY,
	})
	if trace.Hit and not trace.HitSky then
		spawnPos.z = math.max(spawnPos.z, trace.HitPos.z)
	end
	local spawnAng = (player:EyePos() - spawnPos):Angle()
	spawnAng.x = 0
	spawnAng.z = 0

	local offsetter = ents.Create("smh_offsetter")
	if not IsValid(offsetter) then
		return nil
	end

	offsetter:SetPos(spawnPos)
	offsetter:SetAngles(spawnAng)
	offsetter:Spawn()
	offsetter:Activate()

	local phys = offsetter:GetPhysicsObject()
	if IsValid(phys) then
		phys:EnableMotion(false)
		phys:Sleep()
	end

	return offsetter
end

---Remove the outgoing arc from the entity
---@param tr table|TraceResult
---@return boolean
function TOOL:Reload(tr)
	local entity = tr.Entity
	if not IsValid(entity) or entity:IsPlayer() then
		return false
	end

	if CLIENT then
		return true
	end

	local offsetters = SMHOffsetter.Data.GetOffsetters(entity)
	for i = 1, #offsetters do
		local offsetter = offsetters[i]
		if not IsValid(offsetter) then
			continue
		end
		local hologram = SMHOffsetter.Data.GetHologram(offsetter, entity)
		if IsValid(hologram) then
			hologram:Remove()
		end

		SMHOffsetter.Data.RemovePair(offsetter, entity)
		SMHOffsetter.StoreDupeState(offsetter)
	end

	return true
end

---Select an entity to target, and then select another entity to set its arc it.
---@param tr table|TraceResult
---@return boolean
function TOOL:LeftClick(tr)
	local entity = tr.Entity
	if not IsValid(entity) or entity:IsPlayer() then
		return false
	end
	if SERVER and not util.IsValidPhysicsObject(entity, tr.PhysicsBone) then
		return false
	end

	if CLIENT then
		return false
	end

	local weapon = self:GetWeapon()
	if self:GetStage() == 0 then
		self:SetStage(1)
		weapon:SetNW2Entity("smh_offsetter_selection", entity)
	elseif self:GetStage() == 1 and IsValid(weapon:GetNW2Entity("smh_offsetter_selection")) then
		local source = weapon:GetNW2Entity("smh_offsetter_selection")
		local offsetter = entity
		local player = self:GetOwner()
		if entity == source then
			offsetter = createOffsetter(source, player)
			if not IsValid(offsetter) then
				self:SetStage(0)
				return false
			end

			undo.Create("smh_offsetter")
			undo.AddEntity(offsetter)
			undo.SetPlayer(player)
			undo.Finish()
		elseif offsetter:GetClass() ~= "smh_offsetter" then
			return false
		end

		local hologram = SMHOffsetter.Data.GetHologram(offsetter, source)
		if not IsValid(hologram) then
			local package
			if source.EntityMods then
				package = table.Copy(source.EntityMods["SMHPackage"])
				source.EntityMods["SMHPackage"] = nil
			end
			local entTable = duplicator.Copy(source)
			local paste = duplicator.Paste(player, entTable.Entities, entTable.Constraints)
			if source.EntityMods and package then
				source.EntityMods["SMHPackage"] = package
			end
			_, hologram = next(paste)

			undo.Create("smh_offsetter")
			undo.AddEntity(hologram)
			undo.SetPlayer(player)
			undo.Finish()
		end

		SMHOffsetter.CaptureZeroPoint(source, offsetter, hologram)
		SMHOffsetter.SendAttachedPairs(player)
		self:SetStage(0)
	end

	return true
end

---Select an entity to view its data, if it has any
---@param tr table|TraceResult
---@return boolean
function TOOL:RightClick(tr)
	local entity = tr.Entity
	if not IsValid(entity) then
		return false
	end

	if CLIENT then
		return true
	end

	return true
end

if SERVER then
	return
end

TOOL:BuildConVarList()

---@class SMHOffsetterList: DListView
local activeSourceList

local function requestSourceList()
	net.Start("smh_offsetter_request_list")
	net.SendToServer()
end

net.Receive("smh_offsetter_send_list", function()
	local count = net.ReadUInt(16)
	local rows = {}
	for i = 1, count do
		rows[i] = {
			offsetter = net.ReadEntity(),
			source = net.ReadEntity(),
			hologram = net.ReadEntity(),
		}
	end

	if not IsValid(activeSourceList) then
		return
	end

	activeSourceList:Clear()
	for _, row in ipairs(rows) do
		local function label(entity)
			if not IsValid(entity) then
				return language.GetPhrase("tool.smh_offsetter.removed")
			end
			return string.format("%d: %s", entity:EntIndex(), entity:GetModel() or entity:GetClass())
		end

		local line = activeSourceList:AddLine(label(row.offsetter), label(row.source), label(row.hologram))
		line.Source = row.source
		line.Offsetter = row.offsetter
		line.Hologram = row.hologram
	end
end)

local function toolEquipped(pl)
	local weap = pl:GetActiveWeapon()
	local tool = pl:GetTool()
	---@cast tool TOOL
	return IsValid(weap) and weap:GetClass() == "gmod_tool" and tool and tool:GetMode() == TOOL.Mode
end

function TOOL.BuildCPanel(panel)
	activeSourceList = vgui.Create("DListView", panel)
	activeSourceList:SetTall(180)
	activeSourceList:AddColumn("#tool.smh_offsetter.list_offsetter")
	activeSourceList:AddColumn("#tool.smh_offsetter.list_source")
	activeSourceList:AddColumn("#tool.smh_offsetter.list_hologram")
	panel:AddItem(activeSourceList)

	local refreshButton = panel:Button("#tool.smh_offsetter.refresh")
	refreshButton.DoClick = requestSourceList

	local recaptureButton = panel:Button("#tool.smh_offsetter.recapture")
	recaptureButton.DoClick = function()
		local selected = activeSourceList:GetSelectedLine()
		local line = selected and activeSourceList:GetLine(selected)
		if not line or not IsValid(line.Source) or not IsValid(line.Offsetter) then
			return
		end

		net.Start("smh_offsetter_recapture")
		net.WriteEntity(line.Source)
		net.WriteEntity(line.Offsetter)
		net.SendToServer()
	end

	local unlinkButton = panel:Button("#tool.smh_offsetter.unlink")
	unlinkButton.DoClick = function()
		local selected = activeSourceList:GetSelectedLine()
		local line = selected and activeSourceList:GetLine(selected)
		if not line or not IsValid(line.Source) or not IsValid(line.Offsetter) then
			return
		end

		net.Start("smh_offsetter_unlink")
		net.WriteEntity(line.Source)
		net.WriteEntity(line.Offsetter)
		net.SendToServer()
	end

	requestSourceList()

	local pl = LocalPlayer()
	local red = Color(255, 0, 0)
	local green = Color(0, 255, 0)
	local blue = Color(0, 0, 255)
	local function drawHalos()
		if not toolEquipped(pl) then
			return
		end

		local selected = activeSourceList:GetSelectedLine()
		local line = selected and activeSourceList:GetLine(selected)
		if not line or not IsValid(line.Source) or not IsValid(line.Hologram) or not IsValid(line.Offsetter) then
			return
		end

		halo.Add({ line.Source }, green)
		halo.Add({ line.Hologram }, red)
		halo.Add({ line.Offsetter }, blue)

		local pos1, pos2, pos3 = line.Source:GetPos(), line.Hologram:GetPos(), line.Offsetter:GetPos()

		cam.Start3D()
		render.DrawLine(pos1, pos2, green, true)
		render.DrawLine(pos1, pos3, blue, true)
		render.DrawLine(pos2, pos3, blue, true)
		cam.End3D()
	end
	hook.Remove("PreDrawHalos", "smh_offsetter_halos")
	hook.Add("PreDrawHalos", "smh_offsetter_halos", drawHalos)
end

TOOL.Information = {
	{ name = "left", stage = 0 },
	{ name = "left_1", stage = 1 },
	{ name = "right", stage = 0 },
	{ name = "reload" },
}
