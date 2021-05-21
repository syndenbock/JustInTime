local addonName, shared = ...

-- JustInTime by syndenbock
-- inspired by SafeQueue by Jordon

-- raids can have multiple queues, but you can only receive the queue time for
-- the latest queue, so we store these times for reloads/relogs/dcs

local strsplit = _G.strsplit
local GetTime = _G.GetTime
local GetCVar = _G.GetCVar
local PlaySoundFile = _G.PlaySoundFile
local PVPReadyDialog_Showing = _G.PVPReadyDialog_Showing
local IsInGroup = _G.IsInGroup
local IsInRaid = _G.IsInRaid
local SendChatMessage = _G.SendChatMessage
local GetBattlefieldPortExpiration = _G.GetBattlefieldPortExpiration
local SecondsToTime = _G.SecondsToTime
local GetBattlefieldStatus = _G.GetBattlefieldStatus
local GetBattlefieldTimeWaited = _G.GetBattlefieldTimeWaited
local GetLFGQueuedList = _G.GetLFGQueuedList
local GetLFGQueueStats = _G.GetLFGQueueStats
local GetLFGProposal = _G.GetLFGProposal

local PVPReadyDialog = _G.PVPReadyDialog
local LFGDungeonReadyDialog = _G.LFGDungeonReadyDialog
local DEFAULT_CHAT_FRAME = _G.DEFAULT_CHAT_FRAME

local ADDON_VERSION = _G.GetAddOnMetadata(addonName, 'version')
local UPDATE_INTERVAL = 0.1

local addonFrame = _G.CreateFrame('Frame')
local updateTimeStamp
local pvpQueue
local pvpQueueTimes = {}
local pveQueueTimes = {}
local pveRemaining = 0
local events = {}

local options = {}

PVPReadyDialog.label:SetPoint('TOP', 0, -22)
LFGDungeonReadyDialog.label:SetPoint('TOP', 0, -22)

-- the text of the LFG dialog label randomly changes back, so we override the function to prevent that
local updateLFGDialogLabel = LFGDungeonReadyDialog.label.SetText
LFGDungeonReadyDialog.label.SetText = function () end

--[[
///*****************************************************************************
/// general functions
///*****************************************************************************
--]]

local function printMessage (msg)
  DEFAULT_CHAT_FRAME:AddMessage('|cff33ff99JIT|r: ' .. msg)
end

local function playSound (soundId)
  if (options.forceSound ~= true or
      GetCVar('Sound_EnableSFX') ~= '1') then
    return
  end

  PlaySoundFile(soundId, 'master')
end

local function formatTime (seconds)
  local color

  if (seconds > 20) then
    color = 'ff20ff20'
  elseif (seconds > 10) then
    color = 'ffffff00'
  else
    color = 'ffff0000'
  end

  return '|c' .. color .. SecondsToTime(seconds) .. '|r'
end

local function getClosestQueue (list, target)
  local index, distance

  for key in pairs(list) do
    local dist = math.abs(target - key)

    if (distance == nil or
        dist < distance) then
      index = key
      distance = dist
    end
  end

  return index, distance
end


local function printTime (seconds)
  if (options.announce == 'off') then
    return
  end

  local message = 'Queue popped '

  if (seconds < 1) then
    message = message .. 'instantly!'
  else
    message = message .. 'after ' .. SecondsToTime(seconds)
  end

  if (options.announce == 'self' or
      not IsInGroup()) then
    printMessage(message)
  else
    SendChatMessage(message, (IsInRaid() and 'RAID') or 'PARTY')
  end
end

local function hidePvPButton ()
  PVPReadyDialog.leaveButton:Hide()
  -- PVPReadyDialog.leaveButton.Show = function () end -- prevent other mods from showing the button
  PVPReadyDialog.leaveButton:SetAlpha(0)
  PVPReadyDialog.enterButton:ClearAllPoints()
  PVPReadyDialog.enterButton:SetPoint('BOTTOM', PVPReadyDialog, 'BOTTOM', 0, 25)
end

local function hidePvEButton ()
  LFGDungeonReadyDialog.leaveButton:Hide()
  -- LFGDungeonReadyDialog.leaveButton.Show = function () end -- prevent other mods from showing the button
  LFGDungeonReadyDialog.leaveButton:SetAlpha(0)
  LFGDungeonReadyDialog.enterButton:ClearAllPoints()
  LFGDungeonReadyDialog.enterButton:SetPoint('BOTTOM', LFGDungeonReadyDialog, 'BOTTOM', 0, 25)
end

local function hideButton ()
  hidePvPButton()
  hidePvEButton()
end

