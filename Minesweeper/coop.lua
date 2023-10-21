local AddOnName, Engine = ...
local LoutenLib, MINES = unpack(Engine)

MINES.COOPMode = false
MINES.IsHosting = false
MINES.PartnerName = nil

function MINES:InitCOOP()
    MINES.PartnerCursor = LoutenLib:CreateNewFrame(UIParent)
    MINES.PartnerCursor:InitNewFrame(23, 23,
                                "BOTTOMLEFT", nil, "BOTTOMLEFT", 0, 0,
                                1,1,0,1,
                                false, false, nil)
    MINES.PartnerCursor:Hide()
    MINES.PartnerCursor:SetFrameStrata("TOOLTIP")
    MINES.PartnerCursor.Texture:SetTexture("Interface\\AddOns\\"..MINES.Info.FileName.."\\textures\\cursor.blp")
    MINES.PartnerCursor.LastId = nil
end

function MINES.SetCursorTo(frame, cellId)
    cellId = tonumber(cellId)
    if (MINES.Field:IsShown() and not MINES.IsGameHidden) then
        MINES.PartnerCursor:ClearAllPoints()
        MINES.PartnerCursor:SetPoint("CENTER", frame, "CENTER", 13, -13)
        MINES.PartnerCursor:Show()
        MINES.PartnerCursor.LastId = MINES.PartnerCursor.LastId or cellId

        if (MINES.Field.Cells[cellId].Opened) then
            MINES.Field.Cells[cellId]:SetBackdropColor(.35,.35,.35,1)
        else
            MINES.Field.Cells[cellId]:SetBackdropColor(.5,.5,.2,1)
        end
        if (MINES.Field.Cells[cellId].Flag) then
            MINES.Field.Cells[cellId]:SetBackdropColor(.3,.3,.7,1)
        end

        if (MINES.Field.Cells[MINES.PartnerCursor.LastId].Opened) then
            MINES.Field.Cells[MINES.PartnerCursor.LastId]:SetBackdropColor(.5,.5,.5,1)
        else
            MINES.Field.Cells[MINES.PartnerCursor.LastId]:SetBackdropColor(0,.5,0,1)
        end
        if (MINES.Field.Cells[MINES.PartnerCursor.LastId].Flag) then
            MINES.Field.Cells[MINES.PartnerCursor.LastId]:SetBackdropColor(0,0,.7,1)
        end
        MINES.PartnerCursor.LastId = cellId
    end
end

function MINES.SendCursorPoint(cellId)
    SendAddonMessage("mines_cursor", cellId, "WHISPER", MINES.PartnerName)
end

MINES.ConnectionStatus = false
MINES.ConnectionCheck = CreateFrame("Frame")
MINES.CheckTimeStart = 0
MINES.ConnectionWarnings = 0
MINES.IsConnectionStable = true
function MINES.ConnectionCheckStart()
    MINES.CheckTimeStart = GetTime()
    local checkInterval = 3
    local maxWarnings = 3
    COOP_Send_GetConnectionStatus()
    MINES.ConnectionCheck:SetScript("OnUpdate", function()
        if (GetTime() >= MINES.CheckTimeStart + checkInterval) then
            if (MINES.ConnectionStatus) then
                if (not MINES.IsConnectionStable) then
                    MINES:PrintMsg("Подключение восстановлено.", "26ff1f")
                    MINES.IsConnectionStable = true
                end
                checkInterval = 3
                MINES.CheckTimeStart = GetTime()
                MINES.ConnectionWarnings = 0
                MINES.ConnectionStatus = false
                COOP_Send_GetConnectionStatus()
            else
                MINES.IsConnectionStable = false
                MINES.ConnectionWarnings = MINES.ConnectionWarnings + 1
                if (MINES.ConnectionWarnings == 1) then checkInterval = 5
                elseif (MINES.ConnectionWarnings == 2) then checkInterval = 7 end
                MINES:PrintMsg("Нет подключения со вторым игроком. Предупреждений: "..MINES.ConnectionWarnings.."/"..maxWarnings, "ff9100")
                if (MINES.ConnectionWarnings == maxWarnings) then
                    MINES.IsConnectionStable = true
                    MINES.ConnectionCheckStop()
                    MINES.DisconnectCOOP(0)
                    MINES:PrintMsg("Подключение со вторым игроком потеряно, КООП отключен.", "cf0a0a")
                    return
                end
                MINES.CheckTimeStart = GetTime()
                COOP_Send_GetConnectionStatus()
            end
        end
    end)
end
function MINES.ConnectionCheckStop()
    MINES.ConnectionCheck:SetScript("OnUpdate", nil)
