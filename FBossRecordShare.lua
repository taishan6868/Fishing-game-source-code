--[[
boss战绩分享
]]
local UIBase = require_ex("ui.base.UIBase")
local M = class("FBossRecordShare", UIBase)

if not ByEventShareConfig then loadConfig("ByEventShareConfig") end

function M:ctor(params)
    self.effDark = true
	self.effRipple = true
	self._params = params

    UIBase.ctor(self)
    self:init()
end

function M:init()
    self._BindWidget = {
		["panel_touch"] = {handle = handler(self, self.onClose)},
		["bg"] = {},
		["bg/img_boss"] 	= {key = "img_boss"},
		["bg/bft_bet"]	= {key = "bft_bet"},
		["bg/bft_bet_fish"] = {key = "bft_bet_fish"},
		["bg/img_name"]	= {key = "img_name"},
		["bg/txt_desc"]	= {key = "txt_desc"},
		["bg/img_code"]	= {key = "img_code"},
		["bg/lv_reward"]	= {key = "lv_reward"},
		["bg/txt_time"] = {key = "txt_time"},
		
		["panel_buttom"] = {hide = true},
		["panel_buttom/btn_wx"]		= {key = "btn_wx", tag = 0, handle = handler(self, self.onShare)},
		["panel_buttom/btn_py"]		= {key = "btn_py", tag = 1, handle = handler(self, self.onShare)},
		["panel_buttom/btn_save"]	= {key = "btn_save", handle = handler(self, self.onSaveHandler)},
		
		["panel_item"] = {hide = true},
		["panel_item_small"] = {hide = true}
	}
	
	self:initViews()
end

function M:initViews()
    local uiNode = createCsbNode("subgame/catchFish/bossRecordShare.csb")
    self:addChild(uiNode, 1)
    self._rootNode = uiNode

    bindWidgetList(uiNode, self._BindWidget, self._widgets)
	self:show()
	self:captureNode()
end

function M:captureNode()
	self:performWithDelay(function() 
		Assist.captureNode(
			self._widgets.bg,
			function(_, outputFile)
				self._outputFile = outputFile
				self._widgets.panel_buttom:setVisible(true)
				self:showShare()
			end,
			"CaptureBoss_share.jpg"
		)
	end, 1.5)
end

function M:show()
	local cfgEvent = ByEventShareConfig[self._params.eventId]
	if not cfgEvent then return end
	fitIconSize(self._widgets.img_boss, cfgEvent.boss_icon)
	fitIconSize(self._widgets.img_name, cfgEvent.boss_name)
	fitIconSize(self._widgets.img_code, cfgEvent.erweima)
	self._widgets.txt_desc:setString(cfgEvent.share_tips)
	self._widgets.bft_bet_fish:setString(self._params.bet)
	-- setRichText(self._widgets.txt_desc, cfg.share_tips)  -- 截屏不支持
	if self._params.cannonId < 1 then return end
	local cfgCannon = BYCannonConfig[self._params.cannonId]
	self._widgets.bft_bet:setString(cfgCannon.level)
	
	local item, ws, wd = nil, {}, {
		["img_icon"] = {},
		["txt_count"]= {},
	}
	local margin = #self._params.rewardList > 3 and -30 or 10
	local widget = #self._params.rewardList > 3 and self._widgets.panel_item_small or self._widgets.panel_item
	if #self._params.rewardList > 4 then
		local pox = self._widgets.lv_reward:getPositionX()
		self._widgets.lv_reward:setPositionX(pox - 80)
	end
	self._widgets.lv_reward:setItemsMargin(margin)
	for _,v in ipairs(self._params.rewardList) do
		item = widget:clone()
		bindWidgetList(item, wd, ws)
		fitIconSize(ws.img_icon, ItemsConfig.big_icon(v.gtid or v.tool_id))
		ws.txt_count:setString(Assist.formatCount(v.gtid or v.tool_id, v.energyNum or v.num or v.tool_num, "x", ItemLayout.bag))
		item:setVisible(true)
		self._widgets.lv_reward:pushBackCustomItem(item)
	end
	local len = #self._params.rewardList
	if len < 3 then
		local posX = self._widgets.lv_reward:getPositionX() + self._widgets.lv_reward:getContentSize().width/2
		self._widgets.lv_reward:setPositionX(posX +  (len == 1 and -80 or -150))
	end
	if self._widgets.txt_time then
		self._widgets.txt_time:setString(Timer:formatDateTime(Number.floor(self._params.bossDieTime), nil, true))
	end
end

function M:onSaveHandler()
	if not self._outputFile then return end
	Platform.saveToPhotosAlbum(self._outputFile, nil , function(reqCode)
		Game:tipMsg(reqCode and Config.localize("save_tips") or Config.localize("save_tips_error"))
	end)
end

function M:onShare(sender)
	if not Platform.checkAppVersion("2.61.00") then
        return
    end
	local shareTo = sender and sender:getTag() or 1
    if shareTo < 0 or shareTo > 1 then
        shareTo = 1
    end
    if shareTo == 0 and not Platform.checkAppVersion("1.01.00") then
        return
    end
    local data = {
	    url = Game:doPluginAPI("get", "shareUrl") or SHARE_PAGE,
	    to = shareTo, 
	    type = 0, 
	    img = self._outputFile, 
	    icon = Game:doPluginAPI("get", "shareIcon") or ShareIconConfig.icon(Sdk.getMarketId())
	}
	Game:doPluginAPI("share", "info", data)
end

function M:showShare()
	local animateBottom = self._widgets.panel_buttom:getChildren()
	for _,v in ipairs(animateBottom) do
        v:setVisible(false)
    end
	local effType = EffType.slideIn
    Game:doEffectList(effType, animateBottom, true, 0.3, EffDir.bottom, 140)
end

return M