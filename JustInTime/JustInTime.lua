local addonName, shared = ...

-- JustInTime by syndenbock
-- inspired by SafeQueue by Jordon

-- raids can have multiple queues, but you can only receive the queue time for
-- the latest queue, so we store these times for reloads/relogs/dcs


local ADDON_VERSION = GetAddOnMetadata(addonName, 'version')
local UPDATE_INTERVAL = 0.1

local addonFrame = CreateFrame('Frame')
local pvpQueue = 0
local updateTimeStamp = 0
local pveQueueTimes = {}
local pveRemaining = 0
local pvpQueueTimes = {}
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

local function printTable (table)
  for i,v in pairs(table) do
    print(i, ' - ', v)
  end
end

local function playSound (soundId)
  if (options.forceSound == true and
      GetCVar('Sound_EnableSFX') == '0') then
     --[[ because for some fucked up reason blizzard decides to not allow sounds
          to be played using their file path anymore --]]

    PlaySoundFile(soundId, 'master')
  end
end

local function getMinimumDist (list, target)
  local result

  for key, value in pairs(list) do
    local dist = math.abs(target - key)
    if (result == nil or
        dist < result.dist) then
      result = {
        dist = dist,
        key = key
      }
    end
  end

  return result
end

local function Print (msg)
  DEFAULT_CHAT_FRAME:AddMessage('|cff33ff99JIT|r: ' .. msg)
end

local function printTime (time)
  local announce = options.announce

  if (announce == 'off') then
    return
  end

  local secs = floor(GetTime() - time)
  local str = 'Queue popped '

  if (secs < 1) then
    str = str .. 'instantly!'
  else
    str = str .. 'after '

    if (secs >= 60) then
      str = str .. floor(secs / 60) .. 'm '
      secs = secs % 60
    end

    if (secs % 60) ~= 0 then
      str = str .. secs .. 's'
    end
  end
  if (announce == 'self' or
      not IsInGroup()) then
    Print(str)
  else
    local group = IsInRaid() and 'RAID' or 'PARTY'

    SendChatMessage(str, group)
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

local function showPVPTimer (self, elapsed)
  updateTimeStamp = updateTimeStamp + elapsed

  if (updateTimeStamp < UPDATE_INTERVAL) then
    return
  end

  updateTimeStamp = 0

  if PVPReadyDialog_Showing(pvpQueue) then
    local secs = GetBattlefieldPortExpiration(pvpQueue)

    if (secs and secs > 0) then
      local color = secs > 20 and 'f20ff20' or secs > 10 and 'fffff00' or 'fff0000'

      PVPReadyDialog.label:SetText('Expires in |cf'..color.. SecondsToTime(secs) .. '|r')
    end
  else
    pvpQueue = 0
    addonFrame:SetScript('OnUpdate', nil)
  end
end

function events:UPDATE_BATTLEFIELD_STATUS (index)
  local status = GetBattlefieldStatus(index)

  if (status == 'queued') then
    -- we are always updating this, because Blizzard actually returns the time
    -- from the last queue on the first call
    pvpQueueTimes[index] = GetTime() - GetBattlefieldTimeWaited(index) / 1000
  elseif (status == 'confirm') then
    if (pvpQueueTimes[index] ~= nil) then
      printTime(pvpQueueTimes[index])
      pvpQueueTimes[index] = nil
      updateTimeStamp = UPDATE_INTERVAL
      pvpQueue = index
      addonFrame:SetScript('OnUpdate', showPVPTimer)
      playSound(568011)
    end

    if (options.hideButton == true) then
      hidePvPButton()
    else
      showPvPButton()
    end
  else
    pvpQueueTimes[index] = nil
  end
end

--[[
///#############################################################################
/// PVE queue stuff
///#############################################################################
--]]

local function showPVETimer (self, elapsed)
  updateTimeStamp = updateTimeStamp + elapsed

  if (updateTimeStamp < UPDATE_INTERVAL) then
    return
  end

  local secs

  pveRemaining = pveRemaining - updateTimeStamp
  updateTimeStamp = 0
  secs = math.floor(pveRemaining)

  -- I didn't find a function to check if the dialog is still displayed, so we stop updating after the time is over
  if pveRemaining > 0 then
    local color = secs > 20 and 'f20ff20' or secs > 10 and 'fffff00' or 'fff0000'

    updateLFGDialogLabel(LFGDungeonReadyDialog.label, 'Expires in |cf' .. color .. SecondsToTime(secs) .. '|r')
  else
    addonFrame:SetScript('OnUpdate', nil)
  end