local function showPvPButton ()
  local point = {PVPReadyDialog.leaveButton:GetPoint()}

  point[1] = 'BOTTOMRIGHT'
  point[4] = point[4] * (-1)

  PVPReadyDialog.leaveButton:Show()
  -- PVPReadyDialog.leaveButton.Show = function () end -- prevent other mods from showing the button
  PVPReadyDialog.leaveButton:SetAlpha(1)
  -- PVPReadyDialogEnterBattleButton:ClearAllPoints()
  -- PVPReadyDialogEnterBattleButton:SetPoint(unpack(point))
  PVPReadyDialog.enterButton:ClearAllPoints()
  PVPReadyDialog.enterButton:SetPoint(unpack(point))
end

local function showPvEButton ()
  local point = {LFGDungeonReadyDialog.leaveButton:GetPoint()}

  point[1] = 'BOTTOMRIGHT'
  point[4] = point[4] * (-1)

  LFGDungeonReadyDialog.leaveButton:Show()
  -- LFGDungeonReadyDialog.leaveButton.Show = function () end -- prevent other mods from showing the button
  LFGDungeonReadyDialog.leaveButton:SetAlpha(1)
  LFGDungeonReadyDialog.enterButton:ClearAllPoints()
  LFGDungeonReadyDialog.enterButton:SetPoint(unpack(point))
end

local function showButton ()
  showPvPButton()
  showPvEButton()
end

--[[
///#############################################################################
/// PVP queue stuff
///#############################################################################
--]]

local function updatePVPTimer ()
  if PVPReadyDialog_Showing(pvpQueue) then
    local seconds = GetBattlefieldPortExpiration(pvpQueue)

    if (seconds and seconds > 0) then
      PVPReadyDialog.label:SetText('Expires in ' .. formatTime(seconds))
    end
  else
    pvpQueue = nil
    updateTimeStamp = nil
    addonFrame:SetScript('OnUpdate', nil)
  end
end

local function pvpTimer_OnUpdate (_, elapsed)
  updateTimeStamp = updateTimeStamp + elapsed

  if (updateTimeStamp < UPDATE_INTERVAL) then
    return
  end

  updateTimeStamp = 0
  updatePVPTimer()
end

local function storePVPQueueTime (index)
  pvpQueueTimes[index] = GetBattlefieldTimeWaited(index)
end

local function handlePVPQueuePop (index)
  pvpQueue = index
  playSound(568011)

  if (pvpQueueTimes[index] ~= nil) then
    printTime(pvpQueueTimes[index] / 1000)
    pvpQueueTimes[index] = nil
  end

  updatePVPTimer()
  updateTimeStamp = 0
  addonFrame:SetScript('OnUpdate', pvpTimer_OnUpdate)

  if (options.hideButton == true) then
    hidePvPButton()
  else
    showPvPButton()
  end
end

local function checkPVPQueue (index)
  local status = GetBattlefieldStatus(index)

  if (status == 'queued') then
    storePVPQueueTime(index)
  elseif (status == 'confirm') then
    handlePVPQueuePop(index)
  end
end

events.UPDATE_BATTLEFIELD_STATUS = checkPVPQueue

--[[
///#############################################################################
/// PVE queue stuff
///#############################################################################
--]]

local function updatePVETimer ()
  -- I didn't find a function to check if the dialog is still displayed, so we stop updating after the time is over
  if (pveRemaining > 0) then
    updateLFGDialogLabel(LFGDungeonReadyDialog.label, 'Expires in ' .. formatTime(pveRemaining))
  else
    addonFrame:SetScript('OnUpdate', nil)
    updateTimeStamp = nil
  end
end

local function pveTimer_OnUpdate (_, elapsed)
  updateTimeStamp = updateTimeStamp + elapsed

  if (updateTimeStamp < UPDATE_INTERVAL) then
    return
  end

  pveRemaining = pveRemaining - updateTimeStamp
  updateTimeStamp = 0
  updatePVETimer()
end

local function showDungeonPopped (id)
  -- the dungeon sound is called levelup2 lul
  playSound(567478)

  if (pveQueueTimes[id] ~= nil) then
    printTime(GetTime() - pveQueueTimes[id])
    return
  end

  local queue = getClosestQueue(pveQueueTimes, id)

  if (queue ~= nil) then
    printTime(GetTime() - pveQueueTimes[queue])
  end
end

local function checkPVEQueues ()
  for x = 1, 6 do -- queue subtype constants range from 1 to 6
    local categoryList = GetLFGQueuedList(x)
    local time = select(17, GetLFGQueueStats(x))

    for key, value in pairs(categoryList) do
      if (time ~= nil) then
        pveQueueTimes[key] = time
      end
    end
  end
end

