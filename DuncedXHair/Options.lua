local _, ns = ...
local WC = ns.DuncedXHair or _G.DuncedXHair

if not WC then
    return
end

local panelName = "DuncedXHairOptionsPanel"
local controlIndex = 0
local phaseRuleBaseHeight = 330

local function nextName(prefix)
    controlIndex = controlIndex + 1
    return panelName .. prefix .. controlIndex
end

local function controlText(control)
    return control.Text or (control.GetName and _G[control:GetName() .. "Text"])
end

local function setControlText(control, text)
    local fontString = controlText(control)
    if fontString then
        fontString:SetText(text)
    end
end

local function setDropdownFont(dropdown, fontObject)
    local fontString = controlText(dropdown)
    if fontString and fontObject and fontString.SetFontObject then
        fontString:SetFontObject(fontObject)
    end
end

local function makeButton(parent, text, width)
    local button = CreateFrame("Button", nextName("Button"), parent, "UIPanelButtonTemplate")
    button:SetSize(width or 96, 24)
    button:SetText(text)
    return button
end

local function makeCheck(parent, text, onClick)
    local check = CreateFrame("CheckButton", nextName("Check"), parent, "InterfaceOptionsCheckButtonTemplate")
    setControlText(check, text)
    check:SetScript("OnClick", function(button)
        if WC.optionsUpdating then
            return
        end
        onClick(button:GetChecked() and true or false)
        WC:ApplySettings()
        WC:RefreshOptionsPanel()
    end)
    return check
end

local function makeSlider(parent, text, minimum, maximum, step, onValueChanged)
    local slider = CreateFrame("Slider", nextName("Slider"), parent, "OptionsSliderTemplate")
    slider:SetMinMaxValues(minimum, maximum)
    slider:SetValueStep(step)
    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end

    setControlText(slider, text)
    local low = _G[slider:GetName() .. "Low"]
    local high = _G[slider:GetName() .. "High"]
    if low then
        low:SetText(tostring(minimum))
    end
    if high then
        high:SetText(tostring(maximum))
    end

    slider.valueText = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    slider.valueText:SetPoint("LEFT", slider, "RIGHT", 16, 0)

    slider:SetScript("OnValueChanged", function(control, value)
        if step >= 1 then
            value = math.floor(value + 0.5)
        end
        control.valueText:SetText(step >= 1 and tostring(value) or string.format("%.2f", value))
        if WC.optionsUpdating or not WC.db then
            return
        end
        onValueChanged(value)
        WC:ApplySettings()
    end)

    return slider
end

local function makeEditBox(parent, width)
    local box = CreateFrame("EditBox", nextName("EditBox"), parent, "InputBoxTemplate")
    box:SetSize(width, 24)
    box:SetAutoFocus(false)
    return box
end

