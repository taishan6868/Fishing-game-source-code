--[[ 
捕鱼主界面 
]]

local UIBase = require_ex("ui.base.UIBase")
local M = class("FPond", UIBase)
local _TAG = "FISH"

local Actor = require_ex("ui.base.Actor")
local FPlayer = require_ex("games.fish.views.base.FPlayer")
local FMagicEmoji = require_ex("games.fish.views.minor.FMagicEmoji")
local director = cc.Director:getInstance()
-- 垃圾回收停止
local GARBAGE_DISABLE = false -- device.platform=="windows"

-- 动画特效及图片
--local SpineTideWarn = {res="subgame/catchFish/spine/jingbao/yclx/by_yclx", ani="1", isLoop = false}
local SpineFrozen = {res="subgame/catchFish/spine/bd/by_bd", ani="animation", x=CC_DESIGN_RESOLUTION.cx, y=CC_DESIGN_RESOLUTION.cy, zorder=-10, isLoop=false}
local SpineFBomb = {res = "subgame/catchFish/spine/qpzd/by_qpzd", ani="1", x=CC_DESIGN_RESOLUTION.cx, y=CC_DESIGN_RESOLUTION.cy, isLoop=false}
local SpineDropBg = {res="subgame/catchFish/spine/djdl/by_djdl", ani="1", isLoop=true, scale=1.3}
local SpineCoin = {res="subgame/catchFish/spine/jinbi/by_jinbi"}
local SpineDynjPlate = {res = "subgame/field7/spine/bys/by_bys", center = true, isLoop =false}
-- 雷链
local SpineRayChain = {
	{res="subgame/catchFish/spine/leidian/by_leidianyu", ani="1", release=true},
	{res="subgame/catchFish/spine/leidian/by_leidianyu", ani="2", release=true},
}
-- 海妖专属
local SpineHYChain = {
    {res="subgame/field4/spine/hyxw/lightning/hyxw_lightning", ani="1", release=true},
	{res="subgame/field4/spine/hyxw/lightning/hyxw_lightning", ani="2", release=true},
}
-- 玩家聊天冷却
local CHAT_CD = 2
-- 掉落最大展示数量
local ITEM_DROPMAX = 10
-- 弹头类型
--local BULLET_TYPE = 2001
local FPS_CHECKPAD = 60
-- 每帧添加鱼数量
local FPS_ADD_FISH = 3

-- Action逻辑标签
local ActTag = {
    plate = 10001
}
local SpecialDropType={
    suit        = 2008, -- 花色
    bottle      = 2009, -- 酒瓶
}

local APP_LIST = {
    ["qgame"] = true,
    ["mgame"] = true,
}

--[[
掉落物品参数
@param id   number  物品ID
@return number,number,boolean (width,height,showLight)
]]
local function _dropItemArgs(id)
    local iconWidth, iconHeight, showLight = 90, 90, true
    if id == ENUM.ITEM_ID.LOTTERY or id == ENUM.ITEM_ID.DIAMOND
        or id == ENUM.ITEM_ID.BATTLE_AXE
        or id == ENUM.ITEM_ID.MISSILE1 or id == ENUM.ITEM_ID.MISSILE2
        or id == ENUM.ITEM_ID.MISSILE3 or id == ENUM.ITEM_ID.MISSILE4 then
        iconWidth, iconHeight = 150, 150
    elseif id == ENUM.ITEM_ID.COIN or id == ENUM.ITEM_ID.ENERGY or id == ENUM.ITEM_ID.SCORE then
        iconWidth, iconHeight, showLight = 80, 80, false
    end
    return iconWidth, iconHeight, showLight
end

