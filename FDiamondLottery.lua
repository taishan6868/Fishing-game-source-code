--[[
魔晶抽奖
]]
local UIBase = require_ex("ui.base.UIBase")
local M = class("FDiamondLottery", UIBase)

-- 每个区域的角度跨度
local AreaAngle = 360 / 10 
local OuterNum = 6     --外圈转动圈数
local InsideNum = 6    --内圈转动圈数
--local AngleOffset = 10 -- 为了避免停留在交接中间
local TIMER = 3

function M:ctor(param, callback)
    
    self.effDark = true
	self.effRipple = true

    UIBase.ctor(self)
    
    self._param = param
    self._callback = callback
    self._isPlaying = false
    self:init()
end

function M:init()
    self._BindWidget = {
        ["panel_bg/panel_top/img_tit"] = {key = "img_tit"},
        ["panel_bg/panel_top/bf_tit1"] = {key = "bf_tit1"},
        ["panel_bg/panel_top/bf_tit2"] = {key = "bf_tit2"},
        ["panel_bg/panel_top/bf_tit3"] = {key = "bf_tit3"},
        
        ["panel_bg/panel_con/img_v"]  = {key = "img_v"},
        ["panel_bg/panel_con/btn_start"]  = {key = "btn_start", handle = handler(self, self.onClickStart)},
        ["panel_bg/panel_con/panel_anin1"] = {key = "panel_anin1", hide = true, spine = {res="subgame/catchFish/spine/hmlxzp/by_hmlx_dzp_1", center=true, ani="1", aniNext="2", isLoop=true}},
        ["panel_bg/panel_con/panel_anin2"] = {key = "panel_anin2", hide = true, spine = {res="subgame/catchFish/spine/hmlxzp/by_hmlx_dzp_2", center=true, ani="1", isLoop=false}},
        ["panel_bg/panel_con/panel_outer"] = {key = "panel_outer", center=true},
        ["panel_bg/panel_con/panel_outer/txt_1"] = {key = "txt_1"},
        ["panel_bg/panel_con/panel_outer/txt_2"] = {key = "txt_2"},
        ["panel_bg/panel_con/panel_outer/txt_3"] = {key = "txt_3"},
        ["panel_bg/panel_con/panel_outer/txt_4"] = {key = "txt_4"},
        ["panel_bg/panel_con/panel_outer/txt_5"] = {key = "txt_5"},
        ["panel_bg/panel_con/panel_outer/txt_6"] = {key = "txt_6"},
        ["panel_bg/panel_con/panel_outer/txt_7"] = {key = "txt_7"},
        ["panel_bg/panel_con/panel_outer/txt_8"] = {key = "txt_8"},
        ["panel_bg/panel_con/panel_outer/txt_9"] = {key = "txt_9"},
        ["panel_bg/panel_con/panel_outer/txt_10"] = {key = "txt_10"},
        
        ["panel_bg/panel_con/panel_inside"] = {key = "panel_inside", center=true},
        ["panel_bg/panel_con/panel_inside/bf_1"] = {key = "bf_1"},
        ["panel_bg/panel_con/panel_inside/bf_2"] = {key = "bf_2"},
        ["panel_bg/panel_con/panel_inside/bf_3"] = {key = "bf_3"},
        ["panel_bg/panel_con/panel_inside/bf_4"] = {key = "bf_4"},
        ["panel_bg/panel_con/panel_inside/bf_5"] = {key = "bf_5"},
        ["panel_bg/panel_con/panel_inside/bf_6"] = {key = "bf_6"},
        ["panel_bg/panel_con/panel_inside/bf_7"] = {key = "bf_7"},
        ["panel_bg/panel_con/panel_inside/bf_8"] = {key = "bf_8"},
        ["panel_bg/panel_con/panel_inside/bf_9"] = {key = "bf_9"},
        ["panel_bg/panel_con/panel_inside/bf_10"] = {key = "bf_10"},
    }

    self:initViews()
end

function M:initViews()
    local uiNode = createCsbNode("subgame/catchFish/diamondLottery.csb")
    self:addChild(uiNode, 1)
    self._rootNode = uiNode

    bindWidgetList(uiNode, self._BindWidget, self._widgets)
    self._widgets.panel_outer:setRotation(0) 
    self._widgets.panel_inside:setRotation(0) 
    self:show()
end

