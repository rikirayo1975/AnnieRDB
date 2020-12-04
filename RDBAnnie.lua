--[[
Code by: rikirayo
Version: 1.0.2
Published: 28/11/2020
]]

if Player.CharName ~= "Annie" then return end
require("common.log")
module("annieRDB2", package.seeall, log.setup)
local TickCount = 0
local _SDK = _G.CoreEx
local SpellLib = Libs.Spell
local insert, sort = table.insert, table.sort
local Console, ObjManager, EventManager, Geometry, Input, Renderer, Enums, Game = _SDK.Console, _SDK.ObjectManager, _SDK.EventManager, _SDK.Geometry, _SDK.Input, _SDK.Renderer, _SDK.Enums, _SDK.Game
local Menu, Orbwalker, Collision, Prediction, HealthPred = _G.Libs.NewMenu, _G.Libs.Orbwalker, _G.Libs.CollisionLib, _G.Libs.Prediction, _G.Libs.HealthPred
local DmgLib, ImmobileLib, Spell = _G.Libs.DamageLib, _G.Libs.ImmobileLib, _G.Libs.Spell
local TS = _G.Libs.TargetSelector()
local SpellSlots, SpellStates = Enums.SpellSlots, Enums.SpellStates
local Annie = {}
local passive = 0
local spells = {
	Q = Spell.Targeted({
		Slot = SpellSlots.Q,
		Range = 625
	}),
    W = Spell.Skillshot({
        Slot = SpellSlots.W,
        Range = 600,
        Angle = 49.52,
        Delay = 0.25,
        Type = "Linear"
    }),
    E = Spell.Targeted({
        Slot = SpellSlots.E,
        Range = 800
    }),
    R = Spell.Skillshot({
        Slot = SpellSlots.R,
        Range = 600,
        Radius = 250,
        Delay = 0.25,
        Type = "Circular"
    })
}   
local function Game_ON()
	--juego activo, no muerto, etc.
	return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end
function Annie.OnDraw()
    local PP = Player.Position
    if Menu.Get("DQ")then
        Renderer.DrawCircle3D(PP,spells.Q.Range,30,2,0x0099FFFF)
    end
    if Menu.Get("DW") then
        Renderer.DrawCircle3D(PP,spells.W.Range,30,2,0x0099FFFF)
    end
    if Menu.Get("DE") then
        Renderer.DrawCircle3D(PP,spells.E.Range,30,2,0x0099FFFF)
    end
    if Menu.Get("DR") then
        Renderer.DrawCircle3D(PP,spells.R.Range,30,2,0x0099FFFF)
    end
end