local function makeDropdown(parent, width, values, onSelect, fontObject)
    local dropdown = CreateFrame("Frame", nextName("Dropdown"), parent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dropdown, width)
    UIDropDownMenu_Initialize(dropdown, function(_, level)
        if level ~= 1 then
            return
        end
        for _, value in ipairs(values) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = value.text
            info.value = value.value
            info.fontObject = value.fontObject or fontObject
            info.func = function()
                onSelect(value.value)
                UIDropDownMenu_SetSelectedValue(dropdown, value.value)
                WC:ApplySettings()
                WC:RefreshOptionsPanel()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    dropdown.fontObject = fontObject
    setDropdownFont(dropdown, fontObject)
    return dropdown
end

local function makeDynamicDropdown(parent, width, getValues, onSelect)
    local dropdown = CreateFrame("Frame", nextName("Dropdown"), parent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dropdown, width)
    UIDropDownMenu_Initialize(dropdown, function(_, level)
        if level ~= 1 then
            return
        end

        local values = getValues() or {}
        if #values == 0 then
            local info = UIDropDownMenu_CreateInfo()
            info.text = "No encounter IDs found"
            info.disabled = true
            UIDropDownMenu_AddButton(info)
            return
        end

        for _, value in ipairs(values) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = value.text
            info.value = value.value
            info.func = function()
                onSelect(value.value, value)
                UIDropDownMenu_SetText(dropdown, value.text)
                WC:RefreshOptionsPanel()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    return dropdown
end

local function makeLocalCheck(parent, text)
    local check = CreateFrame("CheckButton", nextName("Check"), parent, "InterfaceOptionsCheckButtonTemplate")
    setControlText(check, text)
    return check
end

local function addEncounterOption(options, seen, name, encounterID, source)
    encounterID = tonumber(encounterID)
    if not encounterID or seen[encounterID] then
        return
    end

    seen[encounterID] = true
    name = WC:Trim(name or "")
    if name == "" then
        name = "Encounter " .. tostring(encounterID)
    end

    local prefix = source and source ~= "" and (source .. ": ") or ""
    options[#options + 1] = {
        text = prefix .. name .. " (id:" .. tostring(encounterID) .. ")",
        value = encounterID,
    }
end

local function getJournalInstanceID()
    local mapID
    if C_Map and C_Map.GetBestMapForUnit then
        local ok, value = pcall(C_Map.GetBestMapForUnit, "player")
        if ok then
            mapID = value
        end
    end

    if mapID and EJ_GetInstanceForMap then
        local ok, instanceID = pcall(EJ_GetInstanceForMap, mapID)
        if ok and instanceID then
            return instanceID
        end
    end

    if EJ_GetCurrentInstance then
        local ok, instanceID = pcall(EJ_GetCurrentInstance)
        if ok and instanceID then
            return instanceID
        end
    end

    return nil
end

local function getEncounterIDOptions()
    local options = {}
    local seen = {}

    addEncounterOption(options, seen, WC.currentEncounterName or WC.currentBossModName, WC.currentEncounterID, "Current")

    if not EJ_GetEncounterInfoByIndex then
        return options
    end

    local instanceID = getJournalInstanceID()
    local previousInstance
    if EJ_GetCurrentInstance then
        local ok, value = pcall(EJ_GetCurrentInstance)
        if ok then
            previousInstance = value
        end
    end

    if instanceID and EJ_SelectInstance then
        pcall(EJ_SelectInstance, instanceID)
    end

    for index = 1, 30 do
        local ok, name, _, encounterID = pcall(EJ_GetEncounterInfoByIndex, index, instanceID)
        if not ok or not name then
            ok, name, _, encounterID = pcall(EJ_GetEncounterInfoByIndex, index)
        end

        if not ok or not name then
            break
        end

        addEncounterOption(options, seen, name, encounterID, "Journal")
    end

    if previousInstance and instanceID and previousInstance ~= instanceID and EJ_SelectInstance then
        pcall(EJ_SelectInstance, previousInstance)
    end

    return options
end

local function getSelectedPhaseText(panel)
    local phases = {}
    for _, check in ipairs(panel.phaseChecks or {}) do
        if check:GetChecked() then
            phases[#phases + 1] = check.phaseValue
        end
    end
    return table.concat(phases, ",")
end

local function setSelectedPhases(panel, phases)
    for _, check in ipairs(panel.phaseChecks or {}) do
        check:SetChecked(phases and phases[check.phaseValue] == true)
    end
end

local function loadRuleEditor(panel, key)
    local rule = WC.db and WC.db.rules and WC.db.rules[key]
    if not rule then
        return
    end
    panel.loadedRuleKey = key
    panel.bossBox:SetText(rule.label or key)
    setSelectedPhases(panel, rule.phases)
end

local function setCurrentBossInEditor(panel)
    local boss = WC.currentEncounterName or WC.currentBossModName or WC.manualBossName
    if boss and boss ~= "" then
        panel.bossBox:SetText(boss)
    elseif WC.currentEncounterID then
        panel.bossBox:SetText("id:" .. tostring(WC.currentEncounterID))
    else
        panel.bossBox:SetText("")
    end

    local stage = WC:NormalizeStage(WC.currentStage or "")
    if stage then
        setSelectedPhases(panel, { [stage] = true })
    end
end

local function openColorPicker(owner)
    local db = WC.db
    if not db or not ColorPickerFrame then
        return
    end

    local previous = {
        r = db.customR or 1,
        g = db.customG or 1,
        b = db.customB or 1,
        class_colored = db.class_colored,
    }

    local function getPickerColor()
        if ColorPickerFrame.GetColorRGB then
            return ColorPickerFrame:GetColorRGB()
        end
        if ColorPickerFrame.Content and ColorPickerFrame.Content.ColorPicker and ColorPickerFrame.Content.ColorPicker.GetColorRGB then
            return ColorPickerFrame.Content.ColorPicker:GetColorRGB()
        end
        return previous.r, previous.g, previous.b
    end

    local function updateColor()
        local r, g, b = getPickerColor()
        db.class_colored = false
        db.customR = r
        db.customG = g
        db.customB = b
        WC:UpdateColor()
        WC:RefreshOptionsPanel()
    end

    local function cancelColor()
        db.class_colored = previous.class_colored
        db.customR = previous.r
        db.customG = previous.g
        db.customB = previous.b
        WC:UpdateColor()
        WC:RefreshOptionsPanel()
    end

    db.class_colored = false
    WC:UpdateColor()
    WC:RefreshOptionsPanel()

    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = previous.r,
            g = previous.g,
            b = previous.b,
            hasOpacity = false,
            swatchFunc = updateColor,
            cancelFunc = cancelColor,
        })
    else
        ColorPickerFrame:SetColorRGB(previous.r, previous.g, previous.b)
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.previousValues = previous
        ColorPickerFrame.func = updateColor
        ColorPickerFrame.cancelFunc = cancelColor
        ColorPickerFrame:Show()
    end

    if owner then
        owner:SetChecked(false)
    end
end

function WC:CreateOptionsPanel()
    if self.optionsPanel then
        return self.optionsPanel
    end

    local panel = CreateFrame("Frame", panelName, UIParent)
    panel.name = "DuncedXHair"
    self.optionsPanel = panel

    local scroll = CreateFrame("ScrollFrame", nextName("Scroll"), panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -4)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 4)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(frame, delta)
        local current = frame:GetVerticalScroll()
        local maximum = frame:GetVerticalScrollRange()
        frame:SetVerticalScroll(math.max(0, math.min(maximum, current - (delta * 40))))
    end)
    panel.scrollFrame = scroll

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(640, 1020)
    scroll:SetScrollChild(content)
    panel.content = content

    local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("DuncedXHair")

    local lockButton = makeButton(content, "Unlock", 96)
    lockButton:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -18)
    lockButton:SetScript("OnClick", function()
        self:SetLocked(not self.db.locked)
        self:RefreshOptionsPanel()
    end)
    panel.lockButton = lockButton

    local centerButton = makeButton(content, "Center", 96)
    centerButton:SetPoint("LEFT", lockButton, "RIGHT", 8, 0)
    centerButton:SetScript("OnClick", function()
        self:Center()
        self:RefreshOptionsPanel()
    end)

    local enabled = makeCheck(content, "Enabled", function(value)
        self.db.enabled = value
    end)
    enabled:SetPoint("TOPLEFT", lockButton, "BOTTOMLEFT", 0, -18)
    panel.enabledCheck = enabled

    local preview = makeCheck(content, "Show while unlocked", function(value)
        self.db.showWhileUnlocked = value
    end)
    preview:SetPoint("TOPLEFT", enabled, "BOTTOMLEFT", 0, -8)
    panel.previewCheck = preview

    local horizontal = makeCheck(content, "Lock horizontal position", function(value)
        self.db.lockHorizontal = value
        self:SavePosition()
    end)
    horizontal:SetPoint("TOPLEFT", preview, "BOTTOMLEFT", 0, -8)
    panel.horizontalCheck = horizontal

    local phaseOnly = makeCheck(content, "Use boss phase rules", function(value)
        self.db.phaseRulesEnabled = value
    end)
    phaseOnly:SetPoint("TOPLEFT", horizontal, "BOTTOMLEFT", 0, -8)
    panel.phaseCheck = phaseOnly

    local phaseRules = CreateFrame("Frame", nil, content)
    phaseRules:SetPoint("TOPLEFT", phaseOnly, "BOTTOMLEFT", 0, -8)
    phaseRules:SetSize(360, phaseRuleBaseHeight)
    panel.phaseRuleFrame = phaseRules

    local classColor = makeCheck(content, "Use class color", function(value)
        self.db.class_colored = value
        self:UpdateColor()
    end)
    classColor:SetPoint("TOPLEFT", phaseOnly, "BOTTOMLEFT", 0, -8)
    panel.classColorCheck = classColor

    local colorButton = makeButton(content, "Custom Color", 116)
    colorButton:SetPoint("LEFT", classColor, "RIGHT", 160, 0)
    colorButton:SetScript("OnClick", function()
        openColorPicker(classColor)
    end)
    panel.colorButton = colorButton

    local colorSwatch = CreateFrame("Button", nextName("ColorSwatch"), content)
    colorSwatch:SetSize(24, 24)
    colorSwatch:SetPoint("LEFT", colorButton, "RIGHT", 8, 0)
    colorSwatch.bg = colorSwatch:CreateTexture(nil, "BACKGROUND")
    colorSwatch.bg:SetAllPoints()
    colorSwatch.bg:SetColorTexture(0, 0, 0, 1)
    colorSwatch.tex = colorSwatch:CreateTexture(nil, "ARTWORK")
    colorSwatch.tex:SetPoint("TOPLEFT", 2, -2)
    colorSwatch.tex:SetPoint("BOTTOMRIGHT", -2, 2)
    colorSwatch:SetScript("OnClick", function()
        openColorPicker(classColor)
    end)
    panel.colorSwatch = colorSwatch

    local visibilityLabel = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    visibilityLabel:SetPoint("TOPLEFT", classColor, "BOTTOMLEFT", 0, -16)
    visibilityLabel:SetText("Visibility")

    local visibilityValues = {
        { text = "Always", value = "Always" },
        { text = "In Combat", value = "Combat" },
        { text = "In Instance", value = "Instance" },
        { text = "In Combat + In Instance", value = "CombatAndInstance" },
        { text = "In Combat or In Instance", value = "CombatOrInstance" },
    }
    local visibility = makeDropdown(content, 190, visibilityValues, function(value)
        self.db.visibility = value
    end)
    visibility:SetPoint("TOPLEFT", visibilityLabel, "BOTTOMLEFT", -16, -2)
    panel.visibilityDropdown = visibility

    local shapeLabel = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    shapeLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 360, -18)
    shapeLabel:SetText("Shape")

    local shapeValues = {
        { text = "Cross", value = "Cross" },
        { text = "Circle", value = "Circle" },
        { text = "Square", value = "Square" },
    }
    local shape = makeDropdown(content, 140, shapeValues, function(value)
        self:SetShape(value)
    end)
    shape:SetPoint("TOPLEFT", shapeLabel, "BOTTOMLEFT", -16, -2)
    panel.shapeDropdown = shape

    local timing = makeCheck(content, "Use combat timing", function(value)
        self.db.combatTimingEnabled = value
        self:UpdateCombatTicker()
    end)
    timing:SetPoint("TOPLEFT", shape, "BOTTOMLEFT", 16, -14)
    panel.timingCheck = timing

    local showAfter = makeSlider(content, "Show after combat start", 0, 120, 1, function(value)
        self.db.combatShowAfter = value
        self.db.combatTimingEnabled = true
        panel.timingCheck:SetChecked(true)
        self:UpdateCombatTicker()
    end)
    showAfter:SetPoint("TOPLEFT", timing, "BOTTOMLEFT", 4, -30)
    showAfter:SetWidth(190)
    panel.showAfterSlider = showAfter

    local hideAfter = makeSlider(content, "Hide after combat time", 0, 600, 1, function(value)
        self.db.combatHideAfter = value
        self.db.combatTimingEnabled = true
        panel.timingCheck:SetChecked(true)
        self:UpdateCombatTicker()
    end)
    hideAfter:SetPoint("TOPLEFT", showAfter, "BOTTOMLEFT", 0, -38)
    hideAfter:SetWidth(190)
    panel.hideAfterSlider = hideAfter

    local linger = makeSlider(content, "Linger after combat", 0, 120, 1, function(value)
        self.db.combatEndDelay = value
        self.db.combatTimingEnabled = true
        panel.timingCheck:SetChecked(true)
        self:UpdateCombatTicker()
    end)
    linger:SetPoint("TOPLEFT", hideAfter, "BOTTOMLEFT", 0, -38)
    linger:SetWidth(190)
    panel.lingerSlider = linger

    local alpha = makeSlider(content, "Alpha", 0, 1, 0.01, function(value)
        self.db.alpha = value
    end)
    alpha:SetPoint("TOPLEFT", visibility, "BOTTOMLEFT", 20, -30)
    alpha:SetWidth(220)
    panel.alphaSlider = alpha

    local thickness = makeSlider(content, "Thickness", 1, 32, 1, function(value)
        self.db.thickness = value
    end)
    thickness:SetPoint("TOPLEFT", alpha, "BOTTOMLEFT", 0, -38)
    thickness:SetWidth(220)
    panel.thicknessSlider = thickness

    local innerLength = makeSlider(content, "Size", 4, 256, 1, function(value)
        self.db.inner_length = value
        if self.db.shape == "Cross" or self.db.shape == "Square" then
            self.db.width = value
            self.db.height = value
            self.optionsUpdating = true
            if panel.widthSlider then
                panel.widthSlider:SetValue(value)
            end
            if panel.heightSlider then
                panel.heightSlider:SetValue(value)
            end
            self.optionsUpdating = false
        end
    end)
    innerLength:SetPoint("TOPLEFT", thickness, "BOTTOMLEFT", 0, -38)
    innerLength:SetWidth(220)
    panel.innerLengthSlider = innerLength

    local width = makeSlider(content, "Width", 4, 256, 1, function(value)
        self.db.width = value
    end)
    width:SetPoint("TOPLEFT", innerLength, "BOTTOMLEFT", 0, -38)
    width:SetWidth(220)
    panel.widthSlider = width

    local height = makeSlider(content, "Height", 4, 256, 1, function(value)
        self.db.height = value
    end)
    height:SetPoint("TOPLEFT", width, "BOTTOMLEFT", 0, -38)
    height:SetWidth(220)
    panel.heightSlider = height

    local border = makeSlider(content, "Border size", 0, 64, 1, function(value)
        self.db.border_size = value
    end)
    border:SetPoint("TOPLEFT", height, "BOTTOMLEFT", 0, -38)
    border:SetWidth(220)
    panel.borderSlider = border

    local fill = makeSlider(content, "Fill amount", 0, 1, 0.01, function(value)
        self.db.fill = value
    end)
    fill:SetPoint("TOPLEFT", border, "BOTTOMLEFT", 0, -38)
    fill:SetWidth(220)
    panel.fillSlider = fill

    local ruleTitle = phaseRules:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    ruleTitle:SetPoint("TOPLEFT", phaseRules, "TOPLEFT", 0, -2)
    ruleTitle:SetText("Boss phase rules")

    local bossLabel = phaseRules:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    bossLabel:SetPoint("TOPLEFT", ruleTitle, "BOTTOMLEFT", 0, -12)
    bossLabel:SetText("Boss or id:encounterID")

    local bossBox = makeEditBox(phaseRules, 220)
    bossBox:SetPoint("TOPLEFT", bossLabel, "BOTTOMLEFT", 4, -4)
    panel.bossBox = bossBox

    local currentBoss = makeButton(phaseRules, "Current", 82)
    currentBoss:SetPoint("LEFT", bossBox, "RIGHT", 10, 0)
    currentBoss:SetScript("OnClick", function()
        setCurrentBossInEditor(panel)
    end)

    local encounterLabel = phaseRules:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    encounterLabel:SetPoint("TOPLEFT", bossBox, "BOTTOMLEFT", -4, -10)
    encounterLabel:SetText("Encounter ID helper")

    local encounterDropdown = makeDynamicDropdown(phaseRules, 300, getEncounterIDOptions, function(value)
        bossBox:SetText("id:" .. tostring(value))
        bossBox:ClearFocus()
    end)
    encounterDropdown:SetPoint("TOPLEFT", encounterLabel, "BOTTOMLEFT", -16, -2)
    panel.encounterIDDropdown = encounterDropdown

    local phaseLabel = phaseRules:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    phaseLabel:SetPoint("TOPLEFT", encounterDropdown, "BOTTOMLEFT", 16, -10)
    phaseLabel:SetText("Phases")

    panel.phaseChecks = {}
    for index = 1, 8 do
        local check = makeLocalCheck(phaseRules, "P" .. index)
        check.phaseValue = tostring(index)
        if index == 1 then
            check:SetPoint("TOPLEFT", phaseLabel, "BOTTOMLEFT", -4, -4)
        elseif index == 5 then
            check:SetPoint("TOPLEFT", panel.phaseChecks[1], "BOTTOMLEFT", 0, -2)
        else
            check:SetPoint("LEFT", panel.phaseChecks[index - 1], "RIGHT", 36, 0)
        end
        panel.phaseChecks[index] = check
    end

    local saveRule = makeButton(phaseRules, "Save", 80)
    saveRule:SetPoint("TOPLEFT", panel.phaseChecks[5], "BOTTOMLEFT", 4, -8)
    saveRule:SetScript("OnClick", function()
        local ok, message = self:SetRule(bossBox:GetText(), getSelectedPhaseText(panel))
        if not ok then
            self:Print(message)
        end
        bossBox:ClearFocus()
        self:RefreshOptionsPanel()
    end)

    local deleteRule = makeButton(phaseRules, "Delete", 80)
    deleteRule:SetPoint("LEFT", saveRule, "RIGHT", 8, 0)
    deleteRule:SetScript("OnClick", function()
        local ok, message = self:DeleteRule(bossBox:GetText())
        if not ok then
            self:Print(message)
        end
        self:RefreshOptionsPanel()
    end)

    local clearRule = makeButton(phaseRules, "Clear", 80)
    clearRule:SetPoint("LEFT", deleteRule, "RIGHT", 8, 0)
    clearRule:SetScript("OnClick", function()
        panel.loadedRuleKey = nil
        bossBox:SetText("")
        setSelectedPhases(panel, nil)
        bossBox:ClearFocus()
    end)

    bossBox:SetScript("OnEnterPressed", function()
        saveRule:Click()
    end)

    local status = phaseRules:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", saveRule, "BOTTOMLEFT", -4, -14)
    status:SetText("")
    status:SetWidth(350)
    status:SetJustifyH("LEFT")
    panel.statusText = status

    panel.ruleRows = {}
    for index = 1, 6 do
        local row = {}
        row.text = phaseRules:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        if index == 1 then
            row.text:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -10)
        else
            row.text:SetPoint("TOPLEFT", panel.ruleRows[index - 1].text, "BOTTOMLEFT", 0, -8)
        end
        row.text:SetWidth(200)
        row.text:SetJustifyH("LEFT")

        row.editButton = makeButton(phaseRules, "Edit", 58)
        row.editButton:SetPoint("LEFT", row.text, "RIGHT", 8, 0)
        row.editButton:SetScript("OnClick", function(button)
            if button.ruleKey then
                loadRuleEditor(panel, button.ruleKey)
            end
        end)

        row.deleteButton = makeButton(phaseRules, "Delete", 70)
        row.deleteButton:SetPoint("LEFT", row.editButton, "RIGHT", 6, 0)
        row.deleteButton:SetScript("OnClick", function(button)
            if button.ruleKey then
                self.db.rules[button.ruleKey] = nil
                self:RefreshVisibility()
                self:RefreshOptionsPanel()
            end
        end)

        panel.ruleRows[index] = row
    end

    panel:SetScript("OnShow", function()
        self:RefreshOptionsPanel()
    end)

    return panel
