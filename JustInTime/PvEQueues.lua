local _, addon = ...

local GetTime = _G.GetTime
local GetLFGQueuedList = _G.GetLFGQueuedList
local GetLFGQueueStats = _G.GetLFGQueueStats
local GetLFGProposal = _G.GetLFGProposal

local LFGDungeonReadyDialog = _G.LFGDungeonReadyDialog

local addonFrame = addon.frame
local playSound = addon.playSound
local formatTime = addon.formatTime
local printTime = addon.printTime

local UPDATE_INTERVAL = 0.1

local pveQueueTimes = {}
local pveRemaining = 0
local updateTimeStamp

-- the text of the LFG dialog label randomly changes back, so we override the function to prevent that
local updateLFGDialogLabel = LFGDungeonReadyDialog.label.SetText
LFGDungeonReadyDialog.label.SetText = function () end
LFGDungeonReadyDialog.label:SetPoint('TOP', 0, -22)

local function hidePvEButton ()
  LFGDungeonReadyDialog.leaveButton:Hide()
  -- LFGDungeonReadyDialog.leaveButton.Show = function () end -- prevent other mods from showing the button
  LFGDungeonReadyDialog.leaveButton:SetAlpha(0)
  LFGDungeonReadyDialog.enterButton:ClearAllPoints()
  LFGDungeonReadyDialog.enterButton:SetPoint('BOTTOM', LFGDungeonReadyDialog, 'BOTTOM', 0, 25)
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

local function showDungeonPopped (id)
  -- The game now plays a dungeon queue sound in the master channel on its own
  -- so this is no longer needed
  -- playSound(567478)

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

addon.registerEvent('LFG_QUEUE_STATUS_UPDATE', checkPVEQueues)
addon.registerEvent('LFG_PROPOSAL_FAILED', checkPVEQueues)

addon.registerEvent('LFG_PROPOSAL_SHOW', function ()
  local info = {GetLFGProposal()}
  -- local category = info[4]
  local id = info[2]

  if (addon.options.hideButton == true) then
    hidePvEButton()
  else
    showPvEButton()
  end

  showDungeonPopped(id)
  pveRemaining = 40
  updateTimeStamp = 0
  addonFrame:SetScript('OnUpdate', pveTimer_OnUpdate)
end)

--[[
///#############################################################################
/// exports
///#############################################################################
--]]

addon.hidePvEButton = hidePvEButton
addon.showPvEButton = showPvEButton