function Annie.OnGapclose(source,dash)
    if not (source.IsEnemy and Menu.Get("GE") and spells.E:IsReady()) then return end
    local paths = dash:GetPaths()
    local endPos = paths[#paths].EndPos
    if source:Distance(Player) < 400 then
        spells.E:Cast(Player)
    end
end

	--Calculo el daño de la Q
function Annie.QRawDamage()
	-- 80 / 115 / 150 / 185 / 220 (+ 80% PH)
	return (35*spells.Q:GetLevel()+45)+(Player.TotalAP * 0.8)
end
function Annie.WRawDamage()
    -- 70 / 115 / 160 / 205 / 250 (+ 85% PH)
    return (45*spells.W:GetLevel()+25)+(Player.TotalAP * 0.85)
end
function Annie.RRawDamage()
    -- 150 / 275 / 400 (+ 75% PH)
    return (125*spells.R:GetLevel()+25)+(Player.TotalAP* 0.75)
end
function Annie.BurstDamage()
    local QDmg = Annie.QRawDamage()
    local WDmg= Annie.WRawDamage()
    local RDmg= Annie.RRawDamage()
    return QDmg + WDmg + RDmg
end
function Annie.OnTick()
    	--comprobamos que el juego este activo
    	if not Game_ON() then return end
    	--comprobamos que el Orbwalker funcione
    	if not Orbwalker.CanCast() then return end
    	--ejecutamos el orbwalker que toca
	local ModeToExecute = Annie[Orbwalker.GetMode()]
    if Player:GetBuff("anniepassivestack") then
        local ppassive = Player:GetBuff("anniepassivestack")
        passive = ppassive.Count
    else 
        if Player:GetBuff("anniepassiveprimed") then
           passive = 4
        else
            passive = 0
        end
    end


    if ModeToExecute then
        ModeToExecute()
    end
    if Annie.auto() then return end
end

function Annie.auto()
    if Menu.Get("Burst") then
        local RawBurst = Annie.BurstDamage()
        for k,target in ipairs(Annie.GetTargets(600)) do
            local Burst = DmgLib.CalculateMagicalDamage(Player, target, RawBurst)
            local health = spells.R:GetKillstealHealth(target)
            if Burst > health then
                if spells.Q:IsReady() and spells.Q:Cast(target) then
                end
                if spells.E:IsReady() and spells.E:Cast(Player) then
                end
                if spells.W:IsReady() and spells.W:Cast(target) then
                end
                if spells.R:IsReady() and spells.R:Cast(target)then
                end
            end
        end
    end
end

function Annie.GetTargets(range)
    return {TS:GetTarget(range, true)}
end     
function Annie.QFarmLogic(minions)
    local rawDmg = Annie.QRawDamage()
    for k, minion in ipairs(minions) do
        local healthPred = spells.Q:GetHealthPred(minion)
        local qDmg = DmgLib.CalculateMagicalDamage(Player, minion, rawDmg)
        if healthPred > 0 and healthPred < qDmg and spells.Q:Cast(minion) then

            return true
        end                       
    end    
end
function Annie.WFarmLogic(minions)
    local count = {}
    local SP
    for k, minion in ipairs(minions) do
        SP = Player.Position:Extended(minion.Position, spells.W.Range)
        local minion = minion.AsAI
        if minion and minion.IsTargetable then
            local predPos = minion:FastPrediction(spells.W.Delay)
            local dist = predPos:Distance(Player.Position)
            if dist < spells.W.Range then 
                count[#count + 1] = predPos
            end                     
        end
    end
    local BP, hcount = Geometry.BestCoveringCircle(count,SP,86)
    if BP and hcount >= 1 then
            return spells.W:Cast(BP)
    end    
end

function Annie.GetMinionsQ(t, team_lbl)
    if Menu.Get("farmQ") then
        for k, v in pairs(ObjManager.Get(team_lbl, "minions")) do
            local minion = v.AsAI
            local minionInRange = minion and minion.MaxHealth > 6 and spells.Q:IsInRange(minion)
            local shouldIgnoreMinion = minion and (Orbwalker.IsLasthitMinion(minion) or Orbwalker.IsIgnoringMinion(minion))
            if minionInRange and not shouldIgnoreMinion and minion.IsTargetable then
                insert(t, minion)
            end                       
        end
    end
end

function Annie.Harass()
    if Menu.Get("HQ") and spells.Q:IsReady() then
        for k, qTarget in ipairs(Annie.GetTargets(spells.Q.Range)) do
        if spells.Q:Cast(qTarget) then
            return
        end
        end
    end
    if Menu.Get("HW") then
        for k,wTarget in ipairs(Annie.GetTargets(spells.W.Range)) do
            if spells.W:Cast(wTarget) then
                return
            end
        end
    end
end

function Annie.Combo()

    Orbwalker.BlockAttack()
    for k, Target in ipairs(Annie.GetTargets(spells.Q.Range)) do
        if Menu.Get("CQ") and spells.Q:IsReady() and spells.Q:Cast(Target) then
        end
        if Menu.Get("CW") and spells.W:IsReady() and spells.W:Cast(Target) then
        end
        if Menu.Get("CR") and spells.R:IsReady() and spells.R:Cast(Target) then
        end
    end
end

function Annie.Waveclear()
    if passive < Menu.Get("WP") then
        local minionsInRange = {}
        do -- Llenar la variable con los minions en rango
           Annie.GetMinionsQ(minionsInRange, "enemy")       
           sort(minionsInRange, function(a, b) return a.MaxHealth > b.MaxHealth end)
        end
        Annie.QFarmLogic(minionsInRange)   
        Annie.WFarmLogic(minionsInRange)
    end
end




function Annie.LoadMenu()
	Menu.RegisterMenu("AnnieRDB2","AnnieRDB2",function ()
		Menu.ColumnLayout("cols", "cols", 4, true, function()
			Menu.ColoredText("WaveClear", 0x0099FFFF, false)
				Menu.Checkbox("farmQ", "Use Q", true)
                Menu.Slider("WP", "Save Passive Charges", 3, 3 ,4, 1) 
				TS = _G.Libs.TargetSelector()

            Menu.NextColumn()
            Menu.ColoredText("Combo", 0X0099FFFF,false)
            Menu.Checkbox("CQ", "Use Q", true)
            Menu.Checkbox("CW", "Use W", true)
            Menu.Checkbox("CR","Use R",true)
            Menu.NextColumn()
            Menu.ColoredText("Harass", 0X0099FFFF,false)
            Menu.Checkbox("HQ", "Use Q", true)
            Menu.Checkbox("HW", "Use W", true)
            Menu.NextColumn()
            Menu.ColoredText("AutoSpells", 0X0099FFFF,false)
            Menu.Checkbox("Burst", "Burst", true)
            Menu.Checkbox("GE","E when gapclose",true)
			end)
        Menu.Separator()
        Menu.ColoredText("Draws", 0X0099FFFF, false)
        Menu.Checkbox("DQ","Q range",true)
        Menu.Checkbox("DW","W range",true)
        Menu.Checkbox("DE","E range",true)
        Menu.Checkbox("DR","R range",true)
	end)
end


function OnLoad()
		Annie.LoadMenu()
    for eventName, eventId in pairs(Enums.Events) do
        if Annie[eventName] then
            EventManager.RegisterCallback(eventId, Annie[eventName])
        end
    end    
    return true
end