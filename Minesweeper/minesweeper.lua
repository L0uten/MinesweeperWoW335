local AddOnName, Engine = ...
local LoutenLib, MINES = unpack(Engine)

local Init = CreateFrame("Frame")
Init:RegisterEvent("PLAYER_LOGIN")
Init:SetScript("OnEvent", function()
    LoutenLib:InitAddon("Minesweeper", "Сапёр", "1.7")
    MINES:SetRevision("2023", "10", "29", "00", "01", "00")
    MINES_DB = LoutenLib:InitDataStorage(MINES_DB)
    MINES:LoadedFunction(function()
        MINES:PrintMsg("/mines - открыть поле с игрой")
    end)
    MINES:CreateNewField(MINES.CurrentDifficulty)
    MINES:CreateInterface()
    MINES:InitCOOP()
end)

SlashCmdList.MINES = function(msg, editBox)
    if (#msg == 0) then
        MINES.Field:Show()
    end
end

SLASH_MINES1 = "/mines"
SLASH_MINES2 = "/minesweeper"


-- СЛОЖНОСТЬ ИГРЫ
MINES.GameDifficulty = {
    ["easy"] = {
        fieldWidth = 500,
        fieldHeight = 500,
        minesCount = 70,
        timeInSec = 240,
    },
    ["medium"] = {
        fieldWidth = 750,
        fieldHeight = 500,
        minesCount = 110,
        timeInSec = 360,
    },
    ["hard"] = {
        fieldWidth = 1000,
        fieldHeight = 500,
        minesCount = 160,
        timeInSec = 480,
    }
}
MINES.CurrentDifficulty = "easy"
MINES.NextDifficulty = "easy"

-- ПОЛЕ ИГРЫ
MINES.Field = LoutenLib:CreateNewFrame(UIParent)
local fieldHeaderH = 23

-- ЯЧЕЙКИ
local cellsW = 25
local cellsH = cellsW
MINES.Field.Cells = {}
MINES.CellsLeft = ((MINES.GameDifficulty[MINES.CurrentDifficulty].fieldWidth / cellsW) * (MINES.GameDifficulty[MINES.CurrentDifficulty].fieldHeight / cellsW)) - MINES.GameDifficulty[MINES.CurrentDifficulty].minesCount
MINES.MinesLeft = MINES.GameDifficulty[MINES.CurrentDifficulty].minesCount
MINES.EndGame = true

MINES.Timer = CreateFrame("Frame")
MINES.StartTime = 0
MINES.IsGameHidden = false

MINES.GreenColor = .45
MINES.GrayColor = .45

-- Режим
MINES.Mode = 0 -- 0 - standart mode, 1 - time game
MINES.NextMode = 0
MINES.TimeLeft = 0

-----------
-- FIELD --
function MINES:CreateNewField(difficulty)
    MINES.SetDifficulty(difficulty)

    -- Генерация поля
    MINES.Field:InitNewFrame(MINES.GameDifficulty[MINES.CurrentDifficulty].fieldWidth, MINES.GameDifficulty[MINES.CurrentDifficulty].fieldHeight + fieldHeaderH,
                        "CENTER", nil, "CENTER", 0, 0,
                        0,0,0,1,
                        true, true, 
                        function()
                            if (not MINES.IsGameHidden) then
                                for i = 1, MINES.GetActualMaxCells() do
                                    if (not MINES.Field.Cells[i].IsOverLimit) then
                                        MINES.Field.Cells[i]:Show()
                                    end
                                end
                            end
                        end)
    MINES.Field:SetScript("OnDragStart", function()
        if (MINES.Field:IsMouseOver(nil, MINES.Field:GetHeight() - fieldHeaderH)) then
            for i = 1, MINES.GetActualMaxCells() do
                MINES.Field.Cells[i]:Hide()
            end
            MINES.Field:StartMoving()
        end
    end)
    MINES.Field:SetFrameStrata("HIGH")
    MINES.Field.Header = LoutenLib:CreateNewFrame(MINES.Field)
    
    for y = 0, MINES.GameDifficulty["hard"].fieldHeight / cellsH - 1 do
        for x = 0, MINES.GameDifficulty["hard"].fieldWidth / cellsW - 1 do
            local c = #MINES.Field.Cells
    
            -- Back cells
            MINES.Field.Cells[c+1] = LoutenLib:CreateNewFrame(MINES.Field)
            MINES.Field.Cells[c+1].Mined = false
            MINES.Field.Cells[c+1].MinesInRange = 0
            MINES.Field.Cells[c+1].Flag = false
            MINES.Field.Cells[c+1].Opened = false
            MINES.Field.Cells[c+1]:InitNewFrame(cellsW, cellsH,
                                            "TOPLEFT", MINES.Field, "TOPLEFT", x*cellsW, -y*cellsH,
                                            0,0,0,0,
                                            false, false, nil)
            MINES.Field.Cells[c+1]:TextureToBackdrop(true, 2, 0, 0,0,0,1, 0,MINES.GreenColor,0,1)
            MINES.Field.Cells[c+1]:SetTextToFrame("CENTER", MINES.Field.Cells[c+1], "CENTER", 0, 0, true, 12, "")
            MINES.Field.Cells[c+1].Text:Hide()
            
            MINES.Field.Cells[c+1]:SetScript("OnEnter", function ()
                MINES.Field.Cells[c+1]:SetBackdropColor(MINES.GreenColor,MINES.GreenColor,.2,1)
                if (MINES.COOPMode) then MINES.SendCursorPoint(c+1) end
            end)

            MINES.Field.Cells[c+1]:SetScript("OnLeave", function ()
                MINES.Field.Cells[c+1]:SetBackdropColor(0,MINES.GreenColor,0,1)
            end)
    
            MINES.Field.Cells[c+1]:SetScript("OnMouseUp", function (arg1, arg2)
                if (arg2 == "LeftButton" and MINES.Field.Cells[c+1]:IsMouseOver()) then
                    MINES.OpenCell(c+1)
                elseif (arg2 == "RightButton" and MINES.Field.Cells[c+1]:IsMouseOver()) then
                    MINES.SetFlag(c+1)
                    if (MINES.COOPMode) then
                        COOP_Send_SetFlag(c+1)
                    end
                end
            end)

            MINES.Field.Cells[c+1].IsOverLimit = false
        end
    end
    MINES.RefreshField()
    MINES.Field:Hide()
end
function MINES.RefreshField()
    MINES.DisableField()
    MINES.CellsLeft = MINES.GetCellsLeft()
    MINES.Field:SetWidth(MINES.GameDifficulty[MINES.CurrentDifficulty].fieldWidth)
    if (not MINES.IsGameHidden) then
        MINES.Field:SetHeight(MINES.GameDifficulty[MINES.CurrentDifficulty].fieldHeight + fieldHeaderH)
    end
    MINES.Field.Header:SetWidth(MINES.Field:GetWidth())
    local c = 0
    for y = 0, MINES.GameDifficulty[MINES.CurrentDifficulty].fieldHeight / cellsH - 1 do
        for x = 0, MINES.GameDifficulty[MINES.CurrentDifficulty].fieldWidth / cellsW - 1 do
            c = c + 1
            if (MINES.Field.Cells[c]) then
                if (not MINES.IsGameHidden) then
                    MINES.Field.Cells[c]:Show()
                end
                MINES.Field.Cells[c]:ClearAllPoints()
                MINES.Field.Cells[c]:SetPoint("TOPLEFT", MINES.Field, "TOPLEFT", x*cellsW, -y*cellsH - fieldHeaderH)

                MINES.Field.Cells[c].IsOverLimit = false
            end
        end
    end
    
    for i = c+1, #MINES.Field.Cells do
        MINES.Field.Cells[i]:Hide()
        MINES.Field.Cells[i].IsOverLimit = true
    end
end
function MINES.DisableField()
    for i = 1, MINES.GetActualMaxCells() do
        MINES.Field.Cells[i]:EnableMouse(false)
    end
end
function MINES.EnableField()
    for i = 1, MINES.GetActualMaxCells() do
        MINES.Field.Cells[i]:EnableMouse(true)
    end
end
function MINES.ClearingField()
    for i = 1, ((MINES.GameDifficulty[MINES.CurrentDifficulty].fieldWidth / cellsW) * (MINES.GameDifficulty[MINES.CurrentDifficulty].fieldHeight / cellsH)) do
        MINES.Field.Cells[i].Mined = false
        MINES.Field.Cells[i].Flag = false
        MINES.Field.Cells[i].Opened = false
        MINES.Field.Cells[i].MinesInRange = 0
        MINES.Field.Cells[i].IsResetMine = false
        MINES.Field.Cells[i].Text:Hide()
        MINES.StartTime = 0
        MINES.TimeLeft = 0
        MINES.ReturnToGreenCell(i)
    end
end

-----------
-- CELLS --
function MINES.GetCellsLeft()
    return ((MINES.GameDifficulty[MINES.CurrentDifficulty].fieldWidth / cellsW) * (MINES.GameDifficulty[MINES.CurrentDifficulty].fieldHeight / cellsW)) - MINES.GameDifficulty[MINES.CurrentDifficulty].minesCount
end
function MINES.GetActualMaxCells()
    return ((MINES.GameDifficulty[MINES.CurrentDifficulty].fieldWidth / cellsW) * (MINES.GameDifficulty[MINES.CurrentDifficulty].fieldHeight / cellsH))
end
function MINES.GetMaxCellsInRow()
    return MINES.GameDifficulty[MINES.CurrentDifficulty].fieldWidth / cellsW
end
function MINES.GreenToGrayCell(cellId)
    MINES.Field.Cells[cellId]:SetBackdropColor(MINES.GrayColor,MINES.GrayColor,MINES.GrayColor,1)
    MINES.Field.Cells[cellId]:SetScript("OnEnter", function ()
        MINES.Field.Cells[cellId]:SetBackdropColor(MINES.GrayColor-.1,MINES.GrayColor-.1,MINES.GrayColor-.1,1)
        if (MINES.COOPMode) then MINES.SendCursorPoint(cellId) end
    end)

    MINES.Field.Cells[cellId]:SetScript("OnLeave", function ()
        MINES.Field.Cells[cellId]:SetBackdropColor(MINES.GrayColor,MINES.GrayColor,MINES.GrayColor,1)
    end)
end
function MINES.ReturnToGreenCell(cellId)
    MINES.Field.Cells[cellId]:SetBackdropColor(0,MINES.GreenColor,0,1)
    MINES.Field.Cells[cellId]:SetScript("OnEnter", function ()
        MINES.Field.Cells[cellId]:SetBackdropColor(MINES.GreenColor,MINES.GreenColor,.2,1)
        if (MINES.COOPMode) then MINES.SendCursorPoint(cellId) end
    end)

    MINES.Field.Cells[cellId]:SetScript("OnLeave", function ()
        MINES.Field.Cells[cellId]:SetBackdropColor(0,MINES.GreenColor,0,1)
    end)
end
function MINES.AddTextToCells()
    for i = 1, MINES.GetActualMaxCells() do
        MINES.Field.Cells[i].Text:SetText("")
        if (not MINES.Field.Cells[i].Mined) then
            if (MINES.Field.Cells[i].MinesInRange ~= 0) then
                MINES.Field.Cells[i].Text:SetText(MINES.Field.Cells[i].MinesInRange)
            end
        end
    end
end

-----------
-- TIMER --
function MINES.StartTimer()
    MINES.StartTime = GetTime()
    return MINES.StartTime
end
function MINES.StopTimer()
    local endTime = GetTime() - MINES.StartTime
    MINES.StartTime = 0
    return endTime
end

----------------
-- DIFFICULTY --
function MINES.ChangeDifficulty(difficulty)
    MINES.Field:Hide()
    MINES.NextDifficulty = difficulty
    MINES.RestartFieldInterface()
    MINES.Field:Show()
    MINES.Field.StartGameButton:Show()
    MINES.Field.TimeLeft:Hide()
end
function MINES.SetDifficulty(difficulty)
    MINES.CurrentDifficulty = difficulty
end
function MINES.GetDifficulty()
    local difficultyTextRu, difficultyTextEn
    if (MINES.CurrentDifficulty == "easy") then
        difficultyTextRu = "Легкая"
        difficultyTextEn = "Easy"
    elseif (MINES.CurrentDifficulty == "medium") then
        difficultyTextRu = "Средняя"
        difficultyTextEn = "Medium"
    elseif (MINES.CurrentDifficulty == "hard") then
        difficultyTextRu = "Сложная"
        difficultyTextEn = "Hard"
    end
    return MINES.CurrentDifficulty, difficultyTextRu, difficultyTextEn
end

-----------
-- MINES --
function MINES.SetFlag(cellId)
    if (MINES.MinesLeft == 0 and not MINES.Field.Cells[cellId].Flag) then return end
    if (not MINES.Field.Cells[cellId].Opened) then
        if (MINES.Field.Cells[cellId].Flag) then
            MINES.Field.Cells[cellId].Flag = false
            if (MINES.MinesLeft >= 0) then
                MINES.MinesLeft = MINES.MinesLeft + 1 
                MINES.Field.MinesLeft.Text:SetText(MINES.MinesLeft)
            end
            MINES.ReturnToGreenCell(cellId)
        else
            MINES.Field.Cells[cellId].Flag = true
            if (MINES.MinesLeft > 0) then
                MINES.MinesLeft = MINES.MinesLeft - 1
                MINES.Field.MinesLeft.Text:SetText(MINES.MinesLeft)
            end
            MINES.Field.Cells[cellId]:SetBackdropColor(0,0,.7,1)
            MINES.Field.Cells[cellId]:SetScript("OnEnter", function ()
                MINES.Field.Cells[cellId]:SetBackdropColor(.3,.3,.7,1)
                if (MINES.COOPMode) then MINES.SendCursorPoint(cellId) end
            end)
    
            MINES.Field.Cells[cellId]:SetScript("OnLeave", function ()
                MINES.Field.Cells[cellId]:SetBackdropColor(0,0,.7,1)
            end)
        end
    end
end
function MINES.IsCheckedCell(cellId)
    if (MINES.Field.Cells[cellId] == nil) then return end
    if (MINES.Field.Cells[cellId].IsOverLimit) then return end
    if (MINES.Field.Cells[cellId].Opened) then return end
    MINES.Field.Cells[cellId].Text:Show()
    MINES.Field.Cells[cellId].Opened = true
    MINES.CellsLeft = MINES.CellsLeft - 1
    MINES.CheckForWin()
    MINES.GreenToGrayCell(cellId)
    if (MINES.Field.Cells[cellId].MinesInRange == 0) then
        MINES.OpenSquare(cellId)
    end
end
function MINES.OpenSquare(indexCell)
    -- Правый стена
    if (indexCell%(MINES.GameDifficulty[MINES.CurrentDifficulty].fieldWidth/cellsW) == 0) then
        MINES.IsCheckedCell(indexCell-(MINES.GameDifficulty[MINES.CurrentDifficulty].fieldWidth / cellsW)-1)
        MINES.IsCheckedCell(indexCell-(MINES.GameDifficulty[MINES.CurrentDifficulty].fieldWidth / cellsW))
        MINES.IsCheckedCell(indexCell-1)
        MINES.IsCheckedCell(indexCell+(MINES.GameDifficulty[MINES.CurrentDifficulty].fieldWidth / cellsW)-1)
        MINES.IsCheckedCell(indexCell+(MINES.GameDifficulty[MINES.CurrentDifficulty].fieldWidth / cellsW))
    end
    -- Левая стена
    if ((indexCell-1) % (MINES.GameDifficulty[MINES.CurrentDifficulty].fieldWidth/cellsW) + 1 == 1) then
        MINES.IsCheckedCell(indexCell-(MINES.GameDifficulty[MINES.CurrentDifficulty].fieldWidth / cellsW))
        MINES.IsCheckedCell(indexCell-(MINES.GameDifficulty[MINES.CurrentDifficulty].fieldWidth / cellsW)+1)
        MINES.IsCheckedCell(indexCell+1)
        MINES.IsCheckedCell(indexCell+(MINES.GameDifficulty[MINES.CurrentDifficulty].fieldWidth / cellsW))
        MINES.IsCheckedCell(indexCell+(MINES.GameDifficulty[MINES.CurrentDifficulty].fieldWidth / cellsW)+1)
    end
    -- Все остальное
    if (indexCell%(MINES.GameDifficulty[MINES.CurrentDifficulty].fieldWidth/cellsW) ~= 0 and (indexCell-1) % (MINES.GameDifficulty[MINES.CurrentDifficulty].fieldWidth/cellsW) + 1 ~= 1) then
        MINES.IsCheckedCell(indexCell-(MINES.GameDifficulty[MINES.CurrentDifficulty].fieldWidth / cellsW)-1)
        MINES.IsCheckedCell(indexCell-(MINES.GameDifficulty[MINES.CurrentDifficulty].fieldWidth / cellsW))
        MINES.IsCheckedCell(indexCell-(MINES.GameDifficulty[MINES.CurrentDifficulty].fieldWidth / cellsW)+1)
        MINES.IsCheckedCell(indexCell-1)
        MINES.IsCheckedCell(indexCell+1)
        MINES.IsCheckedCell(indexCell+(MINES.GameDifficulty[MINES.CurrentDifficulty].fieldWidth / cellsW)-1)
        MINES.IsCheckedCell(indexCell+(MINES.GameDifficulty[MINES.CurrentDifficulty].fieldWidth / cellsW))
        MINES.IsCheckedCell(indexCell+(MINES.GameDifficulty[MINES.CurrentDifficulty].fieldWidth / cellsW)+1)
    end
end
function MINES.OpenCell(cellId)
    if (MINES.Field.Cells[cellId].Flag) then return end
    if (MINES.StartTime == 0) then
        MINES.StartTimer()
        if (MINES.GetMode() == 1) then
            MINES.StartTimeMode()
        end
    end
    if (MINES.Field.Cells[cellId].Opened) then return end
    if (MINES.Field.Cells[cellId].Mined) then MINES.LoseGame() return end
    if (MINES.COOPMode and not MINES.Field.Cells[cellId].Opened) then COOP_Send_OpenedCell(cellId) end

    MINES.Field.Cells[cellId].Text:Show()
    MINES.Field.Cells[cellId].Opened = true
    MINES.CellsLeft = MINES.CellsLeft - 1
    MINES.CheckForWin()
    MINES.GreenToGrayCell(cellId)
    if (MINES.Field.Cells[cellId].MinesInRange == 0 and not MINES.Field.Cells[cellId].Mined) then
        MINES.OpenSquare(cellId)
    end
end
function MINES.MineCells()
    local minesCoopList = nil
    local i = 0
    while i < MINES.GameDifficulty[MINES.CurrentDifficulty].minesCount do
        local r = random(1, MINES.GetActualMaxCells())
        if (not MINES.Field.Cells[r].Mined) then
            if (not MINES.Field.Cells[r].IsOverLimit) then
                MINES.Field.Cells[r].Mined = true
            end
        else
            i = i - 1
        end
        i = i + 1
    end

    local restart = false
    local function resetMine(x)
        MINES.Field.Cells[x].Mined = false
        MINES.Field.Cells[x].IsResetMine = true
        local r = random(1, MINES.GetActualMaxCells())
        while (r == x) do
            r = random(1, MINES.GetActualMaxCells())
        end
        if (not MINES.Field.Cells[r].Mined and not MINES.Field.Cells[r].IsResetMine) then
            if (not MINES.Field.Cells[r].IsOverLimit) then
                MINES.Field.Cells[r].Mined = true
                -- MINES.Field.Cells[r].New = true
                -- MINES.Field.Cells[x].Old = true
            end
        end
    end
    
    local function remove5050Mines()
        restart = false
        for i = 1, MINES.GetActualMaxCells() do
            -- Левая Т
            if (MINES.Field.Cells[i].Mined and
                i % MINES.GetMaxCellsInRow() == 3 and
                i ~= 3 and
                i + MINES.GetMaxCellsInRow() < MINES.GetActualMaxCells()) then
                if (MINES.Field.Cells[i-MINES.GetMaxCellsInRow()].Mined and
                    MINES.Field.Cells[i+MINES.GetMaxCellsInRow()].Mined) then
                        if (MINES.Field.Cells[i-1].Mined and not MINES.Field.Cells[i-2].Mined or 
                            not MINES.Field.Cells[i-1].Mined and MINES.Field.Cells[i-2].Mined) then
                            resetMine(i)
                            restart = true
                        end
                end
            end
            -- Правая Т
            if (MINES.Field.Cells[i].Mined and
                i % MINES.GetMaxCellsInRow() == MINES.GetMaxCellsInRow() - 2 and
                i ~= MINES.GetMaxCellsInRow() - 2 and
                i + MINES.GetMaxCellsInRow() < MINES.GetActualMaxCells()) then
                if (MINES.Field.Cells[i-MINES.GetMaxCellsInRow()].Mined and
                    MINES.Field.Cells[i+MINES.GetMaxCellsInRow()].Mined) then
                        if (MINES.Field.Cells[i+1].Mined and not MINES.Field.Cells[i+2].Mined or
                            not MINES.Field.Cells[i+1].Mined and MINES.Field.Cells[i+2].Mined) then
                            resetMine(i)
                            restart = true
                        end
                end
            end
            -- Верхняя Т
            if (MINES.Field.Cells[i].Mined and
                i > MINES.GetMaxCellsInRow() * 2+1 and i < MINES.GetMaxCellsInRow() * 3) then
                if (MINES.Field.Cells[i-1].Mined and
                    MINES.Field.Cells[i+1].Mined) then
                        if (MINES.Field.Cells[i-MINES.GetMaxCellsInRow()].Mined and not MINES.Field.Cells[i-MINES.GetMaxCellsInRow()-MINES.GetMaxCellsInRow()].Mined or
                            not MINES.Field.Cells[i-MINES.GetMaxCellsInRow()].Mined and MINES.Field.Cells[i-MINES.GetMaxCellsInRow()-MINES.GetMaxCellsInRow()].Mined) then
                            resetMine(i)
                            restart = true
                        end
                end
            end
            -- Нижняя Т
            if (MINES.Field.Cells[i].Mined and
                i > MINES.GetActualMaxCells() - (MINES.GetMaxCellsInRow() * 3)+1 and i < MINES.GetActualMaxCells() - (MINES.GetMaxCellsInRow() * 2)-1) then
                if (MINES.Field.Cells[i-1].Mined and
                    MINES.Field.Cells[i+1].Mined) then
                        if (MINES.Field.Cells[i+MINES.GetMaxCellsInRow()].Mined and not MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+MINES.GetMaxCellsInRow()].Mined or 
                            not MINES.Field.Cells[i+MINES.GetMaxCellsInRow()].Mined and MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+MINES.GetMaxCellsInRow()].Mined) then
                            resetMine(i)
                            restart = true
                        end
                end
            end

            -- Левый верх Г
            if (MINES.Field.Cells[i].Mined and
                i == 3) then
                if (MINES.Field.Cells[i+MINES.GetMaxCellsInRow()].Mined and
                    not MINES.Field.Cells[i+MINES.GetMaxCellsInRow()-1].Mined and
                    not MINES.Field.Cells[i+MINES.GetMaxCellsInRow()-1-1].Mined) then

                    if (MINES.Field.Cells[i-1].Mined and not MINES.Field.Cells[i-1-1].Mined or
                        not MINES.Field.Cells[i-1].Mined and MINES.Field.Cells[i-1-1].Mined) then
                        resetMine(i+MINES.GetMaxCellsInRow())
                        restart = true
                    end
                end
            end
            if (MINES.Field.Cells[i].Mined and
                i == MINES.GetMaxCellsInRow() * 2 + 1) then
                if (MINES.Field.Cells[i+1].Mined and
                    not MINES.Field.Cells[i+1-MINES.GetMaxCellsInRow()].Mined and
                    not MINES.Field.Cells[i+1-MINES.GetMaxCellsInRow()-MINES.GetMaxCellsInRow()].Mined) then
                    
                    if (not MINES.Field.Cells[i-MINES.GetMaxCellsInRow()].Mined and MINES.Field.Cells[i-MINES.GetMaxCellsInRow()-MINES.GetMaxCellsInRow()].Mined or
                        MINES.Field.Cells[i-MINES.GetMaxCellsInRow()].Mined and not MINES.Field.Cells[i-MINES.GetMaxCellsInRow()-MINES.GetMaxCellsInRow()].Mined) then
                        resetMine(i+1)
                        restart = true
                    end
                end
            end
            -- Правый верх Г
            if (MINES.Field.Cells[i].Mined and
                i == MINES.GetMaxCellsInRow() - 2) then
                if (MINES.Field.Cells[i+MINES.GetMaxCellsInRow()].Mined and
                    not MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+1].Mined and
                    not MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+1+1].Mined) then
                    
                    if (MINES.Field.Cells[i+1].Mined and not MINES.Field.Cells[i+1+1].Mined or
                        not MINES.Field.Cells[i+1].Mined and MINES.Field.Cells[i+1+1].Mined) then
                        resetMine(i+MINES.GetMaxCellsInRow())
                        restart = true
                    end
                end
            end
            if (MINES.Field.Cells[i].Mined and
                i == MINES.GetMaxCellsInRow() * 3) then
                if (MINES.Field.Cells[i-1].Mined and
                    not MINES.Field.Cells[i-1-MINES.GetMaxCellsInRow()].Mined and
                    not MINES.Field.Cells[i-1-MINES.GetMaxCellsInRow()-MINES.GetMaxCellsInRow()].Mined) then

                    if (MINES.Field.Cells[i-MINES.GetMaxCellsInRow()].Mined and not MINES.Field.Cells[i-MINES.GetMaxCellsInRow()-MINES.GetMaxCellsInRow()].Mined or
                        not MINES.Field.Cells[i-MINES.GetMaxCellsInRow()].Mined and MINES.Field.Cells[i-MINES.GetMaxCellsInRow()-MINES.GetMaxCellsInRow()].Mined) then
                        resetMine(i-1)
                        restart = true
                    end
                end
            end
            -- Нижний левый Г
            if (MINES.Field.Cells[i].Mined and
                i == MINES.GetActualMaxCells()-MINES.GetMaxCellsInRow()+3) then
                if (MINES.Field.Cells[i-MINES.GetMaxCellsInRow()].Mined and
                    not MINES.Field.Cells[i-MINES.GetMaxCellsInRow()-1].Mined and
                    not MINES.Field.Cells[i-MINES.GetMaxCellsInRow()-1-1].Mined) then
                    
                    if (MINES.Field.Cells[i-1].Mined and not MINES.Field.Cells[i-1-1].Mined or 
                        not MINES.Field.Cells[i-1].Mined and MINES.Field.Cells[i-1-1].Mined) then
                        resetMine(i-MINES.GetMaxCellsInRow())
                        restart = true
                    end
                end
            end
            if (MINES.Field.Cells[i].Mined and
                i == MINES.GetActualMaxCells()-MINES.GetMaxCellsInRow()*3+1) then
                if (MINES.Field.Cells[i+1].Mined and
                    not MINES.Field.Cells[i+1+MINES.GetMaxCellsInRow()].Mined and
                    not MINES.Field.Cells[i+1+MINES.GetMaxCellsInRow()+MINES.GetMaxCellsInRow()].Mined) then
                    
                    if (MINES.Field.Cells[i+MINES.GetMaxCellsInRow()].Mined and not MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+MINES.GetMaxCellsInRow()].Mined or
                        not MINES.Field.Cells[i+MINES.GetMaxCellsInRow()].Mined and MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+MINES.GetMaxCellsInRow()].Mined) then
                        resetMine(i+1)
                        restart = true
                    end
                end
            end
            -- Нижный правый Г
            if (MINES.Field.Cells[i].Mined and
                i == MINES.GetActualMaxCells()-MINES.GetMaxCellsInRow()*2) then
                if (MINES.Field.Cells[i-1].Mined and
                not MINES.Field.Cells[i-1+MINES.GetMaxCellsInRow()].Mined and
                not MINES.Field.Cells[i-1+MINES.GetMaxCellsInRow()+MINES.GetMaxCellsInRow()].Mined) then

                    if (MINES.Field.Cells[i+MINES.GetMaxCellsInRow()].Mined and not MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+MINES.GetMaxCellsInRow()].Mined or
                        not MINES.Field.Cells[i+MINES.GetMaxCellsInRow()].Mined and MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+MINES.GetMaxCellsInRow()].Mined) then
                        resetMine(i-1)
                        restart = true
                    end
                end
            end
            if (MINES.Field.Cells[i].Mined and
                i == MINES.GetActualMaxCells()-2) then
                if (MINES.Field.Cells[i-MINES.GetMaxCellsInRow()].Mined and
                    not MINES.Field.Cells[i-MINES.GetMaxCellsInRow()+1].Mined and
                    not MINES.Field.Cells[i-MINES.GetMaxCellsInRow()+1+1].Mined) then

                    if (MINES.Field.Cells[i+1].Mined and not MINES.Field.Cells[i+1+1].Mined or 
                        not MINES.Field.Cells[i+1].Mined and MINES.Field.Cells[i+1+1].Mined) then
                        resetMine(i-MINES.GetMaxCellsInRow())
                        restart = true
                    end
                end
            end

            -- Левая скоба
            if (MINES.Field.Cells[i].Mined and
                i%MINES.GetMaxCellsInRow() == 1 and
                i < MINES.GetActualMaxCells()-MINES.GetMaxCellsInRow()*4+2) then
                if (MINES.Field.Cells[i+1].Mined and
                    not MINES.Field.Cells[i+1+MINES.GetMaxCellsInRow()].Mined and
                    not MINES.Field.Cells[i+1+MINES.GetMaxCellsInRow()+MINES.GetMaxCellsInRow()].Mined and
                    MINES.Field.Cells[i+1+MINES.GetMaxCellsInRow()+MINES.GetMaxCellsInRow()+MINES.GetMaxCellsInRow()].Mined and
                    MINES.Field.Cells[i+1+MINES.GetMaxCellsInRow()+MINES.GetMaxCellsInRow()+MINES.GetMaxCellsInRow()-1].Mined) then

                    if (MINES.Field.Cells[i+MINES.GetMaxCellsInRow()].Mined and not MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+MINES.GetMaxCellsInRow()].Mined or
                        not MINES.Field.Cells[i+MINES.GetMaxCellsInRow()].Mined and MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+MINES.GetMaxCellsInRow()].Mined) then
                        resetMine(i+1)
                        restart = true
                    end
                end
            end
            -- Правая скоба
            if (MINES.Field.Cells[i].Mined and
                i%MINES.GetMaxCellsInRow() == 0 and
                i < MINES.GetActualMaxCells()-MINES.GetMaxCellsInRow()*3) then
                if (MINES.Field.Cells[i-1].Mined and
                    not MINES.Field.Cells[i-1+MINES.GetMaxCellsInRow()].Mined and
                    not MINES.Field.Cells[i-1+MINES.GetMaxCellsInRow()+MINES.GetMaxCellsInRow()].Mined and
                    MINES.Field.Cells[i-1+MINES.GetMaxCellsInRow()+MINES.GetMaxCellsInRow()+MINES.GetMaxCellsInRow()].Mined and
                    MINES.Field.Cells[i-1+MINES.GetMaxCellsInRow()+MINES.GetMaxCellsInRow()+MINES.GetMaxCellsInRow()+1].Mined) then

                    if (MINES.Field.Cells[i+MINES.GetMaxCellsInRow()].Mined and not MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+MINES.GetMaxCellsInRow()].Mined or
                        not MINES.Field.Cells[i+MINES.GetMaxCellsInRow()].Mined and MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+MINES.GetMaxCellsInRow()].Mined) then
                        resetMine(i-1)
                        restart = true
                    end
                end
            end
            -- Верхняя скоба
            if (MINES.Field.Cells[i].Mined and
                i>=1 and i < MINES.GetMaxCellsInRow()-2) then
                if (MINES.Field.Cells[i+MINES.GetMaxCellsInRow()].Mined and
                    not MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+1].Mined and
                    not MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+1+1].Mined and
                    MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+1+1+1].Mined and
                    MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+1+1+1-MINES.GetMaxCellsInRow()].Mined) then

                    if (MINES.Field.Cells[i+1].Mined and not MINES.Field.Cells[i+1+1].Mined or
                        not MINES.Field.Cells[i+1].Mined and MINES.Field.Cells[i+1+1].Mined) then
                        resetMine(i+MINES.GetMaxCellsInRow())
                        restart = true
                    end
                end
            end
            -- Нижняя скоба
            if (MINES.Field.Cells[i].Mined and
                i>=MINES.GetActualMaxCells()-MINES.GetMaxCellsInRow()+1 and i < MINES.GetActualMaxCells()-2) then
                if (MINES.Field.Cells[i-MINES.GetMaxCellsInRow()].Mined and
                    not MINES.Field.Cells[i-MINES.GetMaxCellsInRow()+1].Mined and
                    not MINES.Field.Cells[i-MINES.GetMaxCellsInRow()+1+1].Mined and
                    MINES.Field.Cells[i-MINES.GetMaxCellsInRow()+1+1+1].Mined and
                    MINES.Field.Cells[i-MINES.GetMaxCellsInRow()+1+1+1+MINES.GetMaxCellsInRow()].Mined) then

                    if (MINES.Field.Cells[i+1].Mined and not MINES.Field.Cells[i+1+1].Mined or
                        not MINES.Field.Cells[i+1].Mined and MINES.Field.Cells[i+1+1].Mined) then
                        resetMine(i-MINES.GetMaxCellsInRow())
                        restart = true
                    end
                end
            end

            -- Квадрат внутри
            if (MINES.Field.Cells[i].Mined and
                i % MINES.GetMaxCellsInRow() <= MINES.GetMaxCellsInRow()-3 and i % MINES.GetMaxCellsInRow() ~= 0 and i < (MINES.GetActualMaxCells() - MINES.GetMaxCellsInRow()*3)-3) then
                if (MINES.Field.Cells[i+1+1+1].Mined and MINES.Field.Cells[i+1+1+1+MINES.GetMaxCellsInRow()+MINES.GetMaxCellsInRow()+MINES.GetMaxCellsInRow()].Mined and 
                    MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+MINES.GetMaxCellsInRow()+MINES.GetMaxCellsInRow()].Mined) then
                    if (MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+1].Mined and not MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+1+1].Mined and
                        not MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+1+MINES.GetMaxCellsInRow()].Mined and MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+1+MINES.GetMaxCellsInRow()+1].Mined) then
                        resetMine(i)
                        restart = true
                    end
                    if (not MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+1].Mined and MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+1+1].Mined and
                        MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+1+MINES.GetMaxCellsInRow()].Mined and not MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+1+MINES.GetMaxCellsInRow()+1].Mined) then
                        resetMine(i)
                        restart = true
                    end
                end
            end
            -- Квадрат внизу
            if (MINES.Field.Cells[i].Mined and
                i % MINES.GetMaxCellsInRow() <= MINES.GetMaxCellsInRow()-3 and i % MINES.GetMaxCellsInRow() ~= 0 and i < (MINES.GetActualMaxCells() - MINES.GetMaxCellsInRow()*2)-3) then
                if (MINES.Field.Cells[i+1+1+1].Mined) then
                    if (MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+1].Mined and not MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+1+1].Mined and
                        not MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+1+MINES.GetMaxCellsInRow()].Mined and MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+1+MINES.GetMaxCellsInRow()+1].Mined) then
                        resetMine(i)
                        restart = true
                    end
                    if (not MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+1].Mined and MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+1+1].Mined and
                        MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+1+MINES.GetMaxCellsInRow()].Mined and not MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+1+MINES.GetMaxCellsInRow()+1].Mined) then
                        resetMine(i)
                        restart = true
                    end
                end
            end
            -- Квадрат сверху
            if (MINES.Field.Cells[i].Mined and
                i % MINES.GetMaxCellsInRow() <= MINES.GetMaxCellsInRow()-3 and i % MINES.GetMaxCellsInRow() ~= 0 and i > MINES.GetMaxCellsInRow()*2) then
                if (MINES.Field.Cells[i+1+1+1].Mined) then

                    if (MINES.Field.Cells[i-MINES.GetMaxCellsInRow()+1].Mined and not MINES.Field.Cells[i-MINES.GetMaxCellsInRow()+1+1].Mined and
                        not MINES.Field.Cells[i-MINES.GetMaxCellsInRow()+1-MINES.GetMaxCellsInRow()].Mined and MINES.Field.Cells[i-MINES.GetMaxCellsInRow()+1-MINES.GetMaxCellsInRow()+1].Mined) then
                        resetMine(i)
                        restart = true
                    end
                    if (not MINES.Field.Cells[i-MINES.GetMaxCellsInRow()+1].Mined and MINES.Field.Cells[i-MINES.GetMaxCellsInRow()+1+1].Mined and
                        MINES.Field.Cells[i-MINES.GetMaxCellsInRow()+1-MINES.GetMaxCellsInRow()].Mined and not MINES.Field.Cells[i-MINES.GetMaxCellsInRow()+1-MINES.GetMaxCellsInRow()+1].Mined) then
                        resetMine(i)
                        restart = true
                    end
                end
            end
            -- Квадрат слева
            if (MINES.Field.Cells[i].Mined and
                i % MINES.GetMaxCellsInRow() == 3 and i < MINES.GetActualMaxCells() - MINES.GetMaxCellsInRow()*3) then
                if (MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+MINES.GetMaxCellsInRow()+MINES.GetMaxCellsInRow()].Mined) then
                    
                    if (MINES.Field.Cells[i+MINES.GetMaxCellsInRow()-1].Mined and not MINES.Field.Cells[i+MINES.GetMaxCellsInRow()-1-1].Mined and
                        not MINES.Field.Cells[i+MINES.GetMaxCellsInRow()-1+MINES.GetMaxCellsInRow()].Mined and MINES.Field.Cells[i+MINES.GetMaxCellsInRow()-1+MINES.GetMaxCellsInRow()-1].Mined) then
                        resetMine(i)
                        restart = true
                    end
                    if (not MINES.Field.Cells[i+MINES.GetMaxCellsInRow()-1].Mined and MINES.Field.Cells[i+MINES.GetMaxCellsInRow()-1-1].Mined and
                        MINES.Field.Cells[i+MINES.GetMaxCellsInRow()-1+MINES.GetMaxCellsInRow()].Mined and not MINES.Field.Cells[i+MINES.GetMaxCellsInRow()-1+MINES.GetMaxCellsInRow()-1].Mined) then
                        resetMine(i)
                        restart = true
                    end
                end
            end
            -- Квадрат справа
            if (MINES.Field.Cells[i].Mined and
                i % MINES.GetMaxCellsInRow() == 18 and i < MINES.GetActualMaxCells() - MINES.GetMaxCellsInRow()*3) then
                if (MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+MINES.GetMaxCellsInRow()+MINES.GetMaxCellsInRow()].Mined) then
                    
                    if (MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+1].Mined and not MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+1+1].Mined and
                        not MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+1+MINES.GetMaxCellsInRow()].Mined and MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+1+MINES.GetMaxCellsInRow()+1].Mined) then
                        resetMine(i)
                        restart = true
                    end
                    if (not MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+1].Mined and MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+1+1].Mined and
                        MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+1+MINES.GetMaxCellsInRow()].Mined and not MINES.Field.Cells[i+MINES.GetMaxCellsInRow()+1+MINES.GetMaxCellsInRow()+1].Mined) then
                        resetMine(i)
                        restart = true
                    end
                end
            end
        end
    end

    remove5050Mines()
    while (restart) do
        remove5050Mines()
    end

    

    if (MINES.COOPMode) then
        for i = 1, MINES.GetActualMaxCells() do
            if (MINES.Field.Cells[i].Mined) then
                if (not minesCoopList) then
                    minesCoopList = tostring(i)
                else
                    minesCoopList = minesCoopList.." "..tostring(i)
                end
            end
        end
        COOP_Send_CreatingMinesOnField(minesCoopList)
    end

