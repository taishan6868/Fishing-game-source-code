--[[
宠物技能引导
]]
local UIBase = require_ex("ui.base.UIBase")
local M = class("FPetSkillHelp", UIBase)
local _TAG = "FISH"

local QUESTION_ID = 43

function M:ctor(pos, callback)
    self.effRipple = true
    -- self.effDark = true

    UIBase.ctor(self)
    self._pos = pos
    self._callback = callback
    self:init()
end

function M:init( )
    self._BindWidget = {
        ["panel_touch"] = {handle = handler(self, self.onBack)},
        ["panel_center"] = {},
        ["panel_center/lv_content"] = {key = "lv_content"},
        ["panel_center/txt_tit"] = {key = "txt_tit"},
        ["panel_center/txt_desc1"] = {key = "txt_desc1"},
        ["panel_center/txt_center"] = {key = "txt_center"},
        ["temp_txt"] = {}
    }

    self:initViews()
end

function M:onBack()
    if self._callback then self._callback() end
    self:destroy()
end

function M:initViews()
    local uiNode = createCsbNode("subgame/catchFish/petSkillHelp.csb")
    self:addChild(uiNode, 1)
    self._rootNode = uiNode

    bindWidgetList(uiNode, self._BindWidget, self._widgets)
    local size = self._widgets.panel_center:getContentSize()
    
    local pos = {x = self._pos.x - size.width/2, y = self._pos.y + size.height/2 }
    self._widgets.panel_center:setPosition(pos)
    self:initList()
end

function M:initList()
    local list = QuestionMarkConfig.content(QUESTION_ID)
    local segment = QuestionMarkConfig.segment(QUESTION_ID)
    
	local petData = Game.fishDB:getPetData()
	local petInfo
	for _,v in ipairs(petData) do
		if v.use_state == PetUseState.USE then
			petInfo = v
			break
		end
	end

    local lvInfo = Game:doPluginAPI("get", "petLvInfo", petInfo.pet_id)
    local skillId = PetConfig.skill_id(petInfo.pet_id)
    local skillName = BYSkillConfig.skill_name(skillId)
    local skillDesc = BYSkillConfig.skill_desc(skillId)
    local skill_power =lvInfo[petInfo.level].skill_power or 1
    local listSkill = {skillName, skillDesc, skill_power, skill_power}
    
    local tlist = {}
    for _,v in ipairs(list) do
        local isSplit = string.split(v, "%")
        if #isSplit > 1 then
            local param = table.remove(listSkill, 1)
            v = string.format(v, param)
        end
        table.insert(tlist, v)
    end
    setRichText(self._widgets.txt_center, Assist.mergeRichText(tlist, segment))
end

return M
