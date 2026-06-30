local addonName, ns = ...

local WC = {}
ns.DuncedXHair = WC
_G.DuncedXHair = WC

local defaults = {
    enabled = true,
    locked = true,
    showWhileUnlocked = true,
    visibility = "Always",
    phaseRulesEnabled = false,
    shape = "Cross",
    alpha = 1,
    thickness = 2,
    inner_length = 30,
    border_size = 3,
    fill = 0,
    lockHorizontal = false,
    class_colored = true,
    customR = 1,
    customG = 1,
    customB = 1,
    combatTimingEnabled = false,
    combatShowAfter = 0,
    combatHideAfter = 0,
    combatEndDelay = 0,
    position = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
    },
    rules = {},
}

WC.defaults = defaults

local visibilityLabels = {
    Always = "Always",
    Combat = "In Combat",
    Instance = "In Instance",
    CombatAndInstance = "In Combat + In Instance",
    CombatOrInstance = "In Combat or In Instance",
}

WC.visibilityLabels = visibilityLabels

local shapeLabels = {
    Cross = "Cross",
    ReversedCross = "Reversed Cross",
    Circle = "Circle",
    Square = "Square",
}

WC.shapeLabels = shapeLabels

local shapeOrder = { "Cross", "ReversedCross", "Circle", "Square" }
local shapeSettingKeys = { "alpha", "thickness", "inner_length", "width", "height", "border_size", "fill" }
local shapeSettingDefaults = {
    Cross = {
        alpha = 1,
        thickness = 2,
        inner_length = 30,
        width = 30,
        height = 30,
        border_size = 3,
        fill = 0,
    },
    ReversedCross = {
        alpha = 1,
        thickness = 2,
        inner_length = 30,
        width = 30,
        height = 30,
        border_size = 3,
        fill = 0,
    },
    Circle = {
        alpha = 1,
        thickness = 2,
        inner_length = 30,
        width = 30,
        height = 30,
        border_size = 3,
        fill = 0,
    },
    Square = {
        alpha = 1,
        thickness = 2,
        inner_length = 30,
        width = 30,
        height = 30,
        border_size = 3,
        fill = 0,
    },
}

local function copyDefaults(source, target)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            copyDefaults(value, target[key])
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$") or ""
end

local function clamp(value, minimum, maximum)
    value = tonumber(value)
    if not value then
        return minimum
    end
    if value < minimum then
        return minimum
    end
    if value > maximum then
        return maximum
    end
    return value
end

local function round(value)
    return math.floor((tonumber(value) or 0) + 0.5)
end

local function countTableValues(values)
    local count = 0
    for _ in pairs(values or {}) do
        count = count + 1
    end
    return count
end

local function getClassColor()
    local _, class = UnitClass("player")
    local color = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class]) or RAID_CLASS_COLORS[class]
    if color then
        return color.r, color.g, color.b
    end
    return 1, 1, 1
end

local function getBossModName(mod)
    if type(mod) ~= "table" then
        return mod and tostring(mod) or nil
    end

    if mod.localization and mod.localization.general and mod.localization.general.name then
        return mod.localization.general.name
    end
    if mod.displayName then
        return mod.displayName
    end
    if mod.name then
        return mod.name
    end
    if mod.moduleName then
        return mod.moduleName
    end
    if mod.id then
        return tostring(mod.id)
    end

    return nil
end

local function getBossModEncounterID(mod)
    if type(mod) ~= "table" then
        return nil
    end

    return mod.engageId or mod.encounterId or mod.journalId
end