--[[
物品掉落动作
]]
local function _dropItemAction(id, delay, fromPos, offset, toPos, pSound, callback, dropTime)
    local dur = ItemsConfig.drop_time(id)
    if not dur or checknumber(dur) <=0 then
        dur = 2000
    end
    dur = dur / 1000
	dur = dropTime~=nil and dropTime or dur
    local mtime = Number.min(cc.pGetDistance(fromPos,toPos)/700, 0.6)
    local seq = {
        cc.DelayTime:create(delay),
        cc.CallFunc:create(function()
            if pSound then 
                Audio.playSoundConfig("Daoju", "down")
            end
        end),
        cc.Spawn:create(
            cc.EaseBackOut:create(cc.MoveBy:create(0.3, offset)),
            cc.EaseBackOut:create(cc.ScaleTo:create(0.3, 1))
        ),
        cc.Spawn:create(cc.JumpBy:create(0.7, cc.p(0,0), 50, 2)),
        cc.DelayTime:create(dur-delay),
        cc.CallFunc:create(function()
            if pSound then 
                Audio.playSoundConfig("Daoju", "fly")
            end
        end),
        cc.Spawn:create(
            cc.EaseBackOut:create(cc.MoveTo:create(mtime, toPos)),
            cc.EaseSineOut:create(cc.ScaleTo:create(mtime+0.1, 0.1))
        ),
        cc.RemoveSelf:create()
    }
    if callback then
        table.insert(seq, #seq-1, cc.CallFunc:create(callback))
    end

    return transition.sequence(seq)
end

------------------------------------------------

function M:ctor()
    self.funcKey = "fish"
    
    UIBase.ctor(self)
    self:init()
end

function M:registerListenEvent()
    self:listenCustomEvent(cc.EVENT_COME_TO_FOREGROUND, handler(self, self.onComeToForeGround))
    self:listenCustomEvent(cc.EVENT_COME_TO_BACKGROUND, handler(self, self.onComeToBackGround))

    self:listenCustomEvent(GEvent("NET_READY_RECONNECT"), handler(self, self.onReadyReconnect))
    self:listenCustomEvent(GEvent("NET_HB_CHECK"), handler(self, self.onNetLatency))
    self:listenCustomEvent(GEvent("GAME_LV_MODIFY_EVENT"), handler(self, self.onUpdatePlayerLv))
    self:listenCustomEvent(GEvent("ON_BAG_DATA_UPDATE"), handler(self, self.updateBagData))
    -- self:listenCustomEvent(GEvent("ON_DIAMOND_CHANGE"), handler(self, self.onDiamondChange))
    self:listenCustomEvent(GEvent("ON_VIP_CHANGE"), handler(self, self.onVIPChange))
    -- self:listenCustomEvent(GEvent("GAME_RED_POINT_EVENT"), handler(self, self.onPlayerDataUpdate))
    self:listenCustomEvent(GEvent("CHAT_NORMAL"), handler(self, self.onRoomChat))

    self:listenCustomEvent(GEvent(_TAG, "USE_SKILL"), handler(self, self.onPlayerUseSkill))
    self:listenCustomEvent(GEvent(_TAG, "ADD_PLAYER"), handler(self, self.addPlayer))
    self:listenCustomEvent(GEvent(_TAG, "UPD_PLAYER"), handler(self, self.updatePlayer))
    self:listenCustomEvent(GEvent(_TAG, "DEL_PLAYER"), handler(self, self.removePlayer))
    self:listenCustomEvent(GEvent(_TAG, "SHOOT"), handler(self, self.onPlayerShoot))
    self:listenCustomEvent(GEvent(_TAG, "HIT_FISH"), handler(self, self.onPlayerHit))
    self:listenCustomEvent(GEvent(_TAG, "UPD_CANNON"), handler(self, self.updatePlayerCannon))
    self:listenCustomEvent(GEvent(_TAG, "UPD_CANNON_CB"), handler(self, self.onUpdateCannonCallback))
    self:listenCustomEvent(GEvent(_TAG, "UPD_ROOM"), handler(self, self.refresh))
    self:listenCustomEvent(GEvent(_TAG, "ADD_FISH"), handler(self, self.onAddFish))
    self:listenCustomEvent(GEvent(_TAG, "RELOCATION"), handler(self, self.onFishRelocation))
    self:listenCustomEvent(GEvent(_TAG, "FISH_TIDE"), handler(self, self.onFishTide))
    self:listenCustomEvent(GEvent(_TAG, "DEL_BULLET"), handler(self, self.onRemoveBullet))
    self:listenCustomEvent(GEvent(_TAG, "UPD_CANNONLV"), handler(self, self.onUpdateCannonLv))
    self:listenCustomEvent(GEvent(_TAG, "UPD_LOTTERY"), handler(self, self.onUpdateLottery))
    self:listenCustomEvent(GEvent(_TAG, "DO_LOTTERY"), handler(self, self.onPlayerLottery))

    self:listenCustomEvent(GEvent(_TAG, "TREAS_TASK_START"), handler(self, self.onTreasureStart))
    self:listenCustomEvent(GEvent(_TAG, "TREAS_TASK_CHANGE"), handler(self, self.onTreasureTaskChange))
    self:listenCustomEvent(GEvent(_TAG, "TREAS_TASK_RESULT"), handler(self, self.onTreasureResult))
	self:listenCustomEvent(GEvent(_TAG, "EXIT_GAME"), handler(self, self.onClose))

    self:listenCustomEvent(GEvent(_TAG, "BUGLE_TASK_START"), handler(self, self.onBugleStart))
    self:listenCustomEvent(GEvent(_TAG, "BUGLE_TASK_RESULT"), handler(self, self.onBugleResult))

    self:listenCustomEvent(GEvent(_TAG, "ADD_SPECIAL_DROP"), handler(self, self.onShowSpecialDrop))
    self:listenCustomEvent(GEvent(_TAG, "DEL_SPECIAL_DROP"), handler(self, self.onHideSpecialDrop))
    
    self:listenCustomEvent(GEvent(_TAG, "UPD_BOMBSKILL"), handler(self, self.onBombSkill))

    self:listenCustomEvent(GEvent(_TAG, "LOADING_TIMEOUT"), handler(self, self.onLoadingTimeout))
	self:listenCustomEvent(GEvent(_TAG, "NOTIFY_EFFECT"), handler(self, self.onNotifyEffect))
	
	self:listenCustomEvent(GEvent(_TAG, "CHANGE_ROOMEXIT_GAME"), handler(self, self.onCRExit))

    self:listenCustomEvent(GEvent(_TAG, "PET_HIT_FISH"), handler(self, self.onPetHit))
    self:listenCustomEvent(GEvent(_TAG, "PET_SKILL_TIMEOUT"), handler(self, self.onPetSKillTimeOut))

    self:listenCustomEvent(GEvent(_TAG, "DRILL_START"), handler(self, self.onDrillStart))
    self:listenCustomEvent(GEvent(_TAG, "DRILL_FIRE"), handler(self, self.onDrillFire))
    self:listenCustomEvent(GEvent(_TAG, "DRILL_BOMB"), handler(self, self.onDrillBomb))
	self:listenCustomEvent(GEvent(_TAG, "DRILL_FINISH"), handler(self, self.onDrillFinish))

    self:listenCustomEvent(GEvent(_TAG, "MATCH_TASK_BEGIN"), handler(self, self.onMatchTaskStart))
	self:listenCustomEvent(GEvent(_TAG, "MATCH_TASK_END"), handler(self, self.onMatchTaskEnd))

	self:listenCustomEvent(GEvent(_TAG, "RESET_IDLETIME"), handler(self, self.onResetIdletime))
	
	self:listenCustomEvent(GEvent(_TAG, "PET_CHANGE"), handler(self, self.onPetChange))
    self:listenCustomEvent(GEvent(_TAG, "CHANGE_CLEAR_TASK"), handler(self, self.onChangeClearTask))

    self:listenCustomEvent(GEvent(_TAG, "DEVIL_KING_ANGER"), handler(self,self.onDevilKingShow))
    self:listenCustomEvent(GEvent(_TAG, "DEVIL_KING_STATUS"), handler(self,self.onDevilKingShow))
end

function M:init()
    self._BindWidget = {
        ["bg"] = {},

        ["panel_fish"] = {},
        ["panel_fish1"] = {},
        ["panel_fish2"] = {},
        ["panel_fish3"] = {},
        ["panel_fish4"] = {},
        ["panel_fish5"] = {},
        
        ["panel_surface"] = {},
        ["panel_bullet"] = {},
        ["panel_touch"] = {},

        ["panel_turret"] = {zorder = 1},
        ["panel_turret/turret1"] = {key = "player1"},
        ["panel_turret/turret2"] = {key = "player2"},
        ["panel_turret/turret3"] = {key = "player3"},
        ["panel_turret/turret4"] = {key = "player4"},

        ["panel_turret/img_await_1"] = {key = "playerEmpty1"},
        ["panel_turret/img_await_2"] = {key = "playerEmpty2"},
        ["panel_turret/img_await_3"] = {key = "playerEmpty3"},
        ["panel_turret/img_await_4"] = {key = "playerEmpty4"},

        ["panel_mcPlate"] = {zorder = ENUM.UI_Z.TIP},
        ["panel_mcPlate/act_mcPlate"] = {key = "act_mcPlate", spine={res="subgame/catchFish/spine/djp/by_djp", isLoop=false}},
        ["panel_mcPlate/txt_mcPlate"] = {key = "txt_mcPlate"},
        ["panel_mjPlate"] = {zorder = ENUM.UI_Z.TIP},
        ["panel_mjPlate/act_mcPlate"] = {key = "act_mjPlate", spine={res="subgame/catchFish/spine/bmj/by_bmj2", isLoop=false}},
        ["panel_mjPlate/txt_mcPlate"] = {key = "txt_mjPlate"},
        ["panel_ysPlate"] = {zorder = ENUM.UI_Z.TIP},
        ["panel_ysPlate/act_mcPlate"] = {key = "act_ysPlate"},
        ["panel_ysPlate/txt_mcPlate"] = {key = "txt_ysPlate"},
    }

    self._myUid = Game:doPluginAPI("get", "playerUid")
    self._inv = 1 / 30

    -- 玩家
    self._player = {}
    -- 鱼
    self._fish = {}
    self._fishCount = 0
    self._updFishList = {}
    -- 子弹
    self._bullet = {}
    
    -- 抖屏
    self.shakeNodes = {}
    self.shakeParams = {duration = 0}
    
    -- 低帧频卡顿
    self._fpsRemain = nil
    self._fpsCheckTick = FPS_CHECKPAD
    self._fpsMessy = 0
    -- 流程标记
    self._entering = true
    self._preloading = true

    Game.fishMng = require_ex("games.fish.models.FishMng")
	
    -- 掉落物品，换桌的时候清掉
	self.dropList = {}
    -- 技能列表，方便换桌的时候移除
	self.skilList = {"btn_ice", "btn_summon", "btn_bugle", "btn_lock", "btn_rage", "btn_pet"}

    -- 聊天冷却
    self._chatPlayerCD = {}

    -- 有截图的boss死亡时间
    self._bossDieTime = 0

    -- 渔场加载界面
    if Game.reloadToGame then
        self:performWithDelay(function()
            self:setLoading(false)
        end, 0.1)
    else
        require_ex("games.fish.views.FLoadingUI").new(self):addToScene(ENUM.UI_Z.TOP)
    end

    self:initViews()
    self:scheduleUpdate(true)
end

function M:initViews()
    local uiNode = createCsbNode("subgame/catchFish/pond.csb")
    self:addChild(uiNode, 1)
    self._rootNode = uiNode

    bindWidgetList(uiNode, self._BindWidget, self._widgets)
    self._widgets.bg:setPosition(cc.p(0,0))
    if FISH_DEBUG then
        self:addDebugLabel()
    end
    if GM_DEBUG and Game:funcIsOpen("gm") then
        self:addRapidTestBtn()
    end
    -- 鱼池附属UI
    self._layerBg = require_ex("games.fish.views.FPondBG").new(self._widgets.bg)
    self._layerUI = require_ex("games.fish.views.pond.FPondUI").new(self, self._rootNode)
    self._layerSkill = require_ex("games.fish.views.pond.FSkillType").new(self, self._rootNode)
    self._layerTemp = require_ex("games.fish.views.pond.FTempUI").new(self, self._rootNode)
    self._layerPosFlag = require_ex("games.fish.views.pond.FPosFlag").new(self, self._rootNode)
    self._layerTip = require_ex("games.fish.views.pond.FTipUI").new(self, self._rootNode)
    self._layerGuide = require_ex("games.fish.views.pond.FGuideUI").new(self, self._rootNode)
    self._layerWarning = require_ex("games.fish.views.pond.FWarningUI").new(self, self._rootNode)
	self._cannonGuide = require_ex("games.fish.views.pond.FCannonGuideUI").new(self, self._rootNode)
    if not Game.fishDB:isMatchRoom() and Game:funcIsOpen("task") and
            Game:doPluginAPI("get", "nextTaskId",TaskScene.newbie) > 0 then
        require_ex("games.fish.views.pond.FTaskUI").new(self, self._rootNode)
    end
    self._layerHaiyaoResult= require_ex("games.fish.views.haiyao.FHaiyaoResult").new(self, self._rootNode)
	self._layerBossEff = require_ex("games.fish.views.pond.FBossPlayEff").new(self, self._rootNode)
    -- BOSS展示模块
	self._bossPlayModuleList = {
        [1]= "games.fish.views.pond.FBugleUI",
        [2]= "games.fish.views.haiyao.FHaiyaoUI",
        [3]= "games.fish.views.jadeBoss.FJadeTaskUi",
        [4]= "games.fish.views.jadeBoss.FJadeTaskUi",
    }

    self._flyCoinKey = "txt_plateNum"
    self._killCoinKey = "txt_killNum"
    if Game.fishDB:isRuinsRoom() then
        self._flyCoinKey = "txt_plateNum4"
        self._killCoinKey = "txt_killNum4"
    end

    self._layerBg:changeBg(true)

    -- 初始化四个玩家对象
    local tempCoin = self._layerTemp:getWidget(self._flyCoinKey)
    local tempLottery = self._layerTemp:getWidget("panel_lottery_ing")
    local panel_tips = self._layerTip:getWidget("panel_tips")
    for i = 1, Game.fishDB:getPMAX() do
        local ctrl = self._widgets["player"..i]
        local emptyNode = self._widgets["playerEmpty"..i]
        if emptyNode then
            adaptRescale(emptyNode)
        end
        self._player[i] = FPlayer:new(self, i, ctrl, tempCoin, emptyNode, tempLottery, panel_tips)
        Game.fishMng:setCannonOrigin(i, self._player[i]:getCannonPosition())
    end
    self._layerBossEff:initPlayerPos()
    self:initMatchUI()
    -- 绑定鱼池点击
    self._widgets.panel_touch:onTouch(handler(self, self.onTouchPond))
end

function M:initRoomUI()
    if Game.fishDB:isHuntRoom() then
        if Assist.isEmpty(self._layerHunt) then
            self._layerHunt = require_ex("games.fish.views.hunt.FHunt").new()
            self._layerHunt:addTo(self._rootNode,ENUM.UI_Z.TIP)
        end
    elseif Game.fishDB:isMatchRoom() then
        self:initMatchUI()
        if self._layerMatch and self._layerMatch.startMatch then
            self._layerMatch:startMatch()
        end
    elseif Game.fishDB:isRuinsRoom() or Game.fishDB:isNewRuinsRoom() then
        --
    else
        self._layerTip:updateRedress()
    end
    self._layerUI:setBombVisible(self._layerTip:isBombing())
    self:onTreasureTaskChange()
end

function M:initMatchUI()
    if not self._layerMatch then
        local roomId = Game.fishDB:getRoomId()
        if roomId == ENUM.ROOM_ID.FREE_MATCH then
            self._layerMatch = require_ex("games.fish.views.match.FMatchFreeUI").new():addTo(self._rootNode)
        elseif roomId == ENUM.ROOM_ID.GRAND_PRIX then
            self._layerMatch = require_ex("games.fish.views.match.FMatchGPUI").new(self._layerUI,self,self._layerTemp:getWidget(self._flyCoinKey))
            self._layerMatch:addTo(self._rootNode)
        elseif roomId == ENUM.ROOM_ID.ENTIRE then
            self._layerMatch = require_ex("games.fish.views.match.FMatchEntireUI").new(self._layerUI,self,self._layerTemp:getWidget(self._flyCoinKey))
            self._layerMatch:addTo(self._rootNode)
        end
    end
end

function M:getWidget(mix)
    if String.startWith(mix, "_layer") then
        return self[mix]
    end
    return self._widgets[mix]
end

function M:toFront()
    Game:doPluginAPI("query", "quickInfo")
    if LOW_MACHINE then
        for _, p in ipairs(self._player) do
            p:showLockChain()
        end
    end
end

function M:preloadSpine()
    if Game.fishDB:getRoomId() == FishRoomID.haiyao then
        preloadSpine(BYFishConfig.spine(FishSpe.haiyao_boss))
        preloadSpine(BYFishConfig.spine(FishSpe.haiyao_monster))
    end
end

function M:onEnter()
    if GARBAGE_DISABLE then
        collectgarbage("stop")
    end
    UIBase.onEnter(self)

    Assist.addSpriteFrames("subgame/catchFish/tp/subgame_catchFish")
    Assist.addSpriteFrames("subgame/catchFish/tp/subgame_catchFish_fish")

    Game:unlockTouch()

    -- 隐藏前置界面
    local layer = Game.uiManager:getRoomChooseLayer()
    if layer then
        layer:toBack()
    end
    if Game.hallUI then
        Game.hallUI:toBack()
    end
    --[[新手引导]]
	if Game.fishDB:getRoomId() == FishRoomID.shjs then
		self._layerGuide:showGameGuide("shjs")
	end

    if device.platform ~= "windows" then
        -- 背景音乐预加载（延迟）
        local bgm = string.format(Sound_fishConfig["BGM>normal"].file, 1)
        Audio.preloadMusic(bgm)
        if BGM_MAX > 1 then
            for i = 2, BGM_MAX do
                local _bgm = string.format(Sound_fishConfig["BGM>normal"].file, i)
                self:performWithDelay(function()
					Audio.preloadMusic(_bgm)
                end, 0.1*i)
            end
        end
		if Game.fishDB:isRuinsRoom() then
			bgm =Sound_fishConfig["BGM>yushi"].file
			Audio.preloadMusic(bgm)
		end
        -- 低端机优化
        if not LOW_MACHINE then
            self:performWithDelay(function()
                Audio.preloadMusic(Sound_fishConfig["BGM>boss"].file)
            end, 0.3)
        end
    end

    self:performWithDelay(function()
        for _, id in ipairs(Game.fishDB:getSpecialDrop()) do
            self:onShowSpecialDrop(id)
        end
    end, 0.3)

    if COLLISION_PHYSIC then
        self:detectCollision()
    end
end

function M:onExit()
    Game:doPluginAPI("ingore", "redpacket", 2)

    Game.connectHandler:setHeartBeatInterval(HEART_BEAT_DEFAULT)
    if Game.reloadToGame then
        Game.fieldId = Game.fishDB:getRoomId()
    else
        Game.fishCom:onExit()
    end
    Game.fishDB:init()
    self:resumeMusic()
    UIBase.onExit(self)

    if COLLISION_PHYSIC then
        self:removeCollisionListener()
    end

    if GARBAGE_DISABLE then
        Game:performDelay(function()
            if not Game.uiManager:getLayer("FPond") then
                collectgarbage("restart")
            end
        end, 2)
    end
end

function M:destroy()
    -- 显示前置界面
    local layer = Game.uiManager:getRoomChooseLayer()
    if layer then
        layer:toFront()
    elseif Game.hallUI then
        Game.hallUI.super.toFront(Game.hallUI)
    end

    self:unscheduleUpdate()
    UIBase.destroy(self)
end

-- 背景音乐控制
function M:stopMusic()
    if not self._myVolume then
        self._myVolume = Game.setDB:getVolume()
        Game.setDB:setVolume(0)
    end
end

function M:resumeMusic()
    if self._myVolume then
        Game.setDB:setVolume(self._myVolume)
        self._myVolume = nil
    end
end

--[[
跑马灯位置
]]
function M:setMarqueePos()
    -- 跑马灯位置偏移
    local nodeMarquee = self._layerPosFlag and self._layerPosFlag:getWidget("point_marquee")
    if nodeMarquee then
        local pos = cc.p(nodeMarquee:getPosition())
        Game:doPluginAPI("move", "marquee", pos)
    end
end

---------------------------------------------
-- 碰撞检测
function M:detectCollision()
    local function _contactLogic_(b_uid, f_uid)
        local bullet = self:getBullet(b_uid)
        local fish = self._fish[tostring(f_uid)]
        if not bullet or not fish then return end -- 非法
        if not fish:hitEnable() then return end -- 鱼可以被攻击
        if bullet:hitTargetFish() and not bullet:isTargetFish(f_uid) then return end -- 打中的不是目标鱼
        local hasLife = bullet:hasLife()
        if hasLife then
            if bullet:hadHitFish(f_uid) then return end -- 已经打中过这条鱼
            bullet:addHitFish(f_uid)
        end
        Game.fishCom:onHitFish(b_uid, {f_uid}, hasLife)
        Game.fishMng:removeMyBullet()
    end

    local function _onContactBegin_(contact)
        local bA = contact:getShapeA():getBody()
        local bB = contact:getShapeB():getBody()
        local a = bA:getNode()
        local b = bB:getNode()

        if not a or not b then return end

        -- Log.I(bA:getCategoryBitmask(), bB:getCategoryBitmask(), _TAG)
        if bA:getCategoryBitmask() == FishPhysic.mask_bullet then
            _contactLogic_(a.b_uid, b.f_uid)
        elseif bB:getCategoryBitmask() == FishPhysic.mask_bullet then
            _contactLogic_(b.b_uid, a.f_uid)
        end

        return false
    end
    
    self._contactListener = cc.EventListenerPhysicsContact:create()
    self._contactListener:registerScriptHandler(_onContactBegin_, cc.Handler.EVENT_PHYSICS_CONTACT_BEGIN)
    local eventDispatcher = director:getEventDispatcher()
    eventDispatcher:addEventListenerWithFixedPriority(self._contactListener, 1)
end

function M:removeCollisionListener()
    if self._contactListener then
        local eventDispatcher = director:getEventDispatcher()
        eventDispatcher:removeEventListener(self._contactListener)
        self._contactListener = nil
    end
    local pWorld = display.getRunningScene():getPhysicsWorld()
    if pWorld then
        pWorld:removeAllBodies()
    end
end

---------------------------------------------
-- 刷新
function M:refresh(event)
    if self._preloading then return end

    local notUpdateUI, clear
    if type(event) == "boolean" then
        notUpdateUI = event
    else
        notUpdateUI = event.data[1]
        clear = event.data[2]
    end

    if clear then
        self:clearPond()
    end
	self:clearDrop()	
    if not Assist.isEmpty(self._layerHaiyaoResult) then
        self._layerHaiyaoResult:closeResult()
    end
    if Game.fishDB:getBulgeLastTimeCD() > 0 then
        self._layerUI:startTimer({"btn_bugle"}, Game.fishDB:getBulgeLastTimeCD()) 
       	Game.fishDB:setBulgeLastTimeCD(0)
    end
	if not Assist.isEmpty(self._wlfxBoss) then 
		self._wlfxBoss:doStateIdle()
		self._wlfxBoss = nil
	end
    self._layerBg:changeBg(true)
    self:initBulletList()
    self:initFishPond()
    Game.fishDB:setFrencyPause(false)
    self._layerUI:checkFuncOpen()
    self._layerUI:setFrencySkillType(true)
    self._layerSkill:instanceView()  -- 恢复技能状态
    self._layerTip:setPetSkillVisible(false)  -- 宠物提示语
    for i = 1, Game.fishDB:getPMAX() do
        local player = self._player[i]
        local pInfo = Game.fishDB:getPlayerByIdx(i)
        if pInfo then
            player:onEnterRoom(pInfo, true)
            if player:isMySelf() then
                if player:getBombId() > 0 then
                    self._layerUI:setBombVisible(true)
                    self._layerTip:setBombVisible(true, player)
                else
                    self._layerUI:setBombVisible(false)
                    self._layerTip:setBombVisible(false)
                end
                -- 入场时，宠物技能CD
                self:defaultSkillCD(pInfo.using_pet_id)
            end
        else
            player:onExitRoom()
        end
    end

    local level = Game.fishDB:getPlayerCannonLv()
    if level then
        self._layerUI:updateCannonShow(false)
    end
    if not notUpdateUI then
        self._layerUI:updateLotteryShow(false)
        self:updateBagData()
    end
    self._layerUI:updatePetShow()
end

function M:updateFunc(dt)
    local player = self:getPlayerById(self._myUid)
    if player and player:idleDisable() then
        -- 闲置超时踢出房间
        Game:performDelay(function ()
            showConfirmTip({sTip=Config.localize("fish_idle_kick"), btn2Hide=true}, nil, ENUM.UI_Z.TOP)
        end, 0.5)

        self:unscheduleUpdate()
        self:stopAllActionsForExit()

        self:performWithDelay(function()
            self:onKickOut(1)
        end, 0.04)

        return
    end

    if self:isLoading() then return end

    -- 抖屏
    if #self.shakeNodes > 0 then
        self:updateShake()
    end

    -- 鱼
    for _, fish in pairs(self._fish) do
        if fish:getState(FishState.idle) or fish:isWild() then
            self:removeFish(fish.fish_uid)
        else
            if not fish:getFrozen() and fish:faintTimes()<=0 then
                -- 没有初始同步过或者非冰封和眩晕 
                fish:updateActor(dt)
            end
        end
    end
    for i = 1, FPS_ADD_FISH do
        local v = Game.fishDB:getAddFish()
        if v then
            self:addFish(v, nil, nil, true)
        else
            break
        end
    end
    -- 子弹
    for _, bullet in pairs(self._bullet) do
        if bullet:isWild() then
            self:removeBullet(bullet.shoot_uid)
            Game.fishDB:removeBullet(bullet.shoot_uid)
        else
            bullet:updateActor(dt)
        end
    end
    -- 玩家
    for _, p in ipairs(self._player) do
        p:onUpdate(dt)
    end

    -- 后端调试
    self:updateDebugData()

    -- FPS监控
    if self._fpsRemain then
        self._fpsRemain = self._fpsRemain + self._inv
        self._fpsCheckTick = self._fpsCheckTick - dt
        if self._fpsCheckTick < 0 then
            self._fpsCheckTick = FPS_CHECKPAD
            self:checkFPSMessy()
        end
    end
end

--[[
重置技能cd跑一圈
]]
function M:defaultSkillCD(pId)
    if Assist.isEmpty(pId) then return end
    local skill_id = PetConfig.skill_id(pId) or 0
    local cfg = BYSkillConfig[skill_id]
    if Assist.isEmpty(cfg) then return end
    self._layerUI:startTimer({"btn_pet"}, cfg.cd_time/1000, cfg.cd_tips)
end

function M:clearDrop()
    for _, v in ipairs(self.dropList) do
        if not Assist.isEmpty(v) then
            v:removeFromParent()
        end
    end
    self.dropList = {}
    if self._layerUI then
        self._layerUI:getTimer(self.skilList, true)
    end
end

--------------------------------------------------
-- 数据接口/查询
function M:isLoading()
    return self._preloading
end

function M:setLoading(v)
    if v then
        self._preloading = v
        Game.fishDB:setProgress(0)
    else
        self:onEnterGame()
        self:performWithDelay(function ()
            self._preloading = v
            self:refresh(false)
            Game.fishCom:onFishRelocation()
        end, 0.8)
    end
end

--[[
FPS监控
掉帧是移除鱼影子，恢复再添加
]]
function M:isFPSMessy()
    return self._fpsMessy > 0
end

function M:addFPSMessy()
    self._fpsMessy = self._fpsMessy + 1
    for _, f in pairs(self._fish) do
        f:removeShadow()
    end
end

function M:checkFPSMessy()
    local fps = Timer:getCurTimeStamp()
    if fps - self._fpsRemain > FPS_CHECKPAD/4 then
        self:addFPSMessy()
    else
        self._fpsMessy = 0
    end
    self._fpsRemain = fps
end

function M:isEntering()
    return self._entering
end

function M:getPlayerByIdx(idx)
    return self._player[idx]
end

function M:getPlayerById(uid)
    local idx = Game.fishDB:getPlayerIndex(uid)
    return self._player[idx]
end

function M:resetPlayers()
    for i = 1, Game.fishDB:getPMAX() do
        if self._player[i] then
            self._player[i]:reset()
        end
    end
end

--[[
搜索目标鱼（倍率最大）
]]
function M:searchTargetFish()
    local target
    for _, fish in pairs(self._fish) do
        if fish:hitEnable() then
            if not target or target:getTimesArea() < fish:getTimesArea() then
                target = fish
            end
        end
    end
    return target
end

--[[
扫描圆形区域内的鱼
@param x, y, r  number  圆形参数
@param max      number  扫描上限
@param precise  boolean 是否精确判断
@param bullet   FBullet 子弹（巡游类[钻头]）
]]
function M:scanFishInCircle(x, y, r, max, precise, bullet)
    local ret, f, retUidList = {}, nil, {}
    local checkFishes = Game.fishMng:getAliveFishs()
    for i = #checkFishes, 1, -1 do
        f = checkFishes[i]
        if f:isInScreen() and f:collideCircle(x, y, checknumber(r), precise) then
            if not bullet or not bullet:hadHitFish() then
                table.insert(ret, f)
                table.insert(retUidList, f.fish_uid)
                if max and #ret == max then
                    break
                end
            end
        end
    end
    return ret, retUidList
end

--[[
扫描线上的鱼（激光炮）
]]
function M:scanFishInLine(p1, p2, area)
    local ret, f = {}
    local checkFishes = Game.fishMng:getAliveFishs()
    for i = #checkFishes, 1, -1 do
        f = checkFishes[i]
        if f:isInScreen() and f:checkFishInSameDir(p1, p2) and f:collideLine(p1, p2, area) then
            table.insert(ret, f.fish_uid)
            f:changeState(FishState.hit)
        end
    end
    return ret
end

--[[
冰封
]]
function M:updateFrozenShow(show, dur)
    if show then
        if not self._widgets.act_frozen then
            self._widgets.act_frozen = Actor:new(SpineFrozen.res, SpineFrozen)
            self._widgets.panel_surface:addChild(self._widgets.act_frozen)
        else
            self._widgets.act_frozen:stopAllActions()
            self._widgets.act_frozen:setVisible(true)
            self._widgets.act_frozen:changeAnimation(SpineFrozen.ani, false, nil, true)
        end
        self._widgets.act_frozen:performWithDelay(function()
            self:updateFrozenShow(false, 0)
        end, dur)
    else
        if self._widgets.act_frozen then
            self._widgets.act_frozen:stopAllActions()
            self._widgets.act_frozen:pause()
            self._widgets.act_frozen:setVisible(false)
        end
    end
end

--[[
更新鱼的弹头攻击状态（冰封时）
]]
function M:updateBombFish()
    local player = self:getPlayerById(self._myUid)
    local show = player and player:getBombId() > 0
    for _, f in pairs(self._fish) do
        f:checkBombState(show)
    end
end

function M:showPetCanNotAttTip()
	local player = self:getPlayerById(self._myUid)
	-- 刷新鱼的锁定状态提示
	local petAtt, effType = player:getPetSkillType() > 0, false
    for _, f in pairs(self._fish) do
		effType = f._petskill_effect_type
        f:showPetCanNotAttTip(petAtt and effType)
    end
end

--[[
刷新锁定鱼（仅自己）
]]
function M:updateLockFish(info, ignoreFish)
    info = info or Game.fishDB:getPlayer() or {}
    local showLock = false
    if info.frency or info.lock then
        local idx = Game.fishDB:getMyIndex()
        local player = self._player[idx]
        if not player or player:isDrilling() then return end
        if not player:canHitTargetFish() then 
            -- 自动锁定新的鱼 @discarded
            -- local maxFish = self:searchTargetFish()
            -- player:setTargetFish(maxFish)
            self._layerTip:setLockVisible(true, player)
            showLock = true
        end
    end
    if not ignoreFish then
        -- 刷新鱼的锁定状态提示
        for _, f in pairs(self._fish) do
            f:checkLockState(showLock)
        end
    end
end

--[[
更新任务鱼
]]
function M:updateTaskFish()
    local show -- nil自行检测
    if not Game.fishDB:isInTask() then
        show = false
    end
    for _, f in pairs(self._fish) do
        f:checkTaskState(show)
    end
end

--[[
击杀获得金币飘字
@param pos      point       位置
@param idx      number      归属玩家索引
@param num      number      奖励数量
@param delay    number      延迟时间
]]
function M:flyCoinNumer(pos, idx, num, delay)
    delay = checknumber(delay)
    local tempKey = self._killCoinKey
    if not self._player[idx]:isMySelf() then
        tempKey = "txt_killNum2"
    end
    local tempNode = self._layerTemp:getWidget(tempKey)
    local numFloat = tempNode:clone()

    numFloat:setString(num)
    numFloat:setPosition(pos.x, pos.y + 50)
    numFloat:setVisible(delay == 0)
    self._rootNode:addChild(numFloat, 100)

    local seq = {
        cc.DelayTime:create(delay),
        cc.Show:create(),
		cc.DelayTime:create(0.5),
        cc.EaseSineOut:create(cc.FadeOut:create(0.8)),
        cc.DelayTime:create(0.8),
        cc.ScaleTo:create(0.5, 0.5),
        cc.RemoveSelf:create(),
    }
    numFloat:runAction(transition.sequence(seq))
end

--[[
展示获得金币
@param pos          point       位置
@param idx          number      座位
@param num          number      获得金币数量
@param cannonId     number      炮台ID
@param fish         FFish/table 鱼
@param ignorePlate  boolean     忽略奖金盘展示
]]
function M:displayGetCoin(pos, idx, num, cannonId, fish, ignorePlate)
    if num <= 0 or self._entering then return end

    -- self:flyCoinNumer(pos, idx, num)

    local times, dieName, fishType
    if fish.getTimesArea then
        times = fish:getTimesArea()
        dieName = fish:getDieSpine()
        fishType = fish:getType()
    else
        times = fish.times
        dieName = fish.dieName
        fishType = fish.fishType
    end

    -- 50倍以上的鱼都有转盘
    if not ignorePlate and times >= 50 then
        -- 奖金鱼前端展示扣除抽水
        local tmp = num
        if Game:funcIsOpen("lottery") and fishType==FishType.bonus and (not cannonId or BYCannonConfig.type(cannonId)==1) then
            tmp = tmp / 0.9
        end
        local tempNode = self._layerTemp:getWidget(self._flyCoinKey)
        self._player[idx]:setPlateVisible(true, tempNode, tmp, dieName, fishType)
    end
end

--[[
全屏大奖盘
@param show     boolean     显示/隐藏
@param num      number      奖励数量
@param delay    number      展示延迟
@param itemId    number     物品id
]]
function M:displayFullPlate(show, num, delay, itemId)
    local txt_mcPlate, act_mcPlate, panel_Plate
    if itemId == ENUM.ITEM_ID.JADE then
		if Assist.isEmpty(self._widgets.act_ysPlate.actor) then
			self._widgets.act_ysPlate.actor = Actor:new(SpineDynjPlate.res, SpineDynjPlate)
			self._widgets.act_ysPlate:addChild(self._widgets.act_ysPlate.actor)
			if SpineDynjPlate.center then
				local size = self._widgets.act_ysPlate:getContentSize()
				self._widgets.act_ysPlate.actor:setPosition(cc.p(size.width/2, size.height/2))
			end
		end
        txt_mcPlate = self._widgets.txt_ysPlate 
        act_mcPlate = self._widgets.act_ysPlate.actor
        panel_Plate = self._widgets.panel_ysPlate
    elseif itemId == ENUM.ITEM_ID.ENERGY then
        txt_mcPlate = self._widgets.txt_mjPlate
        act_mcPlate = self._widgets.act_mjPlate.actor
        panel_Plate = self._widgets.panel_mjPlate
    else
        txt_mcPlate = self._widgets.txt_mcPlate
        act_mcPlate = self._widgets.act_mcPlate.actor
        panel_Plate = self._widgets.panel_mcPlate
    end
    
    if show then
        local seq = {
            cc.Hide:create(),
            cc.DelayTime:create(delay or 1.5),
            cc.CallFunc:create(function()
                txt_mcPlate:setVisible(false)
                act_mcPlate:changeAnimation("1", false, nil, true)
                Audio.playSoundConfig("JiangPan", "2")
            end),
            cc.Show:create(),
            cc.DelayTime:create(0.3),
            cc.CallFunc:create(function()
                txt_mcPlate:setVisible(true)
                txt_mcPlate:stopAllActions()
                txt_mcPlate:rollString(num, 0.7, 0)
            end),
            cc.DelayTime:create(2),
            cc.CallFunc:create(function()
                self:displayFullPlate(false, nil, nil, itemId)
            end)
        }
        panel_Plate:stopAllActions()
        panel_Plate:runAction(transition.sequence(seq))
    else
        panel_Plate:setVisible(false)
        act_mcPlate:pause()
        txt_mcPlate:stopAllActions()
    end
end

--[[
雷链（雷龙）
@param trigger  FFish       触发雷链的鱼
@param list     table       数据
@param fishType number      类型
]]
function M:displayRayChain(trigger, list, fishType)
    local triggerPos = trigger:getCenterPos()
    local eff, p, cPos, dir, radian, angle, scale
    for _, fish in ipairs(list) do
        fish:setDieDuration(true)
		if fishType ~= FishType.lighting_small then
			local index = fish==trigger and 1 or 2
			local spineLighting
			if fishType == FishType.hyBoss then
				spineLighting = SpineHYChain[index]
			else
				spineLighting = SpineRayChain[index]  
			end
			eff = Actor:new(spineLighting.res, spineLighting)
			self._widgets.panel_surface:addChild(eff, 10)
			if fish == trigger then
				eff:setPosition(triggerPos)
				eff:setScale(3)
			else
				p = fish:getCenterPos()
				cPos = cc.pMidpoint(triggerPos, p)
				dir = cc.pSub(triggerPos, p)
				radian = -Number.atan2(dir.y , dir.x)
				angle = math.radian2angle(radian) - 180
				scale = cc.pGetLength(dir) / 420
				eff:setScaleX(scale)
				eff:setPosition(cPos)
				eff:setRotation(angle)
			end
		end
    end
    Audio.playSoundConfig(self,"rayChain")
end

function M:displaySkillEffect(skillId,pos)
    local skill_res = BYSkillConfig.skill_res(skillId)
    local actor = Assist.addCfgIcon(self._widgets.panel_surface,{res=skill_res[1],ani=skill_res[2]},{release=true})
    pos = pos or display.center
    actor:setPosition(self._widgets.panel_surface:convertToNodeSpace(pos))
end

--[[
全屏炸弹爆炸
]]
function M:displayBomb()
    Audio.playSoundConfig(self, "Zhadan")

    -- 低端机优化
    if LOW_MACHINE then return end

    if not self._widgets.act_fullBomb then
        self._widgets.act_fullBomb = Actor:new(SpineFBomb.res, SpineFBomb)
        self._widgets.panel_surface:addChild(self._widgets.act_fullBomb)
    else
        self._widgets.act_fullBomb:setVisible(true)
        self._widgets.act_fullBomb:changeAnimation(SpineFBomb.ani, false, nil, true)
    end

    self._widgets.act_fullBomb:stopAllActions()
    self._widgets.act_fullBomb:performWithDelay(function()
        self._widgets.act_fullBomb:pause()
        self._widgets.act_fullBomb:setVisible(false)
    end, 2)
end

--[[
击杀掉落展示
@param idx              number      座位索引
@param list             table       奖励
@param x                number      X坐标
@param y                number      Y坐标
@param callback         function    回调
@param isLimitDropCount number      是否限制掉落数量
@param dropTime         number      掉落时间
@param ignoreNum        boolean     忽略掉落数字展示
]]
function M:displayAwards(idx, list, x, y, callback, isLimitDropCount, dropTime, ignoreNum)
    -- 掉落整理（总数限制）
    local showNums, totalShowNum = {}, 0
    for i, award in ipairs(list) do
        local itemType = ItemsConfig.type(award.gtid or award.id or award.tool_id)
        if isLimitDropCount or ENUM.ITEM_TYPE.BULLET ~= itemType then
            showNums[i] = Number.min(ITEM_DROPMAX, award.num or award.tool_num)
        else
            showNums[i] = award.num 
        end
        totalShowNum = totalShowNum + showNums[i]
    end

    -- 掉落位置
    local totalShowOffsets = {}
    local offsetAddNum, tmpIdx, radius, r = 0, 0, 85
    while true do
        offsetAddNum = offsetAddNum + 4
        for i = 1, offsetAddNum do
            r = i/(offsetAddNum+1)*math.pi*2
            table.insert(totalShowOffsets, cc.p(Number.sin(r)*radius, Number.cos(r)*radius*0.518))
        end
        tmpIdx = tmpIdx + offsetAddNum
        radius = radius + 85
        if tmpIdx >= totalShowNum then
            break
        end
    end

    -- 展示掉落
    local listNum = #list
    local player = self._player[idx]
    local endX, endY = player:getCenterPosition()
    local showIndex = 1
    local gtid, width, height, showLight, actorRes
    local actDrop, dpChip, size, actLight
    local offset, action

    for i, award in ipairs(list) do
        gtid = award.gtid or award.id or award.tool_id
        local itemShowNum = showNums[i]
        -- 话费券控制
        if Game:doPluginAPI("check", "propValid", gtid) then
            width, height, showLight = _dropItemArgs(gtid)
            if gtid == ENUM.ITEM_ID.COIN then
                actorRes = SpineCoin
            else
                actorRes = {res=ItemsConfig.big_icon(gtid)}
            end

            for l = 1, itemShowNum do
                showIndex = showIndex + 1

                actDrop = Actor:new(actorRes.res, actorRes)
                dpChip = actDrop:getDisplayNode()
                size = dpChip:getContentSize()
                self._rootNode:addChild(actDrop, 22000)
    			self.dropList[#self.dropList+1] = actDrop

                actDrop:setPosition(x, y)
                actDrop:setScaleX(0)
                actDrop:setScaleY(0)
                if width > 0 then 
                    dpChip:setScaleX(width/size.width) 
                end
                if height > 0 then 
                    dpChip:setScaleY(height/size.height) 
                end

                local comCall = (l==itemShowNum and i==listNum) and callback or nil
                offset = table.remove(totalShowOffsets, Number.random(1, #totalShowOffsets))
                local pos = Game.fishDB:getItemPos(gtid)
                if not pos or not player:isMySelf() then
                    pos = {}
                    pos.x = endX
                    pos.y = endY
                end
                action = _dropItemAction(gtid, showIndex*self._inv,cc.p(x,y), offset, pos, true, comCall, dropTime)
                actDrop:runAction(action)

                if showLight then
                    actLight = Actor:new(SpineDropBg.res, SpineDropBg)
                    actDrop:addChild(actLight, -1)
                end
            end
            if gtid ~= Game.fishDB:getCostItemId() and not ignoreNum then
                local dur = ItemsConfig.dropnum_time(gtid)
                dur = dur / 1000
                self:displayAwardsNum(award, cc.pAdd(cc.p(x,y), offset), dur)
            end
        end
    end
end

--[[
展示获得道具数量
]]
function M:displayAwardsNum(award, pos, showTime, parent)
    local panel_itemNum = self._layerTemp:getWidget("panel_itemNum")
    parent = parent or self._rootNode
    if panel_itemNum then
        panel_itemNum = panel_itemNum:clone()
        parent:addChild(panel_itemNum, 22001)
        self.dropList[#self.dropList+1] = panel_itemNum
        panel_itemNum:setPosition(cc.pAdd(pos, cc.p(0,-50)))
        local txt_num = panel_itemNum:getChildByName("txt")
        local id = award.gtid or award.id or award.tool_id
        local num = award.energyNum or award.num or award.tool_num
        local name = Game:doPluginAPI("get", "propName", id)
        local count = Game:doPluginAPI("get", "propCount", id, num)
        txt_num:setString(string.format("%s%s", name, count))
        panel_itemNum:setScale(0.1)
        panel_itemNum:runAction(transition.sequence({
            cc.Show:create(),
            cc.EaseBounceOut:create(cc.ScaleTo:create(0.5,1)),
            cc.DelayTime:create(showTime or 3),
            cc.Spawn:create({cc.FadeOut:create(1), cc.MoveBy:create(1, cc.p(0,50))}),
            cc.RemoveSelf:create()
        }))
    end
end

--[[
特殊掉落展示
@param idx      number  座位索引
@param reward   table   奖励
@param rate     number  加成
@param delay    number  延时
]]
function M:displaySpecialAwards(idx, reward, rate, delay)
    delay = delay or 0.1
    local player = self._player[idx]
    local endX, endY = player:getCenterPosition()
    local offset = cc.p(player:getHeadCenterOffset())
    local panel_reward = self._layerTemp:getWidget("panel_reward"):clone()
    local img_icon = panel_reward:getChildByName("img_icon")
    local txt_count = panel_reward:getChildByName("txt_count")
    local txt_rate = panel_reward:getChildByName("txt_rate")
    fitIconSize(img_icon, ItemsConfig.big_icon(reward.id or reward.gtid))
    local x = endX
    local y = endY + offset.y
    if txt_rate then
        txt_rate:setVisible(false)
    end
    panel_reward:setPosition(cc.p(x, y))
    panel_reward:setVisible(false)
    self._rootNode:addChild(panel_reward, ENUM.UI_Z.TOP)
    panel_reward:runAction(transition.sequence({
        cc.DelayTime:create(delay),
        cc.CallFunc:create(function()
            txt_count:rollString(reward.count or reward.num,2)
        end),
        cc.Show:create(),
        cc.DelayTime:create(2),
        cc.CallFunc:create(function()
            if txt_rate and rate and rate ~= 0 then
                txt_rate:setString(string.format("+%s",rate))
                txt_rate:setVisible(true)
            end
        end),
        cc.DelayTime:create(1),
        cc.FadeOut:create(0.5),
        cc.RemoveSelf:create()
    }))
end

--[[
展示抽奖奖励（其他人）
@param idx      number  座位索引
@param list     table   奖励
@param x        number  X坐标
@param y        number  Y坐标
]]
function M:displayLotteryAward(idx, list, x, y)
    local reward = list[1] or list
    local cfg = ItemsConfig[reward.id]
    if not cfg then return end

    local tempNode = self._layerTemp:getWidget("panel_lottery")
    local item = tempNode:clone()
    local ws = {}
    local BindWidget = {
        ["img_icon"] = {spine = {res="gameres/general/spine/charge/dt_charge", ani="4", center=true, zorder=-1}},
        ["txt_name"] = {},
        ["txt_num"] = {},
    }
    bindWidgetList(item, BindWidget, ws)

    fitIconSize(ws.img_icon, cfg.big_icon)
    ws.txt_name:setString(cfg.name)
    ws.txt_num:setString(Assist.formatCount(reward.id, reward.num))

    item:setPosition(x, idx>2 and y-200 or y+200)
    item:setScale(0)
    item:setVisible(true)

    self._rootNode:addChild(item, ENUM.UI_Z.TIP)

    local durOut = 0.5
    local moveOut = cc.MoveTo:create(durOut, cc.p(x, idx>2 and y+10 or y-10))
    local scaleOut = cc.ScaleTo:create(durOut, 0.5)
    local rotateOut = cc.RotateBy:create(durOut, 90)
    local seq = {
        cc.ScaleTo:create(0.2, 1.2),
        cc.ScaleTo:create(0.1, 1.0),
        cc.DelayTime:create(2),
        cc.Spawn:create(moveOut, scaleOut, rotateOut),
        cc.MoveTo:create(0.05, cc.p(x, y)),
        -- cc.FadeOut:create(0.1),
        cc.RemoveSelf:create(),
    }
    item:runAction(transition.sequence(seq))
end

--[[
炮台开火射击展示
@param idx      number  座位索引
@param bullet   table   子弹数据
]]
function M:displayShoot(idx, bullet)
    local player = self._player[idx]
    if not player then return end
    
    if bullet then
        local fish
        if checknumber(bullet.fish_uid) > 0 then
            fish = self._fish[tostring(bullet.fish_uid)]
        end
        player:setTargetFish(fish)
        player:onFire(bullet.pos_x, bullet.pos_y)
    end
    player:doFire()
end

------------------------------------------------
--[[
抖屏
@param target       widget/table    抖动结点
@param duration     number          持续时长
@param strength     number          抖动强度
@param interval     number          抖动间隔
]]
function M:shake(target, duration, strength, interval)
    if self._layerBg:isFishTiding() then return end
    
    target = target or {self._rootNode}
    duration = duration or 0.3
    strength = strength or {15, 15}
    interval = interval or self._inv

    while #self.shakeNodes > 0 do
        self.shakeNodes[1].node:setPosition(self.shakeNodes[1].x, self.shakeNodes[1].y)
        table.remove(self.shakeNodes, 1)
    end

    if type(target) == "table" then
        for _, node in pairs(target) do
            local x, y = node:getPosition()
            local data = {node = node, x = x, y = y}
            table.insert(self.shakeNodes, data)
        end
    elseif target then
        local x, y = target:getPosition()
        local data = {node = target, x = x, y = y}
        table.insert(self.shakeNodes, data)
    end

    self.shakeParams.duration = duration
    self.shakeParams.strength = strength
    self.shakeParams.interval = interval
end

function M:updateShake()
    self.shakeParams.duration = self.shakeParams.duration - self.shakeParams.interval
    if self.shakeParams.duration <= 0 then
        while #self.shakeNodes > 0 do
            self.shakeNodes[1].node:setPosition(self.shakeNodes[1].x, self.shakeNodes[1].y)
            table.remove(self.shakeNodes, 1)
        end
    else
        local randX = Number.random(-self.shakeParams.strength[1], self.shakeParams.strength[1])
        local randY = Number.random(-self.shakeParams.strength[2], self.shakeParams.strength[2])
        for _, target in pairs(self.shakeNodes) do
            target.node:setPosition(target.x+randX, target.y+randY)
        end
    end
end

----------------------------------
-- 监听
function M:onComeToForeGround()
    if self._background then
        local curTime = Timer:getCurTimeStamp()
        local bgTime = os.time() - self._background
        Timer:setCurTimeStamp(curTime + bgTime)
        self._background = nil

        -- 换房 @final
        if self._layerUI then
            self._layerUI:onChangeRoom(nil, nil, handler(self, self.checkMyInfo), slg_cmd.fish.enter[1])
            self._layerUI:clearSkillCD()
            self._layerUI:setFrencySkillType(true)
            if self._layerSkill then
                self._layerSkill:instanceView()
            end
            return
        end

        -- 前后台切换退回到大厅
        if Game.enterFromField then
            self:onKickOut()
            return
        end

        -- 重新检测房间
        local function _canEnterRoom_(idx, coin)
            if BYRoomConfig[idx] and BYRoomConfig[idx].open == 1 then
                local limit = BYRoomConfig[idx].coin_area_k
                if coin >= limit[1] and Number.outRange(limit[2], 0, coin) then
                    return true
                end
            end
            return false
        end

        local myCoin = Game:doPluginAPI("get", "playerCoin")
        local roomId = Game.fishDB:getRoomId()
        if _canEnterRoom_(roomId, myCoin) then
            Game.fieldId = roomId
        else
            Game.fieldId = nil
            local roomIds = BYRoomConfig.getIds()
            table.sort(roomIds)
            for k = #roomIds, 1, -1 do
                if _canEnterRoom_(roomIds[k], myCoin) then
                    Game.fieldId = roomIds[k]
                    break
                end
            end
        end

        self:destroy()
        Game:enterScene(Game:getSceneIdx())
    end
end

function M:onComeToBackGround()
    if not self._background then
        self._fpsRemain = nil
        self._background = os.time()
        Game:destroyWaitUI()
        self:unscheduleUpdate()
        self:stopAllActionsForExit()
        -- self:resetPlayers()
        -- Game.fishCom:onExit()
        Game.fishCom:onComeToBackGround()
    end
end

function M:onReadyReconnect()
    Game:lockTouch()
    self:stopAllActionsForExit()
end

function M:onNetLatency(event)
    if not self._fpsRemain then return end
    local latency = event.data.latency
    if latency > 0 then
        Game:tipMsg(Config.localize("net_is_not_good"))
    else
        self:addFPSMessy()
    end
end

function M:onUpdatePlayerLv(event)
    -- 不是自己&低端机&掉帧 不展示升级
    if event.data.uid ~= self._myUid or LOW_MACHINE or self:isFPSMessy() then
        return
    end
    if Game:doPluginAPI("get", "playerLvUp") then
        Game:doPluginAPI("upgrade", "lv")
    end
end

function M:updateBagData()
    self._layerUI:updateBagData()

    local player = self._player[Game.fishDB:getMyIndex()]
    if player then
        player:setOptVisible(false)
    end
end

function M:onDiamondChange(event)
    if not event or event.data.last < event.data.curr then
        self._layerUI:refreshDiamond(true)
	else
		self._layerUI:refreshDiamond(false)
    end
    self._layerUI:updateBagData()
end

function M:onVIPChange()
    
end

-- @discarded
function M:onPlayerDataUpdate(event)
    if event.data.key == "friend" then
        -- 收到好友私信
        local myIndex = Game.fishDB:getMyIndex()
        local player = self._player[myIndex]
        player:updateFriendApply()
    end
end

--[[
房间内聊天
]]
function M:playerChatCD(send)
    self._chatPlayerCD[send] = true
    self:performWithDelay(function() 
        self._chatPlayerCD[send] = false
    end, CHAT_CD)
end

function M:onRoomChat(event)
    if event.data.subgame == Game:getSceneIdx() then
        -- 只展示同场景的聊天信息
        local send = event.data.send
        if self._chatPlayerCD[send] then return end
        self:playerChatCD(send)
        local recv = event.data.recv
        if not Assist.isEmpty(event.data.magic_id) then
            -- 魔法表情
            local playerFrom = self:getPlayerById(send.sender)
            local playerTo = self:getPlayerById(recv.sender)
            if playerFrom and playerTo then
                local posFrom = playerFrom:getCannonPosition(40)
                local posTo = playerTo:getCannonPosition(40)
                local data = {
                    from = posFrom,
                    to = posTo,
                    mid = event.data.magic_id,
					seat = playerFrom:getSeat()
                }
                FMagicEmoji.new(self._widgets.panel_turret, data)
            end
            
        elseif not Assist.isEmpty(event.data.emoji_id) then
            -- 普通聊天
            local player = self:getPlayerById(send.sender)
            if player then
                player:displayChat(event.data.emoji_id)
            end
		else
			local playerFrom = self:getPlayerById(send.sender)
			if playerFrom then
				local info = {sender= event.data.send, content= event.data.content, isMy=playerFrom:isMySelf()}
				Game:doPluginAPI("set", "chatRecord", info)
				Game.chatDB:setChatList()
				Game.fishCom:onEventChat(info)
				playerFrom:displayChatTips(event.data.content)
			end
        end
    end
end

--[[
展示聊天视图
]]
function M:showChatView()
    local layerChat = require_ex("games.fish.views.pond.FPondChat").new()
    layerChat:addCloseCallback(function()
        excFuncSafe(self, "setMarqueePos")
    end)
    layerChat:addToScene()
end

--[[
广播弹头
]]
function M:onBombSkill(event)
    local info = event.data
    local pInfo = Game.fishDB:getPlayer(info.use_uid)
    local player = self:getPlayerById(info.use_uid)
    if not player then return end
    player:setBombState(info.warhead_id)
    if info.warhead_id > 0 then 
        player:showSkillEffect(FSkill.nbomb, true)
        player:setOptVisible(false)
    else
		if player:isMySelf() then
			player:setOptVisible(true)
		end
        player:showSkillEffect(FSkill.nbomb, false)
        if pInfo.lock or pInfo.frency then
            player:showSkillEffect(FSkill.lock, true)
        end
    end
end

--[[
广播打死特殊鱼延迟显示
]]
function M:onNotifyEffect(event)
	local info = event.data
	--local pInfo = Game.fishDB:getPlayer(info.effects_uid)
	local player = self:getPlayerById(info.effects_uid)
	if not player or Assist.isEmpty(self._layerBossEff) then return end
	local tempNode
    if info.effects_id == FishSpe.dynj or info.effects_id == FishSpe.dynj1 then
        if info.end_status then
            local dur = BYEventConfig.event_cd(RoomEventId.wljy) + 2
            self._layerUI:startTimer({"btn_bugle"}, dur)
            if player:isMySelf() then
                if not Assist.isEmpty(self._wlfxBoss) then
                    self._wlfxBoss:doStateIdle()
                    self._wlfxBoss = nil
                end
            end
        end
        local item = self._layerTemp:getWidget("panel_envelop")
		self._layerBossEff:onNotifyEffect(info.effects_id, info, info.effects_uid, item)
    else
        tempNode = self._layerTemp:getWidget("ft_hy")
		self._layerBossEff:onNotifyEffect(info.effects_id, info)
    end
end

--[[
使用技能
]]
function M:onPlayerUseSkill(event)
    local data = event.data or {}
    local pInfo = Game.fishDB:getPlayer(data.player_id)
    local player = self:getPlayerById(data.player_id)
    if not player then return end
    player:setDefaultKitOutTime()
    local progresses
    local first = true
    local delayAward = 0.1
    if data.skill_id == FSkill.ice then
        for _, fish in pairs(self._fish) do
            fish.cold_history = Game.fishDB:getFishFrozen(fish.fish_uid)
            fish:checkFrozen()
        end
        self:updateFrozenShow(true, Game.fishDB:getSkillDur(FSkill.ice,data.player_id)/1000)
        player:setFrozenVisible(true)
        Audio.playSoundConfig(self, "Bingdong")
        progresses = {"btn_ice"}

    elseif data.skill_id == FSkill.summon then
        progresses = {"btn_summon"}

    elseif data.skill_id == FSkill.bugle then
        progresses = {"btn_bugle"}
        player:displayBugleFish()

    elseif data.skill_id == FSkill.rage or data.skill_id == FSkill.rageFree then
        self:onRageSkillChange(data.player_id)
        progresses = {"btn_rage"}

    elseif data.skill_id == FSkill.lock then
        first = data.is_first
        self:onLockSkillChange(data.player_id, data.is_first)
        progresses = {"btn_lock"}

    elseif data.skill_id == FSkill.laser then
        progresses = {"btn_laser"}
	elseif data.skill_id == FSkill.pet1 or data.skill_id == FSkill.pet2 or data.skill_id == FSkill.pet3 then
		progresses = {"btn_pet"}
        player:showPetSkillRun({"3"})  -- 宠物技能状态3,4
        if player:isMySelf() then      -- 技能提示语
            self._layerWarning:showPetSkillTip(true, data.skill_id, player:getPetPosition())
        end
    elseif data.skill_id == FSkill.battleAxe then
        progresses = {"btn_battleAxe"}
        self:displaySkillEffect(data.skill_id)
        delayAward = 1.5
        self:performWithDelay(function()
            for _, uid in ipairs(data.death_fish) do
                local fish = self._fish[tostring(uid)]
                if fish then
                    fish:changeState(FishState.die)
                    self:removeFish(uid)
                end
            end
        end,0.5)
    elseif data.skill_id == FSkill.devilKing then
        player:displayBugleFish()
        progresses = {}
    end

    if data.player_id == self._myUid then
        if first and #progresses > 0 then
            -- 延迟0.5秒
            local dur = Game.fishDB:getSkillCD(data.skill_id)/1000 + 0.5

            -- 如果是海妖漩涡场景 则走海妖漩涡的技能cd
            if data.skill_id == FSkill.rage or data.skill_id == FSkill.rageFree and player:isMySelf() then
                self:showHaiYaoSkillType(pInfo, dur)
                self._layerUI:delLockSkillCd("btn_lock")
            else
                local cdLastAni = BYSkillConfig.cd_tips(data.skill_id)
                self._layerUI:startTimer(progresses, dur, cdLastAni) 
                self._layerUI:showSkillEff("btn_pet", data.skill_id, false)
            end
        end
        if data.skill_id ~= FSkill.lock or first then
            self:updateBagData()
            if data.skill_id == FSkill.lock or data.skill_id == FSkill.rage or data.skill_id == FSkill.rageFree then
                self._layerGuide:setGuideVisible(false)
            end
            self:updateLockFish(pInfo, true)
        end
    end
    if not Assist.isEmpty(data.award) then
        self:performWithDelay(function()
            self:displayAwards(Game.fishDB:getPlayerIndex(data.player_id),data.award,display.cx,display.cy,nil,true,2.5,true)
            if data.player_id == self._myUid then
                for _, v in ipairs(data.award) do
                    if v.tool_id == Game.fishDB:getCostItemId() then
                        self:displayFullPlate(true,v.tool_num,1.5,v.tool_id)
                        break
                    end
                end
            end
        end,delayAward)
    end
end

--[[
海妖场显示海妖技能状态
]]
function M:showHaiYaoSkillType(pInfo, dur)
    if self._isChangeSkillView then return end
    self._isChangeSkillView = true
    self:performWithDelay(function()
        self._isChangeSkillView = nil
    end, 1.5)
    self._layerUI:setFrencySkillType(false)
    self._layerSkill:setSkillCd(dur, handler(self, self.restoreFrencySkileType))
end

--[[
倒计时结束恢复狂暴技能
]]
function M:restoreFrencySkileType()
    self._layerUI:setFrencySkillType(true)
end

--[[
玩家更新
]]
function M:addPlayer(event)
    local pInfo = event.data or {}
    local idx = Game.fishDB:seatToIdx(pInfo.pos)
    local player = self._player[idx]
    if player then
        player:onEnterRoom(pInfo, true)
    end
end

function M:updatePlayer(event)
    local pInfo = event.data or {}
    local idx = Game.fishDB:seatToIdx(pInfo.pos)
    local player = self._player[idx]
    if player then
        player:refresh(pInfo)
        if (not pInfo.lock) and (not pInfo.frency) then
            player:setTargetFish(nil, true)
            player:showSkillEffect(FSkill.lock, false)
            if player:isMySelf() then
                self._layerTip:setLockVisible(false)
                self:updateLockFish()
            end
        end
    end
end

function M:removePlayer(event)
    local data = event.data or {}
    local idx = Game.fishDB:seatToIdx(data.pos)
    local player = self._player[idx]

    if player then
		if not Assist.isEmpty(self._layerBossEff) then
			self._layerBossEff:removePlayer(idx)
		end
        if player:isDrilling() or player:isMySelf() then
            self._layerTip:setDrillStep(0)
        end
		local detailLayer = Game.uiManager:getLayer("FViewDetail") 
		local uId = player:getUid()
		if not Assist.isEmpty(detailLayer) and detailLayer.getOtherPlayerUid and uId == detailLayer:getOtherPlayerUid() then
			Game.uiManager:removeLayer("FViewDetail")
		end
        player:onExitRoom()
    end

    if data.bs and #data.bs > 0 then
        for _, b in ipairs(data.bs) do
            self:removeBullet(b, false)
        end
    end
end

--[[
重置玩家（自己）的冷却时间
]]
function M:onResetIdletime(event)
    local player = self:getPlayerById()
    if player then
        player:setDefaultKitOutTime()
    end
end

--[[
射击
]]
function M:onPlayerShoot(event)
    if self._preloading then return end
    local shoot = event.data or {}
    if shoot.bombItemId >= 0 then
        Game.fishDB:cacheBomb(shoot.shoot_uid, shoot.bombItemId)
        self:onPlayerBomb(shoot.player_id, shoot.bombItemId, shoot.fish_uid)
    else
        self:addBullet(shoot)
        local pInfo = Game.fishDB:getPlayer(shoot.pos, true)
        local idx = Game.fishDB:seatToIdx(pInfo.pos)
        self:displayShoot(idx, shoot)
    end
end

function M:onPlayerBomb(playerId, bombItemId, fishUid)
    if self._preloading then return end
    local fish = self._fish[tostring(fishUid)]
    if not fish then return end

    local player = self:getPlayerById(playerId)
    if player then
        player:setBombId(bombItemId)
        player:fireBomb(fish, false)
    end
end

function M:onPlayerHit(event)
    if self._preloading then return end
    local info = event.data or {}
    local idx = Game.fishDB:getPlayerIndex(info.player_id)
    local bombItemId = Game.fishDB:uncacheBomb(info.shoot_uid)
    if idx > 0 then
		local dropList = {info.fish_drop, info.normal_drop, info.kill_drop}
        self:updateFishState(info.fish_state_list, idx, info.fish_res_list, bombItemId, info.cards_list, info.card_type, info.fish_multiple, info.dial_list, nil, nil, info.shoot_uid, dropList)
    end
    if info.shoot_hide then
        if info.player_id ~= self._myUid then
            self:removeBullet(info.shoot_uid, true)
        end
        Game.fishDB:removeBullet(info.shoot_uid)
    end
end

--[[
宠物技能超时处理
]]
function M:onPetSKillTimeOut(event)
    local info = event.data or {}
    if info.uid ~= self._myUid then
        local player = self:getPlayerById(info.uid)
        if player then
            player:showPetSkillRun({"4", "2"})
        end
    end
end

function M:onPetHit(event)
    if self._preloading then return end
    local info = event.data or {}
    local idx = Game.fishDB:getPlayerIndex(info.uid)
	if checknumber(info.ret_code) ~= 0 then
        Game:tipError(info.ret_code)
		self._player[idx]:showPetSkillRun({"4", "2"})
		if self._player[idx]:isMySelf() then  --关闭技能提示语
			self._layerWarning:showPetSkillTip(false, info.skill_id)
		end
		return
    end

    if info.uid ~= self._myUid then
        -- 坐标转换
        local myInfo = Game.fishDB:getPlayer()
        local pInfo = Game.fishDB:getPlayer(info.uid)
        if (myInfo.pos > Game.fishDB.PMIRROR and pInfo.pos <= Game.fishDB.PMIRROR) or 
            (pInfo.pos > Game.fishDB.PMIRROR and myInfo.pos <= Game.fishDB.PMIRROR) then
            info.skill_posx = CC_DESIGN_RESOLUTION.width - info.skill_posx
            info.skill_posy = CC_DESIGN_RESOLUTION.height - info.skill_posy
        end
        -- 宠物单体技能特效跟鱼走
        if info.skill_id == FSkill.pet1 and info.die_fish_reward[1] then
            local fishUid = info.die_fish_reward[1].fish_uid
            local fish = self._fish[tostring(fishUid)]
            if fish then   -- 如果鱼不存在走其他宠物技能流程
                local pos = fish:getPosition()
                info.skill_posx, info.skill_posy = pos.x, pos.y
            end
        end
        self._player[idx]:showPetSkillRun({"4", "2"})
    end

    self._player[idx]:reqPetSkill(info)
    if self._player[idx]:isMySelf() then  --关闭技能提示语
        self._layerWarning:showPetSkillTip(false, info.skill_id)
    end

	if idx > 0 and #info.die_fish_reward > 0 then
        self:petHitFish(idx, info.die_fish_reward, info.skill_id)
	end
	
	local key, fish
	dump(info.hit_fish_uid, "test")
	for i=1, #info.hit_fish_uid do
		key = tostring(info.hit_fish_uid[i])
		fish = self._fish[key]
		if fish and fish:isAlive()then
			fish:showFaint(true)  --眩晕
		end
	end
end

--[[
检测宠物打死的是否有特殊鱼
]]
function M:checkIsHasSpecialFish(fishReward, skill_id)
    local skillCorrFishList = BYSkillConfig.special_fish(skill_id)  -- 技能对应的鱼
    if #skillCorrFishList < 1 then return 0, 0 end
    local fish, fishList = nil, {}
    for _, v in ipairs(fishReward) do
        fish = self._fish[tostring(v.fish_uid)]
        if fish then
            table.append(fishList, {fId=fish:getFishId(), mult=v.fish_multiple, fUid=v.fish_uid})
        end
    end
    if #fishList > 0 then
        table.sort(fishList, function(a, b)
            return a.mult > b.mult
        end)
    end
    for _, v in ipairs(fishList) do
        for _, v1 in ipairs(skillCorrFishList) do
            if v.fId == v1 then
                return v.fId, v.fUid
            end
        end
    end
    return 0, 0
end

function M:petHitFish(idx, fishReward, skill_id)
    local special_fish, special_fish_uid = self:checkIsHasSpecialFish(fishReward, skill_id)
    local bigSpecial_fish, isFirst = 0, true
    local stateList, resList, totalRw = nil, nil, {}
    for k, v in ipairs(fishReward) do
        stateList = {}
        resList = {}
        resList.fish_uid = v.fish_uid
        resList.res_list = {}
        resList.res_buf_list = v.res_buf_list
        stateList = {v.fish_uid, 0}
        for _, v1 in ipairs(v.reward) do
            local v11 = { gtid=v1.tool_id, num=v1.tool_num}
            if not totalRw[v11.gtid] then
                totalRw[v11.gtid] = {}
                totalRw[v11.gtid].num = 0
            end
            totalRw[v11.gtid].num = totalRw[v11.gtid].num + v11.num
            table.insert(resList.res_list, v11)
        end
        bigSpecial_fish = 0
        if special_fish_uid == resList.fish_uid and isFirst then
            -- 保证只触发同类型的boss一次并且是最大倍率的
            isFirst = false
            bigSpecial_fish = special_fish
        end
        local isPlayFull = false
        if k == #fishReward then
            if special_fish > 0 then
                isPlayFull = false
            else
                isPlayFull = totalRw
            end
        end
        self:updateFishState(stateList, idx, {resList}, 0, v.cards_list, v.card_type, v.fish_multiple, v.dial_list, isPlayFull, bigSpecial_fish)
    end
end

--[[
宠物切换
]]
function M:onPetChange(event)
	local info = event.data or {}
    local player = self:getPlayerById(info.uid)
	if not player then return end
    if player then
        player:changePet(info)
		if player:isMySelf() then  -- 更新技能图标
			self._layerUI:updatePetShow(info)
		end
		
    end
end

--[[
换炮
]]
function M:updatePlayerCannon(event)
    local idx = event
    if type(event) == "table" then
        idx = event.data[1]
    end

    idx = idx or Game.fishDB:getMyIndex()
    local player = self._player[idx]
    if player then
        player:updateCannon()
        if player:isMySelf() then
            -- 激光炮
            if player:skillEnable(FSkill.laser) then
                self._layerUI:updateLaserShow()
                self._layerUI:setLaserVisible(true)
            else
                self._layerUI:setLaserVisible(false)
            end
			self._layerUI:updatePetShow()
        end
    end
end

function M:onUpdateCannonCallback(event)
    local data = event.data or {}
    Audio.playSoundConfig("Cannon", "2")
        
    self:changeCannon(data.lv)

    self._layerUI:updateCannonShow(true)
    if data.coinAdd > 0 then
        self._layerTip:showUpCannonReward(data.coinAdd)
    end
end

function M:changeCannon(level)
    local player = self._player[Game.fishDB:getMyIndex()]
    if not player then return end

    local cfg = BYCannonLevelConfig[level]
    local ids = BYCannonConfig.getIds()
    local cannonId = 0
    for _, id in ipairs(ids) do
        if BYCannonConfig.level(id) == cfg.cannon_multiple then
            cannonId = id
            break
        end
    end
    if cannonId <= 0 then return end
	player:showUpCannonCoinEff()
    player:changeCannon(cannonId)
end

--[[
鱼
]]
function M:onAddFish(event)
    if self._preloading then return end
    self:appendAddFish(event.data or {})
end

function M:appendAddFish(list, first)
    local index = 0
    for _, v in pairs(list) do
        index = index + 1
        self:addFish(v, first, index)
    end
    return index
end

--[[
同步鱼坐标
]]
function M:onFishRelocation(event)
    if self._preloading then return end
    local info = event.data
    for _, f in ipairs(info) do
        local key = tostring(f.fish_uid)
        local fish = self._fish[key]
        if fish then
            fish:relocation(f)
        end
    end
end

--[[
鱼潮来袭
]]
function M:onFishTide()

    -- 场内所有鱼快速游走
    self:clearFish(true, FishState.idle)

    self._layerWarning:tideWarning(handler(self, self.onFishTideCallback))

    if Game.fishMng:getBossFishCount() == 0 then
        self:performWithDelay(function()
            Game.fishCom:playBGM(true)
        end, 1.0)
    end
end

function M:onFishTideCallback()
    self._layerBg:changeBg()
end

--[[
子弹移除
]]
function M:onRemoveBullet(event)
    local data = event.data or {}
    self:removeBullet(data.uid, data.bomb)
end

--[[
炮台升级
]]
function M:onUpdateCannonLv()
    if self._layerUI then
        self._layerUI:updateCannonShow(false)
    end
    local player = self._player[Game.fishDB:getMyIndex()]
    if player then
        player:showCannonLock()
    end
end

--[[
奖池抽奖
]]
function M:onUpdateLottery(event)
    local act = event.data[1]
    if self._layerUI then
        self._layerUI:updateLotteryShow(act)
    end
end

function M:onPlayerLottery(event)
    local pInfo = event.data or {}
    local player = self:getPlayerById(pInfo.player_id)
    if player then
        player:showLottery(pInfo)
    end
end

--------------------------------------------------
-- 逻辑接口
function M:onEnterGame()
    Game.connectHandler:setHeartBeatInterval(HEART_BEAT_DEFAULT/2)
    
    Game:onFore()

    Game.fishDB:setMagicCost()

    self._fpsMessy = 0

    local seq = {
        cc.DelayTime:create(0.1),
        cc.CallFunc:create(function()
            self:initRoomUI()
        end),
        cc.DelayTime:create(0.4),
        cc.CallFunc:create(function()
            if Game.fishMng:getBossFishCount() > 0 then
                Audio.playSoundConfig("BGM", "boss")
            else
                Game.fishCom:playBGM()
            end
            Audio.preloadSound(Sound_fishConfig["FPond>FIRE"].file)
        end),
        cc.DelayTime:create(0.5),
        cc.CallFunc:create(function() 
            self._entering = false 
            Game:destroyWaitUI()
            Game.uiManager:hideLoading()
            Game.fishDB:setProgress(100)
            self:checkMyInfo()
            self:setMarqueePos()
            Game.uiManager:removeLayer("CheckinUI")
            Game:doPluginAPI("check", "redpacket")
        end),
        cc.DelayTime:create(2.0),
        cc.CallFunc:create(function() 
            self._fpsRemain = Timer:getCurTimeStamp()
        end),
    }
    self:runAction(transition.sequence(seq))

    self:scheduleUpdate()
end

--[[
数据有效性检测
]]
function M:checkMyInfo()
    local player = self:getPlayerById(self._myUid)
    if not player or not player:hasPlayer() then
        local params = {
            sTip = Config.localize("fish_pond_data_error"),
            btn2Hide = true,
            delay1 = 5,
            fCallBack1 = function()
                self:onKickOut(1)
            end,
        }
        showComTip(params, nil, ENUM.UI_Z.TIP)
    end
end

function M:onCRExit(event)
	self:onKickOut(event.data)
end

function M:onClose(event)
	local callback
	if event and event.data then
		callback = event.data
	end
    self._layerUI:onBackHall(0, callback)
end

function M:onLoadingTimeout()
    Game:tipMsg(Config.localize("login_is_long_time_norsp"), 2)
    self:onKickOut(1, function()
        Game.uiManager:removeLayer("FLoadingUI")
    end)
end

function M:onKickOut(op, exitTipView)
    Game:doPluginAPI("ingore", "redpacket", 2)
	Game:unperformDelay("clearCard")
    Game:doPluginAPI("clear", "matchData")
    self:clearDrop()
    self:unscheduleUpdate()
    self:stopAllActionsForExit()
    self:resetPlayers()
    Game.fishCom:onExit(op)
    Game.fishDB:onExit()
    removeHollowCover()
    self:destroy()
    if Game.enterFromField then
        Game.enterFromField = nil
        Game:enterScene(ENUM.SCENCE.PLATFORM, exitTipView)
    else
        Game.fishDB:clear()
        Game:enterScene(Game:getSceneIdx(), exitTipView)
    end
end

function M:clearPond()
    self._entering = true
    self._chatPlayerCD = {}
    self._isChangeSkillView = nil

    self:stopAllActions()
    if Game.fishDB then
        Game.fishDB:setTaskData()
    end

    self:clearFish(true, FishState.idle, true)
    self:clearBullet()
    self:resetPlayers()
    if not Assist.isEmpty(self._layerWarning) then
        self._layerWarning:hide()
    end
    if not Assist.isEmpty(self._layerTip) then
        self._layerTip:setBombVisible(false)
        self._layerTip:setLockVisible(false)
    end
    if not Assist.isEmpty(self._layerTreas) then
        self._layerTreas:removeSelf()
        self._layerTreas = nil
    end
    if not Assist.isEmpty(self._layerMatch) then
        self._layerMatch:removeSelf()
        self._layerMatch = nil
    end
    if not Assist.isEmpty(self._layerMatchTask) then
        self._layerMatchTask:removeSelf()
        self._layerMatchTask = nil
    end
    if self._layerBossPlay and not Assist.isEmpty(self._layerBossPlay) then
        self._layerBossPlay:removeSelf()
        self._layerBossPlay = nil
    end
    if not Assist.isEmpty(self._layerDevilKing) then
        self._layerDevilKing:removeSelf()
        self._layerDevilKing = nil
    end
    self._layerBossEff:clear()
    self._layerBg:clear()

    Game.fishMng:clear()

    self:updateFrozenShow(false)
    self:onEnterGame()
end

function M:stopAllActionsForExit()
    for _, p in pairs(self._player) do
        p:onExitRoom()
    end
    for _, b in pairs(self._bullet) do
        b:hide()
    end
    for _, f in pairs(self._fish) do
        f:hide()
    end
    self:stopAllActions()
    self._layerTip:setBombVisible(false)
    self._layerTip:setLockVisible(false)
end

--------------------------------------------------
-- 交互
function M:onTouchPond(event)
    local pInfo = Game.fishDB:getPlayer()
    if not pInfo then return end

    local function onTouchBegan(touchPos)

        local player = self._player[Game.fishDB:getMyIndex()]
        if not player then
            Log.w("player is nil", _TAG)
            return false
        end
        self._touching = true
        local tPos = self._widgets.panel_touch:convertToNodeSpace(touchPos)
        if player:getBombId() > 0 then
            -- 弹头
            local fishes = self:scanFishInCircle(tPos.x, tPos.y, 10)
            for _, fish in ipairs(fishes) do
                if fish:getType(FishType.bonus) then
                    player:fireBomb(fish, true)
                    player:showSkillEffect(FSkill.nbomb, false)
                    self._layerUI:setBombVisible(false)
                    self._layerTip:setBombVisible(false)

                    if pInfo.lock then
                        player:showSkillEffect(FSkill.lock, true)
                    elseif pInfo.frency then
                        player:showSkillEffect(FSkill.rage, true)
                    end
                    break
                end
            end
        elseif player:isLasering() then
            -- 激光
            self._layerUI:onSkillLaserFire(tPos.x, tPos.y)

        elseif not player:isDrilling() and (pInfo.lock or pInfo.frency) then
            -- 锁定
            local fishes = self:scanFishInCircle(tPos.x, tPos.y, 10, 1)
            if #fishes > 0 then
                player:setTargetFish(fishes[1])
                if self._layerSkill:isVisible() and Game.fishDB:isFrencyPause() then
                    Game.fishDB:setFrencyPause(false)
                    self._layerSkill:setPauseType()
                end
                self._layerTip:setLockVisible(false)
            end
        elseif player.needGuidePos then
            -- 座位指引
            player:setOptVisible(false)
            player:setFlagVisible(true, 0.4)

        else
            -- 开火射击
            player:setAutoFire(true, tPos)
            player:setBombId(nil)
            player:onFire(tPos.x, tPos.y, true, false ,true)
            player:setOptVisible(false)
			player:showPetChange(false)
        end

        return true
    end

    local function onTouchMoved(touchPos)
        local player = self._player[Game.fishDB:getMyIndex()]
        if player and player:getBombId() == 0 and (not player:isLasering()) and (not pInfo.frency) and (not pInfo.lock) then
            local tPos = self._widgets.panel_touch:convertToNodeSpace(touchPos)
            player:setAutoFire(true, tPos)
        end
    end

    local function onTouchEnded()
        local player = self._player[Game.fishDB:getMyIndex()]
        if player then
            player:setAutoFire(false)
        else
            Log.w("onTouchEnded:player is nil", _TAG)
        end
		if self._cannonGuide then
			self._cannonGuide:onBoxDescHandler(3)
		end
        self._touching = nil
    end

    if event.name == "began" then
        return onTouchBegan(event.target:getTouchBeganPosition())
    elseif event.name == "moved" then
        onTouchMoved(event.target:getTouchMovePosition())
    else
        onTouchEnded(event.target:getTouchEndPosition())
    end
end

--------------------------------------------------
-- 鱼
function M:initFishPond()
    local fishes = Game.fishDB:getFishList(true)
    local count = self:appendAddFish(fishes, true)
    local frame = Number.ceil(count/4) + 1
    self:performWithDelay(function()
        self:setVisible(true)
        Game:destroyWaitUI()
    end, frame*self._inv)
end

function M:addFish(f, isEnter, index, sync)
    local key = tostring(f.fish_uid)
    
    -- 鱼已经存在或者没有鱼的数据时直接返回
    if self._fish[key] or (not Game.fishDB:getFish(key)) then return end

    local fish = Game.fishMng:createFish(self, f, isEnter, index)
    self._fishCount = self._fishCount + 1
    self._fish[key] = fish
    fish:updateMove(sync)
    fish:updateActor()
    local frozen, leftTime = fish:checkFrozen()
    if isEnter then
        if frozen and leftTime > 0 then
            self:updateFrozenShow(true, leftTime)
        end
    elseif not self._layerTreas and fish:isBoss() then
        self._layerWarning:bossWarning(BYFishConfig[f.fish_id])
    end

    -- 判断鱼是否被召唤
    local summonPlayerId, isBugle = Game.fishDB:checkSummonFish(f.fish_uid)
    if summonPlayerId or fish:isSummon() then
        fish:setSummonState(true)
        if summonPlayerId then
            local player = self:getPlayerById(summonPlayerId)
            if player then
                player:displaySummonFish(fish, isBugle)
            end
        else
            self:performWithDelay(function()
                fish:setSummonState(false, nil, true)
            end, 0.1)
        end
    end
end

--[[
更新鱼的状态
@see updateFish
]]
function M:updateFishState(fishState, idx, resList, cannonId, cards_list, card_type, fish_multiple, dial_list, petData, bigSpecial_fish, shoot_uid, dropList)
    if #fishState < 2 then return 0 end

    -- 初始奖励数据
    local resDic, buffList, getCoin, getEnergy = {}, {}, 0, 0
    if resList and #resList > 0 then
        for _, resInfo in ipairs(resList) do
            resDic[tostring(resInfo.fish_uid)] = resInfo.res_list
            if not Assist.isEmpty(resInfo.res_buf_list) then
                local buffs = {}
                for _, v in ipairs(resInfo.res_buf_list) do
                    buffs[v.gtid] = v.num
                end
                buffList[tostring(resInfo.fish_uid)] = buffs
            end

            for _, res in ipairs(resInfo.res_list) do
                if res.gtid == ENUM.ITEM_ID.COIN or res.tool_id == ENUM.ITEM_ID.COIN or res.tool_id then
                    getCoin = getCoin + (res.num or res.tool_num)
                elseif res.gtid == ENUM.ITEM_ID.ENERGY or res.tool_id == ENUM.ITEM_ID.ENERGY then  --魔晶
                    getEnergy = getEnergy + (res.num or res.tool_num)
                elseif res.gtid == ENUM.ITEM_ID.JADE  or res.tool_id == ENUM.ITEM_ID.JADE then
                    getEnergy = getEnergy + (res.num or res.tool_num)
                end
            end
        end
    end

    local count = #fishState / 2
    local fullPlate = false
    local chainFish, chainTrigger = {}
    local maxDieFish, ignorePlate
    local key, state, silent, isHyBoss

    -- 第一次遍历
    -- 判断是否需要展示大奖盘(fullPlate)
    -- 填充雷龙鱼(chainFish, chainTrigger)
    -- 找出死亡最高倍率鱼(maxDieFish)
    -- 判断是否需要展示奖金盘(ignorePlate)
    for i = 1, count do
        state = fishState[i * 2]
        key = tostring(fishState[i * 2 - 1])
        local fish = self._fish[key]
        if fish then
            if fish:getPlateType() == PlateType.full then
                fullPlate = true
            end
            if state == FishHitState.die or state == FishHitState.funerary then
                table.insert(chainFish, fish)
                if not chainTrigger and (fish:getType(FishType.lighting) or fish:getType(FishType.lighting_small) or fish:getType(FishType.hyBoss)) then
                    chainTrigger = fish
--                    isHyBoss = fish:getType() == FishType.hyBoss
                end
                if not maxDieFish or maxDieFish:getTimesArea() < fish:getTimesArea() then
                    maxDieFish = fish
                end
                if not ignorePlate and fish:getType(FishType.bomb) then
                    ignorePlate = true
                end
            end
        end
    end

    -- 雷龙
    if chainTrigger and #chainFish > 0 then
        self:displayRayChain(chainTrigger, chainFish, chainTrigger:getType())
    end

    -- 第二次遍历 刷新鱼的状态
    for i = 1, count do
        state = fishState[i * 2]
        key = tostring(fishState[i * 2 - 1])
        local fish = self._fish[key]
        if fish then
            silent = maxDieFish and maxDieFish.fish_uid ~= fish.fish_uid
            self:updateFish(idx, key, state, resDic[key], cannonId, silent, ignorePlate, cards_list, card_type, fish_multiple, getCoin, getEnergy, dial_list, petData, bigSpecial_fish, shoot_uid, dropList, buffList[key])
        end
    end

    -- 全屏大奖盘（中央）
    if getCoin > 0 and fullPlate and idx == Game.fishDB:getMyIndex() then
        self:displayFullPlate(true, getCoin, nil, ENUM.ITEM_ID.COIN)
    end

    return getCoin
end

--[[
刷新鱼的数据
@param idx          number      归属玩家索引
@param key          string      鱼的key
@param state        number      鱼的击杀状态
@param resLst       table       击杀获得
@param cannonId     number      炮ID
@param silent       boolean     不播死亡音效
@param ignorePlate  boolean     忽略奖金盘展示
@param fish_multiple number     拉拔机新数据
@param getEnergy     number     魔晶数据
@param dial_list     table      炸弹章鱼数据
@param petData       table      宠物数据
@param lastSpecial_fish number  宠物击杀特殊鱼
@param shoot_uid   number       子弹uid
@param dropList    list        掉落列表
@param buffList     table       物品加成
]]
function M:updateFish(idx, key, state, resLst, cannonId, silent, ignorePlate, cards_list, card_type, fishMultiple, getCoin, getEnergy, dial_list, petData, bigSpecial_fish, shoot_uid, dropList, buffList)
    local fish = self._fish[key]
    if not fish then return end
	local pos = fish:getPosition()
	local costId = Game.fishDB:getCostItemId()
    local awardItems = {}
    local specialItems = {}
    if resLst then
        local callfuncs = {}
        local dieEff
        if petData then
            getCoin = petData[ENUM.ITEM_ID.COIN] and petData[ENUM.ITEM_ID.COIN].num or 0
            getEnergy = petData[ENUM.ITEM_ID.JADE] and petData[ENUM.ITEM_ID.JADE].num or 0
        end
        local fInfo = {
            times = fish:getTimesArea(),
            dieName = fish:getDieSpine(),
            fishType = fish:getType(),
            bossPlate = table.newclone(fish.bossPlate),
            fish_id = fish.fish_id,
            fish_ratio = fish.fish_ratio,
            fish_multiple = fishMultiple,  -- 新倍率 拉霸机
            fish_bigCoin = getCoin,
            fish_bigJADE = getEnergy,
            dieDuration = fish:getDieDuration(),
        }
        
        for i = 1, #resLst do
            local gtid = resLst[i].gtid or resLst[i].tool_id
            local num = resLst[i].num or resLst[i].tool_num
            self._eneryNum = num -- 统称
            if gtid == costId or gtid == ENUM.ITEM_ID.ENERGY or gtid == ENUM.ITEM_ID.SCORE then
                -- 掉落(类)金币展示
                if num > 0 and Game.fishDB:checkCurrencyDisplay(gtid) then
                    if self:isShowFlyCoinNumber(gtid,fInfo) then
                        self:flyCoinNumer(pos, idx, num, fInfo.dieDuration)
                        if not dieEff then
                            if not ignorePlate then
                                ignorePlate = (fish:getPlateType() ~= PlateType.normal)
                            end
                            -- 特殊BOSS不展示获得金币彩圈
                            if not ignorePlate then
                                ignorePlate = not Assist.isEmpty(fish.bossPlate.plate)
                            end
                            -- 掉落魔晶和积分不展示彩圈
                            if not ignorePlate then
                                ignorePlate = gtid == ENUM.ITEM_ID.ENERGY
                            end
                            -- 拉霸机先展示倍率
                            if not Assist.isEmpty(fish.bossPlate.plate) and BYFishConfig.show_laba(fish.fish_id) == 1 then
                                callfuncs[#callfuncs+1] = function()
                                    self:displayGetCoin(pos, idx, num, cannonId, fInfo, ignorePlate)
                                end
                            else
                                self:displayGetCoin(pos, idx, num, cannonId, fInfo, ignorePlate)
                            end
                            dieEff = true
                        end
                    end
                    -- 拉霸机先展示倍率
                    if not Assist.isEmpty(fish.bossPlate.plate) and BYFishConfig.show_laba(fish.fish_id) == 1 then
                        callfuncs[#callfuncs+1] = function()
                            if not self:isDropItem(fish:getType()) and FishType.bombFish ~= fish:getType() then
                                self._player[idx]:getCoin(num, fInfo.times, pos, gtid)
                            end
                        end
                    else
                        if not self:isDropItem(fish:getType()) and FishType.bombFish ~= fish:getType() then
                            self:performWithDelay(function()
                                self._player[idx]:getCoin(num, fInfo.times, pos, gtid)
                            end, fInfo.dieDuration)
                        end
                    end
                end
            elseif gtid == ENUM.ITEM_ID.RED_ENVELOP or gtid == ENUM.ITEM_ID.RED_PACK then
                -- 红包掉落
                if not Assist.isEmpty(self._layerBossEff) then 
                    local temp = self._layerTemp:getWidget("panel_envelop")
                    self._layerBossEff:showItemDrop(idx, temp, num, pos, gtid, true)
                end
                if gtid == ENUM.ITEM_ID.RED_PACK and self._player[idx]:isMySelf() then
                    self:displayAwardsNum({gtid=gtid, num=num}, cc.pAdd(pos, cc.p(0, -5)), 1)
                end
            elseif ItemsConfig.special_drop(gtid) == 1 then
                table.insert(specialItems,resLst[i])
            else
                -- 掉落物品展示
                table.insert(awardItems, resLst[i])
            end
        end

        local function _awards_(isShowBigCoin)
            if self:isDropItem(fish:getType()) then return end -- 海妖场走自己的掉落
            for _, f in ipairs(callfuncs) do
                f()
            end
            if #awardItems > 0 then
                self:displayAwards(idx, awardItems, pos.x, pos.y, nil, nil, nil, not self._player[idx]:isMySelf())
            end
            if (fInfo.fish_bigCoin or fInfo.fish_bigJADE) and (fInfo.fish_bigCoin > 0 or fInfo.fish_bigJADE > 0) and (not isShowBigCoin or petData) and self._player[idx]:isMySelf()then
                self:performWithDelay(function() 
                    if fInfo.fish_bigJADE and fInfo.fish_bigJADE > 0 then
                        self:displayFullPlate(true, fInfo.fish_bigJADE, 0, ENUM.ITEM_ID.JADE)
                    else
                        self:displayFullPlate(true, fInfo.fish_bigCoin, 0, ENUM.ITEM_ID.COIN)
                    end
                end, petData and 1.5 or 0)
            end
        end

        -- 展示Boss大奖盘及击杀奖励
        if not Assist.isEmpty(fish.bossPlate.plate) and
                not self._layerBossEff:checkBossEvent(fish:getType()) and -- 特殊boss不通过这里展示boss彩金盘
                (self:checkIsPetHitBigSpec(fInfo.fish_id, bigSpecial_fish) or petData) then
            if BYFishConfig.show_laba(fInfo.fish_id) == 1 then
                self._player[idx]:setBossPlateVisible(true, fInfo.bossPlate, function()
                    self._player[idx]:showLapa(fInfo.fish_multiple, _awards_)
                end)
            else
                _awards_(true)
                self._player[idx]:setBossPlateVisible(fInfo.bossPlate.plate ~= "" and true or false, fInfo.bossPlate)
            end
        else
            _awards_(true)
        end
    end

    fish:setStateIdx(state, silent, idx==Game.fishDB:getMyIndex())

    -- 死亡移除
    if state == FishHitState.die or state == FishHitState.funerary then
        if fish:isAlive() and fish:getType(FishType.bomb) then
            self:displayBomb()
        end
		if card_type > 0 and self:checkIsPetHitBigSpec(fish.fish_id, bigSpecial_fish) then
			self._layerBossEff:bossPlayEffCtor(fish:getType(), idx, pos, cards_list, card_type, {resLst, costId, {specialItems,buffList}})
		end
		-- 船长弹头掉落流程优化
		local player = self._player[idx]
		if fish:getType() == FishType.bullet and player:isMySelf() then
			local isWin = false
			for _,v in ipairs(resLst) do
				if (v.gtid or v.tool_id) >= ENUM.ITEM_ID.MISSILE1 and (v.gtid or v.tool_id) <= ENUM.ITEM_ID.MISSILE4 then
					isWin = true
					break
				end
			end
			if not isWin then
				self:displayFullPlate(true, getCoin, nil, ENUM.ITEM_ID.COIN)
			end
			local bulletData = Game.fishDB:getBullet(shoot_uid)
            local cannonId1 = bulletData and bulletData.cannon_id or player:getCannonId()
            self._bossDieTime = Timer:getCurTimeStamp()
			self:showBossRecordShare(RoomEventId.bugle, cannonId1, fishMultiple, dropList and dropList[1] or resLst, 5.5)
		end
		-- 海妖boss
		if self:isDropItem(fish:getType()) and fish:getType() == FishType.hyBoss and self:checkIsPetHitBigSpec(fish.fish_id, bigSpecial_fish) then
			local bulletData = Game.fishDB:getBullet(shoot_uid)
			local cannonId1 = bulletData and bulletData.cannon_id or player:getCannonId()
            self._bossDieTime = Timer:getCurTimeStamp()
			self._layerBossEff:bossPlayEffCtor(fish:getType(), idx, pos, fishMultiple, fish:getTimesArea(), { awardItems, resLst, cannonId1, dropList}, fish.bossPlate, function(energyData, callbacks)
				self:displayAwards(idx, energyData, pos.x, pos.y, nil, true, 2.5, true)
                self:displayAwards(idx, awardItems, pos.x, pos.y, callbacks ,false, 2.5, true)
			end)
		end
		-- 魔晶boss
        if dial_list and #dial_list > 0 and self:checkIsPetHitBigSpec(fish.fish_id, bigSpecial_fish) then
			self._layerBossEff:bossPlayEffCtor(fish:getType(), idx, pos, self._eneryNum, fish:getTimesArea(), {dial_list, getEnergy})
        end
        -- 宝藏鱼
        if fish:getType() == FishType.treasureFish then
            self._layerBossEff:bossPlayEffCtor(fish:getType(),idx,fish.bossPlate)
        end
        -- 摇钱树
        if fish:getType() == FishType.moneyTree then
            self._layerBossEff:bossPlayEffCtor(fish:getType(),idx,fish.bossPlate,fish:getTimesArea(),pos)
        end
        -- 魔王
        if fish:getType() == FishType.devilKing then
            self._layerBossEff:bossPlayEffCtor(fish:getType(),idx,fish.bossPlate)
        end
		-- 地狱男爵
        if fish:getType() == FishType.dynjBoss and self:checkIsPetHitBigSpec(fish.fish_id, bigSpecial_fish) then  --地狱男爵
            self._bossDieTime = Timer:getCurTimeStamp()
			local bulletData = Game.fishDB:getBullet(shoot_uid)
            local cannonId1 = bulletData and bulletData.cannon_id or player:getCannonId()
            self._layerBossEff:bossPlayEffCtor(fish:getType(), idx, pos, self._eneryNum, fish:getTimesArea(), fish.bossPlate,
				function()
					if not Assist.isEmpty(self._layerBossPlay) then
						self._layerBossPlay:startBurstPropTime(pos)
					end
				end,
				function() 
					self:displayFullPlate(true, getEnergy, nil, ENUM.ITEM_ID.JADE)
					local dropList1 = dropList and dropList[1] or { [1]= { gtid = ENUM.ITEM_ID.JADE, tool_num = getEnergy}}
                    local eventId = fish.fish_id == 200 and RoomEventId.dntg or RoomEventId.wljy
					self:showBossRecordShare(eventId, cannonId1, fishMultiple, dropList1 or {}, 4)
				end
			)
        end
        if fish:getDieDuration() == 0 then
            self:removeFish(key)
        end
    end
end

--[[
boss战绩分享
@param eventId 	number 事件id
@param cannonId number 炮倍等级
@param bet      number 鱼的倍数
@param rewardList table 奖励列表
]]
function M:showBossRecordShare(eventId, cannonId, bet, rewardList, time)
	if AppName == "zgame" then  -- 追龙去掉boss战绩分享
		return
	end
	self:performWithDelay(function()
		require_ex("games.fish.views.FBossRecordShare").new({eventId = eventId, cannonId = cannonId, bet = bet, rewardList = rewardList, bossDieTime = self._bossDieTime}):addToScene() 
	end, time or 0.5)
end

--[[
检测是否是宠物击杀的特殊最大倍率的鱼
]]
function M:checkIsPetHitBigSpec(fid, bigSpecial_fish)
    return not bigSpecial_fish or fid == bigSpecial_fish
end

--[[
是否掉落物品
海妖漩涡走自己的掉落物品
]]
function M:isDropItem(fishType)
    if fishType == FishType.hyBoss or fishType == FishType.dynjBoss then
        return true
    end
    return false
end

function M:isShowFlyCoinNumber(gtid,fishInfo)
    if gtid == ENUM.ITEM_ID.ENERGY and not Game.fishDB:isHuntRoom() then
        -- 不是海魔场不展示魔晶数量
        return false
    end
    if gtid == ENUM.ITEM_ID.COIN and (fishInfo.fishType == FishType.flopPoke or fishInfo.fishType == FishType.lapa) then
        -- 翻牌鱼,拉霸鱼不显示金币数量
        return false
    end
    -- 魔晶boss
    if FishType.bombFish == fishInfo.fishType or FishType.dynjBoss == fishInfo.fishType then
        return false
    end
    return true
end

function M:removeFish(uid, retainData)
    local key = tostring(uid)
    local fish = self._fish[key]
    if fish then
		if fish.fish_id == FishSpe.dynj or fish.fish_id == FishSpe.dynj1 then
			self._wlfxBoss = fish
		end
        Game.fishMng:removeFish(fish)
        if not retainData then
            Game.fishDB:removeFish(uid)
        end
        self._fish[key] = nil
        self._fishCount = self._fishCount - 1
    end
    return fish
end

function M:clearFish(ramainData, hideState, force)
	self:updateFrozenShow(false)
    for k, f in pairs(self._fish) do
        if force or f.clearEnable then
            if hideState then
                if hideState == FishState.escape and (f:getFrozen() or f:faintTimes()>0) then
                    hideState = FishState.idle
                end
                f:changeState(hideState)
            end
            if not hideState or hideState == FishState.idle or hideState == FishState.die then
                self:removeFish(k, ramainData)
            end
        end
    end
end

function M:getFish(uid)
    return self._fish[tostring(uid)]
end

function M:getFishCount()
    return self._fishCount
end

--------------------------------------------------
-- 子弹
function M:initBulletList()
    local bullets = Game.fishDB:getBulletList()
    for _, b in ipairs(bullets) do
        self:addBullet(b, nil, true)
    end
end

function M:addBullet(b, bPlaySound, forInit)
    local key = tostring(b.shoot_uid)
    if not self._bullet[key] then
        local pInfo = Game.fishDB:getPlayer()
        if pInfo and pInfo.pos > Game.fishDB.PMIRROR then
            b.pos_x = CC_DESIGN_RESOLUTION.width - b.pos_x
            b.pos_y = CC_DESIGN_RESOLUTION.height - b.pos_y
            if b.angle then
                b.angle = b.angle + math.pi
            end
        end
        if not forInit then
            b.ignoreSynch = true
        end

        if checknumber(b.fish_uid) > 0 then
            b.targetFish = self._fish[tostring(b.fish_uid)]
        else
            b.targetFish = nil
        end

        self._bullet[key] = Game.fishMng:createBullet(self, b)

        if bPlaySound then
            if b.skin == ENUM.RAGE_SKIN_ID then
                Audio.playSoundConfig(self, "FIRE", "KuangBao")
            else
                Audio.playSoundConfig(self, "FIRE")
            end
        end
    end
end

function M:getBullet(uid)
    return self._bullet[tostring(uid)]
end

function M:removeBullet(uid, bomb, flyArgs)
    local key = tostring(uid)
    local bullet = self._bullet[key]
    if bullet then
        bullet:doBomb(bomb, flyArgs)
        Game.fishMng:removeBullet(bullet)
    end
    self._bullet[key] = nil
end

function M:clearBullet()
    for k, _ in pairs(self._bullet) do
        self:removeBullet(k, false)
    end
end

--[[
是否正在使用弹头
]]
function M:isUsingBomb()
    return self._layerTip:isBombing()
end

--[[
核弹头
]]
function M:addBombBullet(icon, x, y, angle, spineRes)
    local tempNode = self._layerTemp:getWidget("panel_bomb")
    local node_bomb = tempNode:clone()
    self._widgets.panel_bullet:addChild(node_bomb, 10000)

    local img_bomb = node_bomb:getChildByName("bombPic")
    local node_spine = node_bomb:getChildByName("effect")

    fitIconSize(img_bomb, icon, 1)

    local actor = Actor:new(spineRes.res, spineRes)
    node_spine:addChild(actor, 1000000)
    actor:setRotation(45)
    node_bomb:setPosition(x, y)
    node_bomb:setRotation((angle + 45) % 360)
    node_bomb:setVisible(true)

    return node_bomb
end

--[[
宠物攻击
]]
function M:addPetBullet(pos, angle, SpinePetAtt)
	local actor = Actor:new(SpinePetAtt.res, SpinePetAtt)
	self._widgets.panel_bullet:addChild(actor, 10000)
	actor:setPosition(pos)
	return actor
end

--------------------------------------------------
-- 技能相关
function M:onLockSkillChange(uid, first)
    if not first then return end
    local pInfo = Game.fishDB:getPlayer(uid)
    local player = self:getPlayerById(uid)
    if not player then return end
    player:showSkillEffect(FSkill.lock, pInfo.lock)
    if pInfo.lock and uid == self._myUid then
        local lastFishUid = player:getLastTargetFishUid()
        local lastFish = self._fish[tostring(lastFishUid)]
        if lastFish and not lastFish:hitEnable() then
            lastFish = nil
        end

        if not lastFish then
            player:setTargetFish(self:searchTargetFish(), true)
        else
            player:setTargetFish(lastFish)
        end
    end
end

function M:onRageSkillChange(uid)
    local pInfo = Game.fishDB:getPlayer(uid)
    local player = self:getPlayerById(uid)
    if not player then return end
    player:showSkillEffect(FSkill.rage, pInfo.frency)
    if pInfo.frency and uid == self._myUid then
        local lastFishUid = player:getLastTargetFishUid()
        local lastFish = self._fish[tostring(lastFishUid)]
        if lastFish and not lastFish:hitEnable() then
            lastFish = nil
        end
        if not lastFish then
            player:setTargetFish(self:searchTargetFish(), true)
        else
            player:setTargetFish(lastFish)
        end
    end
end

-------------------------------------------------------
-- 深海夺宝
function M:showTreasure(data, ignoreStart, waiting)
    Log.I("showTreasure", _TAG)
    if self._layerWarning then
        self._layerWarning:hide()
    end
    if not Assist.isEmpty(self._layerTreas) then
        self._layerTreas:removeSelf()
        self._layerTreas = nil
    end
    self._layerTreas = require_ex("games.fish.views.hunt.FTreasure").new(data, not ignoreStart, waiting)
    self._rootNode:addChild(self._layerTreas, ENUM.UI_Z.TIP)
end

function M:onTreasureStart()
    Log.I("onTreasureStart", _TAG)
    self:showTreasure()
    -- self:updateTaskFish()
end

function M:onTreasureTaskChange()
    Log.I("onTreasureTaskChange", _TAG)
    local task = Game.fishDB:getTaskData()
    if task and not Assist.isEmpty(task.reward_list) then
        if Game.fishDB:isInTask() then
            for _, p in ipairs(task.reward_list) do
                self:onTreasureRankChange(p)
                if p.pid == self._myUid and Assist.isEmpty(self._layerTreas) then
                    self:showTreasure(task, true)
                end
            end
        else
            self:showTreasure(task, true, true)
        end
    end
end

function M:onTreasureRankChange(data)
    if data then
        local player = self:getPlayerById(data.pid)
        if player then
            local tempNode = self._layerTemp:getWidget("img_taskRank")
            player:updateTreasRank(tempNode, data.rank)
        end
    end
end

function M:onTreasureResult(event)
    for _,p in pairs(self._player) do
        if p then
            p:removeTreasRank()
            p:removeTreasTop()
        end
    end
    local data = event.data
    if data then
        local player = self:getPlayerById(data.pid)
        local tempNode = self._layerTemp:getWidget("panel_taskTop")
        if player and tempNode then
            player:showTreasTop(tempNode)
        end
    end
    if not Assist.isEmpty(self._layerTreas) then
        self._layerTreas:performWithDelay(function()
            self._layerTreas:removeSelf()
            self._layerTreas = nil
        end, 10)
    end
    -- self:updateTaskFish()
end

function M:onMatchTaskStart(event)
   if not Assist.isEmpty(self._layerMatchTask) then
        self._layerMatchTask:removeSelf()
		self._layerMatchTask = nil
    end
    self._layerMatchTask = require_ex("games.fish.views.match.FMatchTask").new(event.data)
    self._layerMatchTask:addCloseCallback(function()
        self._layerMatchTask = nil
    end)
    if not Assist.isEmpty(self._layerMatch) and self._layerMatch.getScorePos then
        self._layerMatchTask:setEffectToPos(self._layerMatch:getScorePos())
    end
    self._layerMatchTask:setShowCallback(function()
        Game.fishDB:setTaskData(event.data)
        self:updateTaskFish()
    end)
    self._rootNode:addChild(self._layerMatchTask,ENUM.UI_Z.TIP)
end

function M:onMatchTaskEnd()
    Game.fishDB:setTaskData()
    self:updateTaskFish()
end

function M:onDevilKingShow(event)
    if Assist.isEmpty(self._layerDevilKing) then
        self._layerDevilKing = require_ex("games.fish.views.devilKing.DevilKingTop").new(event.data):addTo(self._rootNode,ENUM.UI_Z.TIP)
    end
end

---------------------------------------------
-- boss玩法
function M:onBugleStart(event)
    Log.I("onBugleStart", _TAG)
    if not BYEventConfig or not BYEventConfig[event.data.event_id] then return end
    self:onBossPlayEvent(event.data.event_id, event)
    if self:isUsingBomb() then
        self._layerUI:onSkillBombCancel()
    end
end

--[[
boss玩法结束
]]
function M:onBugleResult(event)
    Log.I("onBugleResult", _TAG)
    if event.data.event_id ~= RoomEventId.wljy or event.data.player_id == 0 then
        local dur = BYEventConfig.event_cd(event.data.event_id) + 2
        self._layerUI:startTimer({"btn_bugle"}, dur) 
    end
    if not Assist.isEmpty(self._layerBossPlay) then
        local killer = 0
        if event.data.player_id ~= 0 then
            killer = event.data.player_id == Game.fishDB._myUid and 1 or 2
        end
        local dropTime = BYEventConfig.drop_time(event.data.event_id)
        self._layerBossPlay:complete(killer, dropTime, function()
            self._layerBossPlay = nil
        end)
    end
    -- 场内所有鱼快速游走
    self:clearFish(false, FishState.idle, false)
end

--[[
boss玩法开始
]]
function M:onBossPlayEvent(eventId, event)
    self:startBossPlay(eventId, event.data.expire or 300)
    if Number.abs(event.data.create-Timer:getCurTimeStamp()) < 5 then
        local seq = {
            cc.DelayTime:create(2),
            cc.CallFunc:create(function()
                if not self:isEntering() then
                    if eventId == RoomEventId.bugle then
                        -- 全民，追龙不走这一步
                        if AppName == "xgame" then
                            self._layerWarning:captainWarning()  
                        end
    				elseif eventId == RoomEventId.wljy then
    					self._layerWarning:captainHYWarning()
                    end
					-- 场内所有鱼快速游走
					self:clearFish(false, FishState.idle)
				else
					self:performWithDelay(function ()
						self:clearFish(false, FishState.idle)
					end, 2)
                end
            end),
            cc.DelayTime:create(2),
            cc.CallFunc:create(function()
                if self._layerBossPlay then
                    self._layerBossPlay:moveIn()
                end
            end)
        }
        self:runAction(transition.sequence(seq))
    else
        self._layerBossPlay:moveIn()
    end
	local player = self:getPlayerById(self._myUid)
    if self:isUsingBomb() or player:getBombId() > 0 then
        self._layerUI:onSkillBombCancel()
    end
end

function M:startBossPlay(eventId, time)
    if not Assist.isEmpty(self._layerBossPlay) then
        self._layerBossPlay:removeSelf()
        self._layerBossPlay = nil
    end

    self._layerBossPlay = require_ex(self._bossPlayModuleList[eventId]).new(time)
    self._rootNode:addChild(self._layerBossPlay, ENUM.UI_Z.TIP)
end

--------------------------------------------------
-- 花色兑换
function M:showSuit(show)
    if show and not self._layerSuit then
        self._layerSuit = require_ex("games.fish.views.pond.FSuitTaskUI").new(function()
			self._layerGuide:showGameGuide("suit")
		end)
        self._rootNode:addChild(self._layerSuit,ENUM.UI_Z.TIP)
    elseif not show and self._layerSuit then
        self._layerSuit:removeFromParent()
        self._layerSuit = nil
    end
end

-- 水手赏赐
function M:showSailor(show)
    if show and not self._layerSailor then
        self._layerSailor = require_ex("games.fish.views.sailor.FSailorTaskUI").new()
        self._rootNode:addChild(self._layerSailor,ENUM.UI_Z.TIP)
    elseif not show and self._layerSailor then
        self._layerSailor:removeFromParent()
        self._layerSailor = nil
    end
end

--------------------------------------------------
-- 钻头鱼
function M:onDrillStart(event)
    local info = event.data
    if not info then return end

    local player = self:getPlayerById(info.uid)
    if player:isDrilling() then
        player:resetDrilling()
        if player:isMySelf() then
            -- 清弹头状态
            if self:isUsingBomb() or player:getBombId() > 0 then
                self._layerUI:onSkillBombCancel()
                self._layerTip:setBombVisible(false)
            end
            -- 清狂暴状态
            -- Game.fishDB:setFrencyPause(false)
			Game.fishDB:setFrencyBet(1)
            self._layerUI:setFrencySkillType(true)
            self._layerSkill:instanceView()
            -- 清锁定状态
            self._layerTip:setLockVisible(false)
        end
        -- 展示钻头状态
        self._layerTip:setDrillStep(1, player, info.time, function()
            player:onFire(nil, nil, true, true)
            player:setCannonVisible(false)
            self._layerTip:setDrillStep(2)
        end)
    else
        self._layerTip:setDrillStep(0)
    end
end

function M:onDrillFire(event)
    local info = event.data
    if not info or info.uid == self._myUid then return end

    local player = self:getPlayerById(info.uid) 
    if player then
        if info.shoot_id then
            player:setDrillBullet(info.shoot_id)
        end
        player:setCannonVisible(false)
        self._layerTip:setDrillStep(2)
    end
end

function M:onDrillBomb(event)
    local info = event.data
    if not info then return end

    local player = self:getPlayerById(info.uid) 
    if player then
        local bid = info.shoot_id or player:getDrillBullet()
        if bid and self._bullet[tostring(bid)] then
            local x, y = player:getHeadCenterPosition()
            local corrX, corrY = Assist.adapterCoord(x, y)
            --local tempNode = self._layerTemp:getWidget(self._flyCoinKey)
            --local dieName = BYFishConfig.die_sp_spin(info.fish_id or FishSpe.drill)
            local args = {
                x = corrX,
                y = corrY,
                callback = function()
                    self._layerTip:setDrillStep(0)
                    if player:isMySelf() then
                        Game.fishCom:onDrillDie()
                    end
                end
            }
            self:removeBullet(bid, true, args)
        end
        Game.fishDB:removeBullet(bid)
    end
end

function M:onDrillFinish(event)
    local info = event.data
    if not info then return end

    local player = self:getPlayerById(info.uid) 
    if player then
        --local x, y = player:getHeadCenterPosition()
        --local corrX, corrY = Assist.adapterCoord(x, y)
        local tempNode = self._layerTemp:getWidget(self._flyCoinKey)
        local dieName = BYFishConfig.die_sp_spin(info.fish_id or FishSpe.drill)
        player:setPlateVisible(true, tempNode, info.coin, dieName)
        player:resetDrilling()
    end
end

--------------------------------------------------
-- 特殊掉落
function M:onShowSpecialDrop(id,show)
    if type(id) == "table" then
        id = id.data
    end
    if type(show) ~= "boolean" then
        show = true
    end
    if id == SpecialDropType.suit then
        self:showSuit(show)
    elseif id == SpecialDropType.bottle then
        self:showSailor(show)
    end
end

function M:onHideSpecialDrop(id)
    self:onShowSpecialDrop(id,false)
end

-- 切换不同房间需要清掉顶部任务
function M:onChangeClearTask(event)
    local isClearTask = event.data[1]
    if isClearTask and not Assist.isEmpty(self._layerBossPlay) then
        self._layerBossPlay:removeFromParent()
        self._layerBossPlay = nil
    end
end

--------------------------------------------------
-- 后端调试数据
function M:addDebugLabel()
    local widget = ccui.Text:create()
    widget:setFontSize(20)
    widget:setColor(cc.c3b(255, 0, 0))
    widget:setAnchorPoint(cc.p(0, 1))
    widget:setPosition(10, display.height - 10)
    self:addChild(widget, 10)
    self._debugLabel = widget
    self:updateDebugData()
end

function M:updateDebugData()
    if not self._debugLabel then return end

    local fishInfo = Game.fishDB:getDebugData()
    local showStr = ""
    local showTab, newline = {showStr}, "\n"
    if #fishInfo > 0 then
        for _, info in ipairs(fishInfo) do
            for _, v in ipairs(info) do
                showTab[#showTab+1] = string.format("%s:%s", v.key, v.val)
            end
            showTab[#showTab+1] = newline
        end
        showStr = table.concat(showTab, newline)
    end

    self._debugLabel:setString(showStr)
end

--------------------------------------------------
-- 快捷测试
function M:addRapidTestBtn()
    if Game.hallUI then
        local btn = Game.hallUI:getWidget("btn_gm")
        if btn then
            local btnRapidTest = btn:clone()
            local t = "G"
            if device.platform == "windows" and SHOW_FISH_RAPID then
                t = "T"
            end
            btnRapidTest:setTitleString(t)
            btnRapidTest:setPosition(display.width-24, 24)
            bindClickFunc(btnRapidTest, handler(self, self.rapidTest))
            self:addChild(btnRapidTest, 10)
        end
    end
end

function M:rapidTest()
    if device.platform == "windows" and SHOW_FISH_RAPID then
        -- 兑换
        -- Game:doPluginAPI("guide", "exchange")
        -- 全屏彩金盘
        -- self:displayFullPlate(true, 10000)
        -- 延迟卡顿
        -- Game:dispatchCustomEvent(GEvent("NET_HB_CHECK"), {latency=Number.random(-5,5)})
        -- 背景切换
        -- Game.fishDB:setRoomBg(Number.random(1, BG_MAX))
        -- self:onFishTideCallback()
        -- 屏幕旋转
        -- DEBUG_LANDSCAPELEFT = not DEBUG_LANDSCAPELEFT
        -- self._layerUI:onUIOrientionChange()
        -- 海妖结算
        -- local list = {}
        -- for i=1,80 do
        --     list[i] = {id=20010004, num=1}
        -- end
        -- self._layerHaiyaoResult:showResult(list, {}, 0, 0, cc.p(CC_DESIGN_RESOLUTION.cx,CC_DESIGN_RESOLUTION.cy), 9876, 1)
        -- 钻头鱼打死
        -- local idx = Game.fishDB:getMyIndex()
        -- local player = self._player[idx]
        -- self._layerTip:setDrillStep(1, player, function()
        --     player:onFire(nil, nil, true, true)
        --     player:setCannonVisible(false)
        --     self._layerTip:setDrillStep(2)
        -- end)
        -- 钻头鱼结算
        -- local info = {
        --     uid = self._myUid,
        --     coin_num = 80900,
        -- }
        -- self:onDrillBomb({data = info})
    else
        Game:openGMView()
    end
end

return M