end
function MINES.FindMinesInRange()
    local fieldW = MINES.GameDifficulty[MINES.CurrentDifficulty].fieldWidth
    for i = 1, MINES.GetActualMaxCells() do
        if (not MINES.Field.Cells[i].Mined) then
            local minesNum = 0;
            if (i%(fieldW/cellsW) == 0) then
                if (MINES.Field.Cells[i - (fieldW / cellsW) - 1] ~= nil and MINES.Field.Cells[i - (fieldW / cellsW) - 1].Mined) then
                    minesNum = minesNum + 1;
                end
                if (MINES.Field.Cells[i - (fieldW / cellsW)] ~= nil and MINES.Field.Cells[i - (fieldW / cellsW)].Mined) then
                    minesNum = minesNum + 1;
                end
                if (MINES.Field.Cells[i - 1] ~= nil and MINES.Field.Cells[i - 1].Mined) then
                    minesNum = minesNum + 1;
                end
                if (MINES.Field.Cells[i + (fieldW / cellsW) - 1] ~= nil and MINES.Field.Cells[i + (fieldW / cellsW) - 1].Mined) then
                    minesNum = minesNum + 1;
                end
                if (MINES.Field.Cells[i + (fieldW / cellsW)] ~= nil and MINES.Field.Cells[i + (fieldW / cellsW)].Mined) then
                    minesNum = minesNum + 1;
                end 
            end

            if ((i-1) % (fieldW/cellsW) + 1 == 1) then
                if (MINES.Field.Cells[i - (fieldW / cellsW)] ~= nil and MINES.Field.Cells[i - (fieldW / cellsW)].Mined) then
                    minesNum = minesNum + 1;
                end
                if (MINES.Field.Cells[i - (fieldW / cellsW) + 1] ~= nil and MINES.Field.Cells[i - (fieldW / cellsW) + 1].Mined) then
                    minesNum = minesNum + 1;
                end
                if (MINES.Field.Cells[i + 1] ~= nil and MINES.Field.Cells[i + 1].Mined) then
                    minesNum = minesNum + 1;
                end
                if (MINES.Field.Cells[i + (fieldW / cellsW)] ~= nil and MINES.Field.Cells[i + (fieldW / cellsW)].Mined) then
                    minesNum = minesNum + 1;
                end
                if (MINES.Field.Cells[i + (fieldW / cellsW) + 1] ~= nil and MINES.Field.Cells[i + (fieldW / cellsW) + 1].Mined) then
                    minesNum = minesNum + 1;
                end
            end

            if (i%(fieldW/cellsW) ~= 0 and (i-1) % (fieldW/cellsW) + 1 ~= 1) then
                if (MINES.Field.Cells[i - (fieldW / cellsW) - 1] ~= nil and MINES.Field.Cells[i - (fieldW / cellsW) - 1].Mined) then
                    minesNum = minesNum + 1;
                end
                if (MINES.Field.Cells[i - (fieldW / cellsW)] ~= nil and MINES.Field.Cells[i - (fieldW / cellsW)].Mined) then
                    minesNum = minesNum + 1;
                end
                if (MINES.Field.Cells[i - (fieldW / cellsW) + 1] ~= nil and MINES.Field.Cells[i - (fieldW / cellsW) + 1].Mined) then
                    minesNum = minesNum + 1;
                end
                if (MINES.Field.Cells[i - 1] ~= nil and MINES.Field.Cells[i - 1].Mined) then
                    minesNum = minesNum + 1;
                end
                if (MINES.Field.Cells[i + 1] ~= nil and MINES.Field.Cells[i + 1].Mined) then
                    minesNum = minesNum + 1;
                end
                if (MINES.Field.Cells[i + (fieldW / cellsW) - 1] ~= nil and MINES.Field.Cells[i + (fieldW / cellsW) - 1].Mined) then
                    minesNum = minesNum + 1;
                end
                if (MINES.Field.Cells[i + (fieldW / cellsW)] ~= nil and MINES.Field.Cells[i + (fieldW / cellsW)].Mined) then
                    minesNum = minesNum + 1;
                end
                if (MINES.Field.Cells[i + (fieldW / cellsW) + 1] ~= nil and MINES.Field.Cells[i + (fieldW / cellsW) + 1].Mined) then
                    minesNum = minesNum + 1;
                end
            end
            
            MINES.Field.Cells[i].MinesInRange = minesNum;
        end
    end
