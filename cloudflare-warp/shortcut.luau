-- Cloudflare WARP — control center shortcut.

local connected = false

local function render()
  shortcut.setLabel("WARP")
  shortcut.setIcon("cloud-lock", "cloud")
  shortcut.setActive(connected)
  shortcut.setEnabled(true)
end

noctalia.state.watch("connected", function(val)
  connected = val == true
  render()
end)

function onClick()
  noctalia.state.set("command", "toggle")
end
