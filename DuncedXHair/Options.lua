local _, ns = ...
local WC = ns.DuncedXHair or _G.DuncedXHair

if not WC then
    return
end

local panelName = "DuncedXHairOptionsPanel"
local controlIndex = 0

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
        WC:RefreshOptionsPanel()
    end)

    return slider
end

local function makeEditBox(parent, width)
    local box = CreateFrame("EditBox", nextName("EditBox"), parent, "InputBoxTemplate")
    box:SetSize(width, 24)
    box:SetAutoFocus(false)
    return box
end

local function makeDropdown(parent, width, values, onSelect)
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
            info.func = function()
                onSelect(value.value)
                UIDropDownMenu_SetSelectedValue(dropdown, value.value)
                WC:ApplySettings()
                WC:RefreshOptionsPanel()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    return dropdown
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

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("DuncedXHair")

    local lockButton = makeButton(panel, "Unlock", 96)
    lockButton:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -18)
    lockButton:SetScript("OnClick", function()
        self:SetLocked(not self.db.locked)
        self:RefreshOptionsPanel()
    end)
    panel.lockButton = lockButton

    local centerButton = makeButton(panel, "Center", 96)
    centerButton:SetPoint("LEFT", lockButton, "RIGHT", 8, 0)
    centerButton:SetScript("OnClick", function()
        self:Center()
        self:RefreshOptionsPanel()
    end)

    local enabled = makeCheck(panel, "Enabled", function(value)
        self.db.enabled = value
    end)
    enabled:SetPoint("TOPLEFT", lockButton, "BOTTOMLEFT", 0, -18)
    panel.enabledCheck = enabled

    local preview = makeCheck(panel, "Show while unlocked", function(value)
        self.db.showWhileUnlocked = value
    end)
    preview:SetPoint("TOPLEFT", enabled, "BOTTOMLEFT", 0, -8)
    panel.previewCheck = preview

    local horizontal = makeCheck(panel, "Lock horizontal position", function(value)
        self.db.lockHorizontal = value
        self:SavePosition()
    end)
    horizontal:SetPoint("TOPLEFT", preview, "BOTTOMLEFT", 0, -8)
    panel.horizontalCheck = horizontal

    local phaseOnly = makeCheck(panel, "Use boss phase rules", function(value)
        self.db.phaseRulesEnabled = value
    end)
    phaseOnly:SetPoint("TOPLEFT", horizontal, "BOTTOMLEFT", 0, -8)
    panel.phaseCheck = phaseOnly

    local classColor = makeCheck(panel, "Use class color", function(value)
        self.db.class_colored = value
        self:UpdateColor()
    end)
    classColor:SetPoint("TOPLEFT", phaseOnly, "BOTTOMLEFT", 0, -8)
    panel.classColorCheck = classColor

    local colorButton = makeButton(panel, "Custom Color", 116)
    colorButton:SetPoint("LEFT", classColor, "RIGHT", 160, 0)
    colorButton:SetScript("OnClick", function()
        openColorPicker(classColor)
    end)
    panel.colorButton = colorButton

    local colorSwatch = CreateFrame("Button", nextName("ColorSwatch"), panel)
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

    local visibilityLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    visibilityLabel:SetPoint("TOPLEFT", classColor, "BOTTOMLEFT", 0, -16)
    visibilityLabel:SetText("Visibility")

    local visibilityValues = {
        { text = "Always", value = "Always" },
        { text = "In Combat", value = "Combat" },
        { text = "In Instance", value = "Instance" },
        { text = "In Combat + In Instance", value = "CombatAndInstance" },
        { text = "In Combat or In Instance", value = "CombatOrInstance" },
    }
    local visibility = makeDropdown(panel, 190, visibilityValues, function(value)
        self.db.visibility = value
    end)
    visibility:SetPoint("TOPLEFT", visibilityLabel, "BOTTOMLEFT", -16, -2)
    panel.visibilityDropdown = visibility

    local shapeLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    shapeLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 360, -18)
    shapeLabel:SetText("Shape")

    local shapeValues = {
        { text = "Cross", value = "Cross" },
        { text = "Circle", value = "Circle" },
        { text = "Square", value = "Square" },
        { text = "Unicode", value = "Unicode" },
    }
    local shape = makeDropdown(panel, 140, shapeValues, function(value)
        self.db.shape = value
    end)
    shape:SetPoint("TOPLEFT", shapeLabel, "BOTTOMLEFT", -16, -2)
    panel.shapeDropdown = shape

    local symbolLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    symbolLabel:SetPoint("TOPLEFT", shape, "BOTTOMLEFT", 16, -12)
    symbolLabel:SetText("Unicode symbol")

    local symbol = makeDropdown(panel, 140, self.unicodeSymbolValues, function(value)
        self.db.shape = "Unicode"
        self.db.unicodeSymbol = value
    end)
    symbol:SetPoint("TOPLEFT", symbolLabel, "BOTTOMLEFT", -16, -2)
    panel.unicodeSymbolDropdown = symbol

    local glyphWeightLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    glyphWeightLabel:SetPoint("TOPLEFT", symbol, "BOTTOMLEFT", 16, -12)
    glyphWeightLabel:SetText("Unicode weight")

    local glyphWeightValues = {
        { text = "Light", value = "Light" },
        { text = "Regular", value = "Regular" },
        { text = "Medium", value = "Medium" },
        { text = "Bold", value = "Bold" },
    }
    local glyphWeight = makeDropdown(panel, 140, glyphWeightValues, function(value)
        self.db.glyphWeight = value
    end)
    glyphWeight:SetPoint("TOPLEFT", glyphWeightLabel, "BOTTOMLEFT", -16, -2)
    panel.glyphWeightDropdown = glyphWeight

    local timing = makeCheck(panel, "Use combat timing", function(value)
        self.db.combatTimingEnabled = value
        self:UpdateCombatTicker()
    end)
    timing:SetPoint("TOPLEFT", glyphWeight, "BOTTOMLEFT", 16, -14)
    panel.timingCheck = timing

    local showAfter = makeSlider(panel, "Show after combat start", 0, 120, 1, function(value)
        self.db.combatShowAfter = value
        self.db.combatTimingEnabled = true
        self:UpdateCombatTicker()
    end)
    showAfter:SetPoint("TOPLEFT", timing, "BOTTOMLEFT", 4, -30)
    showAfter:SetWidth(190)
    panel.showAfterSlider = showAfter

    local hideAfter = makeSlider(panel, "Hide after combat time", 0, 600, 1, function(value)
        self.db.combatHideAfter = value
        self.db.combatTimingEnabled = true
        self:UpdateCombatTicker()
    end)
    hideAfter:SetPoint("TOPLEFT", showAfter, "BOTTOMLEFT", 0, -38)
    hideAfter:SetWidth(190)
    panel.hideAfterSlider = hideAfter

    local linger = makeSlider(panel, "Linger after combat", 0, 120, 1, function(value)
        self.db.combatEndDelay = value
        self.db.combatTimingEnabled = true
        self:UpdateCombatTicker()
    end)
    linger:SetPoint("TOPLEFT", hideAfter, "BOTTOMLEFT", 0, -38)
    linger:SetWidth(190)
    panel.lingerSlider = linger

    local alpha = makeSlider(panel, "Alpha", 0, 1, 0.01, function(value)
        self.db.alpha = value
    end)
    alpha:SetPoint("TOPLEFT", visibility, "BOTTOMLEFT", 20, -30)
    alpha:SetWidth(220)
    panel.alphaSlider = alpha

    local thickness = makeSlider(panel, "Thickness", 1, 32, 1, function(value)
        self.db.thickness = value
    end)
    thickness:SetPoint("TOPLEFT", alpha, "BOTTOMLEFT", 0, -38)
    thickness:SetWidth(220)
    panel.thicknessSlider = thickness

    local innerLength = makeSlider(panel, "Inner length", 4, 256, 1, function(value)
        self.db.inner_length = value
    end)
    innerLength:SetPoint("TOPLEFT", thickness, "BOTTOMLEFT", 0, -38)
    innerLength:SetWidth(220)
    panel.innerLengthSlider = innerLength

    local border = makeSlider(panel, "Border size", 0, 64, 1, function(value)
        self.db.border_size = value
    end)
    border:SetPoint("TOPLEFT", innerLength, "BOTTOMLEFT", 0, -38)
    border:SetWidth(220)
    panel.borderSlider = border

    local fill = makeSlider(panel, "Fill amount", 0, 1, 0.01, function(value)
        self.db.fill = value
    end)
    fill:SetPoint("TOPLEFT", border, "BOTTOMLEFT", 0, -38)
    fill:SetWidth(220)
    panel.fillSlider = fill

    local ruleTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    ruleTitle:SetPoint("TOPLEFT", fill, "BOTTOMLEFT", -4, -34)
    ruleTitle:SetText("Boss phase rules")

    local bossLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    bossLabel:SetPoint("TOPLEFT", ruleTitle, "BOTTOMLEFT", 0, -12)
    bossLabel:SetText("Boss or id:encounterID")

    local bossBox = makeEditBox(panel, 220)
    bossBox:SetPoint("TOPLEFT", bossLabel, "BOTTOMLEFT", 4, -4)
    panel.bossBox = bossBox

    local phaseLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    phaseLabel:SetPoint("LEFT", bossLabel, "RIGHT", 152, 0)
    phaseLabel:SetText("Phases")

    local phaseBox = makeEditBox(panel, 120)
    phaseBox:SetPoint("TOPLEFT", phaseLabel, "BOTTOMLEFT", 4, -4)
    panel.phaseBox = phaseBox

    local saveRule = makeButton(panel, "Save", 80)
    saveRule:SetPoint("LEFT", phaseBox, "RIGHT", 10, 0)
    saveRule:SetScript("OnClick", function()
        local ok, message = self:SetRule(bossBox:GetText(), phaseBox:GetText())
        if not ok then
            self:Print(message)
        end
        bossBox:ClearFocus()
        phaseBox:ClearFocus()
        self:RefreshOptionsPanel()
    end)

    local deleteRule = makeButton(panel, "Delete", 80)
    deleteRule:SetPoint("LEFT", saveRule, "RIGHT", 8, 0)
    deleteRule:SetScript("OnClick", function()
        local ok, message = self:DeleteRule(bossBox:GetText())
        if not ok then
            self:Print(message)
        end
        self:RefreshOptionsPanel()
    end)

    bossBox:SetScript("OnEnterPressed", function()
        saveRule:Click()
    end)
    phaseBox:SetScript("OnEnterPressed", function()
        saveRule:Click()
    end)

    local status = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", bossBox, "BOTTOMLEFT", -4, -16)
    status:SetText("")
    panel.statusText = status

    panel.ruleRows = {}
    for index = 1, 8 do
        local row = {}
        row.text = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        if index == 1 then
            row.text:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -10)
        else
            row.text:SetPoint("TOPLEFT", panel.ruleRows[index - 1].text, "BOTTOMLEFT", 0, -8)
        end
        row.text:SetWidth(330)
        row.text:SetJustifyH("LEFT")

        row.button = makeButton(panel, "Delete", 70)
        row.button:SetPoint("LEFT", row.text, "RIGHT", 8, 0)
        row.button:SetScript("OnClick", function(button)
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

function WC:RefreshOptionsPanel()
    local panel = self.optionsPanel
    local db = self.db
    if not panel or not db then
        return
    end

    self.optionsUpdating = true

    panel.lockButton:SetText(db.locked and "Unlock" or "Lock")
    panel.enabledCheck:SetChecked(db.enabled)
    panel.previewCheck:SetChecked(db.showWhileUnlocked)
    panel.horizontalCheck:SetChecked(db.lockHorizontal)
    panel.phaseCheck:SetChecked(db.phaseRulesEnabled)
    panel.classColorCheck:SetChecked(db.class_colored)
    panel.colorButton:SetText(db.class_colored and "Custom Color" or "Edit Color")
    panel.colorSwatch.tex:SetColorTexture(db.customR or 1, db.customG or 1, db.customB or 1, 1)
    UIDropDownMenu_SetSelectedValue(panel.visibilityDropdown, db.visibility)
    UIDropDownMenu_SetText(panel.visibilityDropdown, self.visibilityLabels[db.visibility] or db.visibility)
    UIDropDownMenu_SetSelectedValue(panel.shapeDropdown, db.shape)
    UIDropDownMenu_SetText(panel.shapeDropdown, self.shapeLabels[db.shape] or db.shape)
    local unicodeSymbol = self:NormalizeUnicodeSymbol(db.unicodeSymbol) or "+"
    UIDropDownMenu_SetSelectedValue(panel.unicodeSymbolDropdown, unicodeSymbol)
    UIDropDownMenu_SetText(panel.unicodeSymbolDropdown, unicodeSymbol)
    local glyphWeight = self:NormalizeGlyphWeight(db.glyphWeight) or "Regular"
    UIDropDownMenu_SetSelectedValue(panel.glyphWeightDropdown, glyphWeight)
    UIDropDownMenu_SetText(panel.glyphWeightDropdown, self.glyphWeightLabels[glyphWeight] or glyphWeight)
    panel.timingCheck:SetChecked(db.combatTimingEnabled)

    panel.alphaSlider:SetValue(db.alpha)
    panel.thicknessSlider:SetValue(db.thickness)
    panel.innerLengthSlider:SetValue(db.inner_length)
    panel.borderSlider:SetValue(db.border_size)
    panel.fillSlider:SetValue(db.fill or 0)
    panel.showAfterSlider:SetValue(db.combatShowAfter or 0)
    panel.hideAfterSlider:SetValue(db.combatHideAfter or 0)
    panel.lingerSlider:SetValue(db.combatEndDelay or 0)

    local canFill = db.shape == "Circle" or db.shape == "Square"
    local isUnicode = db.shape == "Unicode"
    panel.fillSlider:SetEnabled(canFill)
    panel.fillSlider:SetAlpha(canFill and 1 or 0.45)
    panel.unicodeSymbolDropdown:SetAlpha(isUnicode and 1 or 0.45)
    panel.glyphWeightDropdown:SetAlpha(isUnicode and 1 or 0.45)

    local currentBoss = self.currentEncounterName or self.currentBossModName or self.manualBossName or "none"
    local currentStage = self.currentStage or "none"
    panel.statusText:SetText("Current boss: " .. tostring(currentBoss) .. "  Phase: " .. tostring(currentStage))

    local keys = {}
    for key in pairs(db.rules or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys)

    for index, row in ipairs(panel.ruleRows) do
        local key = keys[index]
        if key then
            local rule = db.rules[key]
            row.text:SetText((rule.label or key) .. " -> " .. self:FormatPhaseList(rule.phases))
            row.button.ruleKey = key
            row.text:Show()
            row.button:Show()
        else
            row.button.ruleKey = nil
            row.text:SetText("")
            row.text:Hide()
            row.button:Hide()
        end
    end

    self.optionsUpdating = false
end
