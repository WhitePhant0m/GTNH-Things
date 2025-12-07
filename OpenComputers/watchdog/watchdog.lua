local filesystem = require("filesystem")

local defaultConfig = {
  hours = { 3, 11, 17 },
  minute = 55,
  interval = 60, -- seconds
  offset = -5,   -- hours
}

local config = defaultConfig

local function writeConfig()
  local file = io.open("/home/watchdog_config.lua", "w")
  if file then
    file:write("return {\n")
    file:write("  hours = { ")
    for _, h in ipairs(defaultConfig.hours) do
      file:write(h .. ", ")
    end
    file:write("},\n")
    file:write("  minute = " .. defaultConfig.minute .. ",\n")
    file:write("  interval = " .. defaultConfig.interval .. ",\n")
    file:write("  offset = " .. defaultConfig.offset .. ",\n")
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
  local handle = Internet.request("http://worldtimeapi.org/api/timezone/Etc/UTC")
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

--- @param date string|osdate
local function checkHour(date)
  local _hour = date.hour
  for _, h in ipairs(config.hours) do
    if _hour == h then
      return true
    end
  end
end

--- @param date string|osdate
local function checkMinute(date)
  local _minute = date.min
  if _minute >= config.minute then
    return true
  end
end

while true do
  local realtime = getRealTime()

  if realtime then
    local temp = os.date("*t", realtime)
    if checkHour(temp) and checkMinute(temp) then
      print("It's time to shut off universals!")
    else
      print("Not time yet.")
    end
    print("Current time (UTC" .. config.offset .. "): " .. temp.hour .. ":" .. temp.min)
  else
    print("Failed to get real-world time. Check internet card.")
  end

  os.sleep(config.interval)
end
