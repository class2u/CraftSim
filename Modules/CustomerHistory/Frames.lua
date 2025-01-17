---@class CraftSim
local CraftSim = select(2, ...)

local GGUI = CraftSim.GGUI

CraftSim.CUSTOMER_HISTORY.FRAMES = {}
CraftSim.CUSTOMER_HISTORY.timeoutSeconds = 5

CraftSim.CUSTOMER_HISTORY.frame = nil

local print = CraftSim.UTIL:SetDebugPrint(CraftSim.CONST.DEBUG_IDS.CUSTOMER_HISTORY)

---@param LOCALIZATION_ID CraftSim.LOCALIZATION_IDS
local function L(LOCALIZATION_ID)
    return CraftSim.LOCAL:GetText(LOCALIZATION_ID)
end

function CraftSim.CUSTOMER_HISTORY.FRAMES:Init()
    local sizeX=1050
    local sizeY=500
    CraftSim.CUSTOMER_HISTORY.frame = GGUI.Frame({
        parent=ProfessionsFrame,
        anchorParent=ProfessionsFrame,
        sizeX=sizeX,sizeY=sizeY,
        frameID=CraftSim.CONST.FRAMES.CUSTOMER_HISTORY,
        title=L(CraftSim.CONST.TEXT.CUSTOMER_HISTORY_TITLE),
        collapseable=true,
        closeable=true,
        moveable=true,
        backdropOptions=CraftSim.CONST.DEFAULT_BACKDROP_OPTIONS,
        frameStrata="DIALOG",
        onCloseCallback=CraftSim.FRAME:HandleModuleClose("modulesCustomerHistory"),
        frameTable=CraftSim.MAIN.FRAMES,
        frameConfigTable=CraftSimGGUIConfig,
    })

    local function createContent(frame)
        frame:Hide()

        ---@type GGUI.FrameList.ColumnOption[]
        local columnOptionsCustomerList = {
            {
                label=L(CraftSim.CONST.TEXT.CUSTOMER_HISTORY_CUSTOMER_HEADER),
                width=100,
            },
            {
                label =L(CraftSim.CONST.TEXT.CUSTOMER_HISTORY_TOTAL_TIP_HEADER),
                width=70,
            },
            {
                label="", -- the remove column
                width=30,
                justifyOptions={type="H", align="CENTER"}
            }
        }
        frame.content.customerList = GGUI.FrameList({  
            sizeY=390, columnOptions=columnOptionsCustomerList, parent=frame.content, anchorParent=frame.content, anchorA="TOPLEFT", anchorB="TOPLEFT", 
            offsetY=-80, offsetX=30, rowHeight=20,
            showBorder=true,
            rowConstructor = function (columns)
                local customerColumn = columns[1]
                local tipColumn = columns[2] 
                local removeColumn = columns[3] 

                local rowContentScale = 0.9

                customerColumn.text = GGUI.Text({
                    parent=customerColumn, anchorParent=customerColumn, anchorA="LEFT", anchorB="LEFT", offsetX=2,
                    justifyOptions={type="H", align="LEFT"}, text="", scale=rowContentScale
                })
                tipColumn.text = GGUI.Text({
                    parent=tipColumn, anchorParent=tipColumn, anchorA="RIGHT", anchorB="RIGHT", offsetX=-10,
                    justifyOptions={type="H", align="RIGHT"}, text=CraftSim.GUTIL:FormatMoney(0), scale=rowContentScale
                })
                removeColumn.removeButton = GGUI.Button({
                    parent=removeColumn, anchorParent=removeColumn, scale = 0.8,
                    label=CraftSim.MEDIA:GetAsTextIcon(CraftSim.MEDIA.IMAGES.FALSE, 0.15),
                    sizeX=25, clickCallback = nil -- set dynamically in Add
                })
            end,
            selectionOptions={
                selectionCallback=function (row)
                    CraftSim.CUSTOMER_HISTORY.FRAMES:OnCustomerSelected(row.customerHistory)
                end
            }
        })

        frame.content.purgeCustomers = GGUI.Button{
            parent=frame.content, anchorParent=frame.content.customerList.frame, anchorA="BOTTOMLEFT", anchorB="TOPLEFT", offsetY=20,
            label=L(CraftSim.CONST.TEXT.CUSTOMER_HISTORY_PURGE_NO_TIP_LABEL), adjustWidth=true,
            clickCallback=function ()
                GGUI:ShowPopup({
                    sizeY=120, title=L(CraftSim.CONST.TEXT.CUSTOMER_HISTORY_PURGE_ZERO_TIPS_CONFIRMATION_POPUP_TITLE),
                    text=L(CraftSim.CONST.TEXT.CUSTOMER_HISTORY_PURGE_ZERO_TIPS_CONFIRMATION_POPUP),
                    anchorParent=frame.content.purgeCustomers.frame, anchorA="CENTER", anchorB="CENTER",
                    onAccept=function ()
                        CraftSim.CUSTOMER_HISTORY:PurgeZeroTipCustomers()
                    end
                })
            end
        }

        frame.content.autoPurgeInput = GGUI.NumericInput{
            parent=frame.content, anchorParent=frame.content.purgeCustomers.frame, anchorA = "BOTTOMLEFT", anchorB="TOPLEFT",
            label=L(CraftSim.CONST.TEXT.CUSTOMER_HISTORY_PURGE_DAYS_INPUT_LABEL), offsetX=7,
            sizeX = 50, minValue = 0, onNumberValidCallback=function (numericInput)
                local value = tonumber(numericInput.currentValue)
                CraftSimOptions.customerHistoryAutoPurgeInterval = value
            end, initialValue=CraftSimOptions.customerHistoryAutoPurgeInterval
        }

        frame.content.autoPurgeInputLabel = GGUI.Text{parent=frame.content, anchorParent=frame.content.autoPurgeInput.textInput.frame, anchorA="LEFT", anchorB="RIGHT", 
        text=L(CraftSim.CONST.TEXT.CUSTOMER_HISTORY_PURGE_DAYS_INPUT_LABEL), offsetX=5}

        GGUI.HelpIcon{parent=frame.content, anchorParent=frame.content.autoPurgeInputLabel.frame, anchorA="LEFT", anchorB="RIGHT", 
        text=L(CraftSim.CONST.TEXT.CUSTOMER_HISTORY_PURGE_DAYS_INPUT_TOOLTIP)}

        frame.content.customerName = GGUI.Text({
            parent=frame.content, anchorParent=frame.content, anchorA="TOP", anchorB="TOP",
            text="", offsetX=80, offsetY=-50, scale=1.5,
        })

        frame.content.whisperButton = GGUI.Button{
            parent=frame.content, anchorParent=frame.content.customerName.frame,
            label=L(CraftSim.CONST.TEXT.CUSTOMER_HISTORY_WHISPER_BUTTON_LABEL), adjustWidth=true,
            anchorA="LEFT", anchorB="RIGHT", offsetX=10,
        }

        local chatMessageColumnWidth=450

        ---@type GGUI.FrameList.ColumnOption[]
        local columnOptionsChatFrame = {
            {
                label="", -- Timestamp
                width=100,
                justifyOptions={type="H", align="RIGHT"}
            },
            {
                label="", -- Sender
                width=100,
                justifyOptions={type="H", align="RIGHT"}
            },
            {
                label ="", -- Message
                width=chatMessageColumnWidth,
                justifyOptions={type="H", align="LEFT"}
            }
        }

        frame.content.chatMessageList = GGUI.FrameList({
            parent=frame.content, anchorParent=frame.content.customerName.frame, anchorA="TOP", anchorB="BOTTOM", offsetY=-8,
            columnOptions=columnOptionsChatFrame, showBorder=true, rowHeight=20, sizeY=200,
            rowConstructor=function (columns)
                local timeColumn = columns[1]
                local senderColumn = columns[2]
                local messageColumn = columns[3]
                
                timeColumn.text = GGUI.Text({
                    parent=timeColumn, anchorParent=timeColumn, anchorA="RIGHT",
                    anchorB="RIGHT", justifyOptions={type="H", align="RIGHT"}, text="Timestamp"                
                })
                senderColumn.text = GGUI.Text({
                    parent=senderColumn, anchorParent=senderColumn, anchorA="RIGHT",
                    anchorB="RIGHT", justifyOptions={type="H", align="RIGHT"}, text="Sender"                
                })
                messageColumn.text = GGUI.Text({
                    parent=messageColumn, anchorParent=messageColumn, anchorA="TOPLEFT",
                    anchorB="TOPLEFT", justifyOptions={type="HV", alignH="LEFT", alignV="LEFT"}, text="Message", fixedWidth=chatMessageColumnWidth, offsetY=-4.1,                
                })

                GGUI:EnableHyperLinksForFrameAndChilds(messageColumn)
            end
        })

        ---@type GGUI.FrameList.ColumnOption[]
        local columnOptionsCraftList = {
            {
                label=L(CraftSim.CONST.TEXT.CUSTOMER_HISTORY_CRAFT_HISTORY_DATE_HEADER), -- Timestamp
                width=100,
                justifyOptions={type="H", align="LEFT"}
            },
            {
                label=L(CraftSim.CONST.TEXT.CUSTOMER_HISTORY_CRAFT_HISTORY_RESULT_HEADER), -- Result
                width=250,
                justifyOptions={type="H", align="RIGHT"}
            },
            {
                label =L(CraftSim.CONST.TEXT.CUSTOMER_HISTORY_CRAFT_HISTORY_TIP_HEADER), -- Tip
                width=100,
                justifyOptions={type="H", align="RIGHT"}
            },
            {
                label =L(CraftSim.CONST.TEXT.CUSTOMER_HISTORY_CRAFT_HISTORY_CUSTOMER_REAGENTS_HEADER), 
                width=150,
                justifyOptions={type="H", align="CENTER"}
            },
            {
                label =L(CraftSim.CONST.TEXT.CUSTOMER_HISTORY_CRAFT_HISTORY_CUSTOMER_NOTE_HEADER), -- Customer Note
                width=50,
                justifyOptions={type="H", align="CENTER"}
            }
        }

        frame.content.craftList = GGUI.FrameList({
            parent=frame.content, anchorParent=frame.content.chatMessageList.frame, anchorA="TOPLEFT", anchorB="BOTTOMLEFT", offsetY=-30,
            columnOptions=columnOptionsCraftList, showBorder = true, rowHeight=20, sizeY=150,
            rowConstructor=function (columns)
                local timeColumn = columns[1]
                local resultColumn = columns[2]
                local tipColumn = columns[3]
                local reagentColumn = columns[4]
                local noteColumn = columns[5]
                
                timeColumn.text = GGUI.Text({
                    parent=timeColumn, anchorParent=timeColumn, anchorA="LEFT",
                    anchorB="LEFT", justifyOptions={type="H", align="LEFT"}, text="Timestamp"                
                })
                resultColumn.text = GGUI.Text({
                    parent=resultColumn, anchorParent=resultColumn, anchorA="RIGHT",
                    anchorB="RIGHT", justifyOptions={type="H", align="LEFT"}, text="ResultLink"                
                })
                tipColumn.text = GGUI.Text({
                    parent=tipColumn, anchorParent=tipColumn, anchorA="RIGHT",
                    anchorB="RIGHT", justifyOptions={type="H", align="RIGHT"}, text="Tip",                
                })
                reagentColumn.icon = GGUI.HelpIcon({
                    parent=reagentColumn, anchorParent=reagentColumn, text="Reagents",                
                })

                noteColumn.icon = GGUI.HelpIcon{
                    parent=noteColumn, anchorParent=noteColumn, text="SomeNote"
                }

                GGUI:EnableHyperLinksForFrameAndChilds(resultColumn)
            end
        })
    end

    createContent(CraftSim.CUSTOMER_HISTORY.frame)
