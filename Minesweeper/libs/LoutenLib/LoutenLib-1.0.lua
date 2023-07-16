local addOn
local dropdownlists = {}
local streams = {}





function CreateNewFrame(parent)
    local uiFrame
    if (parent.ScrollChild) then
        uiFrame = CreateFrame("Frame", nil, parent.ScrollChild)
    else
        uiFrame = CreateFrame("Frame", nil, parent)
    end

    function uiFrame:InitNewFrame(  width, height,
                                    point, pointParent, pointTo, pointX, pointY,
                                    redColorBg, greenColorBg, blueColorBg, alphaColorBg,
                                    enableMouse,
                                    movable, functionOnDragStop)

        self:SetSize(width, height)
        if (pointParent) then
            if (pointParent.ScrollChild) then
                self:SetPoint(point, pointParent.ScrollChild, pointTo, pointX, pointY)
            else
                self:SetPoint(point, pointParent, pointTo, pointX, pointY)
            end
        else
            self:SetPoint(point, pointParent, pointTo, pointX, pointY)
        end
        self.Texture = self:CreateTexture()
        self.Texture:SetAllPoints()
        self.Texture:SetTexture(redColorBg, greenColorBg, blueColorBg, alphaColorBg) -- 0.735 alpha = 1 tooltip alpha
        self:EnableMouse(enableMouse)
        self:SetMovable(movable)

        if (movable) then
            self:RegisterForDrag("LeftButton")
            self:SetScript("OnDragStart", self.StartMoving)
            self:SetScript("OnDragStop", function()
                self:StopMovingOrSizing()
                if (functionOnDragStop) then functionOnDragStop() end
            end)
        end
    end

    function uiFrame:InitNewButton( redColorOnEnter, greenColorOnEnter, blueColorOnEnter, alphaColorOnEnter,
                                    redColorOnLeave, greenColorOnLeave, blueColorOnLeave, alphaColorOnLeave,
                                    redColorOnMouseDown, greenColorOnMouseDown, blueColorOnMouseDown, alphaColorOnMouseDown,
                                    redColorOnMouseUp, greenColorOnMouseUp, blueColorOnMouseUp, alphaColorOnMouseUp,
                                    functionOnMouseDown, functionOnMouseUp)

        self:SetScript("OnEnter", function ()
            if (self:IsTexture()) then
                self.Texture:SetTexture(redColorOnEnter, greenColorOnEnter, blueColorOnEnter, alphaColorOnEnter)
            else
                self:SetBackdropColor(redColorOnEnter, greenColorOnEnter, blueColorOnEnter, alphaColorOnEnter)
            end
        end)

        self:SetScript("OnLeave", function ()
            if (not self.IsPressed) then
                if (self:IsTexture()) then
                    self.Texture:SetTexture(redColorOnLeave, greenColorOnLeave, blueColorOnLeave, alphaColorOnLeave)
                else
                    self:SetBackdropColor(redColorOnLeave, greenColorOnLeave, blueColorOnLeave, alphaColorOnLeave)
                end
            end
        end)

        self:SetScript("OnMouseDown", function ()
            self.IsPressed = true
            if (self:IsTexture()) then
                self.Texture:SetTexture(redColorOnMouseDown, greenColorOnMouseDown, blueColorOnMouseDown, alphaColorOnMouseDown)
            else
                self:SetBackdropColor(redColorOnMouseDown, greenColorOnMouseDown, blueColorOnMouseDown, alphaColorOnMouseDown)
            end
            if (functionOnMouseDown) then
                functionOnMouseDown()
                if (not self:IsShown()) then
                    self.IsPressed = false
                end
            end
        end)

        self:SetScript("OnMouseUp", function ()
            self.IsPressed = false
            if (self:IsMouseOver()) then
                self.Texture:SetTexture(redColorOnMouseUp, greenColorOnMouseUp, blueColorOnMouseUp, alphaColorOnMouseUp)
            else
                self.Texture:SetTexture(redColorOnLeave, greenColorOnLeave, blueColorOnLeave, alphaColorOnLeave)
            end

            if (functionOnMouseUp) then functionOnMouseUp() end
        end)
    end

    function uiFrame:InitNewInput(  fontSize, maxLetterx,
                                    redFontColor, greenFontColor, blueFontColor, alphaFontColor,
                                    functionOnTextChanged, functionOnEnterPressed)

        self.EditBox = CreateFrame("EditBox", nil, self)
        self.EditBox:SetPoint("CENTER", 0, 0)
        self.EditBox:SetWidth(self:GetWidth() - 16)
        self.EditBox:SetHeight(self:GetHeight() - 2)
        self.EditBox:SetFont("Interface\\AddOns\\"..addOn.Info.FileName.."\\fonts\\verdana_normal.ttf", fontSize)
        self.EditBox:SetTextColor(redFontColor, greenFontColor, blueFontColor, alphaFontColor)
        self.EditBox:SetJustifyH("LEFT")
        self.EditBox:EnableMouse(true)
        self.EditBox:SetAutoFocus(false)
        self.EditBox:SetMaxLetters(maxLetterx)
        self.EditBox:SetScript("OnEscapePressed", function ()
            self.EditBox:ClearFocus()
        end)
        self.EditBox:SetScript("OnTextChanged", function ()
            if (functionOnTextChanged) then functionOnTextChanged() end
        end)
        self.EditBox:SetScript("OnEnterPressed", function()
            if (functionOnEnterPressed) then functionOnEnterPressed() end
        end)
    end

    function uiFrame:SetTextToFrame(point, pointParent, pointTo, pointX, pointY,
                                    isTextBold, textSize,
                                    text)
        self.Text = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        self.Text:SetPoint(point, pointParent, pointTo, pointX, pointY)
        self.Text:SetText(text)

        if (isTextBold) then
            self.Text:SetFont("Interface\\AddOns\\"..addOn.Info.FileName.."\\fonts\\verdana_bold.ttf", textSize)
        else
            self.Text:SetFont("Interface\\AddOns\\"..addOn.Info.FileName.."\\fonts\\verdana_normal.ttf", textSize)
        end
    end

    function uiFrame:InitNewCheckButton(size, setChecked, text, boldText, textSize, functionOnClick)
        self.CheckButton = CreateFrame("CheckButton", nil, self, "InterfaceOptionsCheckButtonTemplate")
        self.CheckButton:SetSize(size, size)
        self.CheckButton:SetPoint("LEFT", self, "LEFT", -3, 0)
        self.CheckButton:SetChecked(setChecked)
        
        if (text) then
            self:SetTextToFrame("LEFT", self, "LEFT", 24, 2, boldText, textSize, text)
            self.Text:SetJustifyH("LEFT")
        end
    
        self.CheckButton:SetScript("OnClick", function()
            if (functionOnClick) then functionOnClick() end
        end)
    end

    function uiFrame:InitNewDropDownList(buttW, buttH, listMultipW, listMultipH,
                                         redColorOnEnter, greenColorOnEnter, blueColorOnEnter, alphaColorOnEnter,
                                         redColorOnLeave, greenColorOnLeave, blueColorOnLeave, alphaColorOnLeave,
                                         redColorOnMouseDown, greenColorOnMouseDown, blueColorOnMouseDown, alphaColorOnMouseDown,
                                         redColorOnMouseUp, greenColorOnMouseUp, blueColorOnMouseUp, alphaColorOnMouseUp, 
                                         arrayWithEl, buttText, func, type, addOptional)

        self.DropDownButton = CreateNewFrame(self)
        self.DropDownList = CreateNewFrame(self)
        self.DropDownList.Elements = {}
        dropdownlists[#dropdownlists+1] = self
        self.DropDownButton.Arrow = CreateNewFrame(self.DropDownButton)
        self.DropDownList:Hide()

        self.DropDownButton:InitNewFrame(buttW, buttH,
                                        "LEFT", self, "LEFT", 0, 0,
                                        redColorOnLeave, greenColorOnLeave, blueColorOnLeave, alphaColorOnLeave,
                                        true, false, nil)

        self.DropDownButton.Arrow:InitNewFrame(self.DropDownButton:GetHeight()/1.5, self.DropDownButton:GetHeight()/1.5,
                                                    "RIGHT", self.DropDownButton, "RIGHT", -(self.DropDownButton:GetHeight()*0.1), 0,
                                                    0,0,0,0,
                                                    false, false, nil)
        self.DropDownButton.Arrow.Texture:SetTexture("Interface\\AddOns\\"..addOn.Info.FileName.."\\textures\\movedown.tga")

        self.DropDownButton:InitNewButton(redColorOnEnter, greenColorOnEnter, blueColorOnEnter, alphaColorOnEnter,
                                            redColorOnLeave, greenColorOnLeave, blueColorOnLeave, alphaColorOnLeave,
                                            redColorOnMouseDown, greenColorOnMouseDown, blueColorOnMouseDown, alphaColorOnMouseDown,
                                            redColorOnMouseUp, greenColorOnMouseUp, blueColorOnMouseUp, alphaColorOnMouseUp, 
                                            nil,
                                            function()
                                                if (self.DropDownList:IsShown()) then
                                                    ---------------------
                                                    -- close animation -- 
                                                    self.DropDownButton:EnableMouse(false)
                                                    self.DropDownList.Texture:SetTexture(0,0,0,0)
                                                    for i = 1, #arrayWithEl do
                                                        self.DropDownList.Elements[i]:EnableMouse(false)
                                                    end

                                                    local openAnimF = CreateFrame("Frame")
                                                    local animSpeed
                                                    local alpha = 1
                                                    local indexEl = #arrayWithEl
                                                    openAnimF:SetScript("OnUpdate", function()
                                                        self.DropDownList.Elements[indexEl]:SetAlpha(alpha)
                                                        if (GetFramerate() < 30) then
                                                            animSpeed = 0.25
                                                        elseif (GetFramerate() >= 30 and GetFramerate() <= 60) then
                                                            animSpeed =  0.20
                                                        else
                                                            animSpeed = 0.15
                                                        end
                                                        -- animation acceleration
                                                        local animAccel = animSpeed / 100 * #arrayWithEl
                                                        alpha = alpha - (animSpeed + animAccel)
                                                        if (alpha < 0) then
                                                            self.DropDownList.Elements[indexEl]:SetAlpha(0)
                                                            alpha = 1
                                                            indexEl = indexEl - 1
                                                            if (indexEl < 1) then
                                                                self.DropDownList:Hide()
                                                                self.DropDownButton:EnableMouse(true)
                                                                for i = 1, #arrayWithEl do
                                                                    self.DropDownList.Elements[i]:EnableMouse(true)
                                                                end
                                                                openAnimF:SetScript("OnUpdate", nil)
                                                            end
                                                        end
                                                    end)
                                                    -- close animation --
                                                    ---------------------

                                                    self.DropDownButton.Arrow.Texture:SetTexture("Interface\\AddOns\\"..addOn.Info.FileName.."\\textures\\movedown.tga")
                                                else
                                                    self.DropDownList:Show()
                                                    
                                                    --------------------
                                                    -- open animation -- 
                                                    self.DropDownList.Texture:SetTexture(0,0,0,0)
                                                    self.DropDownButton:EnableMouse(false)
                                                    for i = 1, #arrayWithEl do
                                                        self.DropDownList.Elements[i]:EnableMouse(false)
                                                        self.DropDownList.Elements[i]:SetAlpha(0)
                                                    end

                                                    local openAnimF = CreateFrame("Frame")
                                                    local animSpeed
                                                    local alpha = 0
                                                    local indexEl = 1
                                                    openAnimF:SetScript("OnUpdate", function()
                                                        self.DropDownList.Elements[indexEl]:SetAlpha(alpha)
                                                        if (GetFramerate() < 30) then
                                                            animSpeed = 0.25
                                                        elseif (GetFramerate() >= 30 and GetFramerate() <= 60) then
                                                            animSpeed =  0.20
                                                        else
                                                            animSpeed = 0.15
                                                        end
                                                        -- animation acceleration
                                                        local animAccel = animSpeed / 100 * #arrayWithEl
                                                        alpha = alpha + (animSpeed + animAccel)
                                                        if (alpha >= 1) then
                                                            alpha = 0
                                                            indexEl = indexEl + 1
                                                            if (indexEl > #arrayWithEl) then
                                                                self.DropDownList.Texture:SetTexture(0,0,0,1)
                                                                self.DropDownButton:EnableMouse(true)
                                                                for i = 1, #arrayWithEl do
                                                                    self.DropDownList.Elements[i]:EnableMouse(true)
                                                                end
                                                                openAnimF:SetScript("OnUpdate", nil)
                                                            end
                                                        end
                                                    end)
                                                    -- open animation --
                                                    --------------------


                                                    self.DropDownButton.Arrow.Texture:SetTexture("Interface\\AddOns\\"..addOn.Info.FileName.."\\textures\\moveup.tga")
                                                    for i = 1, #dropdownlists do
                                                        if (self ~= dropdownlists[i]) then
                                                            dropdownlists[i].DropDownList:Hide()
                                                            dropdownlists[i].DropDownButton.Arrow.Texture:SetTexture("Interface\\AddOns\\"..addOn.Info.FileName.."\\textures\\movedown.tga")
                                                        end
                                                    end
                                                end
                                            end)
        self.DropDownButton:SetScript("OnEnter", function ()
            self.DropDownButton.Texture:SetTexture(redColorOnLeave, greenColorOnLeave, blueColorOnLeave, alphaColorOnLeave)
        end)
        self.DropDownButton:SetTextToFrame("CENTER", self.DropDownButton, "CENTER", 0,0,
                                            true, buttH / 2.1, buttText)





        self.DropDownList:InitNewFrame(buttW * listMultipW, (buttH * #arrayWithEl) * listMultipH,
                                        "BOTTOMLEFT", self.DropDownButton, "BOTTOMLEFT", 0, -(buttH * #arrayWithEl) * listMultipH,
                                        0, 0, 0, 1,
                                        true, false, nil)

        self.DropDownList:SetFrameStrata("HIGH")
        self.DropDownList:SetFrameLevel(self.DropDownList:GetFrameLevel()+10)
        for i = 1, #arrayWithEl do
            self.DropDownList.Elements[i] = CreateNewFrame(self.DropDownList)

            self.DropDownList.Elements[i]:InitNewFrame(self.DropDownList:GetWidth(), self.DropDownList:GetHeight() / #arrayWithEl,
                                                        "TOP", self.DropDownList, "TOP", 0,0,
                                                        redColorOnMouseDown, greenColorOnMouseDown, blueColorOnMouseDown, alphaColorOnMouseDown,
                                                        true, false, nil)

            if (i == 1) then
                self.DropDownList.Elements[i]:SetPoint("TOP", self.DropDownList, "TOP")
            else
                self.DropDownList.Elements[i]:SetPoint("TOP", self.DropDownList.Elements[i - 1], "TOP", 0, -(self.DropDownList.Elements[i]:GetHeight()))
            end

            if (type == "Button") then
                self.DropDownList.Elements[i]:SetTextToFrame("CENTER", self.DropDownList.Elements[i], "CENTER", 0, 0,
                                                                true, buttH / 2.2, arrayWithEl[i])

                self.DropDownList.Elements[i]:InitNewButton(redColorOnEnter, greenColorOnEnter, blueColorOnEnter, alphaColorOnEnter - .3,
                                                            redColorOnMouseDown, greenColorOnMouseDown, blueColorOnMouseDown, alphaColorOnMouseDown,
                                                            redColorOnEnter, greenColorOnEnter, blueColorOnEnter, alphaColorOnEnter - .5,
                                                            redColorOnEnter, greenColorOnEnter, blueColorOnEnter, alphaColorOnEnter - .3,
                                                            nil, func[i])
            end

            if (type == "CheckButton") then
                self.DropDownList.Elements[i]:InitNewCheckButton(self:GetHeight()*1.1, addOptional[i], arrayWithEl[i], buttH / 2.2, func[i])
            end
        end
    end

    function uiFrame:AddScrollToFrame()
        self:EnableMouseWheel(true)
    
        self.ScrollFrame = CreateFrame("ScrollFrame", nil, self)
        self.ScrollChild = CreateFrame("Frame")

        self.ScrollBar = CreateFrame("Slider", nil, self.ScrollFrame, "UIPanelScrollBarTemplate")
        self.ScrollBar:SetPoint("RIGHT", self, "RIGHT", -5, 0)
        self.ScrollBar:SetSize(10, self:GetHeight() - 40)
        self.ScrollBar:SetMinMaxValues(0, 10)
        self.ScrollBar:SetValue(0)
        self.ScrollBar:SetValueStep(1)
        self.ScrollBar:SetOrientation('VERTICAL')
        self.ScrollFrame:SetScrollChild(self.ScrollChild)

        self.ScrollFrame:SetAllPoints(self)
    
        self.ScrollChild:SetWidth(self.ScrollFrame:GetWidth()-10)
        self.ScrollChild:SetHeight(self.ScrollFrame:GetHeight())
    
    
        self:SetScript("OnMouseWheel", function (s, delta)
            self.ScrollBar:SetValue(self.ScrollBar:GetValue() - delta * 20)
            self.ScrollBar:SetMinMaxValues(0, self.ScrollFrame:GetVerticalScrollRange())
        end)
    
        self.ScrollBar:SetScript("OnMouseDown", function (s, button)
            self.ScrollBar:SetMinMaxValues(0, self.ScrollFrame:GetVerticalScrollRange())
        end)
    end

    function uiFrame:TextureToBackdrop(addBorders, bordersSize, insets, borderColorRed, borderColorGreen, borderColorBlue, borderColorAlpha,
                                        backdropColorRed, backdropColorGreen, backdropColorBlue, backdropColorAlpha)
        self.Texture:ClearAllPoints()
        self.Texture = nil

        if (addBorders) then
            self:SetBackdrop({
                bgFile = "Interface/Tooltips/UI-Tooltip-Background",
                edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
                edgeSize = bordersSize,
                insets = {left = insets, right = insets, top = insets, bottom = insets},
            });
            self:SetBackdropColor(backdropColorRed,backdropColorGreen,backdropColorBlue,backdropColorAlpha);
            self:SetBackdropBorderColor(borderColorRed, borderColorGreen, borderColorBlue, borderColorAlpha);
        else
            self:SetBackdrop({
                bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            })
            self:SetBackdropColor(backdropColorRed,backdropColorGreen,backdropColorBlue,backdropColorAlpha);
        end
    end

    function uiFrame:BackdropToTexture(redColorBg, greenColorBg, blueColorBg, alphaColorBg)
        self:SetBackdropColor(0,0,0,0)
        self:SetBackdropBorderColor(0,0,0,0)
        self:SetBackdrop({
            bgFile = nil,
            edgeFile = nil,
            edgeSize = nil,
            insets = nil,
        })

        self.Texture = self:CreateTexture()
        self.Texture:SetAllPoints()
        self.Texture:SetTexture(redColorBg, greenColorBg, blueColorBg, alphaColorBg) -- 0.735 alpha = 1 tooltip alpha
    end

    function uiFrame:IsTexture()
        if (self.Texture) then
            return true
        else
            return false
        end
    end

    return uiFrame
end

function DelayAction(time, func, cancelSameFunc)
    local startTime = GetTime()
    local endTime = startTime + time

    if (#streams > 0) then
        if (cancelSameFunc) then
            for i = 1, #streams do
                if (streams[i]) then
                    if (streams[i].fn == func) then
                        streams[i].f:SetScript("OnUpdate", nil)
                        streams[i] = nil
                    end
                end
            end
        end
    end

    streams[#streams+1] = { f = CreateFrame("Frame"), t = startTime, fn = func}

    for i = 1, #streams do
        if (streams[i]) then
            if (streams[i].t == startTime) then
                streams[i].f:SetScript("OnUpdate", function()
                    if (GetTime() >= endTime) then
                        streams[i].f:SetScript("OnUpdate", nil)
                        streams[i].f = nil
                        streams[i].t = nil
                        streams[i] = nil
                        func()
                        return 1
                    end
                end)
            end
        end
    end
end







function InitAddon(fileName, name, version)
    if (addOn) then return end
    
    addOn = {}
    addOn.Info = {}
    addOn.Info.FileName = fileName
    addOn.Info.Name = name
    addOn.Info.Version = version

    addOn.ChatPrefix = {}
    addOn.ChatPrefix.Color = "2499ed"
    addOn.ChatPrefix.Prefix = "|cff"..addOn.ChatPrefix.Color.."["..addOn.Info.Name.."]|r"

    ----------
    -- Chat --
    function addOn:SetChatPrefixColor(hex)
        self.ChatPrefix.Color = hex
        self.ChatPrefix.Prefix = "|cff"..self.ChatPrefix.Color.."["..addOn.Info.Name.."]|r"
    end

    function addOn:GetChatPrefixColor()
        return self.ChatPrefix.Color
    end

    function addOn:PrintMsg(msg, msgColor)
        if (msgColor) then
            print(self.ChatPrefix.Prefix.." |cff"..msgColor..msg.."|r")
        else
            print(self.ChatPrefix.Prefix.." "..msg)
        end
    end
    -- Chat --
    ----------
    
    --------------------
    -- Addon Revision --
    function addOn:SetRevision(year, month, day, major, minor, maintenance)
        self.Info.Revision = year..month..day..major..minor..maintenance
    end
    -- Addon Revision --
    --------------------

    --------------------------------
    -- Check Actual Addon Version --
    
        -- когда нибудь я сюда вернусь и перестану удалять код...

    -- Check Actual Addon Version --
    --------------------------------

    ------------------
    -- Addon Loaded --
    function addOn:LoadedFunction(func)
        addOn.LoadedFunc = func
    end
    addOn.LoadedFunc = nil
    addOn.Loaded = CreateFrame("Frame")
    addOn.Loaded:RegisterEvent("ADDON_LOADED")
    addOn.Loaded:SetScript("OnEvent", function(s, event, addOnName)
        if (addOnName == addOn.Info.FileName) then
            addOn:PrintMsg("Аддон загружен: v"..addOn.Info.Version, nil)
            if (addOn.LoadedFunction) then addOn.LoadedFunc() end
        end
    end)
    -- Addon Loaded --
    ------------------



    ------------------
    -- Notification --
    local notifWidth = 350
    local notifHeight = 140
    addOn.Notification = CreateNewFrame(UIParent)
    addOn.Notification:InitNewFrame(notifWidth, notifHeight,
                                    "BOTTOMRIGHT", nil, "BOTTOMRIGHT", -20, 20,
                                    0, 0, 0, 0.788,
                                    true, false, nil)
    addOn.Notification:Hide()
    addOn.Notification:SetFrameStrata("TOOLTIP")
    addOn.Notification.Header = CreateNewFrame(addOn.Notification)
    addOn.Notification.Header:InitNewFrame(addOn.Notification:GetWidth(), addOn.Notification:GetHeight() * 0.15,
                                            "TOP", addOn.Notification, "TOP", 0, 0,
                                            0,0,0,1,
                                            true, false, nil)
    addOn.Notification.Content = CreateNewFrame(addOn.Notification)
    addOn.Notification.Content:InitNewFrame(notifWidth * 0.95, (notifHeight - addOn.Notification.Header:GetHeight()) * 0.80,
                                                "TOP", addOn.Notification, "TOP", 0, -(addOn.Notification.Header:GetHeight()) - 7,
                                                0,0,0,0,
                                                false, false, nil)
    addOn.Notification.Content:SetTextToFrame("TOPLEFT", addOn.Notification.Content, "TOPLEFT", 0,0, true, 11, "")
    addOn.Notification.Content.Text:SetWidth(addOn.Notification.Content:GetWidth())
    addOn.Notification.Content.Text:SetJustifyH("LEFT")
    addOn.Notification.Header.Title = CreateNewFrame(addOn.Notification.Header)
    addOn.Notification.Header.Title:SetTextToFrame("LEFT", addOn.Notification.Header, "LEFT", 5, 0, true, 12, addOn.ChatPrefix.Prefix.." Уведомление!")
    addOn.Notification.Header.CloseButton = CreateNewFrame(addOn.Notification.Header)
    addOn.Notification.Header.CloseButton:InitNewFrame(addOn.Notification.Header:GetHeight(), addOn.Notification.Header:GetHeight(),
                                                        "RIGHT", addOn.Notification.Header, "RIGHT", 0, 0,
                                                        .05, .05, .05, 1,
                                                        true, false, nil)
    addOn.Notification.Header.CloseButton:SetTextToFrame("CENTER", addOn.Notification.Header.CloseButton, "CENTER", 0, 0, true, 11, "x")
    local notifAnimF = CreateFrame("Frame")
    local function notificationHide()
        notifAnimF:SetScript("OnUpdate", nil)
        addOn.Notification:SetHeight(notifHeight)
        addOn.Notification.Header.CloseButton.Texture:SetTexture(.05, .05, .05, 1)
        addOn.Notification:ClearAllPoints()
        addOn.Notification:SetPoint("BOTTOMRIGHT", nil, "BOTTOMRIGHT", notifWidth, 20)
        addOn.Notification:Hide()
    end
    local notifAnimCloseF = CreateFrame("Frame")
    local function notificationClose()
        addOn.Notification.Content:Hide()
        addOn.Notification.Content.AcceptButton:Hide()
        addOn.Notification.Content.DeclineButton:Hide()
        local h = addOn.Notification:GetHeight()
        notifAnimCloseF:SetScript("OnUpdate", function()
            if (GetFramerate() < 30) then
                h = h - 15
            elseif (GetFramerate() >= 30 and GetFramerate() < 60) then
                h = h - 10
            elseif (GetFramerate() >= 60) then
                h = h - 5
            end
            addOn.Notification:SetHeight(h)
            if (addOn.Notification:GetHeight() <= addOn.Notification.Header:GetHeight()) then
                notifAnimCloseF:SetScript("OnUpdate", nil)
                notificationHide()
            end
        end)
    end
    addOn.Notification.Header.CloseButton:InitNewButton(.1, .1, .1, 1,
                                                        .05, .05, .05, 1,
                                                        .1, .1, .1, 1,
                                                        .1, .1, .1, 1,
                                                        notificationClose, nil)

    addOn.Notification.Content.AcceptButton = CreateNewFrame(addOn.Notification.Content)
    addOn.Notification.Content.AcceptButton:InitNewFrame(75, 23,
                                                        "BOTTOM", addOn.Notification, "BOTTOM", -60, 0,
                                                        .25,1,.38,1, true, false, nil)
    addOn.Notification.Content.AcceptButton:SetTextToFrame("CENTER", addOn.Notification.Content.AcceptButton, "CENTER", 0,0, true, 12, "Принять")
    addOn.Notification.Content.AcceptButton:InitNewButton(.35,1,.48,1,
                                                            .25,1,.38,1,
                                                            .15,.85,.28,1,
                                                            .35,1,.48,1,
                                                            nil, nil)
    addOn.Notification.Content.DeclineButton = CreateNewFrame(addOn.Notification.Content)
    addOn.Notification.Content.DeclineButton:InitNewFrame(75, 23,
                                                        "BOTTOM", addOn.Notification, "BOTTOM", 60, 0,
                                                        .9,.2,.2,1, true, false, nil)
    addOn.Notification.Content.DeclineButton:SetTextToFrame("CENTER", addOn.Notification.Content.DeclineButton, "CENTER", 0,0, true, 12, "Отклонить")
    addOn.Notification.Content.DeclineButton:InitNewButton(.9,.3,.3,1,
                                                            .9,.2,.2,1,
                                                            .8,.2,.2,1,
                                                            .9,.3,.3,1,
                                                            nil, nil)
    addOn.Notification.Content.AcceptButton:Hide()
    addOn.Notification.Content.DeclineButton:Hide()
    local function notificationShow()
        notificationHide()
        addOn.Notification:Show()
        addOn.Notification.Content.Text:Show()
        addOn.Notification.Content:Show()
        local x = addOn.Notification:GetWidth()
        notifAnimF:SetScript("OnUpdate", function()
            if (GetFramerate() < 30) then
                x = x - 40
            elseif (GetFramerate() >= 30 and GetFramerate() < 60) then
                x = x - 30
            elseif (GetFramerate() >= 60) then
                x = x - 20
            end
            addOn.Notification:ClearAllPoints()
            addOn.Notification:SetPoint("BOTTOMRIGHT", nil, "BOTTOMRIGHT", x, 20)
            if (x <= -20) then
                notifAnimF:SetScript("OnUpdate", nil)
                addOn.Notification:SetPoint("BOTTOMRIGHT", nil, "BOTTOMRIGHT", -20, 20)
            end
        end)
    end

    function addOn:Notify(text, isChooser, acceptFunc, declineFunc)
        self.Notification.Content.Text:SetText(text)
        if (isChooser) then
            addOn.Notification.Content.AcceptButton:Show()
            addOn.Notification.Content.AcceptButton:SetScript("OnMouseDown", function()
                if (acceptFunc) then acceptFunc() end
                acceptFunc()
            end)
            addOn.Notification.Content.DeclineButton:Show()
            addOn.Notification.Content.DeclineButton:SetScript("OnMouseDown", function()
                if (declineFunc) then declineFunc() end
            end)
        end
        notificationShow()
        DelayAction(10, notificationClose, true)
    end

    function addOn:NotifyForceClose()
        notificationClose()
    end
    -- Notification --
    ------------------

    ------------------
    -- Data Storage --
    function addOn:SetDataStorage(DB)
        addOn.DBCopy = DB
    end

    --------------
    -- Settings --
    -- addOn.SettingsWindow = CreateNewFrame(UIParent)
    -- addOn.SettingsWindow:InitNewFrame(800, 570,
    --                                     "CENTER", nil, "CENTER", 0, 0,
    --                                     0, 0, 0, .735,
    --                                     true, true, nil)

    -- addOn.SettingsWindow.Header = CreateNewFrame(addOn.SettingsWindow)
    -- addOn.SettingsWindow.Header:InitNewFrame(addOn.SettingsWindow:GetWidth(), addOn.SettingsWindow:GetHeight() * 0.042,
    --                                             "TOP", addOn.SettingsWindow, "TOP", 0, 0,
    --                                             0,0,0,1,
    --                                             true, false, nil)
    -- addOn.SettingsWindow.Header.Title = CreateNewFrame(addOn.SettingsWindow.Header)
    -- addOn.SettingsWindow.Header.Title:SetTextToFrame("CENTER", addOn.SettingsWindow.Header, "CENTER", 0, -1, true, 12, addOn.Info.Name)
    -- addOn.SettingsWindow.Header.CloseButton = CreateNewFrame(addOn.SettingsWindow.Header)
    -- addOn.SettingsWindow.Header.CloseButton:InitNewFrame(addOn.SettingsWindow.Header:GetHeight(), addOn.SettingsWindow.Header:GetHeight(),
    --                                                         "RIGHT", addOn.SettingsWindow.Header, "RIGHT", 0, 0,
    --                                                         .2, 0, 0, 1,
    --                                                         true, false, nil)
    -- addOn.SettingsWindow.Header.CloseButton:SetTextToFrame("CENTER", addOn.SettingsWindow.Header.CloseButton, "CENTER", 0, 1, true, 15, "x")
    -- addOn.SettingsWindow.Header.CloseButton:InitNewButton(  .4, 0, 0, 1,
    --                                                         .2,0,0,1,
    --                                                         .25, 0, 0, 1,
    --                                                         .4, 0, 0, 1,
    --                                                         function()end, nil)
    --------------
    -- Settings --

    return addOn
end

function InitDataStorage(DB)
    if (not addOn) then return end

    if (not DB) then
        DB = {
            Profiles = {}
        }
    end

    function DB:ClearDataStorage()
        table.wipe(DB.Profiles)
        table.wipe(DB)
        DB.Profiles = {}
    end



    --------------
    -- Profiles --
    function DB:AddProfile(profileName)
        if (not DB.Profiles[profileName]) then
            DB.Profiles[profileName] = {}
        end
    end

    function DB:RemoveProfile(profileName)
        if (not DB.Profiles[profileName]) then
            DB.Profiles[profileName] = nil
        end
    end

    if (not DB.Profiles[UnitName("player")]) then
        DB:AddProfile(UnitName("player"))
    end
    -- Profiles --
    --------------

    return DB
end