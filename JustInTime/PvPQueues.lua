local _, addon = ...

local PVPReadyDialog_Showing = _G.PVPReadyDialog_Showing
local GetBattlefieldPortExpiration = _G.GetBattlefieldPortExpiration
local GetBattlefieldStatus = _G.GetBattlefieldStatus
local GetBattlefieldTimeWaited = _G.GetBattlefieldTimeWaited

local PVPReadyDialog = _G.PVPReadyDialog

local addonFrame = addon.frame
local printTime = addon.printTime
local formatTime = addon.formatTime
local playSound = addon.playSound

local UPDATE_INTERVAL = 0.1
local updateTimeStamp
local pvpQueue
local pvpQueueTimes = {}

local function getPVPDialogLabel ()
  return PVPReadyDialog.label or PVPReadyDialog.text;
end

getPVPDialogLabel():SetPoint('TOP', 0, -22)

local function hidePvPButton ()
  PVPReadyDialog.leaveButton:Hide()
  -- PVPReadyDialog.leaveButton.Show = function () end -- prevent other mods from showing the button
  PVPReadyDialog.leaveButton:SetAlpha(0)
  PVPReadyDialog.enterButton:ClearAllPoints()
  PVPReadyDialog.enterButton:SetPoint('BOTTOM', PVPReadyDialog, 'BOTTOM', 0, 25)
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

local function updatePVPTimer ()
  if PVPReadyDialog_Showing(pvpQueue) then
    local seconds = GetBattlefieldPortExpiration(pvpQueue)

    if (seconds and seconds > 0) then
      getPVPDialogLabel():SetText('Expires in ' .. formatTime(seconds))
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

  if (addon.options.hideButton == true) then
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

addon.registerEvent('UPDATE_BATTLEFIELD_STATUS', checkPVPQueue)

--[[
///#############################################################################
/// exports
///#############################################################################
--]]

addon.hidePvPButton = hidePvPButton
addon.showPvPButton = showPvPButton