end

----------
-- GAME -- 
function MINES.PreparingGame()
    local isFieldShown = MINES.Field:IsShown()
    MINES.StopTimeMode()
    MINES.Field:Hide()
    MINES.ClearingField()
    MINES.SetDifficulty(MINES.NextDifficulty)
    MINES.ChangeMode(MINES.NextMode)
    MINES.RefreshField()
    MINES.Field.Settings:SetWidth(MINES.Field:GetWidth())
    if (isFieldShown) then MINES.Field:Show() end
    MINES.MineCells()
    MINES.MinesLeft = MINES.GameDifficulty[MINES.CurrentDifficulty].minesCount
    MINES.Field.MinesLeft.Text:SetText(MINES.MinesLeft)
    MINES.EndGame = false
    if (MINES.GetMode() == 1) then
        MINES.Field.TimeLeft:Show()
        MINES.Field.TimeLeft.Text:SetText(MINES.GameDifficulty[MINES.GetDifficulty()].timeInSec)
    end
    if (not MINES.COOPMode) then
        MINES.StartGame()
    end
end
function MINES.StartGame()
    MINES.Field.StartGameButton:Hide()
    MINES.FindMinesInRange()
    MINES.AddTextToCells()
    MINES.EnableField()
    MINES:PrintMsg("Начата новая игра.")
    MINES.Field.StartGameButton:EnableMouse(true)
