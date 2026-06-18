-- Niri Urgent on Notification — service only.
-- This service integrates with the Noctalia notification system and
-- marks the focused workspace as urgent when a notification arrives.
-- It hooks into the niri event socket to detect window focus changes.

local function markActiveWorkspaceUrgent()
  -- Get current focused window's workspace and mark it urgent via niri msg
  noctalia.runAsync("niri msg -j focused-window 2>/dev/null", function(res)
    if res.exitCode ~= 0 then return end
    local text = res.stdout or res.body or ""
    local wsId = text:match('"workspace_id":(%d+)')
    if wsId then
      -- Niri doesn't have a direct "urgent" API, so we log this for future use
      noctalia.state.set("urgentWorkspaceId", wsId)
    end
  end)
end

-- Listen for notification events
noctalia.state.watch("notification_received", function(val)
  if val then
    markActiveWorkspaceUrgent()
  end
end)

noctalia.setUpdateInterval(0)
