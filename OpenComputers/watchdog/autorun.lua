local component = require("component")
local internet = require("internet")
local gpu = component.gpu
local filesystem = require("filesystem")

local w, h = gpu.getResolution()

gpu.fill(1, 1, w, h, " ")
gpu.set(1, 1, "Starting Watchdog...")

if not component.isAvailable("internet") then
  print("No internet card detected, watchdog cannot run.")
  return
end

print("Internet card detected, downloading latest watchdog...")

-- Download latest watchdog from GitHub
local function downloadWatchdog()
  local github_url = "https://raw.githubusercontent.com/WhitePhant0m/GTNH-Things/main/OpenComputers/watchdog/watchdog.lua"
  local local_path = "/home/watchdog.lua"

  local success = false
  local handle = internet.request(github_url)

  if handle then
    local content = ""
    for chunk in handle do
      content = content .. chunk
    end

    -- Write the downloaded content to local file
    local file = io.open(local_path, "w")
    if file then
      file:write(content)
      file:close()
      print("Watchdog downloaded successfully!")
      success = true
    else
      print("Error: Could not write watchdog file.")
    end
  else
    print("Error: Failed to download watchdog from GitHub.")
  end

  return success
end

-- Download the watchdog, fall back to existing one if download fails
if downloadWatchdog() or filesystem.exists("/home/watchdog.lua") then
  print("Starting watchdog...")
  dofile("/home/watchdog.lua")
else
  print("Failed to download watchdog and no existing version found. Aborting.")
end