end
function MINES.LoseGame()
    if (not MINES.EndGame) then
        MINES.StopTimeMode()
        MINES.StopTimer()
        MINES:PrintMsg("Вы проиграли.", "ff2121")
        local isFieldShown = MINES.Field:IsShown()
        MINES.Field:Hide()
        MINES.DisableField()
        MINES.EndGame = true
        if (MINES.COOPMode) then COOP_Send_EndGame() end
        for i = 1, MINES.GetActualMaxCells() do
            if (not MINES.Field.Cells[i].Flag) then
                if (MINES.Field.Cells[i].Mined) then
                    MINES.Field.Cells[i]:SetBackdropColor(.55,0,0,1)
                end
            end
        end
        if (isFieldShown) then MINES.Field:Show() end
        if (not MINES.IsGameHidden) then MINES.Field.StartGameButton:Show() end
    end
end
function MINES.CheckForWin()
    if (MINES.CellsLeft == 0) then
        if (MINES.GetMode() == 1) then
            MINES.StopTimeMode()
        end
        MINES.DisableField()
        MINES.Field.StartGameButton:Show()
        MINES:PrintMsg("Вы ПОБЕДИЛИ в сложности "..MINES.CurrentDifficulty.." за "..SecondsToTime(MINES.StopTimer())..".", "2bff2b")
    end
