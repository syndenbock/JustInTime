local _, addon = ...

local GetCVar = _G.GetCVar
local PlaySoundFile = _G.PlaySoundFile
local IsInGroup = _G.IsInGroup
local IsInRaid = _G.IsInRaid
local SendChatMessage = _G.SendChatMessage
local SecondsToTime = _G.SecondsToTime

local DEFAULT_CHAT_FRAME = _G.DEFAULT_CHAT_FRAME

local function printMessage (msg)
  DEFAULT_CHAT_FRAME:AddMessage('|cff33ff99JIT|r: ' .. msg)
end

local function playSound (soundId)
  if (addon.options.forceSound ~= true or
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


local function printTime (seconds)
  if (addon.options.announce == 'off') then
    return
  end

  local message = 'Queue popped '

  if (seconds < 1) then
    message = message .. 'instantly!'
  else
    message = message .. 'after ' .. SecondsToTime(seconds)
  end

  if (addon.options.announce == 'self' or
      not IsInGroup()) then
    printMessage(message)
  else
    SendChatMessage(message, (IsInRaid() and 'RAID') or 'PARTY')
  end
end

--[[
///#############################################################################
/// exports
///#############################################################################
--]]

addon.printMessage = printMessage
addon.playSound = playSound
addon.formatTime = formatTime
addon.printTime = printTime