function M:show()
    local data, item = nil, nil
    for i=1, 10 do
        data = BYFishTurntableNumberConfig[i]
        item = self._widgets["bf_" .. i]
        item:setString(data.number/10)
        data = BYFishTurntableNumberConfig[i+10]
        item = self._widgets["txt_" .. i]
        item:setString(data.number/10)
        -- self:showTxtAnim(item, i/3, i)
    end
    
    self._widgets.panel_anin1:setVisible(true)
    self._widgets.panel_anin1.actor:changeAnimation("1", true, "2", true)
    self:performWithDelay(function() 
        self._widgets.panel_outer:setVisible(true)
        self._widgets.panel_inside:setVisible(true)
        self._widgets.btn_start:setVisible(true)
        self._widgets.img_v:setVisible(true)
        self._widgets.img_tit:setVisible(true)
        self:scheduleUpdate()
    end, 0.5)
end

-- function M:showTxtAnim(node, deley, idx)
-- end

function M:showInsdieNum(num)
    self:performWithDelay(function() 
        self._widgets.panel_anin2:setVisible(false)
        self._widgets.panel_anin2.actor:pause()
        self._widgets.img_tit:setVisible(false)
        self._widgets.bf_tit1:setVisible(true)
        self._widgets.bf_tit1:setString(self._param[1])
        self:showPlaneAnim(1)
        Audio.playSoundConfig(self, "2")
    end, 1)
end

function M:showOuterNum(num)
    self:performWithDelay(function() 
        self._widgets.panel_anin2:setVisible(false)
        self._widgets.panel_anin2.actor:pause()
        self._widgets.bf_tit2:setVisible(true)
        self._widgets.bf_tit3:setVisible(true)
        self._widgets.bf_tit2:setString("x" .. self._param[2] .. "=")
        self._widgets.bf_tit3:setString(self._param[1] * self._param[2])
        self:showPlaneAnim(2)
        self:showPlaneAnim(3)
         Audio.playSoundConfig(self, "2")
    end, 0.9)
   
end
--数字特效
function M:showPlaneAnim(idx)
    self._widgets["bf_tit" .. idx]:setScale(0.1)
    local dest = 1
    local seq = {
        cc.ScaleTo:create(0.1, 0.8*dest),
        cc.ScaleTo:create(0.1, 0.5*dest),
    }
    self._widgets["bf_tit" .. idx]:runAction(transition.sequence(seq))
end

function M:updateFunc(dt)
    if TIMER < 0 then
        self:unscheduleUpdate()
        if self._isPlaying then return end
        self:onClickStart()
    end
    TIMER = TIMER-dt
end
--====================================交互=========================================
function M:onClickStart()
    -- 转盘停止位置
    if self._isPlaying then return end
    self._isPlaying = true
    self:unscheduleUpdate()
    Audio.playSoundConfig(self, "1")
	local stopId = self:getItemIndex(1, self._param[1])   --内
    local stopId_outer = self:getItemIndex(11, self._param[2])   --外
  
	local angleMin = (stopId - 1) * AreaAngle  
    local angleMin1 = (stopId_outer - 1) * AreaAngle  
	-- 产生RoundMin-RoundMax之间的整数  
	local outerRoundCount = OuterNum 
    local insideRoundCount = InsideNum
	-- 转动角度
	-- 避免掉AngleOffset角度的停留，防止停留在交界线上
	local angleTotal = 360*outerRoundCount + angleMin1  
    local angleTotal1 = 360*insideRoundCount + angleMin 
    --外圈
    local seq_out = {
		cc.EaseExponentialOut:create(cc.RotateBy:create(11.0, angleTotal)), --:reverse()
		cc.CallFunc:create(function()
            self._widgets.panel_anin2.actor:changeAnimation("2", false, nil, true)
            self._widgets.panel_anin2:setVisible(true)
            self:showOuterNum(stopId_outer)
		end),
		cc.DelayTime:create(4),
		cc.CallFunc:create(function()
            self:destroy()
            if self._callback then
                self._callback()   
            end
		end)
	}
	self._widgets.panel_outer:runAction(transition.sequence(seq_out))
    --内圈
    local seq_in = {
		cc.EaseExponentialOut:create(cc.RotateBy:create(5.0, angleTotal1)),
		cc.CallFunc:create(function()
            self._widgets.panel_anin2.actor:changeAnimation("1", false, nil, true)
            self._widgets.panel_anin2:setVisible(true)
            self:showInsdieNum(stopId)
		end),
	}
	self._widgets.panel_inside:runAction(transition.sequence(seq_in))
end



function M:getItemIndex(idx, num)
    local data, id = nil, 1
    local total = idx > 10 and 20 or 10
    for i=idx, total do
        data = BYFishTurntableNumberConfig[i]
        id = i
        if data and (data.number/10) == num then
            if idx > 10 then 
               id = id-10
            end
            return id
        end
    end
    return id
end




return M