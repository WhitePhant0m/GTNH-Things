local filesystem = require("filesystem")
local internet = require("internet")
local computer = require("computer")
local component = require("component")
local gpu = component.gpu

local defaultConfig = {
  hours = { 3, 11, 17 },
  minute = 55,
  interval = 60,                  -- seconds between checks
  offset = -5,                    -- hours relative to UTC
  warn_before = { 900, 300, 60 }, -- seconds before restart to warn (15m, 5m, 1m)
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

---@param text string
local function write(text)
  if gpu then
    gpu.setForeground(0xFFFFFF)
    gpu.setBackground(0x000000)
    gpu.fill(1, 1, gpu.getResolution(), gpu.getResolution(), " ")
    gpu.set(1, 1, text)
  else
    print(text)
  end
end

while true do
  local realtime = getRealTime()

  if realtime then
    local temp = os.date("*t", realtime)
    local secondsLeft, targetTs = secondsToNextRestart(realtime)

    if targetTs and targetTs ~= lastTarget then
      warned = {}
      lastTarget = targetTs
    end

    if secondsLeft then
      for _, warnSeconds in ipairs(config.warn_before) do
        if secondsLeft <= warnSeconds and secondsLeft > 0 and not warned[warnSeconds] then
          local minutes = math.floor(warnSeconds / 60)
          write("Server restart in " .. minutes .. " minute(s).")
          if config.beep and computer and computer.beep then
            computer.beep(1000, 0.2)
          end
          warned[warnSeconds] = true
        end
      end

      if secondsLeft <= 0 and not warned["now"] then
        write("Server restart should be happening now.")
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
      write(text)
    else
      write("No restart schedule configured.")
    end
  else
    write("Failed to get real-world time. Check internet card.")
  end

  os.sleep(config.interval)
end
