--[[ 
好友申请列表 
]]

local UIBase = require_ex("ui.base.UIBase")
local M = class("FFriendApply", UIBase)

local InitCount = 8

function M:ctor(closeCB)
    if type(closeCB) == "function" then
        self._closeCallback = closeCB
    end

    self.effRipple = true
    self.effDark = true
    
    UIBase.ctor(self)
    self:init()
end

function M:init()
    self._BindWidget = {
        ["panel_touch"] = {handle = handler(self, self.onClose)},
        ["panel_center/btn_close"] = {handle = handler(self, self.onClose)},
        ["panel_center/lv_list"] = {key = "lv_list"},

        ["temp_list"] = {},
    }

    self._listData = {}
    self._initIdx = 1

    self:initViews()
end

function M:initViews()
    local uiNode = createCsbNode("subgame/catchFish/frendapply.csb")
    self:addChild(uiNode, 1)
    self._rootNode = uiNode

    bindWidgetList(uiNode, self._BindWidget, self._widgets)

    self._widgets.lv_list:stopAllActions()
    self._widgets.lv_list:removeAllItems()

    local list = Game:doPluginAPI("get", "friendApply")
    if not list or #list == 0 then
        if self._widgets.panel_empty then
            self._widgets.panel_empty:setVisible(true)
        end
        return
    end
    if self._widgets.panel_empty then
        self._widgets.panel_empty:setVisible(false)
    end

    self._listData = list
    local amount = #list
    local count = Number.min(amount, InitCount)
    for i = 1, count do
        self:addItem(i)
    end

    if count < amount then
        self._initIdx = count + 1
        self:scheduleUpdate()
    end

    self._widgets.lv_list:jumpToTop()
end

function M:addItem(idx)
    idx = idx or self._initIdx

    local v = self._listData[idx]
    local item = self._widgets.temp_list:clone()
    local panel_head, img_head, txt_name, img_online, img_offline, btn_accept, btn_refuse

    panel_head = item:getChildByName("panel_head")
    img_head = panel_head:getChildByName("img_head")
    txt_name = item:getChildByName("txt_name")
    img_online = item:getChildByName("img_onlie")
    img_offline = item:getChildByName("img_offline")
    btn_accept = item:getChildByName("btn_agree")
    btn_refuse = item:getChildByName("btn_refuse")

    Game:doPluginAPI("set", "headIcon", img_head, v.facelook, true)

    txt_name:setString(v.nick)
    if v.online == 1 then
        img_online:setVisible(true)
        img_offline:setVisible(false)
    else
        img_online:setVisible(false)
        img_offline:setVisible(true)
    end
    if btn_accept then
        btn_accept.uData = v
        bindClickFunc(btn_accept, handler(self, self.onAccept))
    end
    if btn_refuse then
        btn_refuse.uData = v
        bindClickFunc(btn_refuse, handler(self, self.onRefuse))
    end

    item.uData = v
    bindClickFunc(item, handler(self, self.onViewDetail))

    item:setVisible(true)
    self._widgets.lv_list:pushBackCustomItem(item)
end

function M:removeItem(item)
    local idx = self._widgets.lv_list:getIndex(item)
    if idx >= 0 then
        self._widgets.lv_list:removeItem(idx)
        if #self._widgets.lv_list:getItems() == 0 and self._widgets.panel_empty then
            self._widgets.panel_empty:setVisible(true)
        end
    end
end

function M:updateFunc()
    self:addItem()

    self._initIdx = self._initIdx + 1
    if self._initIdx > #self._listData then
        self:unscheduleUpdate()
    end
end

----------------------------------
-- 交互及回调
function M:onAccept(sender)
    local v = sender.uData
    Game:doPluginAPI("send", "friendApply", v.pid, FriendApply.accept, function()
        self:removeItem(sender:getParent())
        Game:tipMsg(Config.localize("friend_apply_accept"))
    end)
end

function M:onRefuse(sender)
    local v = sender.uData
    Game:doPluginAPI("send", "friendApply", v.pid, FriendApply.refuse, function()
        self:removeItem(sender:getParent())
        Game:tipMsg(Config.localize("friend_apply_refuse"))
    end)
end

function M:onViewDetail(sender)
    local v = sender.uData
    if DEBUG_OFFLINE then
        Game:doPluginAPI("enter", "playerDetail", v)
        return
    end

    local uid = v.pid or v.uid
    local args
    if not Game:doPluginAPI("get", "friend", uid) then
        args = {
            confirm_title = Config.localize("que_ding"),
            confirm_func = NULL.F,
        }
    end
    Game:doPluginAPI("send", "playerDetail", uid, args)
end

function M:onClose()
    if self._closeCallback then
        self._closeCallback()
    end
    self:destroy()
end

return M