events.LFG_QUEUE_STATUS_UPDATE = checkPVEQueues
events.LFG_PROPOSAL_FAILED = checkPVEQueues

function events.LFG_PROPOSAL_SHOW ()
  local info = {GetLFGProposal()}
  -- local category = info[4]
  local id = info[2]

  showDungeonPopped(id)
  pveRemaining = 40
  updateTimeStamp = 0
  addonFrame:SetScript('OnUpdate', pveTimer_OnUpdate)
end

--[[
///#############################################################################
/// event handling
///#############################################################################
--]]

local function migrateOptions ()
  if (type(_G.JustInTime_options) == 'table') then
    options = _G.JustInTime_options
  elseif (type(_G.options) == 'table') then
    local paramList = {
      'hideButton',
      'forceSound',
      'announce',
    }

    for _, option in ipairs(paramList) do
      options[option] = _G.options[option]
    end
  end
end

local function globalizeOptions ()
  if (type(_G.JustInTime_options) == 'table') then
    for option, value in pairs(options) do
      _G.JustInTime_options[option] = value
    end
  else
    _G.JustInTime_options = options
  end
end

local function initDefaultOptions ()
  options.announce = options.announce or 'self'
  options.hideButton = options.hideButton or false
  options.forceSound = options.forceSound or true
end

function events.ADDON_LOADED (name)
  if (name ~= addonName) then return end

  migrateOptions()

  if (options.hideButton == nil) then
    printMessage('Toggle the Leave Queue Button using \'/jit button hide/show\'')
  end

  if (options.forceSound == nil) then
    printMessage('You can play queue sounds even when muted using \'/jit sound on/off\'')
  end

  initDefaultOptions()

  if (options.hideButton == true) then
    hideButton()
  end

  events.ADDON_LOADED = nil
  addonFrame:UnregisterEvent('ADDON_LOADED')
end

events.PLAYER_ENTERING_WORLD = checkPVEQueues
events.PLAYER_LOGOUT = globalizeOptions

local function eventHandler (_, event, ...)
  events[event](...)
end

addonFrame:SetScript('OnEvent', eventHandler)

for k, v in pairs(events) do
  addonFrame:RegisterEvent(k)
end

--[[
///*****************************************************************************
/// slashcommand handlers
///*****************************************************************************
--]]

local slashCommands = {}

function slashCommands:announce (arg)
  if (arg == 'off' or arg == 'self' or arg == 'group') then
    options.announce = arg
    printMessage('Announce set to ' .. arg)
  elseif (arg == '') then
    printMessage('Announce is currently set to ' .. options.announce)
  else
    printMessage('Invalid announce setting')
    printMessage('Announce types are \'off\', \'self\', and \'group\'')
  end
end

function slashCommands:button (arg)
  if (arg == 'hide' or arg == 'off') then
    options.hideButton = true
    hideButton()
    printMessage('Leave Queue button is now hidden')
    return
  elseif (arg == 'show' or arg == 'on') then
    options.hideButton = false
    showButton()
    printMessage('Leave Queue button is now shown')
    return
  elseif (arg == '') then
    if (options.hideButton == true) then
      printMessage('Leave Queue button is hidden')
    else
      printMessage('Leave Queue button is shown')
    end
    return
  else
    printMessage('Invalid button setting')
    printMessage('Allowed settings are \'hide\' and \'show\'')
  end
end

function slashCommands:sound (arg)
  if (arg == 'on') then
    printMessage('Queue sounds will play even when muted')
    options.forceSound = true
  elseif (arg == 'off') then
    options.forceSound = false
    printMessage('Queue sounds will not play when muted')
  elseif (arg == '') then
    if (options.forceSound == true) then
      printMessage('Queue sounds will play even when muted')
    else
      printMessage('Queue sounds will not play when muted')
    end
  else
    printMessage('Invalid sound setting')
    printMessage('Allowed settings are \'on\' and \'off\'')
  end
end

function slashCommands:default ()
  DEFAULT_CHAT_FRAME:AddMessage('|cff33ff99JustInTime ' .. ADDON_VERSION .. '|r')
end

local function slashHandler (msg)
  msg = msg or ''

  local cmd, arg = strsplit(' ', msg, 2)

  cmd = string.lower(cmd or '')
  arg = string.lower(arg or '')

  cmd = cmd == '' and 'default' or cmd

  if (slashCommands[cmd] ~= nil) then
    slashCommands[cmd](nil, arg)
    return
  end

  printMessage('Unknown command "' .. msg .. '"')
end

SLASH_JustInTime1 = '/justintime'
SLASH_JustInTime2 = '/jit'
_G.SlashCmdList.JustInTime = slashHandler
