TOOL.Category = "Stop Motion Helper"
TOOL.Name = "Offsetter"
TOOL.Command = nil
TOOL.ConfigName = ""

local firstReload = true
function TOOL:Think()
	if CLIENT and firstReload then
		self:RebuildControlPanel()
		firstReload = false
	end
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

	local offsetter = entity.offsetter
	if IsValid(offsetter) then
		local holograms = offsetter.holograms
		local hologram = holograms and holograms[entity]
		if IsValid(hologram) then
			hologram:Remove()
		end

		if offsetter.sources then
			offsetter.sources[entity] = nil
		end
		if holograms then
			holograms[entity] = nil
		end

		entity.offsetter = nil
		entity.zeroPoint = nil
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
		if offsetter:GetClass() ~= "smh_offsetter" then
			return false
		end

		local previousOffsetter = source.offsetter
		if IsValid(previousOffsetter) and previousOffsetter ~= offsetter then
			local previousHolograms = previousOffsetter.holograms
			local previousHologram = previousHolograms and previousHolograms[source]
			if IsValid(previousHologram) then
				previousHologram:Remove()
			end
			if previousOffsetter.sources then
				previousOffsetter.sources[source] = nil
			end
			if previousHolograms then
				previousHolograms[source] = nil
			end
			SMHOffsetter.StoreDupeState(previousOffsetter)
		end

		offsetter.sources = offsetter.sources or {}
		offsetter.holograms = offsetter.holograms or {}
		source.offsetter = offsetter
		offsetter.sources[source] = true
		local hologram = offsetter.holograms[source]
		if not IsValid(hologram) then
			local player = self:GetOwner()
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
			offsetter.holograms[source] = hologram

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
				return "Removed"
			end
			return string.format("%d: %s", entity:EntIndex(), entity:GetModel() or entity:GetClass())
		end

		local line = activeSourceList:AddLine(label(row.offsetter), label(row.source), label(row.hologram))
		line.Source = row.source
		line.Hologram = row.hologram
	end
end)

function TOOL.BuildCPanel(panel)
	activeSourceList = vgui.Create("DListView", panel)
	activeSourceList:SetTall(180)
	activeSourceList:AddColumn("Offsetter")
	activeSourceList:AddColumn("Source")
	activeSourceList:AddColumn("Hologram")
	panel:AddItem(activeSourceList)

	local refreshButton = panel:Button("Refresh sources")
	refreshButton.DoClick = requestSourceList

	local recaptureButton = panel:Button("Recapture selected zero point")
	recaptureButton.DoClick = function()
		local selected = activeSourceList:GetSelectedLine()
		local line = selected and activeSourceList:GetLine(selected)
		if not line or not IsValid(line.Source) then
			return
		end
		print("recapture")

		net.Start("smh_offsetter_recapture")
		net.WriteEntity(line.Source)
		net.SendToServer()
	end

	requestSourceList()

	local red = Color(255, 0, 0)
	local green = Color(0, 255, 0)
	local function drawHalos()
		local selected = activeSourceList:GetSelectedLine()
		local line = selected and activeSourceList:GetLine(selected)
		if not line or not IsValid(line.Source) or not IsValid(line.Hologram) then
			return
		end

		halo.Add({ line.Source }, green)
		halo.Add({ line.Hologram }, red)
	end
	hook.Add("PreDrawHalos", "smh_offsetter_halos", drawHalos)
end

TOOL.Information = {
	{ name = "left", stage = 0 },
	{ name = "left_1", stage = 1 },
	{ name = "right", stage = 0 },
	{ name = "reload" },
}