end
function MINES.StartGameButtonFunction()
    MINES.Field.StartGameButton:EnableMouse(false)
    if (MINES.COOPMode) then
        if (not MINES.IsHosting) then
            COOP_Send_StartGamePartner()
            return
        end
        MINES.Field.StartGameButton:Hide()
        MINES.DisableField()
        COOP_Send_ChangeDifficulty(MINES.NextDifficulty)
        COOP_Send_ChangeMode(MINES.NextMode)
        COOP_Send_CreateNewGame()
        return
    end

    MINES.PreparingGame()
end

-----------
-- MODES --
function MINES.ChangeMode(mode)
    -- 0 - standart mode, 1 - time game
    if (type(mode) == "number") then
        MINES.Mode = mode

        if (mode == 0) then MINES.Field.Header.GameMode.Text:SetTextColor(1,1,1,1) end
        if (mode == 1) then MINES.Field.Header.GameMode.Text:SetTextColor(1,.5,.5,1) end
        MINES.Field.Header.GameMode.Text:SetText("Режим: "..select(2, MINES.GetMode()))
    end
end
function MINES.GetMode()
    local modeTextRu, modeTextEn
    if (MINES.Mode == 0) then
        modeTextEn = "Stantard"
        modeTextRu = "Стандартный"
    elseif (MINES.Mode == 1) then
        modeTextEn = "Time Game"
        modeTextRu = "Игра на время"
    end
    return MINES.Mode, modeTextRu, modeTextEn
