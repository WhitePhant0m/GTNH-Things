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

-- Download latest files from GitHub
local function updateScript()
  local github_url = "https://raw.githubusercontent.com/WhitePhant0m/GTNH-Things/main/OpenComputers/watchdog/"

  local files = {
    { remote = "autorun.lua", target = "/autorun.lua" },
    { remote = "watchdog.lua", target = "/home/watchdog.lua" },
  }

  local success = true

  local handles = {}
  for _, file in ipairs(files) do
    local url = github_url .. file.remote
    local handle = internet.request(url)
    handles[file.remote] = { handle = handle, target = file.target }
  end

  for remote, data in pairs(handles) do
    local handle = data.handle
    local target = data.target
    if handle then
      local content = ""
      for chunk in handle do
        content = content .. chunk
      end

      -- Write the downloaded content to local file
      local dir = filesystem.path(target)
      if dir and #dir > 0 then
        filesystem.makeDirectory(dir)
      end
      local file = io.open(target, "w")
      if file then
        file:write(content)
        file:close()
        print(remote .. " -> " .. target .. " downloaded successfully!")
      else
        print("Error: Could not write " .. remote .. " file to " .. target .. ".")
        success = false
      end
    else
      print("Error: Failed to download " .. remote .. " from GitHub.")
      success = false
    end
  end

  return success
end

if updateScript() then
  print("Starting watchdog...")
  dofile("/home/watchdog.lua")
else
  if filesystem.exists("/home/watchdog.lua") then
    print("Failed to download latest watchdog, starting existing version...")
    dofile("/home/watchdog.lua")
  else
    print("Failed to download watchdog and no existing version found. Aborting.")
  end
end