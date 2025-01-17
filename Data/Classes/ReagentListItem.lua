---@class CraftSim
local CraftSim = select(2, ...)

---@class CraftSim.ReagentListItem
CraftSim.ReagentListItem = CraftSim.Object:extend()

---@param itemID number
---@param quantity number
function CraftSim.ReagentListItem:new(itemID, quantity)
    self.itemID = itemID
    self.quantity = quantity
end