end
function MINES.StartTimeMode()
    MINES.Field.TimeLeft:SetScript("OnUpdate", function()
        MINES.TimeLeft = floor(MINES.GameDifficulty[MINES.GetDifficulty()].timeInSec - (GetTime() - MINES.StartTime))
        if (MINES.COOPMode) then
            MINES.TimeLeft = floor((MINES.GameDifficulty[MINES.GetDifficulty()].timeInSec / 1.5) - (GetTime() - MINES.StartTime))
        end
        MINES.Field.TimeLeft.Text:SetText(MINES.TimeLeft)
        if (MINES.TimeLeft <= 0) then
            MINES.StopTimeMode()
            MINES.LoseGame()
        end
    end)
end
function MINES.StopTimeMode()
    MINES.Field.TimeLeft:SetScript("OnUpdate", nil)
    MINES.Field.TimeLeft.Text:SetText("")
    MINES.Field.TimeLeft:Hide()
end




-- Интерфейс игры
function MINES:CreateInterface()
    MINES.Field.StartGameButton = LoutenLib:CreateNewFrame(MINES.Field)
    MINES.Field.StartGameButton:InitNewFrame2(140, 35,
                                "BOTTOM", MINES.Field, "TOP", 0, 0,
                                52, 235, 107,1,
                                true, false, nil)
    MINES.Field.StartGameButton:InitNewButton2(52, 235, 107, 1,
                                        function ()
                                            MINES.StartGameButtonFunction()
                                        end)
    MINES.Field.StartGameButton:SetTextToFrame("CENTER", MINES.Field.StartGameButton, "CENTER", 0, 0, true, 16, "Начать игру")


    MINES.Field.Header:InitNewFrame(MINES.Field:GetWidth(), fieldHeaderH,
                                "TOP", MINES.Field, "TOP", 0, 0,
                                .05,.05,.05,1,
                                false, false, nil)
    MINES.Field.Header:SetTextToFrame("CENTER", MINES.Field.Header, "CENTER", 0,0, true, 13, MINES.Info.Name)
    MINES.Field.Header.CloseButton = LoutenLib:CreateNewFrame(MINES.Field.Header)
    MINES.Field.Header.CloseButton:InitNewFrame(MINES.Field.Header:GetHeight(), MINES.Field.Header:GetHeight(),
                                            "RIGHT", MINES.Field.Header, "RIGHT", 0, 0,
                                            0,0,0,1,
                                            true, false, nil)
    MINES.Field.Header.CloseButton:SetTextToFrame("CENTER", MINES.Field.Header.CloseButton, "CENTER", 0,2, true, 20, "x")
    MINES.Field.Header.CloseButton:InitNewButton(.4,0,0,1,
                                            0,0,0,1,
                                            .2,0,0,1,
                                            .4,0,0,1,
                                            nil, function()
                                                MINES.Field.Header.HideButton.Texture:SetTexture(0,0,0,1)
                                                MINES.Field:Hide()
                                                MINES.PartnerCursor:Hide()
                                            end)


    MINES.Field.Header.HideButton = LoutenLib:CreateNewFrame(MINES.Field.Header)
    MINES.Field.Header.HideButton:InitNewFrame(MINES.Field.Header:GetHeight(), MINES.Field.Header:GetHeight(),
                                            "LEFT", MINES.Field.Header.CloseButton, "LEFT", -MINES.Field.Header:GetHeight(), 0,
                                            0,0,0,1,
                                            true, false, nil)
    MINES.Field.Header.HideButton:SetTextToFrame("CENTER", MINES.Field.Header.HideButton, "CENTER", 0,0, true, 30, "-")
    MINES.Field.Header.HideButton:InitNewButton(.4,.4,.2,1,
                                            0,0,0,1,
                                            .2,.2,.1,1,
                                            .4,.4,.2,1,
                                            nil, function()
                                                local function HideToHeader()
                                                    MINES.Field.Header.HideButton:EnableMouse(false)
                                                    MINES.PartnerCursor:Hide()
                                                    MINES.Field.StartGameButton:Hide()
                                                    MINES.Field.SettingsButton:Hide()
                                                    MINES.Field.MinesLeft:Hide()
                                                    if (MINES.Field.Settings:IsShown()) then
                                                        if (not MINES.Field.SettingsButton.IsActive) then
                                                            MINES.Field.SettingsButton.Arrow.Texture:SetTexture("Interface\\AddOns\\"..MINES.Info.FileName.."\\textures\\movedown.tga")
                                                            MINES.CloseSettings()
                                                        end
                                                    end
                                                    for i = 1, MINES.GetActualMaxCells() do
                                                        MINES.Field.Cells[i]:Hide()
                                                    end
                                                    local animSpeed = 0
                                                    MINES.Field.Header.HideButton:SetScript("OnUpdate", function()
                                                        if (GetFramerate() < 20) then
                                                            animSpeed = 100
                                                        elseif (GetFramerate() < 30) then
                                                            animSpeed = 80
                                                        elseif (GetFramerate() >= 30 and GetFramerate() <= 60) then
                                                            animSpeed = 65
                                                        else
                                                            animSpeed = 45
                                                        end
                                                        MINES.Field:SetHeight(MINES.Field:GetHeight()-animSpeed)
                                                        if (MINES.Field:GetHeight() <= fieldHeaderH) then
                                                            MINES.Field.Header.HideButton:SetScript("OnUpdate", nil)
                                                            MINES.Field:SetHeight(fieldHeaderH)
                                                            MINES.Field.Header.HideButton:EnableMouse(true)
                                                        end
                                                    end)
                                                end

                                                local function OpenFromHeader()
                                                    MINES.Field.Header.HideButton:EnableMouse(false)
                                                    if (MINES.COOPMode) then
                                                        MINES.PartnerCursor:Show()
                                                    end
                                                    if (MINES.EndGame) then
                                                        MINES.Field.StartGameButton:Show()
                                                    end
                                                    MINES.Field.SettingsButton:Show()
                                                    MINES.Field.MinesLeft:Show()
                                                    local animSpeed = 0
                                                    MINES.Field.Header.HideButton:SetScript("OnUpdate", function()
                                                        if (GetFramerate() < 20) then
                                                            animSpeed = 100
                                                        elseif (GetFramerate() < 30) then
                                                            animSpeed = 80
                                                        elseif (GetFramerate() >= 30 and GetFramerate() <= 60) then
                                                            animSpeed = 65
                                                        else
                                                            animSpeed = 45
                                                        end
                                                        MINES.Field:SetHeight(MINES.Field:GetHeight()+animSpeed)
                                                        if (MINES.Field:GetHeight() >= MINES.GameDifficulty[MINES.CurrentDifficulty].fieldHeight + fieldHeaderH) then
                                                            MINES.Field.Header.HideButton:SetScript("OnUpdate", nil)
                                                            MINES.Field:SetHeight(MINES.GameDifficulty[MINES.CurrentDifficulty].fieldHeight + fieldHeaderH)
                                                            for i = 1, MINES.GetActualMaxCells() do
                                                                MINES.Field.Cells[i]:Show()
                                                            end
                                                            MINES.Field.Header.HideButton:EnableMouse(true)
                                                        end
                                                    end)
                                                end

                                                if (MINES.IsGameHidden) then
                                                    OpenFromHeader()
                                                else
                                                    HideToHeader()
                                                end
                                                MINES.IsGameHidden = not MINES.IsGameHidden
                                            end)

    MINES.Field.Header.GameMode = LoutenLib:CreateNewFrame(MINES.Field.Header)
    MINES.Field.Header.GameMode:InitNewFrame(200, fieldHeaderH,
                                            "LEFT", MINES.Field.Header, "LEFT", 10, 0,
                                            0,0,0,0, false, false, nil)      
    MINES.Field.Header.GameMode:SetTextToFrame("LEFT", MINES.Field.Header.GameMode, "LEFT", 0,0, true, 11, "Режим: "..select(2, MINES.GetMode()))

    MINES.Field.Header.PartnerInfo = LoutenLib:CreateNewFrame(MINES.Field.Header)
    MINES.Field.Header.PartnerInfo:InitNewFrame(200, fieldHeaderH,
                                            "LEFT", MINES.Field.Header.Text, "LEFT", 80, 0,
                                            0,0,0,0, false, false, nil)      
    MINES.Field.Header.PartnerInfo:SetTextToFrame("LEFT", MINES.Field.Header.PartnerInfo, "LEFT", 0,0, true, 11, "COOP:")
    MINES.Field.Header.PartnerInfo:Hide()
    MINES.Field.Header.PartnerInfo.Text:SetTextColor(.5,1,.5,1)




    MINES.Field.SettingsButton = LoutenLib:CreateNewFrame(MINES.Field)
    MINES.Field.SettingsButton:InitNewFrame(130, 25,
                                        "TOPLEFT", MINES.Field, "TOPLEFT", 0, 25,
                                        0,0,0,1,
                                        true, false, nil)
    MINES.Field.SettingsButton:SetTextToFrame("CENTER", MINES.Field.SettingsButton, "CENTER", 0,0, true, MINES.Field.SettingsButton:GetHeight() / 2.1, "Настройки")
    MINES.Field.SettingsButton.Arrow = LoutenLib:CreateNewFrame(MINES.Field.SettingsButton)
    MINES.Field.SettingsButton.Arrow:InitNewFrame(MINES.Field.SettingsButton:GetHeight()/1.5, MINES.Field.SettingsButton:GetHeight()/1.5,
                                                        "RIGHT", MINES.Field.SettingsButton, "RIGHT", -(MINES.Field.SettingsButton:GetHeight()*0.1), 0,
                                                        0,0,0,0,
                                                        false, false, nil)
    MINES.Field.SettingsButton.Arrow.Texture:SetTexture("Interface\\AddOns\\"..MINES.Info.FileName.."\\textures\\movedown.tga")
    MINES.Field.SettingsButton:InitNewButton(.15,.15,.15,1,
                                        0,0,0,1,
                                        .1,.1,.1,1,
                                        .15,.15,.15,1,
                                        function()
                                            if (MINES.Field.Settings:IsShown()) then
                                                if (not MINES.Field.SettingsButton.IsActive) then
                                                    MINES.Field.SettingsButton.Arrow.Texture:SetTexture("Interface\\AddOns\\"..MINES.Info.FileName.."\\textures\\movedown.tga")
                                                    MINES.CloseSettings()
                                                end
                                            else
                                                if (not MINES.Field.SettingsButton.IsActive) then
                                                    MINES.Field.SettingsButton.Arrow.Texture:SetTexture("Interface\\AddOns\\"..MINES.Info.FileName.."\\textures\\moveup.tga")
                                                    MINES.OpenSettings()
                                                end
                                            end
                                        end, nil)
    MINES.Field.SettingsButton.IsActive = false










    MINES.Field.Settings = LoutenLib:CreateNewFrame(MINES.Field.Header)
    MINES.Field.Settings:InitNewFrame(MINES.Field:GetWidth(), MINES.Field:GetHeight() - fieldHeaderH,
                                    "TOP", MINES.Field.Header, "TOP", 0, -fieldHeaderH,
                                    0,0,0,.8,
                                    true, false, nil)
    MINES.Field.Settings:Hide()
    function MINES.CloseSettings()
        MINES.Field.SettingsButton.IsActive = true
        local children  = {MINES.Field.Settings:GetChildren()}
        for i, child in ipairs(children) do
            child:Hide()
        end
        local animSpeed = 0
        MINES.Field.Settings:SetScript("OnUpdate", function()
            if (GetFramerate() < 20) then
                animSpeed = 100
            elseif (GetFramerate() < 30) then
                animSpeed = 70
            elseif (GetFramerate() >= 30 and GetFramerate() <= 60) then
                animSpeed = 35
            else
                animSpeed = 20
            end
            MINES.Field.Settings:SetHeight(MINES.Field.Settings:GetHeight() - animSpeed)
            if (MINES.Field.Settings:GetHeight() <= 0) then
                MINES.Field.Settings:SetScript("OnUpdate", nil)
                MINES.Field.Settings:SetHeight(0)
                MINES.Field.Settings:Hide()
                MINES.Field.SettingsButton.IsActive = false
            end
        end)
    end
    function MINES.OpenSettings()
        MINES.Field.SettingsButton.IsActive = true
        local animSpeed = 0
        if (GetFramerate() < 20) then
            animSpeed = 100
        elseif (GetFramerate() < 30) then
            animSpeed = 70
        elseif (GetFramerate() >= 30 and GetFramerate() <= 60) then
            animSpeed = 35
        else
            animSpeed = 20
        end
        MINES.Field.Settings:SetHeight(0)
        MINES.Field.Settings:Show()
        MINES.Field.Settings:SetScript("OnUpdate", function()
            if (GetFramerate() < 20) then
                animSpeed = 100
            elseif (GetFramerate() < 30) then
                animSpeed = 70
            elseif (GetFramerate() >= 30 and GetFramerate() <= 60) then
                animSpeed = 35
            else
                animSpeed = 20
            end
            MINES.Field.Settings:SetHeight(MINES.Field.Settings:GetHeight() + animSpeed)
            if (MINES.Field.Settings:GetHeight() >= MINES.Field:GetHeight() - fieldHeaderH) then
                MINES.Field.Settings:SetScript("OnUpdate", nil)
                MINES.Field.Settings:SetHeight(MINES.Field:GetHeight() - fieldHeaderH)
                local children  = {MINES.Field.Settings:GetChildren()}
                for i, child in ipairs(children) do
                    child:Show()
                end
                MINES.Field.SettingsButton.IsActive = false
            end
        end)
    end
    MINES.Field.Settings.Box = LoutenLib:CreateNewFrame(MINES.Field.Settings)
    MINES.Field.Settings.Box:InitNewFrame(MINES.GameDifficulty["easy"].fieldWidth * 0.75, MINES.Field.Settings:GetHeight() * 0.85,
                                        "CENTER", MINES.Field.Settings, "CENTER", 0,0,
                                        0,0,0,0, false, false, nil)
    MINES.Field.Settings.Box:Hide()













    MINES.Field.Settings.ChangeDifficulty = LoutenLib:CreateNewFrame(MINES.Field.Settings.Box)
    MINES.Field.Settings.ChangeDifficulty:InitNewFrame2(180, 25,
                                        "TOPLEFT", MINES.Field.Settings.Box, "TOPLEFT", 0, 0,
                                        3,168,116,.8,
                                        true, false, nil)
    MINES.Field.Settings.ChangeDifficulty:InitNewDropDownList(3,168,116,.8,
                                                                "down", "Button",
                                                                "Сложность: "..select(3,MINES.GetDifficulty()),
                                                                {"Easy", "Medium", "Hard"},
                                                                {function()
                                                                    if (MINES.COOPMode and not MINES.IsHosting) then return end
                                                                    MINES.ChangeDifficulty("easy")
                                                                    MINES.Field.Settings.ChangeDifficulty.DropDownButton.Text:SetText("Сложность: Easy")
                                                                end,
                                                                function()
                                                                    if (MINES.COOPMode and not MINES.IsHosting) then return end
                                                                    MINES.ChangeDifficulty("medium")
                                                                    MINES.Field.Settings.ChangeDifficulty.DropDownButton.Text:SetText("Сложность: Medium")
                                                                end,
                                                                function()
                                                                    if (MINES.COOPMode and not MINES.IsHosting) then return end
                                                                    MINES.ChangeDifficulty("hard")
                                                                    MINES.Field.Settings.ChangeDifficulty.DropDownButton.Text:SetText("Сложность: Hard")
                                                                end})


    MINES.Field.Settings.ChangeMode = LoutenLib:CreateNewFrame(MINES.Field.Settings.Box)
    MINES.Field.Settings.ChangeMode:InitNewFrame2(190, 25,
                                        "TOPRIGHT", MINES.Field.Settings.Box, "TOPRIGHT", 0, 0,
                                        168, 75, 3,.8,
                                        true, false, nil)
    MINES.Field.Settings.ChangeMode:InitNewDropDownList(168, 75, 3,.8,
                                                                "down", "Button",
                                                                "Режим: "..select(2, MINES.GetMode()),
                                                                {"Стандартный", "Игра на время"},
                                                                {function()
                                                                    if (MINES.COOPMode and not MINES.IsHosting) then return end
                                                                    MINES.NextMode = 0
                                                                    MINES.Field.Settings.ChangeMode.DropDownButton.Text:SetText("Режим: Стандартный")
                                                                end,
                                                                function()
                                                                    if (MINES.COOPMode and not MINES.IsHosting) then return end
                                                                    MINES.NextMode = 1
                                                                    MINES.Field.Settings.ChangeMode.DropDownButton.Text:SetText("Режим: Игра на время")
                                                                end})









    MINES.Field.Settings.InvitePlayerBox = LoutenLib:CreateNewFrame(MINES.Field.Settings.Box)
    MINES.Field.Settings.InvitePlayerBox:InitNewFrame(170, 42,
                                                "CENTER", MINES.Field.Settings.Box, "CENTER", 0, 0,
                                                0,0,0,0, false, false, nil)
    MINES.Field.Settings.InvitePlayerBox.Text = LoutenLib:CreateNewFrame(MINES.Field.Settings.InvitePlayerBox)
    MINES.Field.Settings.InvitePlayerBox.Text:SetTextToFrame("TOPLEFT", MINES.Field.Settings.InvitePlayerBox, "TOPLEFT", 0,0, true, 12, "Пригласить игрока:")
    MINES.Field.Settings.InvitePlayerBox.Input = LoutenLib:CreateNewFrame(MINES.Field.Settings.InvitePlayerBox)
    MINES.Field.Settings.InvitePlayerBox.Input:InitNewFrame(140, 18,
                                                "BOTTOMLEFT", MINES.Field.Settings.InvitePlayerBox, "BOTTOMLEFT", 0, 0,
                                                .8,.8,.8,1,
                                                true, false, nil)
    MINES.Field.Settings.InvitePlayerBox.Input:InitNewInput(13, 20, 0,0,.1,1,
                                                nil, nil)
    MINES.Field.Settings.InvitePlayerBox.SendButton = LoutenLib:CreateNewFrame(MINES.Field.Settings.InvitePlayerBox)
    MINES.Field.Settings.InvitePlayerBox.SendButton:InitNewFrame(25, 18,
                                                            "BOTTOMRIGHT", MINES.Field.Settings.InvitePlayerBox, "BOTTOMRIGHT", 0,0,
                                                            1,.3,.1,1, true, false, nil)
    MINES.Field.Settings.InvitePlayerBox.SendButton:SetTextToFrame("CENTER", MINES.Field.Settings.InvitePlayerBox.SendButton, "CENTER", 0,0, true, 12, "Ок")
    MINES.Field.Settings.InvitePlayerBox.SendButton:InitNewButton(1,.4,.2,1,
                                                            1,.3,.1,1,
                                                            1,.2,.05,1,
                                                            1,.4,.2,1, nil,
                                                            function()
                                                                if (MINES.COOPMode) then return end
                                                                if (MINES.Field.Settings.InvitePlayerBox.Input.EditBox:GetText() ~= UnitName("player")) then
                                                                    COOP_Send_InvitePartner(MINES.Field.Settings.InvitePlayerBox.Input.EditBox:GetText())
                                                                    return
                                                                end
                                                            end)













    MINES.Field.MinesLeft = LoutenLib:CreateNewFrame(MINES.Field)
    MINES.Field.MinesLeft:InitNewFrame(60, 30,
                                    "BOTTOM", MINES.Field, "TOP", 170, 0,
                                    0,0,0,.85, false, false, nil)
    MINES.Field.MinesLeft:SetTextToFrame("RIGHT", MINES.Field.MinesLeft, "RIGHT", -3,0, true, 15, tostring(MINES.GameDifficulty[MINES.CurrentDifficulty].minesCount))
    MINES.Field.MinesLeft.Icon = LoutenLib:CreateNewFrame(MINES.Field.MinesLeft)
    MINES.Field.MinesLeft.Icon:InitNewFrame(23,23,
                                            "LEFT", MINES.Field.MinesLeft, "LEFT", 0,0,
                                            0,0,0,0)
    MINES.Field.MinesLeft.Icon.Texture:SetTexture("Interface\\AddOns\\"..MINES.Info.FileName.."\\textures\\flag.blp")












    MINES.Field.Settings.LeaveCOOP = LoutenLib:CreateNewFrame(MINES.Field.Settings.Box)
    MINES.Field.Settings.LeaveCOOP:InitNewFrame(120, 23,
                                            "BOTTOM", MINES.Field.Settings.InvitePlayerBox, "BOTTOM", 0, -40,
                                            .7,0,0,1, true, false, nil)
    MINES.Field.Settings.LeaveCOOP:SetTextToFrame("CENTER", MINES.Field.Settings.LeaveCOOP, "CENTER", 0,0, true, 11, "Покинуть КООП")
    MINES.Field.Settings.LeaveCOOP:InitNewButton(1,.1,.1,1,
                                                .7,0,0,1,
                                                .6,0,0,1,
                                                1,.1,.1,1,
                                                nil, 
                                                function()
                                                    COOP_Send_SendLeaveCOOP()
                                                    MINES.DisconnectCOOP(1)
                                                end)
    MINES.Field.Settings.LeaveCOOP:Hide()














    MINES.Field.Settings.LeaveMeAlone = LoutenLib:CreateNewFrame(MINES.Field.Settings.Box)
    MINES.Field.Settings.LeaveMeAlone:InitNewFrame(100, 25,
                                                    "BOTTOM", MINES.Field.Settings.LeaveCOOP, "BOTTOM", -40, -40,
                                                    0,0,0,0, true, false, nil)
    MINES.Field.Settings.LeaveMeAlone:InitNewCheckButton(20, false, "Отключить приглашения\nот других игроков", true, 12,
                                                            function()
                                                                MINES_DB.Profiles[UnitName("player")].LeaveMeAlone = not MINES_DB.Profiles[UnitName("player")].LeaveMeAlone
                                                            end)
    if (MINES_DB.Profiles[UnitName("player")].LeaveMeAlone) then
        MINES.Field.Settings.LeaveMeAlone.CheckButton:SetChecked(MINES_DB.Profiles[UnitName("player")].LeaveMeAlone)
    end












    MINES.Field.ResumeGame = LoutenLib:CreateNewFrame(MINES.Field)
    MINES.Field.ResumeGame:Hide()
    MINES.Field.ResumeGame:InitNewFrame(MINES.Field.Settings.Box:GetWidth(), 60,
                                        "CENTER", MINES.Field, "CENTER", 0,0,
                                        0,0,0,.735, true, false, nil)
    MINES.Field.ResumeGame.ResumeBT = LoutenLib:CreateNewFrame(MINES.Field.ResumeGame)
    MINES.Field.ResumeGame.ResumeBT:InitNewFrame2(MINES.Field.ResumeGame:GetWidth()/2 * .9, MINES.Field.ResumeGame:GetHeight() * .7,
                                                    "LEFT", MINES.Field.ResumeGame, "LEFT", 10,0,
                                                    250, 128, 52,1, true, false, nil)
    MINES.Field.ResumeGame.ResumeBT:InitNewButton2(250, 128, 52,1,
                                                    nil, function()
                                                        COOP_Send_ChangeDifficulty(MINES.CurrentDifficulty)
                                                        COOP_Send_CreateNewGame()
                                                    end)
    MINES.Field.ResumeGame.ResumeBT:SetTextToFrame("CENTER", MINES.Field.ResumeGame.ResumeBT, "CENTER", 0,0, true, 12, "Продолжить игру")

    MINES.Field.ResumeGame.NewGameBT = LoutenLib:CreateNewFrame(MINES.Field.ResumeGame)
    MINES.Field.ResumeGame.NewGameBT:InitNewFrame2(MINES.Field.ResumeGame:GetWidth()/2 * .9, MINES.Field.ResumeGame:GetHeight() * .7,
                                                    "RIGHT", MINES.Field.ResumeGame, "RIGHT", -10,0,
                                                    125, 255, 92, 1, true, false, nil)
    MINES.Field.ResumeGame.NewGameBT:InitNewButton2(125, 255, 92, 1,
                                                    nil, function()
                                                        MINES.Field.ResumeGame:Hide()
                                                        MINES.StartGameButtonFunction()
                                                    end)
    MINES.Field.ResumeGame.NewGameBT:SetTextToFrame("CENTER", MINES.Field.ResumeGame.NewGameBT, "CENTER", 0,0, true, 12, "Начать новую игру")
    function MINES.RestartFieldInterface()
        local function RestorePoint(f)
            local point, relativeTo, relativePoint, xOfs, yOfs = f:GetPoint()
            f:ClearAllPoints()
            f:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs)
        end
        RestorePoint(MINES.Field.StartGameButton)
        RestorePoint(MINES.Field.Header.HideButton)
        RestorePoint(MINES.Field.Header.CloseButton)
        RestorePoint(MINES.Field.Header.Text)
    end











    MINES.Field.TimeLeft = LoutenLib:CreateNewFrame(MINES.Field)
    MINES.Field.TimeLeft:InitNewFrame(60, 30,
                                    "RIGHT", MINES.Field.MinesLeft, "LEFT", -10, 0,
                                    0,0,0,.85, false, false, nil)
    MINES.Field.TimeLeft:SetTextToFrame("RIGHT", MINES.Field.TimeLeft, "RIGHT", -3,0, true, 15, "")
    MINES.Field.TimeLeft:Hide()
    MINES.Field.TimeLeft.Icon = LoutenLib:CreateNewFrame(MINES.Field.TimeLeft)
    MINES.Field.TimeLeft.Icon:InitNewFrame(23,23,
                                            "LEFT", MINES.Field.TimeLeft, "LEFT", 0,0,
                                            0,0,0,0)
    MINES.Field.TimeLeft.Icon.Texture:SetTexture("Interface\\AddOns\\"..MINES.Info.FileName.."\\textures\\timer.blp")
