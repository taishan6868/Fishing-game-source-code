--[[
换炮台
]]

local UIBase = require_ex("ui.base.UIBase")
local M = class("FChangeSkinUI", UIBase)

-- 栏目数量
local TabCount = 2
local OutLine={
    select = "871f17",
    normal = "173987"
}

local TAB_LIST = {
    ["qgame"] = 2,
    ["mgame"] = 2,
}

local function _getVipSkinIds(list)
    local ret = {}
    local ids = BYCannonSkinConfig.getIds()
    for _, id in ipairs(ids) do
        local cfg = BYCannonSkinConfig[id]
        if cfg.type == CannonType.vip or cfg.type == CannonType.laser then
            local time = 0
            local forever = false
            if list[id] then
                time = list[id].valid_day or 0
                forever = list[id].forever or false
            end
            table.insert(ret, {idx = id, valid_time = time,forever=forever})
        end
    end
    table.sort(ret, function(a, b)
        local a1, b1 = a.idx, b.idx
        local e1 = BYCannonSkinConfig[a1]
        local e2 = BYCannonSkinConfig[b1]
        if a.forever ~= b.forever then
            return a.forever
        elseif a.valid_time ~= b.valid_time then
            return a.valid_time > b.valid_time
        elseif e1.type == e2.type then
            return e1.lv < e2.lv or (e1.lv == e2.lv and e1.id < e2.id)
        else
            return e1.type > e2.type
        end
    end)

    return ret
end

function M:ctor(useSkin)
    self._useSkin = useSkin

    self.effDark = true
    self.effRipple = true
    UIBase.ctor(self)
    
    self._currTab = TAB_LIST[AppName] or 1  --1:基础炮台   2：付费炮台
    self:init()
end

function M:registerListenEvent()
    self:listenCustomEvent(GEvent("ON_RECHARGE_FINISH"), handler(self,self.onPayFinish))
    self:listenCustomEvent(GEvent("FISH","UPD_SKIN_DATA"), handler(self,self.onPayFinish))
end

function M:init()
    self._BindWidget = {
        ["panel_touch"] = {handle = handler(self, self.onClose)},
        ["btn_close"] = {handle = handler(self, self.onClose)},
        
        ["lv_list"] = {},
        ["temp_cannon"] = {hide=true},
        ["panel_tab/cb1"] = {key = "cb_tab1", tag = 1},
        ["panel_tab/cb2"] = {key = "cb_tab2", tag = 2},
    }

    self:initViews()
    
end

