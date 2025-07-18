--[[
炮台解锁升级（钻石）
]]

local UIBase = require_ex("ui.base.UIBase")
local M = class("FCannonUnlockUI", UIBase)

function M:ctor(cannonLv)
    self._cannonLv = cannonLv

    self.effDark = true

    UIBase.ctor(self)
    self:init()
end

function M:init()
    self._BindWidget = {
        ["panel_touch"] = {handle = handler(self, self.onClose)},
        ["panel_clear"] = {},
        ["panel_clear/img_icon"] = {key = "img_icon"},
        ["panel_clear/txt_power"] = {key = "txt_power"},
        ["panel_clear/txt_num"] = {key = "txt_num"},
        ["panel_clear/btn_confirm"] = {key = "btn_confirm",handle = handler(self, self.onUnlock)},
    }

    self:initViews()
end

function M:initViews()
    local uiNode = createCsbNode("subgame/catchFish/unlockCannon.csb")
    self:addChild(uiNode, 1)
    self._rootNode = uiNode

    bindWidgetList(uiNode, self._BindWidget, self._widgets)

    local cfg = BYCannonLevelConfig[self._cannonLv]
    local nextLv = cfg.next_level
    local nextInfo = BYCannonLevelConfig[nextLv]
    
    self._widgets.txt_power:setString(nextInfo.cannon_multiple)

    local coin = 0
    for _, award in ipairs(cfg.level_reward) do
        if award[1] == ENUM.ITEM_ID.COIN then
            coin = coin + award[2]
        end
    end
    local text = ""
    if coin > 0 then
        text = coin..Config.localize("magic_icon_desc")
    end
    self._widgets.txt_num:setString(text)

    local _, needDiamond = Game.fishDB:cannonUpgEnable(self._cannonLv)
    self._widgets.btn_confirm:setTitleString(tostring(needDiamond))
end

----------------------------------
-- 交互及回调
function M:onUnlock()
    local canUp = Game.fishDB:cannonUpgEnable(self._cannonLv)
    if canUp then
        Game.fishCom:reqUpgradeCannon()
    else
        Game:doPluginAPI("enter", "shop", ShopType.diamond)
    end
    self:onClose()
end

return M
