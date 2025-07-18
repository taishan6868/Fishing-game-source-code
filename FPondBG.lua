local UIBase = require_ex("ui.base.UIBase")
local M = class("FPondBG", UIBase)

local SpineTide = {res="subgame/catchFish/spine/yuchao/by_yuchao", ani="1", x=-150, y=display.cy, isLoop=true}


function M:ctor(parent)
    UIBase.ctor(self)
    self:init()
    parent:addChild(self)
end

function M:init()
    self._BindWidget = {
        ["panel_bg"] = {},
        ["node_spine"] = {},
    }
    self._bgList = {}
    self:initView()
end

function M:initView()
    local uiNode = createCsbNode("subgame/catchFish/pond_bg.csb",true)
    self:addChild(uiNode, 1)
    self._rootNode = uiNode
    bindWidgetList(uiNode, self._BindWidget, self._widgets)
    self._orgSize = self._widgets.panel_bg:getContentSize()
    adapterScreenCC(uiNode,nil,true)
    self._widgets.node_spine:setPosition(self._widgets.panel_bg:convertToWorldSpace(cc.p(0,0)))
    self._bgSize = self._widgets.panel_bg:getContentSize()
    self._tide = Assist.addCfgIcon(self._widgets.node_spine,SpineTide)
    self._tide:setVisible(false)
end

function M:changeBg(immediately)
    if not self._bgList[1] or self._bgList[1].id ~= Game.fishDB:getRoomBg() then
        self:createBg()
        self:resetZOrder()
    end
    self._bgList[1]:setContentSize(self._bgSize)
    if immediately then
        self:onChangeBgFinished()
        return
    end
    self._fishTideX = self._bgSize.width + 250
    self._tide:setVisible(true)
    self:updateFunc()
    self:scheduleUpdate()
    self._fishTiding = true
end

function M:createBg()
    local id = Game.fishDB:getRoomBg()
    local res = BYRoomBGConfig.res_ids(id)
    local bg = ccui.Layout:create()
    bg:setClippingEnabled(true)
    self._widgets.panel_bg:addChild(bg)
    for _, rId in ipairs(res) do
        self:initBg(bg, rId)
    end
    adapterScreen(bg,BYRoomBGConfig.adapter(id),true)
    bg:setContentSize(self._bgSize)
    bg.id = id
    table.insert(self._bgList,bg)
end

function M:initBg(bg, rid)
    local actor = Assist.addCfgIcon(bg, BYRoomBGResConfig.res(rid))
    local posInfo = BYRoomBGResConfig.pos(rid)
    local size = BYRoomBGResConfig.size(rid)
    local adapter = BYRoomBGResConfig.adapter(rid) or 0
    if posInfo.y and posInfo.x then
        actor:setPosition(bg:convertToNodeSpace(cc.p(posInfo.x, posInfo.y)))
    elseif posInfo.px and posInfo.py then
        actor:setPosition(bg:convertToNodeSpace(cc.p(CC_DESIGN_RESOLUTION.width * posInfo.px,CC_DESIGN_RESOLUTION.height * posInfo.py)))
    end
    if actor:getAnimType() == ActorType.image then
        if size.width and size.height then
            actor:getDisplayNode():ignoreContentAdaptWithSize(false)
            actor:getDisplayNode():setContentSize(size)
        end
    end
    actor:setScale(BYRoomBGResConfig.scale(rid))
    if adapter == -666 then
        size = actor:getDisplayNode():getContentSize()
        if size.width == 0 or size.height == 0 then
            size = self._orgSize
        end
        local scale = Number.max(self._bgSize.width / size.width, self._bgSize.height / size.height)
        actor:setScale(scale)
    elseif adapter == -667 then
        size = actor:getDisplayNode():getContentSize()
        if size.width == 0 or size.height == 0 then
            size = self._orgSize
        end
        actor:setScale(cc.size(self._bgSize.width / size.width, self._bgSize.height / size.height))
    else
        actor:setTag(adapter)
    end
end

function M:updateFunc()
    self._tide:setPositionX(self._fishTideX)
    local percent = self._fishTideX / self._bgSize.width
    if self._bgList[2] and percent >= 0 and percent <= 1 then
        self._bgList[1]:setContentSize(cc.size(self._bgSize.width * percent,self._bgSize.height))
    end
    self._fishTideX = self._fishTideX - (self._bgSize.width+250)/30/3

    if self._fishTideX < -150 then
        self:onChangeBgFinished()
    end
end

function M:clear()
    self:onChangeBgFinished()
end

function M:resetZOrder()
    local count = #self._bgList
    for i, v in ipairs(self._bgList) do
        v:setLocalZOrder(count-i)
    end
end

function M:isFishTiding()
    return self._fishTiding
end

function M:onChangeBgFinished()
    if #self._bgList > 1 then
        self._bgList[1]:removeFromParent()
        table.remove(self._bgList,1)
    end
    self._tide:setVisible(false)
    self:unscheduleUpdate()
    self._fishTiding = false
end

return M