function M:initViews()
    local uiNode = createCsbNode("subgame/catchFish/barter.csb")
    self:addChild(uiNode, 1)
    self._rootNode = uiNode

    bindWidgetList(uiNode, self._BindWidget, self._widgets)

    -- self:initList() 
    self:refresh()
    local cbs = {}
    for i=1,TabCount do
        local cb = self._widgets["cb_tab"..i]
        if cb then
            local args = {
                parent = self._rootNode,
                 txtNormal = cb:getChildByName("txt"),
                txtSelected = cb:getChildByName("txt_forcus"),
            }
            cbs[#cbs+1] = require_ex("lib.UICheckBoxEx").new(cb, args)
        end
    end
    local args = {default = self._currTab, clickCallback = handler(self, self.onTab)}
    require_ex("lib.UIRadioGroupEx").new(cbs, args)
    if Game:funcIsOpen("code_animate") then
        Game:doEffectList(EffType.bubble, self._widgets.lv_list, true, 0.05, 1.05, 0.5)
    end
end

function M:initList()
    self._itemList = {}
    self._widgets.lv_list:removeAllItems()
    self._skinList = Game.fishDB:getSkinData()
    local ids = _getVipSkinIds(self._skinList)
    ids = self:checkType(ids)
    for i, id in ipairs(ids) do
        local item = self._widgets.temp_cannon:clone()
        self:initItem(item, id)
        self._widgets.lv_list:pushBackCustomItem(item)
        self._itemList[i] = item
    end
end

function M:initItem(item, id)
    local cfg = BYCannonSkinConfig[id]
    local loop = false
    if TAB_LIST[AppName] then
       loop = not Assist.isEmpty(cfg.icon[3]) or false
    else
        loop = cfg.type==CannonType.laser or (not Assist.isEmpty(cfg.icon[3]))
    end
    local BindWidget = {
        ["img_no_get"] = {},
        ["img_get"] = {},
        ["txt_name"] = {},
        ["txt_desc"] = {zorder=2},
        ["img_icon"] = {},
        ["btn_useing"] = {},
        ["txt_time"] = {key = "txt_time",hide=true},
        ["btn_change"] = {handle = handler(self,self.onBtnChooseItem)},
        ["btn_equipGain"] = {handle = handler(self,self.onBtnGetItem)},
    }
    bindWidgetList(item, BindWidget, item)
    Assist.showCannonAnim(item.img_icon, cfg.icon, 2, 1, 1, loop)
    fitIconSize(item.txt_name, cfg.icon_name)
    item:setVisible(true)
    item.id = id
    item.btn_change.id = id
    item.btn_equipGain.id = id
end

--[[
检测激光炮台有效性
]]
function M:checkCannonType(cannonId)
    local cannonInfo = self._skinList[cannonId]
    if not cannonInfo then
        Log.w("can't find cannon info:"..cannonId,"FChangeSkinUI")
    end
    return cannonInfo or {}
end

function M:checkType(ids)
    local list = {}
    for _,id in ipairs(ids) do
        if self._currTab == 1 then
            if BYCannonSkinConfig.type(id.idx) == CannonType.vip then
                table.insert(list, id.idx)
            end 
        else
            if BYCannonSkinConfig.type(id.idx) == CannonType.laser then
                table.insert(list, id.idx)
            end
        end
    end
    return list
end

function M:refresh(skin)
    self:initList()
    skin = skin or self._useSkin
    
    self._skinList = Game.fishDB:getSkinData()
    local vip = Game:doPluginAPI("get", "playerVIP")
    -- local itemList = self:checkType()
    for _, item in ipairs(self._itemList) do
        local cfg = BYCannonSkinConfig[item.id]
        local color = skin == cfg.id and OutLine.select or OutLine.normal
        item.btn_useing:setVisible(skin==cfg.id)
        item.btn_equipGain:setVisible(skin~=cfg.id)
        item.img_get:setVisible(skin==cfg.id)
        item.img_no_get:setVisible(skin~=cfg.id)
        item.btn_change:setVisible(false)
        if item.txt_desc then
            item.txt_desc:enableOutline(Assist.colorFromString(color),2)
            setRichText(item.txt_desc,cfg.desc)
        end
        local cannonInfo = self:checkCannonType(cfg.id)
        local valid_time = cannonInfo.valid_day or 0
        local change = valid_time > 0 or cannonInfo.forever
        if valid_time > 0 and not cannonInfo.forever then
            item.txt_time:setVisible(true)
            item.txt_time:setString(Timer:formatDayCD(valid_time,Config.localize("cannon_use_time"),false,true))
        end
        if skin ~= cfg.id then
            if cfg.type == CannonType.laser then --激光武器
                item.btn_change:setVisible(change)
                item.btn_equipGain:setVisible(not item.btn_change:isVisible())
                item.btn_equipGain:setTitleString(Config.localize("title_need_get"))
            else
                local key = vip>=cfg.lv and "title_equip_enable" or "title_need_get"
                item.btn_equipGain:setTitleString(Config.localize(key))
                item.btn_change:setVisible(vip>=cfg.lv)
                item.btn_equipGain:setVisible(not item.btn_change:isVisible())
            end
            
        end
    end
end

----------------------------------
function M:onTab(tabIdx)
    if self._currTab ~= tabIdx then
        self._currTab = tabIdx
        self:refresh()
    end
end
-- 交互及回调
function M:onBtnChooseItem(btn)
    Game.fishCom:reqChangeSkin(btn.id,handlerSafe(self,self.onChooseCallback))
end

function M:onChooseCallback(info)
    if info.code == 0 then
        Game:tipMsg(Config.localize("fish_change_skill_succ"))
        self._useSkin = info.skin
        self:refresh(info.skin)
    end
end

function M:onBtnGetItem(btn)
    local args = BYCannonSkinConfig.func_args(btn.id)
    local params = {}
    if BYCannonSkinConfig.params then --todo 同步字段到追龙、全民
        params = BYCannonSkinConfig.params(btn.id) or {}
    end 
    if args == "cannonShop" then
        Game:doPluginAPI("enter", "cannonShop", btn.id, function()
            local pInfo = Game.fishDB:getPlayer()
            self._useSkin = pInfo.skin
            self:refresh(pInfo.skin)
        end)
    elseif args == "activity" and not Assist.isEmpty(params) then
        if Game:doPluginAPI("get", "activity", params[1], true) then
            Game:doPluginAPI("exit", "fish",function()
                Game:performDelay(function()
                    Game:doPluginAPI("enter",args,unpack(params))
                end,0.5)
            end)
        else
            Game:tipMsg(Config.localize("cannon_jump_fail"))
        end
    elseif not Assist.isEmpty(args) then
        Game:doPluginAPI("enter",args,unpack(params))
    end
end

function M:onPayFinish()
    self:performWithDelay(function()
        local pInfo = Game.fishDB:getPlayer()
        self._useSkin = pInfo.skin
        self:refresh(pInfo.skin)
    end,1)
end

return M