end

function MINES.DisconnectCOOP(disconnectType)
    MINES.ConnectionCheckStop()
    MINES.ConnectionStatus = false
    MINES.COOPMode = false
    MINES.PartnerName = nil
    MINES.IsHosting = false
    MINES.PartnerCursor:Hide()
    MINES.Field.Header.PartnerInfo:Hide()
    MINES.Field.Settings.LeaveCOOP:Hide()
    MINES.Field.StartGameButton:Show()

    if (disconnectType == 0) then
        MINES:Notify("Подключение со вторым игроком потеряно, КООП отключен.")
    elseif (disconnectType == 1) then
        MINES:Notify("Вы покинули КООП.")
    elseif (disconnectType == 2) then
        MINES:Notify("Второй игрок покинул КООП.")
    end
end

-- Получение КООП информации
local getCOOPInfo = CreateFrame("Frame")
getCOOPInfo:RegisterEvent("CHAT_MSG_ADDON")
getCOOPInfo:SetScript('OnEvent', function(s, e, arg1, arg2, arg3, arg4)
    if (e == "CHAT_MSG_ADDON") then
        -- Уведомление второму игроку об приглашении
        if (arg1 == "mines_invite") then
            if (MINES_DB.Profiles[UnitName("player")].LeaveMeAlone) then
                COOP_Send_LeaveMeAlone(arg4)
                return
            end
            COOP_Send_GotInvite(arg4)
            MINES:Notify("Игрок "..arg4.." приглашает вас в КООП режим.", true,
                function()
                    MINES.EndGame = true
                    MINES.DisableField()
                    MINES.PartnerName = arg4
                    MINES.COOPMode = true
                    MINES.IsHosting = false
                    COOP_Send_AcceptInvite(arg4)
                    MINES:NotifyForceClose()
                    MINES.Field.Header.PartnerInfo.Text:SetText("COOP: "..MINES.PartnerName)
                    MINES.Field.Header.PartnerInfo:Show()
                    MINES.Field.Settings.LeaveCOOP:Show()
                    MINES.Field.StartGameButton:Hide()
                    MINES.ConnectionCheckStart()
                end, function() MINES:NotifyForceClose() end)
            return
        end
        
        -- Уведомление первому игроку о принятии приглашения вторым игроком
        if (arg1 == "mines_accept_invite") then
            MINES.DisableField()
            if (not MINES.EndGame) then
                MINES.Field.ResumeGame:Show()
            else
                MINES.Field.StartGameButton:Show()
            end
            MINES:Notify("Игрок "..arg4.." принял ваше приглашение.")
            MINES.PartnerName = arg4
            MINES.COOPMode = true
            MINES.IsHosting = true
            MINES.Field.Header.PartnerInfo.Text:SetText("COOP: "..MINES.PartnerName)
            MINES.Field.Header.PartnerInfo:Show()
            MINES.Field.Settings.LeaveCOOP:Show()
            MINES.ConnectionCheckStart()
            return
        end

        -- Уведомление первому игроку о том что до второго игрока дошло приглашение
        if (arg1 == "mines_got_invite") then
            MINES:Notify("Игроку "..arg4.." было отправлено приглашение.")
            return
        end
        -- Уведомление первого игрока о том что у второго игрока отключены приглашения
        if (arg1 == "mines_leave_me_alone") then
            MINES:Notify("Вы не можете пригласить "..arg4..", так как этот игрок отключил приглашения.")
            return
        end

        if (MINES.COOPMode) then
            -----------------
            -- Get Command --

            -- Получение позиции курсора второго игрока
            if (arg1 == "mines_cursor" and arg4 == MINES.PartnerName) then
                MINES.SetCursorTo(MINES.Field.Cells[tonumber(arg2)], arg2)
                return
            end
            -- Получение открытой ячейки
            if (arg1 == "mines_opened_cell" and arg4 == MINES.PartnerName) then
                MINES.OpenCell(tonumber(arg2))
                return
            end
            -- Добавление мин на поле
            if (arg1 == "mines_add_mine" and arg4 == MINES.PartnerName and not MINES.IsHosting) then
                local coopMines = {strsplit(" ", arg2)}
                for i = 1, #coopMines do
                    MINES.Field.Cells[tonumber(coopMines[i])].Mined = true
                end

                COOP_Status_CreatingMinesOnField()
                return
            end
            -- Старт игры у второго игрока
            if (arg1 == "mines_start_game" and arg4 == MINES.PartnerName) then
                MINES.StartGame()
                COOP_Status_IsReadyStartGame()
                return
            end
            -- Создание игры
            if (arg1 == "mines_new_game" and arg4 == MINES.PartnerName and not MINES.IsHosting) then
                local isFieldShown = MINES.Field:IsShown()
                MINES.Field:Hide()
                MINES.DisableField()
                MINES.ClearingField()
                MINES.SetDifficulty(MINES.NextDifficulty)
                MINES.RefreshField()
                MINES.Field.Settings:SetWidth(MINES.Field:GetWidth())
                if (isFieldShown) then
                    MINES.Field:Show()
                end
                MINES.MinesLeft = MINES.GameDifficulty[MINES.CurrentDifficulty].minesCount
                MINES.Field.MinesLeft.Text:SetText(MINES.MinesLeft)
                MINES.EndGame = false
                COOP_Status_IsReadyCreateNewGame()
                return
            end
            -- Установка флажка
            if (arg1 == "mines_set_flag" and arg4 == MINES.PartnerName) then
                MINES.SetFlag(tonumber(arg2))
                return
            end
            -- Смена сложности у второго игрока
            if (arg1 == "mines_change_difficulty" and arg4 == MINES.PartnerName and not MINES.IsHosting) then
                MINES.NextDifficulty = arg2
                return
            end
            -- Проигрыш
            if (arg1 == "mines_end_game" and arg4 == MINES.PartnerName) then
                MINES.LoseGame()
                return
            end
            -- Нажатие Start Game вторым игроком
            if (arg1 == "mines_start_game_partner" and arg4 == MINES.PartnerName and MINES.IsHosting) then
                MINES.StartGameBT()
                return
            end
            -- Проверка подключения
            if (arg1 == "mines_get_connection_status" and arg4 == MINES.PartnerName) then
                COOP_Send_SendConnectionStatus()
                return
            end

            if (arg1 == "mines_send_connection_status" and arg4 == MINES.PartnerName) then
                MINES.ConnectionStatus = true
                return
            end
            -- Отключение от кооп
            if (arg1 == "mines_send_leave_coop" and arg4 == MINES.PartnerName) then
                MINES.DisconnectCOOP(2)
                return
            end


            if (arg1 == "mines_resume_mines" and arg4 == MINES.PartnerName) then
                local coopMines = {strsplit(" ", arg2)}
                for i = 1, #coopMines do
                    MINES.Field.Cells[tonumber(coopMines[i])].Mined = true
                end
                return
            end

            if (arg1 == "mines_resume_opened_cells" and arg4 == MINES.PartnerName) then
                local coopMines = {strsplit(" ", arg2)}
                for i = 1, #coopMines do
                    MINES.Field.Cells[tonumber(coopMines[i])].Opened = true
                    MINES.Field.Cells[tonumber(coopMines[i])].Text:Show()
                    MINES.GreenToGrayCell(tonumber(coopMines[i]))
                end
                return
            end

            if (arg1 == "mines_resume_flags" and arg4 == MINES.PartnerName) then
                local coopMines = {strsplit(" ", arg2)}
                for i = 1, #coopMines do
                    MINES.SetFlag(tonumber(coopMines[i]))
                end
                return
            end


            ----------------
            -- Get Status --
            -- Статус второго игрога на создание игры
            if (arg1 == "mines_status_new_game" and arg4 == MINES.PartnerName and MINES.IsHosting) then
                if (MINES.Field.ResumeGame:IsShown()) then
                    local mines = nil
                    local opened = nil
                    local flags = nil
                    for i = 1, MINES.GetActualMaxCells() do
                        if (MINES.Field.Cells[i].Mined) then
                            if (not mines) then
                                mines = tostring(i)
                            else
                                mines = mines.." "..tostring(i)
                            end
                        end
                        if (MINES.Field.Cells[i].Opened) then
                            if (not opened) then
                                opened = tostring(i)
                            else
                                opened = opened.." "..tostring(i)
                            end
                        end
                        if (MINES.Field.Cells[i].Flag) then
                            if (not flags) then
                                flags = tostring(i)
                            else
                                flags = flags.." "..tostring(i)
                            end
                        end
                    end
                    COOP_Send_ResumeMines(mines)
                    if (opened) then COOP_Send_ResumeOpenedCells(opened) end
                    if (flags) then COOP_Send_ResumeFlags(flags)end
                    COOP_Send_StartGame()
                    MINES.Field.ResumeGame:Hide()
                    MINES.EnableField()
                    return
                end
                MINES.PreparingGame()
                return
            end
            -- Статус второго игрока на подготовку мин
            if (arg1 == "mines_status_add_mine" and arg4 == MINES.PartnerName and MINES.IsHosting) then
                COOP_Send_StartGame()
                MINES.StartGame()
                return
            end
            -- Статус второго игрока на начало игры
            if (arg1 == "mines_status_start_game" and arg4 == MINES.PartnerName and MINES.IsHosting) then
                IsReadyStartGame = true
                return
            end
        end
    end
end)

