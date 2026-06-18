-- USB Drive Manager — background service.
-- Polls for removable block devices using lsblk and manages mount/unmount.

local drives = {}
local driveCount = 0
local mountedCount = 0

local function updateState()
  noctalia.state.set("driveCount", driveCount)
  noctalia.state.set("mountedCount", mountedCount)
  -- Encode drive list as a simple summary string: "label:mountpoint;..."
  local summary = {}
  for _, d in ipairs(drives) do
    local entry = (d.label or d.name) .. ":" .. (d.mountpoint or "")
    summary[#summary + 1] = entry
  end
  noctalia.state.set("driveSummary", table.concat(summary, ";"))
end

local function parseBlockDevices(text)
  local result = {}
  -- Parse lsblk JSON output manually
  -- Look for removable=1 devices with children
  for block in text:gmatch('"name":"([^"]+)","maj:min":"[^"]+","rm":(true)') do
    -- Found a removable device
  end

  -- Simpler: grep for USB devices with mountpoints
  -- Extract from JSON: name, rm (removable), mountpoint, label, size
  local function extractDevices(json)
    local devs = {}
    for deviceJson in json:gmatch('"children":%[(.-)%]') do
      for nameVal, mountVal, labelVal in deviceJson:gmatch('"name":"([^"]+)"[^}]-"mountpoint[s]?":"([^"]*)"[^}]-"label":"([^"]*)"') do
        if nameVal and mountVal then
          devs[#devs + 1] = {name = nameVal, mountpoint = mountVal ~= "null" and mountVal or "", label = labelVal ~= "null" and labelVal or nameVal}
        end
      end
    end
    return devs
  end

  -- Simplified approach: find all partitions of removable disks
  local devs = {}
  -- Look for rm:true (or "rm":true or "rm":1) blocks
  for entry in text:gmatch('{[^{}]+}') do
    local name = entry:match('"name":"([^"]+)"')
    local rm = entry:match('"rm":(true)') or entry:match('"rm":1')
    local mountpoint = entry:match('"mountpoint":"([^"]*)"') or entry:match('"mountpoints":%["([^"]*)"')
    local label = entry:match('"label":"([^"]*)"')
    local size = entry:match('"size":"([^"]*)"')

    if name and rm then
      devs[#devs + 1] = {
        name = name,
        mountpoint = (mountpoint and mountpoint ~= "null") and mountpoint or "",
        label = (label and label ~= "null" and label ~= "") and label or name,
        size = (size and size ~= "null") and size or "",
      }
    end
  end
  return devs
end

local function refresh()
  noctalia.runAsync("lsblk -J -o NAME,RM,MOUNTPOINT,LABEL,SIZE,TYPE 2>/dev/null", function(res)
    if res.exitCode ~= 0 then
      drives = {}
      driveCount = 0
      mountedCount = 0
      updateState()
      return
    end
    local text = res.stdout or res.body or ""
    local devs = parseBlockDevices(text)

    -- Filter to only partitions of removable disks
    local filtered = {}
    for _, d in ipairs(devs) do
      if d.name:match("^sd") or d.name:match("^sda") or d.name:match("nvme") then
        -- skip nvme (usually internal)
      else
        filtered[#filtered + 1] = d
      end
    end

    drives = filtered
    driveCount = #drives
    mountedCount = 0
    for _, d in ipairs(drives) do
      if d.mountpoint ~= "" then
        mountedCount = mountedCount + 1
      end
    end
    updateState()
  end)
end

local function mountDrive(name)
  noctalia.runAsync("udisksctl mount -b /dev/" .. name .. " 2>/dev/null", function(res)
    refresh()
  end)
end

local function unmountDrive(name)
  noctalia.runAsync("udisksctl unmount -b /dev/" .. name .. " 2>/dev/null", function(res)
    refresh()
  end)
end

local function unmountAll()
  for _, d in ipairs(drives) do
    if d.mountpoint ~= "" then
      unmountDrive(d.name)
    end
  end
end

noctalia.state.watch("command", function(cmd)
  if cmd == "refresh" then
    refresh()
  elseif cmd == "unmountAll" then
    unmountAll()
  elseif cmd then
    local action, name = cmd:match("^([^:]+):(.+)$")
    if action == "mount" then
      mountDrive(name)
    elseif action == "unmount" then
      unmountDrive(name)
    end
  end
end)

refresh()

noctalia.setUpdateInterval(5000)

function onUpdate()
  refresh()
end
