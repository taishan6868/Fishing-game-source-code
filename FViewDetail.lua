--[[ 
玩家详情 
]]

local UIBase = require_ex("ui.base.UIBase")
local M = class("FViewDetail", UIBase)

local ListCol = 4

function M:ctor(data)
    self.effRipple = true
    self.effDark = true
    
    UIBase.ctor(self)
    self:init(data)
end

function M:init(data)
    self._BindWidget = {
        ["panel_touch"] = {handle = handler(self, self.onClose)},
        ["panel_center/btn_confirm"] = {key = "btn_confirm", handle = handler(self, self.onConfirm)},
        ["panel_center/txt_emoji"] = {key = "txt_emoji"},
        ["panel_center/txt_magic"] = {key = "txt_magic"},
        ["panel_center/txt_magic/txt_magic_cost"] = {key = "txt_magic_cost"},
        ["panel_center/txt_name"] = {key = "txt_name"},
        ["panel_center/panel_head/img_head"] = {key = "img_head"},
        ["panel_center/txt_VIP"] = {key = "txt_vip"},
        ["panel_center/txt_ID"] = {key = "txt_id"},
        ["panel_center/txt_cannon"] = {key = "txt_cannon"},
        ["panel_center/panel_fee"] = {key = "panel_fee"},
        ["panel_center/panel_fee/txt_fee"] = {key = "txt_fee"},
        ["panel_center/lv_list"] = {key = "lv_list"},
        ["point_marquee"] = {},
        ["temp_list"] = {},
    }

    self._pid = 0
    
    self:initViews(data)
end

function M:initViews(data)
    local uiNode = createCsbNode("subgame/catchFish/personage.csb")
    self:addChild(uiNode, 1)
    self._rootNode = uiNode

    bindWidgetList(uiNode, self._BindWidget, self._widgets)

    local tag = self._widgets.temp_list:getTag()
    if tag < 10 then
        ListCol = tag
    end

    if Assist.isEmpty(data) then
        self:initMyInfo()
    else
        self:initOtherInfo(data)
    end
end

function M:initMyInfo()
    self._widgets.txt_emoji:setVisible(true)
    self._widgets.txt_magic:setVisible(false)

    local v = {
        uid = Game:doPluginAPI("get", "playerUid"),
        nick = Game:doPluginAPI("get", "playerName"),
        facelook = Game:doPluginAPI("get", "playerIcon"),
        lottery = Game:doPluginAPI("get", "playerLottery"),
        vip = Game:doPluginAPI("get", "playerVIP"),
        cannon = Game.fishDB:getPlayerCannonLv(),
    }
    local cannonLv = v.cannon or 1
    local cannon = BYCannonLevelConfig.cannon_multiple(cannonLv) or cannonLv
    
    Game:doPluginAPI("set", "headIcon", self._widgets.img_head, v.facelook, true)

    self._widgets.txt_id:setString("ID:"..v.uid)
    self._widgets.txt_name:setString(v.nick)
    Assist.checkTTF(self._widgets.txt_name)
    self._widgets.txt_cannon:setString(Config.localize("detail_cannon")..cannon)
    if Game:funcIsOpen("vip") then
        self._widgets.txt_vip:setString("VIP"..checknumber(v.vip))
    else
        self._widgets.txt_vip:setVisible(false)
    end
    if Game:funcIsOpen("exchange") then
        self._widgets.txt_fee:setString(string.format("%.2f%s", v.lottery/100, Config.localize("recharge_yuan")))
    else
        self._widgets.panel_fee:setVisible(false)
    end

    local emojis = BYEmojiConfig.getIds()
    table.sort(emojis)
    local idx, clone, item, cfg = 1
    for i, eid in ipairs(emojis) do
        cfg = BYEmojiConfig[eid]
        if not clone or idx > ListCol then
            clone = self._widgets.temp_list:clone()
            clone:setVisible(true)
            self._widgets.lv_list:pushBackCustomItem(clone)
            idx = 1
        end
        item = clone:getChildByName("img_icon_"..idx)
        fitIconSize(item, cfg.icon)
        item:setTag(i)
        item:setVisible(true)
        bindClickFunc(item, handler(self, self.onEmoji))

        idx = idx + 1
    end

    self._widgets.lv_list:jumpToTop()
end

function M:initOtherInfo(v)
    self._widgets.txt_emoji:setVisible(false)
    self._widgets.txt_magic:setVisible(true)
    if self._widgets.txt_magic_cost then
        self._widgets.txt_magic_cost:setString(Game.fishDB:getMagicCost())
    end

    local cannon = BYCannonLevelConfig.cannon_multiple(v.cannon_lv or 1) 
    Game:doPluginAPI("set", "headIcon", self._widgets.img_head, v.facelook)

    self._pid = v.player_id
    self._widgets.txt_id:setString("ID:"..v.player_id)
    self._widgets.txt_name:setString(v.name)
    Assist.checkTTF(self._widgets.txt_name)
    self._widgets.txt_cannon:setString(Config.localize("detail_cannon")..cannon)
    if Game:funcIsOpen("vip") then
        self._widgets.txt_vip:setString("VIP"..checknumber(v.vip))
    else
        self._widgets.txt_vip:setVisible(false)
    end
    if Game:funcIsOpen("exchange") and v.lottery then
        self._widgets.txt_fee:setString(string.format("%.2f%s", v.lottery/100, Config.localize("recharge_yuan")))
    else
        self._widgets.panel_fee:setVisible(false)
    end

    local emojis = MagicEmojiConfig.getIds()
    table.sort(emojis)
    local idx, clone, item, cfg = 1
    for i, eid in ipairs(emojis) do
        cfg = MagicEmojiConfig[eid]
        if not clone or idx > ListCol then
            clone = self._widgets.temp_list:clone()
            clone:setVisible(true)
            self._widgets.lv_list:pushBackCustomItem(clone)
            idx = 1
        end
        item = clone:getChildByName("img_icon_"..idx)
        fitIconSize(item, cfg.icon)
        item:setTag(i)
        item:setVisible(true)
        bindClickFunc(item, handler(self, self.onMagicEmoji))

        idx = idx + 1
    end

    self._widgets.lv_list:jumpToTop()

    if not Game:doPluginAPI("get", "friend", self._pid) and Game:funcIsOpen("friend") then
        self._canAddFriend = true
        self._widgets.btn_confirm:setTitleString(Config.localize("add_friend"))
    end
end

----------------------------------
-- 交互及回调
function M:onEmoji(sender)
    local eid = sender:getTag()
    Game:doPluginAPI("send", "chat", eid, Game:doPluginAPI("get", "playerUid"))
    self:onClose()
end

function M:onMagicEmoji(sender)
    if Game:doPluginAPI("get", "playerCoin") < Game.fishDB:getMagicCost() then
        Game:tipMsg(Config.localize("magic_goldless"))
    else
        local mid = sender:getTag()
        Game:doPluginAPI("send", "chat", {magic=mid}, self._pid)
        self:onClose()
    end
end

function M:onConfirm()
    if self._canAddFriend then
        Game:doPluginAPI("add", "friend", self._pid, function()
            self._canAddFriend = false
            self._widgets.btn_confirm:setTitleString(Config.localize("que_ding"))
        end)
    else
        self:onClose()
    end
end

function M:getOtherPlayerUid()
	return self._pid or 0
end

function M:onEnter()
    UIBase.onEnter(self)
    if self._widgets.point_marquee then
        local pos = cc.p(self._widgets.point_marquee:getPosition())
        Game:doPluginAPI("move", "marquee", pos)
    end
end

return M