function COOP_Send_ResumeMines(mines)
    SendAddonMessage("mines_resume_mines", mines, "WHISPER", MINES.PartnerName)
end
function COOP_Send_ResumeOpenedCells(openedCells)
    SendAddonMessage("mines_resume_opened_cells", openedCells, "WHISPER", MINES.PartnerName)
end
function COOP_Send_ResumeFlags(flags)
    SendAddonMessage("mines_resume_flags", flags, "WHISPER", MINES.PartnerName)
end




    -- Send Leave COOP --
-- Send
function COOP_Send_SendLeaveCOOP()
    SendAddonMessage("mines_send_leave_coop", "1", "WHISPER", MINES.PartnerName)
end





    -- Send Connection Status --
-- Send
function COOP_Send_SendConnectionStatus()
    SendAddonMessage("mines_send_connection_status", "1", "WHISPER", MINES.PartnerName)
end





    -- Get Connection Status --
-- Send
function COOP_Send_GetConnectionStatus()
    SendAddonMessage("mines_get_connection_status", "1", "WHISPER", MINES.PartnerName)
end





    -- Leave Me Alone --
-- Send
function COOP_Send_LeaveMeAlone(inviterName)
    SendAddonMessage("mines_leave_me_alone", "1", "WHISPER", inviterName)
