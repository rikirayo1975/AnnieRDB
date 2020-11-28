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
local TS
local SpellSlots, SpellStates = Enums.SpellSlots, Enums.SpellStates
local Annie = {}
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
	--Calculo el daño de la Q
function Annie.QRawDamage()
	-- 80 / 115 / 150 / 185 / 220 (+ 80% PH)
	local AnnieQ = {80,115,150,185,220}
	return AnnieQ[spells.Q:GetLevel()]+(Player.TotalAP * 0.8)
end
function Annie.WRawDamage()
    -- 70 / 115 / 160 / 205 / 250 (+ 85% PH)
    local AnnieW = {70,115,160,185,220}
    return AnnieW[spells.W:GetLevel()]+(Player.TotalAP * 0.85)
end
function Annie.RRawDamage()
    -- 150 / 275 / 400 (+ 75% PH)
    local AnnieR = {150,275,400}
    return AnnieR[spells.R:GetLevel()]+(Player.TotalAP* 0.75)
end
function Annie.OnTick()
    	--comprobamos que el juego este activo
    	if not Game_ON() then return end
    	--comprobamos que el Orbwalker funcione
    	if not Orbwalker.CanCast() then return end
    	--ejecutamos el orbwalker que toca
	local ModeToExecute = Annie[Orbwalker.GetMode()]
    if ModeToExecute then
        ModeToExecute()
    end
end
function Annie.GetTargets(range)
    return {TS:GetTarget(range, true)}
end
function Annie.FarmLogic(minions)
    local rawDmg = Annie.QRawDamage()
    for k, minion in ipairs(minions) do
        local healthPred = spells.Q:GetHealthPred(minion)
        local qDmg = DmgLib.CalculateMagicalDamage(Player, minion, rawDmg)
        if healthPred > 0 and healthPred < qDmg and spells.Q:Cast(minion) then

            return true
        end                       
    end    
end
function Annie.GetMinionsQ(t, team_lbl)
    for k, v in pairs(ObjManager.Get(team_lbl, "minions")) do
        local minion = v.AsAI
        local minionInRange = minion and minion.MaxHealth > 6 and spells.Q:IsInRange(minion)
        local shouldIgnoreMinion = minion and (Orbwalker.IsLasthitMinion(minion) or Orbwalker.IsIgnoringMinion(minion))
        if minionInRange and not shouldIgnoreMinion and minion.IsTargetable then
            insert(t, minion)
        end                       
    end
end
function Annie.Harass()
    for k, qTarget in ipairs(Annie.GetTargets(spells.Q.Range)) do
        if spells.Q:Cast(qTarget) then
            return
        end
    end
end
function Annie.Combo()
    Annie.Harass()
    for k,wTarget in ipairs(Annie.GetTargets(spells.W.Range)) do
        if spells.W:CastOnHitChance(wTarget, 0.8) then
            return
        end
    end
    for k,RTarget in ipairs(Annie.GetTargets(spells.R.Range)) do
        if spells.R:CastOnHitChance(RTarget, 0.8) then
            return
        end
    end
end

function Annie.Waveclear()
    local minionsInRange = {}
    do -- Llenar la variable con los minions en rango
       Annie.GetMinionsQ(minionsInRange, "enemy")       
       sort(minionsInRange, function(a, b) return a.MaxHealth > b.MaxHealth end)
    end
    Annie.FarmLogic(minionsInRange)
end
	function Annie.LoadMenu()
		Menu.RegisterMenu("AnnieRDB2","AnnieRDB2",function ()
			Menu.ColumnLayout("cols", "cols", 3, true, function()
				Menu.ColoredText("FarmQ", 0x0099FFFF, false)
   				Menu.Checkbox("FarmQ", "Use", true)
   				TS = _G.Libs.TargetSelector()
   			end)
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