local addonName, addon = ...

local strlower = _G.strlower
local strsplit = _G.strsplit

local slashCommands = {}
local handlerCount = 0

local function executeSlashCommand (command, ...)
  local handler = slashCommands[strlower(command)]

  if (not handler) then
    return addon.printAddonMessage(L['unknown command'], '"' .. command .. '"')
  end

  handler(...)
end

local function slashHandler (input)
  if (input == nil or input == '') then
    return executeSlashCommand('default')
  end

  executeSlashCommand(strsplit(' ', input))
end

local function addHandlerName (name)
  handlerCount = handlerCount + 1
  _G['SLASH_' .. addonName .. handlerCount] = '/' .. name
end

_G.SlashCmdList[addonName] = slashHandler

--[[
///#############################################################################
/// exports
///#############################################################################
--]]

addon.addSlashHandlerName = addHandlerName

function addon.slash (command, callback)
  assert(slashCommands[command] == nil,
      addonName .. ': slash handler already exists for ' .. command)

  slashCommands[command] = callback
end