function WC:Print(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff19ff59DuncedXHair:|r " .. tostring(message))
    end
end

function WC:Trim(value)
    return trim(value)
end

function WC:NormalizeBossName(value)
    value = trim(value):lower()
    value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    value = value:gsub("[%s%p%c]+", "")
    return value
end

function WC:RuleKey(value)
    value = trim(value)
    local id = value:match("^id:%s*(%d+)$")
    if id then
        return "id:" .. id
    end
    return self:NormalizeBossName(value)
end

function WC:NormalizeStage(value)
    if value == nil or value == "" then
        return nil
    end

    local text = trim(value):lower():gsub("^p", "")
    local numberText = text:match("(%d+%.?%d*)")
    local number = tonumber(numberText)
    if number then
        if number == math.floor(number) then
            return tostring(math.floor(number))
        end
        return tostring(number)
    end

    return text ~= "" and text or nil
end

function WC:ParsePhaseList(value)
    local phases = {}
    for phase in tostring(value or ""):gmatch("%d+%.?%d*") do
        phase = self:NormalizeStage(phase)
        if phase then
            phases[phase] = true
        end
    end
    return phases, countTableValues(phases)
end

function WC:FormatPhaseList(phases)
    local values = {}
    for phase in pairs(phases or {}) do
        values[#values + 1] = phase
    end

    table.sort(values, function(left, right)
        return (tonumber(left) or left) < (tonumber(right) or right)
    end)

    for index, phase in ipairs(values) do
        values[index] = "P" .. tostring(phase)
    end

    return table.concat(values, ", ")
end

function WC:SetRule(bossName, phaseText)
    if not self.db then
        return false, "Addon is not initialized yet."
    end

    local label = trim(bossName)
    local key = self:RuleKey(label)
    if key == "" then
        return false, "Enter a boss name or id:encounterID."
    end

    local phases, count = self:ParsePhaseList(phaseText)
    if count == 0 then
        return false, "Enter one or more phases, for example 2,4."
    end

    self.db.rules[key] = {
        label = label,
        phases = phases,
    }
    self.db.phaseRulesEnabled = true

    self:RefreshVisibility()
    if self.RefreshOptionsPanel then
        self:RefreshOptionsPanel()
    end

    return true
end

function WC:DeleteRule(bossName)
    if not self.db then
        return false, "Addon is not initialized yet."
    end

    local key = self:RuleKey(bossName)
    if key == "" or not self.db.rules[key] then
        return false, "That boss rule was not found."
    end

    self.db.rules[key] = nil
    self:RefreshVisibility()
    if self.RefreshOptionsPanel then
        self:RefreshOptionsPanel()
    end

    return true
end

function WC:GetMatchingRule()
    if not self.db or not self.db.rules then
        return nil
    end

    if self.currentEncounterID then
        local idKey = "id:" .. tostring(self.currentEncounterID)
        if self.db.rules[idKey] then
            return self.db.rules[idKey], idKey
        end
    end

    local names = {
        self.currentEncounterName,
        self.currentBossModName,
        self.manualBossName,
    }

    for _, name in ipairs(names) do
        local normalized = self:NormalizeBossName(name)
        if normalized ~= "" then
            if self.db.rules[normalized] then
                return self.db.rules[normalized], normalized
            end

            for key, rule in pairs(self.db.rules) do
                if key ~= "" and key:sub(1, 3) ~= "id:" then
                    if normalized:find(key, 1, true) or key:find(normalized, 1, true) then
                        return rule, key
                    end
                end
            end
        end
    end

    return nil
end

function WC:CreateCrosshair()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "DuncedXHairFrame", UIParent)
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(900)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")

    frame:SetScript("OnDragStart", function(crosshair)
        if self.db and not self.db.locked then
            crosshair:StartMoving()
        end
    end)

    frame:SetScript("OnDragStop", function(crosshair)
        crosshair:StopMovingOrSizing()
        self:SavePosition()
    end)

    frame:SetScript("OnMouseUp", function(crosshair)
        crosshair:StopMovingOrSizing()
        self:SavePosition()
    end)

    frame:SetScript("OnHide", function(crosshair)
        crosshair:StopMovingOrSizing()
    end)

    self.frame = frame
    self.linePools = {}
    self.allLines = {}
    self.rectPools = {}
    self.allRects = {}

    local function makeBar(name)
        local bar = CreateFrame("Frame", name, frame)
        bar:EnableMouse(false)
        local texture = bar:CreateTexture(nil, "BACKGROUND")
        texture:SetAllPoints()
        bar.tex = texture
        self.allRects[#self.allRects + 1] = bar
        return bar
    end

    self.bars = {
        outerVertical = makeBar("DuncedXHairOuterVertical"),
        outerHorizontal = makeBar("DuncedXHairOuterHorizontal"),
        innerVertical = makeBar("DuncedXHairInnerVertical"),
        innerHorizontal = makeBar("DuncedXHairInnerHorizontal"),
    }
end

function WC:NormalizeShape(value)
    value = trim(value):lower():gsub("[%s_%-]+", "")
    if value == "cross" or value == "plus" or value == "xhair" then
        return "Cross"
    elseif value == "reversedcross" or value == "reversecross" or value == "hollowcross" or value == "outlinecross" or value == "reversed" or value == "reverse" then
        return "ReversedCross"
    elseif value == "dot" or value == "filledcircle" then
        return "Circle", 1
    elseif value == "circle" or value == "ring" or value == "round" then
        return "Circle"
    elseif value == "square" or value == "box" then
        return "Square"
    end
    return nil
end

function WC:GetDrawColor()
    if self.db.class_colored then
        return getClassColor()
    end
    return self.db.customR or 1, self.db.customG or 1, self.db.customB or 1
end

function WC:HideShapeElements()
    for _, bar in pairs(self.bars or {}) do
        bar:Hide()
    end
    for _, rect in ipairs(self.allRects or {}) do
        rect:Hide()
    end
    for _, line in ipairs(self.allLines or {}) do
        line:Hide()
    end
end

function WC:GetLine(poolName, index)
    if not self.frame or not self.frame.CreateLine then
        return nil
    end

    self.linePools[poolName] = self.linePools[poolName] or {}
    local pool = self.linePools[poolName]
    if not pool[index] then
        local line = self.frame:CreateLine(nil, "BACKGROUND")
        pool[index] = line
        self.allLines[#self.allLines + 1] = line
    end
    return pool[index]
end

function WC:SetLine(poolName, index, x1, y1, x2, y2, thickness, r, g, b, a, subLevel)
    local line = self:GetLine(poolName, index)
    if not line then
        return
    end

    if line.SetDrawLayer then
        line:SetDrawLayer("BACKGROUND", subLevel or 0)
    end
    line:SetStartPoint("CENTER", self.frame, x1, y1)
    line:SetEndPoint("CENTER", self.frame, x2, y2)
    line:SetThickness(thickness)
    line:SetColorTexture(r, g, b, a or 1)
    line:Show()
end

function WC:GetRect(poolName, index)
    if not self.frame then
        return nil
    end

    self.rectPools[poolName] = self.rectPools[poolName] or {}
    local pool = self.rectPools[poolName]
    if not pool[index] then
        local rect = CreateFrame("Frame", nil, self.frame)
        rect:EnableMouse(false)
        local texture = rect:CreateTexture(nil, "BACKGROUND")
        texture:SetAllPoints()
        rect.tex = texture
        pool[index] = rect
        self.allRects[#self.allRects + 1] = rect
    end
    return pool[index]
end

function WC:SetRect(poolName, index, width, height, x, y, r, g, b, a, subLevel)
    local rect = self:GetRect(poolName, index)
    if not rect then
        return
    end

    width = math.max(0.5, width)
    height = math.max(0.5, height)
    rect:ClearAllPoints()
    rect:SetSize(width, height)
    rect:SetPoint("CENTER", self.frame, "CENTER", x or 0, y or 0)
    rect.tex:SetDrawLayer("BACKGROUND", subLevel or 0)
    rect.tex:SetColorTexture(r, g, b, a or 1)
    rect:Show()
end

function WC:ApplyCrossShape(thickness, innerWidth, innerHeight, borderSize, r, g, b)
    innerWidth = math.max(4, innerWidth or defaults.inner_length)
    innerHeight = math.max(4, innerHeight or innerWidth)

    local frameWidth = math.max(innerWidth + borderSize, thickness + borderSize) + 4
    local frameHeight = math.max(innerHeight + borderSize, thickness + borderSize) + 4
    local outerThickness = thickness + borderSize
    local outerWidth = innerWidth + borderSize
    local outerHeight = innerHeight + borderSize

    self.frame:SetSize(frameWidth, frameHeight)

    self.bars.outerVertical:ClearAllPoints()
    self.bars.outerVertical:SetSize(outerThickness, outerHeight)
    self.bars.outerVertical:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
    self.bars.outerVertical.tex:SetDrawLayer("BACKGROUND", 0)
    self.bars.outerVertical.tex:SetColorTexture(0, 0, 0, 1)
    self.bars.outerVertical:Show()

    self.bars.outerHorizontal:ClearAllPoints()
    self.bars.outerHorizontal:SetSize(outerWidth, outerThickness)
    self.bars.outerHorizontal:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
    self.bars.outerHorizontal.tex:SetDrawLayer("BACKGROUND", 0)
    self.bars.outerHorizontal.tex:SetColorTexture(0, 0, 0, 1)
    self.bars.outerHorizontal:Show()

    self.bars.innerVertical:ClearAllPoints()
    self.bars.innerVertical:SetSize(thickness, innerHeight)
    self.bars.innerVertical:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
    self.bars.innerVertical.tex:SetDrawLayer("BACKGROUND", 1)
    self.bars.innerVertical.tex:SetColorTexture(r, g, b, 1)
    self.bars.innerVertical:Show()

    self.bars.innerHorizontal:ClearAllPoints()
    self.bars.innerHorizontal:SetSize(innerWidth, thickness)
    self.bars.innerHorizontal:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
    self.bars.innerHorizontal.tex:SetDrawLayer("BACKGROUND", 1)
    self.bars.innerHorizontal.tex:SetColorTexture(r, g, b, 1)
    self.bars.innerHorizontal:Show()
end

function WC:GetReversedCrossArmThickness(width, height, stroke)
    local minimumDimension = math.max(4, math.min(width or defaults.inner_length, height or width or defaults.inner_length))
    local armThickness = math.max(minimumDimension * 0.38, (stroke or 1) * 2)
    return math.min(armThickness, minimumDimension)
end

function WC:DrawReversedCross(poolName, outerWidth, outerHeight, stroke, armThickness, r, g, b, a, subLevel)
    outerWidth = math.max(4, outerWidth or defaults.inner_length)
    outerHeight = math.max(4, outerHeight or outerWidth)

    armThickness = math.min(math.max(1, armThickness or self:GetReversedCrossArmThickness(outerWidth, outerHeight, stroke)), math.min(outerWidth, outerHeight))
    stroke = math.min(math.max(1, stroke or 1), math.max(1, armThickness / 2))

    local halfWidth = outerWidth / 2
    local halfHeight = outerHeight / 2
    local armHalf = armThickness / 2
    local verticalLength = math.max(0, halfHeight - armHalf)
    local horizontalLength = math.max(0, halfWidth - armHalf)
    local index = 0

    local function rect(width, height, x, y)
        index = index + 1
        self:SetRect(poolName, index, width, height, x, y, r, g, b, a, subLevel)
    end

    if verticalLength > 0 then
        local sideY = armHalf + (verticalLength / 2)
        rect(armThickness, stroke, 0, halfHeight - (stroke / 2))
        rect(stroke, verticalLength, -armHalf + (stroke / 2), sideY)
        rect(stroke, verticalLength, armHalf - (stroke / 2), sideY)

        sideY = -armHalf - (verticalLength / 2)
        rect(armThickness, stroke, 0, -halfHeight + (stroke / 2))
        rect(stroke, verticalLength, -armHalf + (stroke / 2), sideY)
        rect(stroke, verticalLength, armHalf - (stroke / 2), sideY)
    end

    if horizontalLength > 0 then
        local leftX = -armHalf - (horizontalLength / 2)
        local rightX = armHalf + (horizontalLength / 2)
        local topY = armHalf - (stroke / 2)
        local bottomY = -armHalf + (stroke / 2)

        rect(horizontalLength, stroke, leftX, topY)
        rect(horizontalLength, stroke, leftX, bottomY)
        rect(stroke, armThickness, -halfWidth + (stroke / 2), 0)

        rect(horizontalLength, stroke, rightX, topY)
        rect(horizontalLength, stroke, rightX, bottomY)
        rect(stroke, armThickness, halfWidth - (stroke / 2), 0)
    end
end

function WC:ApplyReversedCrossShape(thickness, innerWidth, innerHeight, borderSize, r, g, b)
    innerWidth = math.max(4, innerWidth or defaults.inner_length)
    innerHeight = math.max(4, innerHeight or innerWidth)

    local frameWidth = innerWidth + (borderSize * 2) + 4
    local frameHeight = innerHeight + (borderSize * 2) + 4
    local stroke = math.max(1, thickness or 1)
    local armThickness = self:GetReversedCrossArmThickness(innerWidth, innerHeight, stroke)

    self.frame:SetSize(frameWidth, frameHeight)

    if borderSize > 0 then
        self:DrawReversedCross("reversedCrossBorder", innerWidth + (borderSize * 2), innerHeight + (borderSize * 2), stroke + (borderSize * 2), armThickness + (borderSize * 2), 0, 0, 0, 1, 0)
    end
    self:DrawReversedCross("reversedCrossFill", innerWidth, innerHeight, stroke, armThickness, r, g, b, 1, 1)
end

function WC:GetFillHoleRadius(radius, thickness, fill)
    fill = clamp(fill, 0, 1)
    local outlineThickness = math.min(radius, math.max(0, thickness or 0))
    local outlineHoleRadius = math.max(0, radius - outlineThickness)
    return outlineHoleRadius * (1 - fill)
end

function WC:DrawCircleBand(poolName, radius, holeRadius, r, g, b, a, subLevel)
    if not self.frame or not self.frame.CreateLine or radius <= 0 then
        return
    end

    holeRadius = math.max(0, math.min(holeRadius or 0, radius))
    local diameter = radius * 2
    local segments = math.min(256, math.max(48, math.ceil(diameter)))
    local step = diameter / segments
    local lineThickness = math.max(1, step + 0.35)
    local lineIndex = 0

    for row = 1, segments do
        local y = -radius + ((row - 0.5) * step)
        local outerHalf = math.sqrt(math.max(0, (radius * radius) - (y * y)))

        if holeRadius > 0 and math.abs(y) < holeRadius then
            local innerHalf = math.sqrt(math.max(0, (holeRadius * holeRadius) - (y * y)))
            if outerHalf > innerHalf then
                lineIndex = lineIndex + 1
                self:SetLine(poolName, lineIndex, -outerHalf, y, -innerHalf, y, lineThickness, r, g, b, a, subLevel)
                lineIndex = lineIndex + 1
                self:SetLine(poolName, lineIndex, innerHalf, y, outerHalf, y, lineThickness, r, g, b, a, subLevel)
            end
        else
            lineIndex = lineIndex + 1
            self:SetLine(poolName, lineIndex, -outerHalf, y, outerHalf, y, lineThickness, r, g, b, a, subLevel)
        end
    end
end

function WC:ApplyCircleShape(thickness, innerLength, borderSize, fill, r, g, b)
    local radius = innerLength / 2
    local outerRadius = radius + borderSize
    local holeRadius = self:GetFillHoleRadius(radius, thickness, fill)
    local borderHoleRadius = math.max(0, holeRadius - borderSize)
    local frameSize = (outerRadius * 2) + 4

    self.frame:SetSize(frameSize, frameSize)
    self:DrawCircleBand("circleBorder", outerRadius, borderHoleRadius, 0, 0, 0, 1, 0)
    self:DrawCircleBand("circleFill", radius, holeRadius, r, g, b, 1, 1)
end

function WC:DrawSquareBand(poolName, outerHalf, holeHalf, r, g, b, a, subLevel)
    outerHalf = math.max(0, outerHalf)
    holeHalf = math.max(0, math.min(holeHalf or 0, outerHalf))

    local outerSize = outerHalf * 2
    if holeHalf <= 0 then
        self:SetRect(poolName, 1, outerSize, outerSize, 0, 0, r, g, b, a, subLevel)
        return
    end

    local band = outerHalf - holeHalf
    local centerOffset = holeHalf + (band / 2)
    self:SetRect(poolName, 1, outerSize, band, 0, centerOffset, r, g, b, a, subLevel)
    self:SetRect(poolName, 2, outerSize, band, 0, -centerOffset, r, g, b, a, subLevel)
    self:SetRect(poolName, 3, band, holeHalf * 2, -centerOffset, 0, r, g, b, a, subLevel)
    self:SetRect(poolName, 4, band, holeHalf * 2, centerOffset, 0, r, g, b, a, subLevel)
end

function WC:DrawRectBand(poolName, outerWidth, outerHeight, holeWidth, holeHeight, r, g, b, a, subLevel)
    outerWidth = math.max(0, outerWidth)
    outerHeight = math.max(0, outerHeight)
    holeWidth = math.max(0, math.min(holeWidth or 0, outerWidth))
    holeHeight = math.max(0, math.min(holeHeight or 0, outerHeight))

    if holeWidth <= 0 or holeHeight <= 0 then
        self:SetRect(poolName, 1, outerWidth, outerHeight, 0, 0, r, g, b, a, subLevel)
        return
    end

    local topHeight = (outerHeight - holeHeight) / 2
    local sideWidth = (outerWidth - holeWidth) / 2

    if topHeight > 0 then
        local y = (holeHeight / 2) + (topHeight / 2)
        self:SetRect(poolName, 1, outerWidth, topHeight, 0, y, r, g, b, a, subLevel)
        self:SetRect(poolName, 2, outerWidth, topHeight, 0, -y, r, g, b, a, subLevel)
    end

    if sideWidth > 0 then
        local x = (holeWidth / 2) + (sideWidth / 2)
        self:SetRect(poolName, 3, sideWidth, holeHeight, -x, 0, r, g, b, a, subLevel)
        self:SetRect(poolName, 4, sideWidth, holeHeight, x, 0, r, g, b, a, subLevel)
    end
end

function WC:ApplySquareShape(thickness, innerWidth, innerHeight, borderSize, fill, r, g, b)
    innerWidth = math.max(4, innerWidth or defaults.inner_length)
    innerHeight = math.max(4, innerHeight or innerWidth)

    local halfWidth = innerWidth / 2
    local halfHeight = innerHeight / 2
    local outerWidth = innerWidth + (borderSize * 2)
    local outerHeight = innerHeight + (borderSize * 2)
    local holeHalfWidth = self:GetFillHoleRadius(halfWidth, thickness, fill)
    local holeHalfHeight = self:GetFillHoleRadius(halfHeight, thickness, fill)
    local borderHoleWidth = math.max(0, holeHalfWidth - borderSize) * 2
    local borderHoleHeight = math.max(0, holeHalfHeight - borderSize) * 2
    local frameWidth = outerWidth + 4
    local frameHeight = outerHeight + 4

    self.frame:SetSize(frameWidth, frameHeight)
    self:DrawRectBand("squareBorder", outerWidth, outerHeight, borderHoleWidth, borderHoleHeight, 0, 0, 0, 1, 0)
    self:DrawRectBand("squareFill", innerWidth, innerHeight, holeHalfWidth * 2, holeHalfHeight * 2, r, g, b, 1, 1)
end

function WC:EnsureShapeSettings(seedCurrent)
    if not self.db then
        return
    end

    local db = self.db
    local currentShape = self:NormalizeShape(db.shape) or "Cross"
    db.shape = currentShape
    if type(db.shapeSettings) ~= "table" then
        db.shapeSettings = {}
    end

    for _, shape in ipairs(shapeOrder) do
        if type(db.shapeSettings[shape]) ~= "table" then
            db.shapeSettings[shape] = {}
        end
        local settings = db.shapeSettings[shape]
        local defaultsForShape = shapeSettingDefaults[shape]
        for _, key in ipairs(shapeSettingKeys) do
            if settings[key] == nil then
                settings[key] = defaultsForShape[key]
            end
        end
    end

    if seedCurrent then
        self:SaveShapeSettings(currentShape)
    end
end

function WC:SaveShapeSettings(shape)
    if not self.db then
        return
    end

    shape = self:NormalizeShape(shape or self.db.shape) or "Cross"
    self.db.shapeSettings = self.db.shapeSettings or {}
    self.db.shapeSettings[shape] = self.db.shapeSettings[shape] or {}

    local settings = self.db.shapeSettings[shape]
    for _, key in ipairs(shapeSettingKeys) do
        settings[key] = self.db[key]
    end
end

function WC:LoadShapeSettings(shape)
    if not self.db then
        return
    end

    self:EnsureShapeSettings(false)
    shape = self:NormalizeShape(shape or self.db.shape) or "Cross"
    local settings = self.db.shapeSettings and self.db.shapeSettings[shape]
    if not settings then
        return
    end

    for _, key in ipairs(shapeSettingKeys) do
        if settings[key] ~= nil then
            self.db[key] = settings[key]
        end
    end
end

function WC:SetShape(shape, requestedFill)
    if not self.db then
        return false
    end

    shape = self:NormalizeShape(shape)
    if not shape then
        return false
    end

    self:EnsureShapeSettings(false)
    self:SaveShapeSettings(self.db.shape)
    self.db.shape = shape
    self:LoadShapeSettings(shape)

    if requestedFill ~= nil then
        self.db.fill = requestedFill
        self:SaveShapeSettings(shape)
    end

    return true
end

function WC:ApplyShape()
    if not self.frame or not self.db then
        return
    end

    local db = self.db
    self:EnsureShapeSettings(false)
    db.alpha = clamp(db.alpha, 0, 1)
    db.thickness = round(clamp(db.thickness, 1, 32))
    db.inner_length = round(clamp(db.inner_length, 4, 256))
    db.width = round(clamp(db.width or db.inner_length, 4, 256))
    db.height = round(clamp(db.height or db.inner_length, 4, 256))
    db.border_size = round(clamp(db.border_size, 0, 64))
    db.fill = clamp(db.fill, 0, 1)
    db.shape = self:NormalizeShape(db.shape) or "Cross"
    self:SaveShapeSettings(db.shape)

    local thickness = db.thickness
    local innerLength = db.inner_length
    local innerWidth = db.width
    local innerHeight = db.height
    local borderSize = db.border_size
    local fill = db.fill
    local r, g, b = self:GetDrawColor()
    local shape = db.shape

    self.frame:SetAlpha(db.alpha)
    self:HideShapeElements()

    if shape == "Circle" then
        if self.frame.CreateLine then
            self:ApplyCircleShape(thickness, innerLength, borderSize, fill, r, g, b)
        else
            db.shape = "Cross"
            self:ApplyCrossShape(thickness, innerWidth, innerHeight, borderSize, r, g, b)
        end
    elseif shape == "ReversedCross" then
        self:ApplyReversedCrossShape(thickness, innerWidth, innerHeight, borderSize, r, g, b)
    elseif shape == "Square" then
        self:ApplySquareShape(thickness, innerWidth, innerHeight, borderSize, fill, r, g, b)
    else
        db.shape = "Cross"
        self:ApplyCrossShape(thickness, innerWidth, innerHeight, borderSize, r, g, b)
    end
end

function WC:UpdateColor()
    self:ApplyShape()
end

function WC:ApplyPosition()
    if not self.frame or not self.db then
        return
    end

    local position = self.db.position or defaults.position
    self.frame:ClearAllPoints()
    self.frame:SetPoint(position.point or "CENTER", UIParent, position.relativePoint or "CENTER", position.x or 0, position.y or 0)
end

function WC:ApplySettings()
    if not self.frame or not self.db then
        return
    end

    self:ApplyShape()
    self:ApplyPosition()
    self.frame:EnableMouse(not self.db.locked)
    self:UpdateCombatTicker()
    self:RefreshVisibility()
end

function WC:SavePosition()
    if not self.frame or not self.db then
        return
    end

    local frameX, frameY = self.frame:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    local x, y

    if frameX and frameY and parentX and parentY then
        x = frameX - parentX
        y = frameY - parentY
    else
        _, _, _, x, y = self.frame:GetPoint()
    end

    self.db.position = self.db.position or {}
    self.db.position.point = "CENTER"
    self.db.position.relativePoint = "CENTER"
    self.db.position.x = math.floor(((x or 0) * 10) + 0.5) / 10
    self.db.position.y = math.floor(((y or 0) * 10) + 0.5) / 10

    if self.db.lockHorizontal then
        self.db.position.x = 0
        self:ApplyPosition()
    end
end

function WC:SetLocked(locked)
    if not self.db then
        return
    end

    self.db.locked = locked and true or false
    self:ApplySettings()
    if self.RefreshOptionsPanel then
        self:RefreshOptionsPanel()
    end
end

function WC:Center()
    if not self.db then
        return
    end

    self.db.position = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
    }
    self:ApplySettings()
end

function WC:IsInCombat()
    return UnitAffectingCombat("player") or (InCombatLockdown and InCombatLockdown())
end

function WC:UpdateCombatTicker()
    if not self.db or not C_Timer or not C_Timer.NewTicker then
        return
    end

    local timingActive = self.db.combatTimingEnabled and (
        (self.db.combatShowAfter or 0) > 0 or
        (self.db.combatHideAfter or 0) > 0 or
        (self.db.combatEndDelay or 0) > 0
    )

    if timingActive and not self.combatTicker then
        self.combatTicker = C_Timer.NewTicker(0.25, function()
            self:RefreshVisibility()
        end)
    elseif not timingActive and self.combatTicker then
        self.combatTicker:Cancel()
        self.combatTicker = nil
    end
end

function WC:GetCombatElapsed()
    if not self.combatStartTime then
        return 0
    end
    return math.max(0, GetTime() - self.combatStartTime)
end

function WC:IsInPostCombatDelay()
    if not self.db or not self.db.combatTimingEnabled or not self.combatEndTime then
        return false
    end

    local delay = tonumber(self.db.combatEndDelay) or 0
    return delay > 0 and (GetTime() - self.combatEndTime) <= delay
end

function WC:IsCombatVisibleForBaseVisibility()
    return self:IsInCombat() or self:IsInPostCombatDelay()
end

function WC:PassesCombatTiming()
    if not self.db.combatTimingEnabled then
        return true
    end

    local inCombat = self:IsInCombat()
    if not inCombat then
        return self:IsInPostCombatDelay()
    end

    local elapsed = self:GetCombatElapsed()
    local showAfter = tonumber(self.db.combatShowAfter) or 0
    local hideAfter = tonumber(self.db.combatHideAfter) or 0

    if showAfter > 0 and elapsed < showAfter then
        return false
    end
    if hideAfter > 0 and elapsed >= hideAfter then
        return false
    end

    return true
end

function WC:PassesBaseVisibility()
    local mode = self.db.visibility or "Always"
    local inCombat = self:IsCombatVisibleForBaseVisibility()
    local inInstance = IsInInstance()

    if mode == "Combat" then
        return inCombat
    elseif mode == "Instance" then
        return inInstance
    elseif mode == "CombatAndInstance" then
        return inCombat and inInstance
    elseif mode == "CombatOrInstance" then
        return inCombat or inInstance
    end

    return true
end

function WC:PassesPhaseRules()
    if not self.db.phaseRulesEnabled or not next(self.db.rules) then
        return true
    end

    local rule = self:GetMatchingRule()
    if not rule then
        return false
    end

    local stage = self:NormalizeStage(self.currentStage or 1)
    return stage ~= nil and rule.phases[stage] == true
end

function WC:ShouldShow()
    if not self.db or not self.db.enabled then
        return false
    end

    if self.frame and not self.db.locked and self.db.showWhileUnlocked then
        return true
    end

    return self:PassesBaseVisibility() and self:PassesCombatTiming() and self:PassesPhaseRules()
end

function WC:RefreshVisibility()
    if not self.frame then
        return
    end

    if self:ShouldShow() then
        self.frame:Show()
    else
        self.frame:Hide()
    end

    if self.RefreshPhaseRuleStatus then
        self:RefreshPhaseRuleStatus()
    end
end

local function registerBigWigsMessage(target, message, method)
    local loader = _G.BigWigsLoader
    if not loader or not loader.RegisterMessage then
        return false
    end

    return pcall(loader.RegisterMessage, target, message, method)
end

function WC:RegisterBossModCallbacks()
    if _G.BigWigsLoader and not self.bigWigsRegistered then
        local setStage = registerBigWigsMessage(self, "BigWigs_SetStage", "OnBigWigsSetStage")
        local engage = registerBigWigsMessage(self, "BigWigs_OnBossEngage", "OnBigWigsBossEngage")
        local win = registerBigWigsMessage(self, "BigWigs_OnBossWin", "OnBigWigsBossEnd")
        local wipe = registerBigWigsMessage(self, "BigWigs_OnBossWipe", "OnBigWigsBossEnd")
        local disable = registerBigWigsMessage(self, "BigWigs_OnBossDisable", "OnBigWigsBossEnd")
        self.bigWigsRegistered = setStage or engage or win or wipe or disable
    end

    if _G.DBM and _G.DBM.RegisterCallback and not self.dbmRegistered then
        self.dbmSetStageCallback = function(event, ...)
            self:OnDBMSetStage(event, ...)
        end
        self.dbmBossEndCallback = function()
            self:OnDBMBossEnd()
        end

        pcall(_G.DBM.RegisterCallback, _G.DBM, "DBM_SetStage", self.dbmSetStageCallback)
        pcall(_G.DBM.RegisterCallback, _G.DBM, "DBM_Kill", self.dbmBossEndCallback)
        pcall(_G.DBM.RegisterCallback, _G.DBM, "DBM_Wipe", self.dbmBossEndCallback)
        self.dbmRegistered = true
    end
end

function WC:OnBigWigsSetStage(_, module, stage)
    self.currentBossModName = getBossModName(module) or self.currentBossModName
    self.currentEncounterID = getBossModEncounterID(module) or self.currentEncounterID
    self.currentStage = self:NormalizeStage(stage)
    self:RefreshVisibility()
end

function WC:OnBigWigsBossEngage(_, module)
    self.currentBossModName = getBossModName(module) or self.currentBossModName
    self.currentEncounterID = getBossModEncounterID(module) or self.currentEncounterID
    self.currentStage = self.currentStage or "1"
    self:RefreshVisibility()
end

function WC:OnBigWigsBossEnd()
    self.currentBossModName = nil
    self.currentStage = nil
    self:RefreshVisibility()
end

function WC:OnDBMSetStage(_, mod, modID, stage, encounterID)
    self.currentBossModName = getBossModName(mod) or tostring(modID or "") ~= "" and tostring(modID) or self.currentBossModName
    self.currentEncounterID = encounterID or getBossModEncounterID(mod) or self.currentEncounterID
    self.currentStage = self:NormalizeStage(stage)
    self:RefreshVisibility()
end

function WC:OnDBMBossEnd()
    self.currentBossModName = nil
    self.currentStage = nil
    self:RefreshVisibility()
end

function WC:ENCOUNTER_START(encounterID, encounterName)
    self.currentEncounterID = encounterID
    self.currentEncounterName = encounterName
    self.currentStage = "1"
    self:RefreshVisibility()
end

function WC:ENCOUNTER_END()
    self.currentEncounterID = nil
    self.currentEncounterName = nil
    self.currentBossModName = nil
    self.currentStage = nil
    self:RefreshVisibility()
end

local function parseBoolean(value)
    value = trim(value):lower()
    if value == "1" or value == "on" or value == "true" or value == "yes" then
        return true
    end
    if value == "0" or value == "off" or value == "false" or value == "no" then
        return false
    end
    return nil
end

function WC:NormalizeVisibility(value)
    value = trim(value):lower():gsub("[%s_%-]+", "")
    if value == "always" then
        return "Always"
    elseif value == "combat" or value == "incombat" then
        return "Combat"
    elseif value == "instance" or value == "ininstance" then
        return "Instance"
    elseif value == "combatinstance" or value == "combatandinstance" or value == "incombatininstance" then
        return "CombatAndInstance"
    elseif value == "combatorinstance" then
        return "CombatOrInstance"
    end
    return nil
end

function WC:PrintRules()
    if not self.db or not next(self.db.rules) then
        self:Print("No boss phase rules are configured.")
        return
    end

    self:Print("Boss phase rules:")
    for key, rule in pairs(self.db.rules) do
        self:Print("  " .. (rule.label or key) .. " -> " .. self:FormatPhaseList(rule.phases))
    end
end

function WC:PrintStatus()
    local db = self.db
    if not db then
        return
    end

    local currentBoss = self.currentEncounterName or self.currentBossModName or self.manualBossName or "none"
    local currentStage = self.currentStage or "none"
    self:Print("enabled=" .. tostring(db.enabled) ..
        ", locked=" .. tostring(db.locked) ..
        ", shape=" .. tostring(shapeLabels[db.shape] or db.shape) ..
        ", fill=" .. string.format("%.0f", (db.fill or 0) * 100) .. "%" ..
        ", visibility=" .. tostring(visibilityLabels[db.visibility] or db.visibility) ..
        ", combatTiming=" .. tostring(db.combatTimingEnabled) ..
        ", showAfter=" .. tostring(db.combatShowAfter or 0) ..
        ", hideAfter=" .. tostring(db.combatHideAfter or 0) ..
        ", linger=" .. tostring(db.combatEndDelay or 0) ..
        ", phaseRules=" .. tostring(db.phaseRulesEnabled) ..
        ", currentBoss=" .. tostring(currentBoss) ..
        ", currentPhase=" .. tostring(currentStage))
end

function WC:PrintHelp()
    self:Print("Commands:")
    self:Print("/dxh options - open options")
    self:Print("/dxh lock, unlock, center, on, off")
    self:Print("/dxh alpha 0.8, thickness 2, size 30, width 45, height 30, border 3, fill 100")
    self:Print("/dxh shape cross|reversed|circle|square. /dxh shape dot selects circle fill 100")
    self:Print("/dxh visibility always|combat|instance|combatinstance|combatorinstance")
    self:Print("/dxh timing on|off, showafter 3, hideafter 20, linger 2")
    self:Print("/dxh phases on|off - show only during configured boss phases")
    self:Print("/dxh rule lura 4 - show on P4 for boss names containing Lura")
    self:Print("/dxh rule lura 2,4 - show on P2 and P4")
    self:Print("/dxh color class or /dxh color 0 1 0")
    self:Print("/dxh delrule lura, /dxh rules, /dxh status")
end

function WC:OpenOptions()
    self:PrintHelp()
end

function WC:HandleSlash(message)
    message = trim(message)
    if message == "" or message:lower() == "options" or message:lower() == "config" then
        self:OpenOptions()
        return
    end

    local command, rest = message:match("^(%S+)%s*(.-)$")
    command = (command or ""):lower()
    rest = trim(rest)

    if command == "help" then
        self:PrintHelp()
    elseif command == "on" or command == "enable" then
        self.db.enabled = true
        self:RefreshVisibility()
        self:Print("Enabled.")
    elseif command == "off" or command == "disable" then
        self.db.enabled = false
        self:RefreshVisibility()
        self:Print("Disabled.")
    elseif command == "lock" then
        self:SetLocked(true)
        self:Print("Locked.")
    elseif command == "unlock" then
        self:SetLocked(false)
        self:Print("Unlocked. Drag the crosshair, then /dxh lock.")
    elseif command == "center" or command == "reset" then
        self:Center()
        self:Print("Moved to screen center.")
    elseif command == "alpha" or command == "opacity" then
        local value = tonumber(rest)
        if value and value > 1 then
            value = value / 100
        end
        self.db.alpha = clamp(value, 0, 1)
        self:ApplySettings()
        self:Print("Alpha set to " .. string.format("%.2f", self.db.alpha) .. ".")
    elseif command == "thickness" then
        self.db.thickness = round(clamp(rest, 1, 32))
        self:ApplySettings()
        self:Print("Thickness set to " .. self.db.thickness .. ".")
    elseif command == "inner" or command == "length" or command == "size" then
        local value = round(clamp(rest, 4, 256))
        self.db.inner_length = value
        if self.db.shape == "Cross" or self.db.shape == "ReversedCross" or self.db.shape == "Square" then
            self.db.width = value
            self.db.height = value
        end
        self:ApplySettings()
        self:Print("Size set to " .. self.db.inner_length .. ".")
    elseif command == "width" then
        self.db.width = round(clamp(rest, 4, 256))
        self:ApplySettings()
        self:Print("Width set to " .. self.db.width .. ".")
    elseif command == "height" then
        self.db.height = round(clamp(rest, 4, 256))
        self:ApplySettings()
        self:Print("Height set to " .. self.db.height .. ".")
    elseif command == "border" then
        self.db.border_size = round(clamp(rest, 0, 64))
        self:ApplySettings()
        self:Print("Border size set to " .. self.db.border_size .. ".")
    elseif command == "fill" or command == "filled" then
        local enabled = parseBoolean(rest)
        local value = tonumber(rest)
        if enabled ~= nil then
            value = enabled and 1 or 0
        elseif value and value > 1 then
            value = value / 100
        end
        self.db.fill = clamp(value, 0, 1)
        self:ApplySettings()
        self:Print("Fill set to " .. string.format("%.0f", self.db.fill * 100) .. "%.")
    elseif command == "shape" or command == "texture" then
        local shape, requestedFill = self:NormalizeShape(rest)
        if not shape then
            self:Print("Shape values: cross, reversed, circle, square. Dot is circle with fill 100.")
        else
            self:SetShape(shape, requestedFill)
            self:ApplySettings()
            self:Print("Shape set to " .. shapeLabels[shape] .. ".")
        end
    elseif command == "horizontal" or command == "lockhorizontal" then
        local enabled = parseBoolean(rest)
        if enabled == nil then
            enabled = not self.db.lockHorizontal
        end
        self.db.lockHorizontal = enabled
        self:SavePosition()
        self:Print("Lock horizontal " .. (enabled and "enabled." or "disabled."))
    elseif command == "visibility" or command == "show" then
        local visibility = self:NormalizeVisibility(rest)
        if not visibility then
            self:Print("Visibility values: always, combat, instance, combatinstance, combatorinstance.")
        else
            self.db.visibility = visibility
            self:RefreshVisibility()
            self:Print("Visibility set to " .. visibilityLabels[visibility] .. ".")
        end
    elseif command == "combat" or command == "combatonly" then
        local enabled = parseBoolean(rest)
        if enabled == nil then
            enabled = self.db.visibility ~= "Combat"
        end
        self.db.visibility = enabled and "Combat" or "Always"
        self:RefreshVisibility()
        self:Print("Combat-only visibility " .. (enabled and "enabled." or "disabled."))
    elseif command == "timing" or command == "combattiming" then
        local enabled = parseBoolean(rest)
        if enabled == nil then
            enabled = not self.db.combatTimingEnabled
        end
        self.db.combatTimingEnabled = enabled
        self:ApplySettings()
        self:Print("Combat timing " .. (enabled and "enabled." or "disabled."))
    elseif command == "showafter" or command == "combatshowafter" then
        self.db.combatShowAfter = clamp(rest, 0, 600)
        self.db.combatTimingEnabled = true
        self:ApplySettings()
        self:Print("Combat show-after set to " .. self.db.combatShowAfter .. " seconds.")
    elseif command == "hideafter" or command == "combathideafter" then
        self.db.combatHideAfter = clamp(rest, 0, 600)
        self.db.combatTimingEnabled = true
        self:ApplySettings()
        self:Print("Combat hide-after set to " .. self.db.combatHideAfter .. " seconds.")
    elseif command == "linger" or command == "enddelay" or command == "combatenddelay" then
        self.db.combatEndDelay = clamp(rest, 0, 120)
        self.db.combatTimingEnabled = true
        self:ApplySettings()
        self:Print("Post-combat linger set to " .. self.db.combatEndDelay .. " seconds.")
    elseif command == "phases" or command == "phaseonly" then
        local enabled = parseBoolean(rest)
        if enabled == nil then
            enabled = not self.db.phaseRulesEnabled
        end
        self.db.phaseRulesEnabled = enabled
        self:RefreshVisibility()
        self:Print("Boss phase rules " .. (enabled and "enabled." or "disabled."))
    elseif command == "rule" then
        local boss, phases = rest:match("^(.-)%s+([pP%d%.%,%s]+)$")
        local ok, errorMessage = self:SetRule(boss, phases)
        if ok then
            self:Print("Saved rule for " .. trim(boss) .. " -> " .. self:FormatPhaseList(self.db.rules[self:RuleKey(boss)].phases) .. ".")
        else
            self:Print(errorMessage)
        end
    elseif command == "delrule" or command == "removerule" then
        local ok, errorMessage = self:DeleteRule(rest)
        self:Print(ok and "Deleted rule." or errorMessage)
    elseif command == "rules" then
        self:PrintRules()
    elseif command == "color" then
        local r, g, b = rest:match("^(%S+)%s+(%S+)%s+(%S+)$")
        if rest:lower() == "class" then
            self.db.class_colored = true
            self:UpdateColor()
            self:Print("Using class color.")
        elseif r and g and b then
            self.db.class_colored = false
            self.db.customR = clamp(r, 0, 1)
            self.db.customG = clamp(g, 0, 1)
            self.db.customB = clamp(b, 0, 1)
            self:UpdateColor()
            self:Print("Using custom color.")
        else
            self:Print("Use /dxh color class or /dxh color 0 1 0.")
        end
    elseif command == "phase" then
        self.currentStage = self:NormalizeStage(rest)
        self:RefreshVisibility()
        self:Print("Manual current phase set to " .. tostring(self.currentStage) .. ".")
    elseif command == "boss" then
        self.manualBossName = rest ~= "" and rest or nil
        self:RefreshVisibility()
        self:Print("Manual boss set to " .. tostring(self.manualBossName or "none") .. ".")
    elseif command == "status" then
        self:PrintStatus()
    else
        self:PrintHelp()
    end

    if self.RefreshOptionsPanel then
        self:RefreshOptionsPanel()
    end
end

function WC:PLAYER_REGEN_DISABLED()
    self.combatStartTime = GetTime()
    self.combatEndTime = nil
    self:UpdateCombatTicker()
    self:RefreshVisibility()
end

function WC:PLAYER_REGEN_ENABLED()
    self.combatEndTime = GetTime()
    self:UpdateCombatTicker()
    self:RefreshVisibility()
end

function WC:PLAYER_ENTERING_WORLD()
    if self:IsInCombat() then
        self.combatStartTime = self.combatStartTime or GetTime()
        self.combatEndTime = nil
    else
        self.combatStartTime = nil
        self.combatEndTime = nil
    end
    self:UpdateCombatTicker()
    self:RefreshVisibility()
    self:RegisterBossModCallbacks()
end

function WC:ADDON_LOADED(loadedAddonName)
    if loadedAddonName == addonName then
        DuncedXHairDB = DuncedXHairDB or WilduCrosshairDB or {}
        local hadShapeSettings = type(DuncedXHairDB.shapeSettings) == "table"
        if DuncedXHairDB.shape == "Dot" and DuncedXHairDB.fill == nil then
            DuncedXHairDB.fill = 1
        end
        copyDefaults(defaults, DuncedXHairDB)
        self.db = DuncedXHairDB
        self:EnsureShapeSettings(not hadShapeSettings)
        self:LoadShapeSettings(self.db.shape)

        self:CreateCrosshair()
        self:ApplySettings()

        self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        self.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
        self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        self.eventFrame:RegisterEvent("ENCOUNTER_START")
        self.eventFrame:RegisterEvent("ENCOUNTER_END")

        SLASH_DUNCEDXHAIR1 = "/dxh"
        SlashCmdList.DUNCEDXHAIR = function(slashMessage)
            self:HandleSlash(slashMessage)
        end

        if self.RegisterOptions then
            self:RegisterOptions()
        end

        self:RegisterBossModCallbacks()
        if C_Timer and C_Timer.After then
            C_Timer.After(2, function()
                self:RegisterBossModCallbacks()
            end)
        end
    elseif self.db and loadedAddonName and (loadedAddonName:find("BigWigs") or loadedAddonName:find("DBM")) then
        self:RegisterBossModCallbacks()
    end
end

WC.eventFrame = CreateFrame("Frame")
WC.eventFrame:RegisterEvent("ADDON_LOADED")
WC.eventFrame:SetScript("OnEvent", function(_, event, ...)
    if WC[event] then
        WC[event](WC, ...)
    end
end)

