local component = require("component")
local gpu = component.gpu

local w, h = gpu.getResolution()

gpu.fill(1, 1, w, h, " ")
gpu.set(1, 1, "Starting Watchdog...")

if component.isAvailable("internet") then
  print("Internet card detected, starting watchdog.")
else
  print("No internet card detected, watchdog cannot run.")
  return
end

