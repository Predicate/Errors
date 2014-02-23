local ldb = LibStub:GetLibrary("LibDataBroker-1.1")

local f, editbox, buttons
local current, showErr, dobj
local errs = {}
local function initFrames()
	f = CreateFrame("ScrollFrame", nil, UIParent)
	f:Hide()
	f:SetBackdrop({ bgFile = [[Interface/BUTTONS/White8x8]] })
	f:SetPoint("CENTER")
	f:SetHeight(200)
	f:SetWidth(500)
	f:SetBackdropColor(0, 0, 0, 1)
	f:EnableMouseWheel(true)
	f:SetScript("OnMouseWheel", function(self, delta)
		self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - delta * 30)))
	end)
	editbox = CreateFrame("EditBox", nil, f)
	editbox:SetPoint("TOP")
	editbox:SetWidth(f:GetWidth())
	editbox:SetFont([[Fonts/ARIALN.TTF]], 12)
	editbox:SetAutoFocus(false)
	editbox:SetMultiLine(true)
	editbox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
	editbox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	editbox:SetText("|cff00ff00No errors yet!|r")
	editbox:SetHyperlinksEnabled(true)
	editbox:SetScript("OnHyperlinkEnter", function(self, link)
		GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
		GameTooltip:ClearLines()
		local name, title, notes = GetAddOnInfo(link:match("^addon:(.*)$"))
		GameTooltip:AddLine(title or name)
		if notes then GameTooltip:AddLine(notes, 1, 1, 1, true) end
		GameTooltip:Show()
	end)
	editbox:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() end)

	f:SetScrollChild(editbox)
	f:SetScript("OnVerticalScroll", function(self, offset)
		editbox:ClearAllPoints()
		editbox:SetPoint("TOP", 0, offset)
	end)
	
	buttons = {
		First = CreateFrame("Button", nil, f),
		Prev = CreateFrame("Button", nil, f),
		Next = CreateFrame("Button", nil, f),
		Last = CreateFrame("Button", nil, f),
	}

	for n, b in pairs(buttons) do
		b:SetHeight(20)
		b:SetWidth(36)
		b:SetNormalTexture([[Interface/BUTTONS/GREENGRAD64]])
		b:SetDisabledTexture([[Interface/BUTTONS/RedGrad64]])
		local fs = b:CreateFontString()
		fs:SetFont([[Fonts/ARIALN.TTF]], 16)
		fs:SetShadowOffset(1,-1)
		b:SetFontString(fs)
		b:SetText(n)
		b:Disable()
	end

	buttons.First:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 3)
	buttons.Prev:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 40, 3)
	buttons.Next:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -40, 3)
	buttons.Last:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 0, 3)

	buttons.First:SetScript("OnClick", function() showErr(1) end)
	buttons.Prev:SetScript("OnClick", function() showErr(current-1) end)
	buttons.Next:SetScript("OnClick", function() showErr(current+1) end)
	buttons.Last:SetScript("OnClick", function() showErr(#errs) end)

	showErr(#errs)
end


local errstrings = {
	ERROR = "|cffff0000Error:|r",
	ADDON_ACTION_FORBIDDEN = "|cffff0000Action forbidden:|r",
	LUA_WARNING = "|cffffff00Lua warning:|r",
	LUA_WARNING_ERROR = "|cffff0000Lua warning:|r",
}

local function updateButtons()
	buttons.First:Enable()
	buttons.Prev:Enable()
	buttons.Next:Enable()
	buttons.Last:Enable()
	if current == 1 then
		buttons.First:Disable()
		buttons.Prev:Disable()
	end
	if current == #errs then
		buttons.Next:Disable()
		buttons.Last:Disable()
	end
end

local function stackformat(s)
	if s == "" then return s end
	return s:gsub("([^\n]+): ([^\n]+)", function(location, str)
		if location == "[C]" then
			return "|cff0000ff"..location..":|r "..str
		else
			local file, line = location:match("^([^\n]+):(%d+)$")
			if file:match("%[.*%]$") then
				return "|cffff8080" ..file.."|r:"..line..": "..str
			elseif file:find("^%.%.%.") then
				return file..":"..line..": "..str
			else
				local name, filename = file:match([[^Interface\(.+)\(.-)$]])
				local addon = name:match([[^AddOns\(.*)$]])
				if addon then
					name = (addon:find("^Blizzard_") and "|cff0080ff" or "|cffffff00") .. "|Haddon:"..addon.."|h["..addon.."]|h|r"
				else
					name = "|cff0080ff["..name.."]|r"
				end
				return name.." |cffff8000"..filename.."#"..line..":|r "..str
			end
		end
	end)
end

local lastseen = 0
function showErr(index)
	local err = errs[index]
	if err then
		local t = {}
		t[#t+1] = "|cffa0a0a0[Event #".. index .." @ "..err.timestamp.."]|r "
		t[#t+1] = errstrings[err.type]
		t[#t+1] = (err.type == "ERROR") and stackformat(err.msg) or err.msg
		t[#t+1] = "\n|cffff0000Stack trace:|r"
		t[#t+1] = stackformat(err.stack)
		t[#t+1] = "\n|cffff0000Locals:|r"
		t[#t+1] = err.locals
		editbox:SetText(table.concat(t,"\n"))
		f:SetVerticalScroll(0)
		current = index
		updateButtons()
		lastseen = math.max(current, lastseen)
		dobj.text = #errs - lastseen .. "/" .. #errs
		if lastseen == #errs then
			dobj.icon = [[Interface/HELPFRAME/HelpIcon-ReportAbuse]]
		end
	end
end

dobj = ldb:NewDataObject("Errors", {
	type = "data source",
	text = "0",
	icon = [[Interface/HELPFRAME/HelpIcon-ReportAbuse]],
	OnClick = function()
		if not f then initFrames() end
		if f:IsShown() then
			f:Hide()
		else
			f:Show()
		end
	end,
})

local function newErr(type, msg, stack, locals)
	errs[#errs+1] = {
		timestamp = date("%I:%M:%S %p"),
		type = type,
		msg = msg,
		stack = stack,
		locals = locals,
	}
	dobj.icon = [[Interface/DialogFrame/UI-Dialog-Icon-AlertNew]]
	dobj.text = #errs - lastseen .. "/" .. #errs
	if f then
		if current then
			updateButtons()
		else
			showErr(#errs)
		end
	end
end

seterrorhandler(function(msg)
	newErr("ERROR", msg, debugstack(4), debuglocals(4))
end)

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
eventFrame:RegisterEvent("LUA_WARNING")
eventFrame:SetScript("OnEvent", function(_, event, arg1, arg2)
	local msg
	if event == "ADDON_ACTION_FORBIDDEN" then
		msg = arg1 .. " tainted call of " .. arg2 .. (InCombatLockdown() and " in combat" or "")
	elseif event == "LUA_WARNING" then
		if arg1 == 0 then event = "LUA_WARNING_ERROR" end
		msg = arg2
	end
	newErr(event, msg, debugstack(3), debuglocals(3))
end)