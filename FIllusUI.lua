--[[
百科（图鉴）
]]

local UIBase = require_ex("ui.base.UIBase")
local M = class("FIllusUI", UIBase)

function M:ctor()
    self.effRipple = true
    self.effDark = true

    UIBase.ctor(self)
    self:init()
end

function M:init( )
    self._BindWidget = {
        ["panel_touch"] = {handle = handler(self, self.onClose)},
        ["btn_close"] = {handle = handler(self, self.onClose)},
		["img_title"] = {},
        ["Panel_fish1/Panel_item"] = {key = "panel_item", hide = true},
        ["Panel_fish1/ListView_1"] = {key = "lv_item"},

        ["Panel_fish2/Panel_item"] = {key = "panel_item2"},
        ["Panel_fish2/ListView_1"] = {key = "lv_item2"},

        ["panel_lotteryTip"] = {},
    }

    self:initViews()
end

function M:initViews()
    local uiNode = createCsbNode("subgame/catchFish/encyclopedia.csb")
    self:addChild(uiNode, 1)
    self._rootNode = uiNode

    bindWidgetList(uiNode, self._BindWidget, self._widgets)

    self:initList()

    self:checkFuncOpen()
end

function M:checkFuncOpen()
    if self._widgets.panel_lotteryTip then
        self._widgets.panel_lotteryTip:setVisible(Game:funcIsOpen("lottery"))
    end
end

function M:initList()
    local ids = BYFishWikiConfig.getIds()
    local item1, cell1, item2, cell2
    local once, cfg
    local items = {{}, {}}

    local BindWidget = {
        ["fish"] = {key = "img_fish"},
        ["txt_times_0"] = {key = "txt_times_0", hide = true},
		["txt_name_0"] = {key = "txt_name_0", hide = true},
		["txt_times_1"] = {key = "txt_times_1", hide = true},
		["txt_name_1"] = {key = "txt_name_1", hide = true},
		["txt_times_2"] = {key = "txt_times_2", hide = true},
		["txt_name_2"] = {key = "txt_name_2", hide = true},
        ["name_png"] = {key = "img_name"},
        ["img_noble_0"] = {hide =  true},
        ["img_noble_1"] = {hide = true},
		["img_noble_2"] = {hide = true},

        --兼容追龙，全民
		["name"] = {key = "txt_name"},
        ["img_noble"] = {},
        ["img_noblest"] = {},
    }
    local currRoomId = Game.fishDB:getRoomId()
    if  BYRoomConfig.fish_wiki then
	   fitIconSize(self._widgets.img_title, BYRoomConfig.fish_wiki(currRoomId))
    end
    local temp = -1
    for _, val in ipairs(ids) do
        cfg = BYFishWikiConfig[val]
        if cfg.other == 0 then
            local ws = {}
            if table.indexof(cfg.wiki_room_id, currRoomId) then
                if cfg.type == 1 then
                    temp = temp + 1
                    if temp % 6 == 0 then
                        item1 = self._widgets.panel_item:clone()
                        cell1 = item1:getChildByName("Panel_2")
                        item1:setVisible(true)
                        self._widgets.lv_item:pushBackCustomItem(item1)
                    else
                        cell1 = cell1:clone()
                        Assist.offsetPos(cell1, 166)
                        item1:addChild(cell1)
                    end

                    bindWidgetList(cell1, BindWidget, ws)
                    table.insert(items[1], cell1)
                    if AppName == "xgame" then
                        fitIconSize(ws.img_fish, cfg.spine, 1)				
					   self:setState(ws, cfg.frame, cfg.times_area, cfg.name)	
                    else
                        local times_area = cfg.times_area
                        if times_area[1] ~= times_area[2] then
                            ws.txt_name:setString(string.format("%s-%s", times_area[1], times_area[2]))
                        else
                            ws.txt_name:setString(times_area[1])
                        end
                        fitIconSize(ws.img_fish, cfg.spine, 1)
                        ws.img_noble:setVisible(cfg.frame==1)
                        ws.img_noblest:setVisible(cfg.frame==2)
                    end
                    ws.img_name:setVisible(false)

                elseif cfg.type == 2 then
                    if not once then
                        item2 = self._widgets.panel_item2:clone()
                        cell2 = item2:getChildByName("Panel_2")
                        item2:setVisible(true)
                        self._widgets.lv_item2:pushBackCustomItem(item2)
                    else
                        cell2 = cell2:clone()
                        Assist.offsetPos(cell2, 280)
                        item2:addChild(cell2)
                    end

                    bindWidgetList(cell2, BindWidget, ws)
                    table.insert(items[2], cell2)

                    if once then
                        ws.img_name:setContentSize(103, 27)
                    end
                    fitIconSize(ws.img_name, cfg.name_png, 0)
                    fitIconSize(ws.img_fish, cfg.spine, 1)
                    if AppName == "xgame" then
    					self:setState(ws, cfg.frame, cfg.times_area, cfg.name)
                    else
                        ws.txt_name:setString(cfg.name)
                        ws.img_noble:setVisible(cfg.frame==1)
                        ws.img_noblest:setVisible(cfg.frame==2)
                    end
                    once = true
                end
            end
        end
    end

    if Game:funcIsOpen("code_animate") then
        local its = table.mergeList(items[1], items[2])
        Game:doEffectList(EffType.bubble, its, true, 0.05, 1.05, 0.5)
    end
end

function M:setState(ws, frame, times_area, name)
	if ws["txt_times_" .. frame] then
		ws["txt_times_" .. frame]:setVisible(true)
		ws["txt_times_" .. frame]:setString(times_area)
		ws["txt_name_" .. frame]:setVisible(true)
		ws["txt_name_" .. frame]:setString(name)
		ws["img_noble_" .. frame]:setVisible(true)
	end
end

return M