end

function WC:RegisterOptions()
    if self.optionsRegistered then
        return
    end

    local panel = self:CreateOptionsPanel()
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name, panel.name)
        Settings.RegisterAddOnCategory(category)
        self.optionsCategory = category
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end

    self.optionsRegistered = true
end

function WC:OpenOptions()
    self:RegisterOptions()

    if Settings and Settings.OpenToCategory and self.optionsCategory then
        local id = self.optionsCategory.ID or self.optionsCategory:GetID()
        local ok = pcall(Settings.OpenToCategory, id)
        if not ok then
            pcall(Settings.OpenToCategory, self.optionsCategory)
        end
    elseif InterfaceOptionsFrame_OpenToCategory and self.optionsPanel then
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
    else
        self:PrintHelp()
    end
end

function WC:RefreshPhaseRuleStatus()
    local panel = self.optionsPanel
    local db = self.db
    if not panel or not db or not panel.statusText then
        return
    end

    local currentBoss = self.currentEncounterName or self.currentBossModName or self.manualBossName or "none"
    local currentStage = self.currentStage or "none"
    local matchingRule = self:GetMatchingRule()
    local baseAllowed = self:PassesBaseVisibility() and self:PassesCombatTiming()
    local phaseAllowed = self:PassesPhaseRules()
    local ruleStatus
    if not db.phaseRulesEnabled then
        ruleStatus = "Phase rules off"
    elseif not next(db.rules or {}) then
        ruleStatus = "No rules"
    elseif matchingRule then
        ruleStatus = "Rule " .. self:FormatPhaseList(matchingRule.phases) .. (phaseAllowed and " allows" or " hides")
    else
        ruleStatus = "No matching rule"
    end

    panel.statusText:SetText(
        "Current: " .. tostring(currentBoss) .. " P" .. tostring(currentStage) ..
        "  Base: " .. (baseAllowed and "allows" or "hides") ..
        "  " .. ruleStatus
    )