end




    -- Start Game Partner --
-- Send
function COOP_Send_StartGamePartner()
    SendAddonMessage("mines_start_game_partner", "1", "WHISPER", MINES.PartnerName)
end





    -- End Game --
--Send
function COOP_Send_EndGame()
    SendAddonMessage("mines_end_game", "1", "WHISPER", MINES.PartnerName)
end




    -- Got invite --
-- Send
function COOP_Send_GotInvite(inviter)
    SendAddonMessage("mines_got_invite", "1", "WHISPER", inviter)
end




        -- Invite Partner --
-- Send
function COOP_Send_InvitePartner(partner)
    SendAddonMessage("mines_invite", UnitName("player"), "WHISPER", partner)
end




        -- Accept Invite --
-- Send
function COOP_Send_AcceptInvite(partner)
    SendAddonMessage("mines_accept_invite", "1", "WHISPER", partner)
end




        -- Start Game --
-- Send
function COOP_Send_StartGame()
    SendAddonMessage("mines_start_game", "1", "WHISPER", MINES.PartnerName)
end
-- Status
IsReadyStartGame = false
function COOP_Status_IsReadyStartGame()
    SendAddonMessage("mines_status_start_game", "1", "WHISPER", MINES.PartnerName)
end




        -- Creating Mines On Field --
-- Send
function COOP_Send_CreatingMinesOnField(cellId)
    SendAddonMessage("mines_add_mine", cellId, "WHISPER", MINES.PartnerName)
end
-- Status
IsReadyCreatingMinesOnField = false
function COOP_Status_CreatingMinesOnField()
    SendAddonMessage("mines_status_add_mine", "1", "WHISPER", MINES.PartnerName)
end





    -- Open Cells --
-- Send
function COOP_Send_OpenedCell(cellId)
    SendAddonMessage("mines_opened_cell", cellId, "WHISPER", MINES.PartnerName)
end





        -- CreateNewGame --
-- Send
function COOP_Send_CreateNewGame()
    SendAddonMessage("mines_new_game", "1", "WHISPER", MINES.PartnerName)
end
-- Status
IsReadyCreateNewGame = false
function COOP_Status_IsReadyCreateNewGame()
    SendAddonMessage("mines_status_new_game", "1", "WHISPER", MINES.PartnerName)
end





        -- Set Flag --
-- Send
function COOP_Send_SetFlag(cellId)
    SendAddonMessage("mines_set_flag", cellId, "WHISPER", MINES.PartnerName)
end





        -- Set Diffuculty --
-- Send
function COOP_Send_ChangeDifficulty(difficulty)
    SendAddonMessage("mines_change_difficulty", difficulty, "WHISPER", MINES.PartnerName)
end






-- Ошибка соединения
function COOP_ErrorConnection(code)
    MINES:Notify("Ошибка соединения со вторым игроком. Код ошибки:"..code.."\nБольше информации об ошибках вы найдете тут: discord.gg/TubeZVD")
end