end

function CraftSim.CUSTOMER_HISTORY.FRAMES:UpdateDisplay()
    CraftSim.CUSTOMER_HISTORY.FRAMES:UpdateCustomerHistoryList()
end
    
function CraftSim.CUSTOMER_HISTORY.FRAMES:UpdateCustomerHistoryList()
    if not CraftSimCustomerHistoryV2 then
        return
    end

    ---@type GGUI.FrameList
    local customerList = CraftSim.CUSTOMER_HISTORY.frame.content.customerList
    customerList:Remove()

    for _, customerHistory in pairs(CraftSimCustomerHistoryV2) do
        customerList:Add(function (row) 
            local columns = row.columns
            local customerColumn = columns[1]
            local tipColumn = columns[2] 
            local removeColumn = columns[3] 
            row.customerHistory = customerHistory
            customerColumn.text:SetText(customerHistory.customer)
            tipColumn.text:SetText(CraftSim.GUTIL:FormatMoney(customerHistory.totalTip or 0))
            removeColumn.removeButton.clickCallback = function ()
                GGUI:ShowPopup({
                    sizeY=120, title=L(CraftSim.CONST.TEXT.CUSTOMER_HISTORY_DELETE_CUSTOMER_POPUP_TITLE),
                    anchorParent=removeColumn.removeButton.frame, anchorA="CENTER", anchorB="CENTER",
                    onAccept=function ()
                        CraftSim.CUSTOMER_HISTORY:RemoveCustomer(row, customerHistory)
                    end, text=string.format(L(CraftSim.CONST.TEXT.CUSTOMER_HISTORY_DELETE_CUSTOMER_CONFIRMATION_POPUP), customerHistory.customer)
                })

            end
        end)
    end 

    customerList:UpdateDisplay(function (rowA, rowB)
        return rowA.customerHistory.totalTip >= rowB.customerHistory.totalTip
    end)

    if not customerList.selectedRow then
        customerList:SelectRow(1)
    end

    local hideCustomerInfo = not CraftSimCustomerHistoryV2 or CraftSim.GUTIL:Count(CraftSimCustomerHistoryV2) == 0
    if hideCustomerInfo then
        CraftSim.CUSTOMER_HISTORY.frame.content.customerName:Hide()
        CraftSim.CUSTOMER_HISTORY.frame.content.whisperButton:Hide()
        CraftSim.CUSTOMER_HISTORY.frame.content.craftList:Hide()
        CraftSim.CUSTOMER_HISTORY.frame.content.chatMessageList:Hide()
    else
        CraftSim.CUSTOMER_HISTORY.frame.content.customerName:Show()
        CraftSim.CUSTOMER_HISTORY.frame.content.whisperButton:Show()
        CraftSim.CUSTOMER_HISTORY.frame.content.craftList:Show()
        CraftSim.CUSTOMER_HISTORY.frame.content.chatMessageList:Show()
    end
