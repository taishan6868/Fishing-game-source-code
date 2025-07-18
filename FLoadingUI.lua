--[[ 
FishLoading主界面
使用真假进度形式
]]

local UIBase = require_ex("ui.base.UIBase")
local M = class("FLoadingUI", UIBase)

local Actor = require_ex("ui.base.Actor")

-- 单条提示信息持续时间
local TipDur = 5
local LoadingStep = 5
local UpdDuty = 2
local _TAG = "FISH"
local LoadingOnce = 3
local LoadingList = {
    "subgame/catchFish/spine/yuchao/by_yuchao",
    "subgame/catchFish/spine/yiwangdajin/by_ywdj",
    "subgame/catchFish/spine/zhaohuan/by_zhaohuan",
    "subgame/catchFish/spine/nx/by_nshb",
    "subgame/catchFish/spine/jingbao/jingbao/by_jb",
    "subgame/catchFish/spine/jingbao/yclx/by_yclx",
}
local LoadingDie = {
    "subgame/catchFish/spine/die/coin/by_coin",
    "subgame/catchFish/spine/die/die01/by_die01",
    "subgame/catchFish/spine/die/die02/by_die02",
    "subgame/catchFish/spine/die/mjdie/by_mjdie",
}

local function _addLoading(spine)
    if Assist.isEmpty(spine) or table.indexof(LoadingList, spine) then 
        return 
    end
    LoadingList[#LoadingList+1] = spine
end

function M:ctor(pond)
    self._pond = pond

    -- self.effRipple = true
    -- self.effDark = true

    UIBase.ctor(self)
    self:init()
end

function M:registerListenEvent()
    self:listenCustomEvent(HttpEvent.HTTP_PROCESS_EVENT, handler(self, self.onHttpProcessEvent))
end

function M:init()
    self._BindWidget = {
        ["img_bg"] = {},
        ["node_spine"] = {},
        ["loadingBar"] = {},
        ["txt_prg"] = {},
        ["txt_tip"] = {},
    }

    -- 假进度
    self._fakeProgress = 5
    self._updProgress = 0

    -- 加载提示乱序
    local ids = LoadingTipsConfig.getIds()
    self._tipList = Table.shuffle(ids)
    self._tipIdx = 0
    self._tick = 0
    self._loadIdx = 0

    local cfg
    -- 预加载鱼
    local roomId = Game.fishDB:getRoomIdx()
    ids = BYRoomConfig.fish_list(roomId) or {}
    for _, v in ipairs(ids) do
        cfg = BYFishConfig[v] or {}
        _addLoading(cfg.spine)
        _addLoading(cfg.shadow_spine)
        _addLoading(cfg.coming_pic)
    end
    if not LOW_MACHINE and device.platform~="ios" then
        -- 预加载死亡特效
        for _, v in ipairs(LoadingDie) do
            _addLoading(v)
        end
        -- 预加载炮台
        ids = BYCannonSkinConfig.getIds() or {}
        for _, v in ipairs(ids) do
            cfg = BYCannonSkinConfig[v]
            _addLoading(cfg.icon_vip[1])
            _addLoading(cfg.icon[1])
            _addLoading(cfg.fire_sp[1])
            _addLoading(cfg.fish_nets[1])
            _addLoading(cfg.cannon_cjp[1])
            _addLoading(cfg.wl_cjp[1])
        end
    end

    self:initViews()
end

function M:initViews()
    local uiNode = createCsbNode("subgame/catchFish/pond_loading.csb")
    self:addChild(uiNode, 1)
    self._rootNode = uiNode

    bindWidgetList(uiNode, self._BindWidget, self._widgets)

    self:changeTip()
    self:refresh()
end

function M:onEnter()
    UIBase.onEnter(self)
    
    Game:destroyWaitUI()
    Game.uiManager:hideLoading()

    self:checkUpdate()
    self:scheduleUpdate()
end

function M:prepareLoading()
    self._fakeProgress = Number.max(self._fakeProgress, self._updProgress/UpdDuty)
    self._updProgress = 1000
    self._loadIdx = #LoadingList
    self._tipIdx = 0

    if self._loadIdx == 0 then
        self._pond:setLoading(false)
    else
        local needStep = Number.ceil(self._loadIdx/LoadingOnce)
        if needStep > 90/LoadingStep then
            LoadingStep = Number.ceil(90/needStep)
        end
    end
end

function M:doLoading(times)
    times = times or Number.min(self._loadIdx, LoadingOnce)
    local res = ""
    for _ = 1, times do
        res = LoadingList[self._loadIdx]
        if String.endWith(res, "png") or String.endWith(res, "jpg") then
            display.newImageView(res, ccui.TextureResType.localType)
        else
            preloadSpine(res, Actor)
        end
        self._loadIdx = self._loadIdx - 1
    end
end

function M:updateFunc(dt)
    if self:refresh() then return end

    if self._loadIdx == #LoadingList then
        Game:purgeUnused(true)
    end
    if self._loadIdx > 0 then
        self:doLoading()
        if self._loadIdx <= 0 then
            self._pond:setLoading(false)
        end
    end

    self._tick = self._tick + dt
    if self._tick > TipDur then
        self._tick = 0
        self:changeTip(self._loadIdx > 0 or self._updProgress < 1000)
    end
end

----------------------------------
-- 刷新
function M:refresh()
    local progress, percent = 0, 0

    if self._updProgress < 1000 then
        percent = Number.floor(self._updProgress/UpdDuty)
    else
        if self._fakeProgress < 95 then
            self._fakeProgress = self._fakeProgress + LoadingStep
        end
        progress = Game.fishDB:getProgress()
        percent = Number.floor(Number.max(self._fakeProgress, progress))
    end

    self._widgets.loadingBar:setPercent(percent)
    self._widgets.txt_prg:setString(percent.."%")
    if progress == 100 then
        self:unscheduleUpdate()
        self:performWithDelay(handler(self, self.destroy), 1.5)
        return true
    end
end

function M:changeTip(ignoreTimeout)
    self._tipIdx = self._tipIdx + 1
    if self._tipIdx > #self._tipList or self._tipIdx > 4 then
        -- 超时
        if ignoreTimeout then
            if self._tipIdx > #self._tipList then
                self._tipIdx = 1
            end
        else
            Game:dispatchCustomEvent(GEvent(_TAG, "LOADING_TIMEOUT"))
            return
        end
    end
    setRichText(self._widgets.txt_tip, LoadingTipsConfig.text(self._tipList[self._tipIdx]))
end

----------------------------------
-- 更新检测
function M:checkUpdate()
    local roomId = Game.fishDB:getRoomIdx()
    local funcId = BYRoomConfig.room_key(roomId) or 0
    local cfg = FuncListConfig[funcId]
    if not cfg then
        self:prepareLoading()
        return
    end

    local field_entry = string.format("games.%s.GameEntry", cfg.key)
    if not Game:isLuaFileExist(field_entry) then
        Game.localDB:setStringForKey("res_ver_"..roomId, "1.00.00")
    end
    local version = Game.localDB:getStringForKey("res_ver_"..roomId, "1.00.00")

    Game:doPluginAPI("update", "subgame", 
        cfg.id, 
        handler(self, self.prepareLoading), 
        function(url) self._url = url end, 
        version
    )
end

function M:onHttpProcessEvent(event)
    if not self._url then return end
    local url = tostring(event.data.url)
    if url == self._url then
        self._updProgress = Number.floor(100 * event.data.recvSize / event.data.totalSize)
    end
end

----------------------------------
-- 交互
function M:onClose()
    -- 重写忽略返回键
end

return M