end

local function showDungeonPopped (id)
  -- the dungeon sound is called levelup2 lul
  playSound(567478)

  if (pveQueueTimes[id] ~= nil) then
    printTime(pveQueueTimes[id])
    -- pveQueueTimes[id] = nil
    return
  end

  local dist = getMinimumDist(pveQueueTimes, id)

  if (dist ~= nil) then
    printTime(pveQueueTimes[dist.key])
  end
end

local function checkQueues ()
  for i = 1, 6 do -- queue subtype constants range from 1 to 6
    local categoryList = GetLFGQueuedList(i)
    local time = select(17, GetLFGQueueStats(i))

    time = tonumber(time)

    for key, value in pairs(categoryList) do
      if (time ~= nil) then
        pveQueueTimes[key] = time
      end
    end
  end
end

function events:LFG_UPDATE ()
  checkQueues()
end

function events:LFG_PROPOSAL_FAILED ()
  -- print('failed')
  checkQueues()
end

function events:LFG_PROPOSAL_SHOW ()
  local info = {GetLFGProposal()}
  -- local category = info[4]
  local id = info[2]

  showDungeonPopped(id)

  pveRemaining = 40 + UPDATE_INTERVAL
  updateTimeStamp = UPDATE_INTERVAL
  addonFrame:SetScript('OnUpdate', showPVETimer)
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

function events:ADDON_LOADED (name)
  if (name ~= addonName) then return end

  migrateOptions()

  if (options.hideButton == nil) then
    Print('Toggle the Leave Queue Button using \'/jit button hide/show\'')
  end

  if (options.forceSound == nil) then
    Print('You can play queue sounds even when muted using \'/jit sound on/off\'')
  end

  initDefaultOptions()

  if (options.hideButton == true) then
    hideButton()
  end
end

events.PLAYER_LOGOUT = globalizeOptions

function events:PLAYER_ENTERING_WORLD ()
  checkQueues()
end

local function eventHandler (self, event, ...)
  events[event](self, ...)
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
    Print('Announce set to ' .. arg)
  elseif (arg == '') then
    Print('Announce is currently set to ' .. options.announce)
  else
    Print('Invalid announce setting')
    Print('Announce types are \'off\', \'self\', and \'group\'')
  end
end

function slashCommands:button (arg)
  if (arg == 'hide' or arg == 'off') then
    options.hideButton = true
    hideButton()
    Print('Leave Queue button is now hidden')
    return
  elseif (arg == 'show' or arg == 'on') then
    options.hideButton = false
    showButton()
    Print('Leave Queue button is now shown')
    return
  elseif (arg == '') then
    if (options.hideButton == true) then
      Print('Leave Queue button is hidden')
    else
      Print('Leave Queue button is shown')
    end
    return
  else
    Print('Invalid button setting')
    Print('Allowed settings are \'hide\' and \'show\'')
  end
end

function slashCommands:sound (arg)
  if (arg == 'on') then
    Print('Queue sounds will play even when muted')
    options.forceSound = true
  elseif (arg == 'off') then
    options.forceSound = false
    Print('Queue sounds will not play when muted')
  elseif (arg == '') then
    if (options.forceSound == true) then
      Print('Queue sounds will play even when muted')
    else
      Print('Queue sounds will not play when muted')
    end
  else
    Print('Invalid sound setting')
    Print('Allowed settings are \'on\' and \'off\'')
  end
end

function slashCommands:default ()
  DEFAULT_CHAT_FRAME:AddMessage('|cff33ff99JustInTime ' .. ADDON_VERSION .. '|r')
end

local function slashHandler (msg)
  msg = msg or ''

  local cmd, arg = string.split(' ', msg, 2)

  cmd = string.lower(cmd or '')
  arg = string.lower(arg or '')

  cmd = cmd == '' and 'default' or cmd

  if (slashCommands[cmd] ~= nil) then
    slashCommands[cmd](nil, arg)
    return
  end

  Print('Unknown command "' .. msg .. '"')
end

SLASH_JustInTime1 = '/justintime'
SLASH_JustInTime2 = '/jit'
SlashCmdList.JustInTime = slashHandler
