local filesystem = require("filesystem")
local internet = require("internet")
local computer = require("computer")
local component = require("component")
local gpu = component.gpu
local redstone = require("redstone")

local defaultConfig = {
  hours = { 4, 12, 18 },          -- hours in UTC time for restarts
  minute = 0,                     -- minute of the hour for restarts
  interval = 60,                  -- seconds between checks
  offset = -5,                    -- hours relative to UTC
  warn_before = { 900, 300, 60 }, -- seconds before restart to warn (15m, 5m, 1m)
  turn_off_before = 300,          -- seconds before restart to turn off redstone signal
  beep = true,                    -- beep on warnings if the computer supports it
}

local function copyTable(t)
  local result = {}
  for k, v in pairs(t) do
    if type(v) == "table" then
      result[k] = {}
      for i, val in ipairs(v) do
        result[k][i] = val
      end
    else
      result[k] = v
    end
  end
  return result
end

local config = copyTable(defaultConfig)

local function writeConfig()
  local file = io.open("/home/watchdog_config.lua", "w")
  if file then
    file:write("return {\n")
    file:write("  hours = { ")
    for _, h in ipairs(config.hours) do
      file:write(h .. ", ")
    end
    file:write("},\n")
    file:write("  minute = " .. config.minute .. ",\n")
    file:write("  interval = " .. config.interval .. ",\n")
    file:write("  offset = " .. config.offset .. ",\n")
    file:write("  warn_before = { ")
    for _, s in ipairs(config.warn_before) do
      file:write(s .. ", ")
    end
    file:write("},\n")
    file:write("  turn_off_before = " .. config.turn_off_before .. ",\n")
    file:write("  beep = " .. tostring(config.beep) .. ",\n")
    file:write("}\n")
    file:close()
  end
end

if filesystem.exists("/home/watchdog_config.lua") then
  local success, _config = pcall(dofile, "/home/watchdog_config.lua")
  if success and type(_config) == "table" then
    print("Config loaded successfully.")
    for k, v in pairs(_config) do
      config[k] = v
    end
  else
    print("Error loading config, using default settings.")
    writeConfig()
  end
else
  print("No config found, creating default config.")
  writeConfig()
end

os.sleep(1)

local function getRealTime()
  local handle = internet.request("http://worldtimeapi.org/api/timezone/Etc/UTC")
  if handle then
    local result = ""
    for chunk in handle do
      result = result .. chunk
    end

    local unixtime = result:match('"unixtime":(%d+)')
    if unixtime then
      return tonumber(unixtime + (config.offset * 3600))
    end
  end
  return nil
end

-- Return seconds until the next configured restart and the epoch timestamp of that restart
local function secondsToNextRestart(now)
  local nowDate = os.date("*t", now)
  local candidates = {}

  for _, hour in ipairs(config.hours) do
    local target = {
      year = nowDate.year,
      month = nowDate.month,
      day = nowDate.day,
      hour = hour,
      min = config.minute,
      sec = 0,
      isdst = nowDate.isdst,
    }

    local ts = os.time(target)
    if ts <= now then
      ts = ts + 86400 -- move to next day if already passed
    end
    table.insert(candidates, ts)
  end

  if #candidates == 0 then
    return nil, nil
  end

  local nextTs = candidates[1]
  for i = 2, #candidates do
    if candidates[i] < nextTs then
      nextTs = candidates[i]
    end
  end

  return nextTs - now, nextTs
end

local warned = {}
local lastTarget = nil

local function clearText()
  if gpu then
    gpu.setForeground(0xFFFFFF)
    gpu.setBackground(0x000000)
    gpu.fill(1, 1, gpu.getResolution(), gpu.getResolution(), " ")
  end
end

local function write(x, y, text)
  if gpu then
    gpu.set(x, y, text)
  else
    print(text)
  end
end


local redstone_active = false
clearText()
redstone.init({ frequency = 404 })

while true do
  local realtime = getRealTime()

  if realtime then
    local temp = os.date("*t", realtime)
    local secondsLeft, targetTs = secondsToNextRestart(realtime)

    if targetTs and targetTs ~= lastTarget then
      warned = {}
      lastTarget = targetTs
      redstone_active = false
    end

    if secondsLeft then
      for _, warnSeconds in ipairs(config.warn_before) do
        if secondsLeft <= warnSeconds and secondsLeft > 0 and not warned[warnSeconds] then
          local minutes = math.floor(warnSeconds / 60)
          write(1, 1, "Server restart in " .. minutes .. " minute(s).")
          if config.beep and computer and computer.beep then
            computer.beep(1000, 0.2)
          end
          warned[warnSeconds] = true
        end
      end

      -- Toggle redstone based on how many seconds remain until restart
      if secondsLeft <= config.turn_off_before and secondsLeft > 0 and not redstone_active then
        if redstone.setWirelessOutput(false) then
          redstone_active = true
          write(1, 2, "Universal crafter loader DEACTIVATED!")
        else
          write(1, 2, "Error: Failed to activate redstone signal.")
        end
      elseif secondsLeft > config.turn_off_before and redstone_active then
        if redstone.setWirelessOutput(true) then
          redstone_active = false
          write(1, 2, "Universal crafter loader ACTIVATED!")
        else
          write(1, 2, "Error: Failed to deactivate redstone signal.")
        end
      end

      if secondsLeft <= 0 and not warned["now"] then
        write(1, 1, "Server restart should be happening now.")
        if config.beep and computer and computer.beep then
          computer.beep(1500, 0.3)
        end
        warned["now"] = true
      end

      local minutes = math.floor(secondsLeft / 60)
      local hours = math.floor(minutes / 60)

      local text = "Current time (UTC" ..
          config.offset .. "): " .. temp.hour .. ":" .. temp.min .. " | Next restart in "
      if hours > 0 then
        text = text .. hours .. " hour(s) "
      end
      text = text .. (minutes % 60) .. " minute(s)."
      write(1, 1, text)
    else
      write(1, 1, "No restart schedule configured.")
    end
  else
    write(1, 1, "Failed to get real-world time. Check internet card.")
  end

  os.sleep(config.interval)
end
