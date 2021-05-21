local addonName, addon = ...

-- JustInTime by syndenbock
-- inspired by SafeQueue by Jordon

-- raids can have multiple queues, but you can only receive the queue time for
-- the latest queue, so we store these times for reloads/relogs/dcs

local DEFAULT_CHAT_FRAME = _G.DEFAULT_CHAT_FRAME
local ADDON_VERSION = _G.GetAddOnMetadata(addonName, 'version')

local printMessage = addon.printMessage

addon.frame = _G.CreateFrame('Frame')
addon.options = {}

local function hideButton ()
  addon.hidePvPButton()
  addon.hidePvEButton()
end

local function showButton ()
  addon.showPvPButton()
  addon.showPvEButton()
end

local function migrateOptions ()
  local options

  if (type(_G.JustInTime_options) == 'table') then
    options = _G.JustInTime_options
  elseif (type(_G.options) == 'table') then
    local paramList = {
      'hideButton',
      'forceSound',
      'announce',
    }

    options = {}

    for _, option in ipairs(paramList) do
      options[option] = _G.options[option]
    end
  end

  addon.options = options
end

local function initDefaultOptions ()
  local options = addon.options

  options.announce = options.announce or 'self'
  options.hideButton = options.hideButton or false
  options.forceSound = options.forceSound or true
end

local function initOptions ()
  migrateOptions()

  if (addon.options.hideButton == nil) then
    printMessage('Toggle the Leave Queue Button using \'/jit button hide/show\'')
  end

  if (addon.options.forceSound == nil) then
    printMessage('You can play queue sounds even when muted using \'/jit sound on/off\'')
  end

  initDefaultOptions()

  if (addon.options.hideButton == true) then
    hideButton()
  end
end

local function globalizeOptions ()
  if (type(_G.JustInTime_options) == 'table') then
    for option, value in pairs(addon.options) do
      _G.JustInTime_options[option] = value
    end
  else
    _G.JustInTime_options = addon.options
  end
end

addon.registerEvent('ADDON_LOADED', function (name)
  if (name ~= addonName) then
    return false
  end

  initOptions()

  return true
end)

addon.registerEvent('PLAYER_LOGOUT', globalizeOptions)

--[[
///*****************************************************************************
/// slashcommand handlers
///*****************************************************************************
--]]

addon.addSlashHandlerName('jit')

addon.slash('announce', function (arg)
  if (arg == nil) then
    printMessage('Announce is currently set to ' .. addon.options.announce)
  elseif (arg == 'off' or arg == 'self' or arg == 'group') then
    addon.options.announce = arg
    printMessage('Announce set to ' .. arg)
  else
    printMessage('Invalid announce setting')
    printMessage('Announce types are \'off\', \'self\', and \'group\'')
  end
end)

addon.slash('button', function (arg)
  local options = addon.options

  if (arg == nil) then
    if (options.hideButton == true) then
      printMessage('Leave Queue button is hidden')
    else
      printMessage('Leave Queue button is shown')
    end
  elseif (arg == 'hide' or arg == 'off') then
    options.hideButton = true
    hideButton()
    printMessage('Leave Queue button is now hidden')
  elseif (arg == 'show' or arg == 'on') then
    options.hideButton = false
    showButton()
    printMessage('Leave Queue button is now shown')
  else
    printMessage('Invalid button setting')
    printMessage('Allowed settings are \'hide\' and \'show\'')
  end
end)

addon.slash('sound', function (arg)
  local options = addon.options

  if (arg == nil) then
    if (options.forceSound == true) then
      printMessage('Queue sounds will play even when muted')
    else
      printMessage('Queue sounds will not play when muted')
    end
  elseif (arg == 'on') then
    printMessage('Queue sounds will play even when muted')
    options.forceSound = true
  elseif (arg == 'off') then
    options.forceSound = false
    printMessage('Queue sounds will not play when muted')
  else
    printMessage('Invalid sound setting')
    printMessage('Allowed settings are \'on\' and \'off\'')
  end
end)

addon.slash('default', function ()
  DEFAULT_CHAT_FRAME:AddMessage('|cff33ff99JustInTime ' .. ADDON_VERSION .. '|r')
end)