end

function WC:RefreshOptionsPanel()
    local panel = self.optionsPanel
    local db = self.db
    if not panel or not db then
        return
    end

    self.optionsUpdating = true
    db.shape = self:NormalizeShape(db.shape) or "Cross"

    panel.lockButton:SetText(db.locked and "Unlock" or "Lock")
    panel.enabledCheck:SetChecked(db.enabled)
    panel.previewCheck:SetChecked(db.showWhileUnlocked)
    panel.horizontalCheck:SetChecked(db.lockHorizontal)
    panel.phaseCheck:SetChecked(db.phaseRulesEnabled)
    local keys = {}
    for key in pairs(db.rules or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys)

    local visibleRuleCount = math.min(#keys, #(panel.ruleRows or {}))
    local phaseRuleHeight = phaseRuleBaseHeight + (visibleRuleCount * 30)
    panel.phaseRuleFrame:SetShown(db.phaseRulesEnabled)
    panel.phaseRuleFrame:SetHeight(phaseRuleHeight)
    panel.content:SetHeight(1020 + (db.phaseRulesEnabled and math.max(0, phaseRuleHeight - 218) or 0))
    panel.classColorCheck:ClearAllPoints()
    if db.phaseRulesEnabled then
        panel.classColorCheck:SetPoint("TOPLEFT", panel.phaseRuleFrame, "BOTTOMLEFT", 0, -12)
    else
        panel.classColorCheck:SetPoint("TOPLEFT", panel.phaseCheck, "BOTTOMLEFT", 0, -8)
    end
    panel.classColorCheck:SetChecked(db.class_colored)
    panel.colorButton:SetText(db.class_colored and "Custom Color" or "Edit Color")
    panel.colorSwatch.tex:SetColorTexture(db.customR or 1, db.customG or 1, db.customB or 1, 1)
    UIDropDownMenu_SetSelectedValue(panel.visibilityDropdown, db.visibility)
    UIDropDownMenu_SetText(panel.visibilityDropdown, self.visibilityLabels[db.visibility] or db.visibility)
    UIDropDownMenu_SetSelectedValue(panel.shapeDropdown, db.shape)
    UIDropDownMenu_SetText(panel.shapeDropdown, self.shapeLabels[db.shape] or db.shape)
    UIDropDownMenu_SetText(panel.encounterIDDropdown, "Select encounter ID")
    panel.timingCheck:SetChecked(db.combatTimingEnabled)

    panel.alphaSlider:SetValue(db.alpha)
    panel.thicknessSlider:SetValue(db.thickness)
    panel.innerLengthSlider:SetValue(db.inner_length)
    panel.widthSlider:SetValue(db.width or db.inner_length)
    panel.heightSlider:SetValue(db.height or db.inner_length)
    panel.borderSlider:SetValue(db.border_size)
    panel.fillSlider:SetValue(db.fill or 0)
    panel.showAfterSlider:SetValue(db.combatShowAfter or 0)
    panel.hideAfterSlider:SetValue(db.combatHideAfter or 0)
    panel.lingerSlider:SetValue(db.combatEndDelay or 0)

    local canFill = db.shape == "Circle" or db.shape == "Square"
    local canUseAxes = db.shape == "Cross" or db.shape == "Square"
    panel.thicknessSlider:SetEnabled(true)
    panel.thicknessSlider:SetAlpha(1)
    panel.widthSlider:SetEnabled(canUseAxes)
    panel.widthSlider:SetAlpha(canUseAxes and 1 or 0.45)
    panel.heightSlider:SetEnabled(canUseAxes)
    panel.heightSlider:SetAlpha(canUseAxes and 1 or 0.45)
    panel.borderSlider:SetEnabled(true)
    panel.borderSlider:SetAlpha(1)
    panel.fillSlider:SetEnabled(canFill)
    panel.fillSlider:SetAlpha(canFill and 1 or 0.45)

    self:RefreshPhaseRuleStatus()

    for index, row in ipairs(panel.ruleRows) do
        local key = keys[index]
        if key then
            local rule = db.rules[key]
            row.text:SetText((rule.label or key) .. " -> " .. self:FormatPhaseList(rule.phases))
            row.editButton.ruleKey = key
            row.deleteButton.ruleKey = key
            row.text:Show()
            row.editButton:Show()
            row.deleteButton:Show()
        else
            row.editButton.ruleKey = nil
            row.deleteButton.ruleKey = nil
            row.text:SetText("")
            row.text:Hide()
            row.editButton:Hide()
            row.deleteButton:Hide()
        end
    end

    self.optionsUpdating = false
end