end

---@param customerHistory CraftSim.CustomerHistory
function CraftSim.CUSTOMER_HISTORY.FRAMES:OnCustomerSelected(customerHistory)
    ---@type GGUI.Text
    local customerName = CraftSim.CUSTOMER_HISTORY.frame.content.customerName
    local fullName = customerHistory.customer .. "-" .. customerHistory.realm
    customerName:SetText(customerHistory.customer .. "-" .. customerHistory.realm)
    CraftSim.CUSTOMER_HISTORY.frame.content.whisperButton.clickCallback = function ()
        CraftSim.CUSTOMER_HISTORY:StartWhisper(fullName)
    end

    CraftSim.CUSTOMER_HISTORY.FRAMES:UpdateCustomerChatHistory(customerHistory.customer, customerHistory.chatHistory)
    CraftSim.CUSTOMER_HISTORY.FRAMES:UpdateCustomerCraftHistory(customerHistory.craftHistory)
end

---@param craftHistory CraftSim.CustomerHistory.Craft
function CraftSim.CUSTOMER_HISTORY.FRAMES:UpdateCustomerCraftHistory(craftHistory)
    ---@type GGUI.FrameList
    local craftList = CraftSim.CUSTOMER_HISTORY.frame.content.craftList

    craftList:Remove()

    ---@type CraftSim.CustomerHistory.Craft[]
    local craftsSorted = CraftSim.GUTIL:Sort(craftHistory, 
    ---@param craftA CraftSim.CustomerHistory.Craft
    ---@param craftB CraftSim.CustomerHistory.Craft
    function(craftA, craftB) 
        return craftA.timestamp > craftB.timestamp
    end)

    local f = CraftSim.UTIL:GetFormatter()
    for _, craft in pairs(craftsSorted) do
        craftList:Add(function (row)
            local columns = row.columns
            local timeColumn = columns[1]
            local resultColumn = columns[2]
            local tipColumn = columns[3]
            local reagentColumn = columns[4]
            local noteColumn = columns[5]

            timeColumn.text:SetText(CraftSim.CUSTOMER_HISTORY.FRAMES:GetNormalizedDayString(craft.timestamp))
    
            resultColumn.text:SetText(tostring(craft.itemLink))
            tipColumn.text:SetText(f.m(craft.tip))

            noteColumn.icon:SetText(craft.customerNotes)
            noteColumn.icon:SetEnabled(#craft.customerNotes > 0)

            local reagentItems = CraftSim.GUTIL:Map(craft.reagents, function(r) return Item:CreateFromItemID(r.reagent.itemID) end)
            CraftSim.GUTIL:ContinueOnAllItemsLoaded(reagentItems, function ()     
                local reagentText=""
                for _, reagent in pairs(craft.reagents) do
                    local item = Item:CreateFromItemID(reagent.reagent.itemID)
                    local qualityID = CraftSim.GUTIL:GetQualityIDFromLink(item:GetItemLink())
                    local qualityIcon = ""
                    local itemIcon = CraftSim.GUTIL:IconToText(item:GetItemIcon(), 20, 20)
                    if qualityID then
                        qualityIcon = CraftSim.GUTIL:GetQualityIconString(qualityID, 20, 20, 0, 0)
                    end
                    reagentText = reagentText .. itemIcon .. qualityIcon .. " x " .. reagent.reagent.quantity .. "\n"
                end
                reagentColumn.icon:SetText(reagentText)
            end)

        end)
    end

    craftList:UpdateDisplay()
end

---@param chatHistory CraftSim.CustomerHistory.ChatMessage
function CraftSim.CUSTOMER_HISTORY.FRAMES:UpdateCustomerChatHistory(customer, chatHistory)
    
    ---@type GGUI.FrameList
    local chatMessageList = CraftSim.CUSTOMER_HISTORY.frame.content.chatMessageList

    chatMessageList:Remove()

    ---@type CraftSim.CustomerHistory.ChatMessage[]
    local chatMessagesReversed = CraftSim.GUTIL:Sort(chatHistory, 
    ---@param chatMessageA CraftSim.CustomerHistory.ChatMessage
    ---@param chatMessageB CraftSim.CustomerHistory.ChatMessage
    function(chatMessageA, chatMessageB) 
        return chatMessageA.timestamp < chatMessageB.timestamp
    end)

    -- insert headers per day
    ---@type (CraftSim.CustomerHistory.ChatMessage | {day:string})[]
    local chatMessages = {}
    local currentDate = nil
    for _, chatMessage in pairs(chatMessagesReversed) do
        local dayString = CraftSim.CUSTOMER_HISTORY.FRAMES:GetNormalizedDayString(chatMessage.timestamp)
        if currentDate ~= dayString then
            table.insert(chatMessages, {
                day=dayString
            })
            currentDate = dayString
        end
        table.insert(chatMessages, chatMessage)
    end

    local f = CraftSim.UTIL:GetFormatter()
    for _, chatMessage in pairs(chatMessages) do
        chatMessageList:Add(function (row)
            local columns = row.columns
            local timeColumn = columns[1]
            local senderColumn = columns[2]
            local messageColumn = columns[3]

            if chatMessage.day then
                timeColumn.text:SetText(f.whisper("[" .. chatMessage.day .. "]"))
                senderColumn.text:SetText("")
                messageColumn.text:SetText("")
            else
                timeColumn.text:SetText(f.whisper("[" .. CraftSim.CUSTOMER_HISTORY.FRAMES:GetNormalizedTimeString(chatMessage.timestamp) .. "]"))
    
                local sender = "[" .. tostring(customer) .. "]: "
    
                if chatMessage.fromPlayer then
                    sender = "[You]: "
                end
        
                senderColumn.text:SetText(f.whisper(tostring(sender)))
                messageColumn.text:SetText(f.whisper(tostring(chatMessage.content)))
            end

            -- adjust row height
            ---@type Frame
            local rowFrame = row.frame
            ---@type SimpleFontString
            local messageText = messageColumn.text.frame
            local messageHeight = math.max(20, messageText:GetStringHeight())
            rowFrame:SetHeight(messageHeight)
        end)
    end

    chatMessageList:UpdateDisplay()
    RunNextFrame(function ()
        chatMessageList:ScrollDown()
    end)
end

local function normalize(dateNumber)
    dateNumber = tostring(dateNumber)
    if #dateNumber == 2 then
        return dateNumber
    else
        return "0" .. dateNumber
    end
end

---@param timestamp number
---@return string
function CraftSim.CUSTOMER_HISTORY.FRAMES:GetNormalizedDayString(timestamp)
    local date = date("*t", timestamp)
    return string.format("%s.%s.%s", normalize(date.day), normalize(date.month), date.year)
end
---@param timestamp number
---@return string
function CraftSim.CUSTOMER_HISTORY.FRAMES:GetNormalizedTimeString(timestamp)
    local date = date("*t", timestamp)
    return string.format("%s:%s:%s", normalize(date.hour), normalize(date.min), normalize(date.sec))
end