end
















GLOBALTEST = false
local _1 = 0
SlashCmdList.TESTTT = function(msg, editBox)
    if (#msg == 0) then
        GLOBALTEST = false
        _1 = 0
        local qwe = GetTime()
        local fff = CreateFrame("Frame")
        fff:SetScript("OnUpdate", function()
            if (MINES.EndGame) then
                _1 = _1 + 1
                MINES.StartGameButtonFunction()
                if (GLOBALTEST) then
                    fff:SetScript("OnUpdate", nil)
                    MINES.LoseGame()
                    MINES:PrintMsg("Попыток: ".._1)
                    MINES:PrintMsg("Время: "..GetTime() - qwe)
                    for i = 1, MINES.GetActualMaxCells() do
                        if (MINES.Field.Cells[i].New) then
                            MINES.Field.Cells[i]:SetBackdropColor(.3,1,.9,1)
                        end
                        if (MINES.Field.Cells[i].Old) then
                            MINES.Field.Cells[i]:SetBackdropColor(1,.7,0,1)
                        end
                        MINES.Field.Cells[i].Old = false
                        MINES.Field.Cells[i].New = false
                    end
                    return
                end
                MINES.LoseGame()
                for i = 1, MINES.GetActualMaxCells() do
                    MINES.Field.Cells[i].Old = false
                    MINES.Field.Cells[i].New = false
                end
            end
        end)
    end
end

SLASH_TESTTT1 = "/t123"
