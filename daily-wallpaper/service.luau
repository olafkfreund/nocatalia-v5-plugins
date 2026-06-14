-- Daily Wallpaper — background service.
-- Periodically checks and downloads the daily wallpaper from Bing or NASA.

noctalia.setUpdateInterval(600000) -- check every 10 minutes

local lastDate = ""
local running = false

local function todayString()
  return os.date("%Y-%m-%d")
end

local function normalizeLocale(rawLocale)
  local locale = ((rawLocale or ""):gsub("^%s+", ""):gsub("%s+$", ""):lower():gsub("_", "-"))
  return locale ~= "" and locale or "en-us"
end

local function setWallpaper(filePath)
  noctalia.log(`DailyWallpaper: Setting wallpaper to {filePath}`)
  noctalia.runAsync(`noctalia msg wallpaper-set '{filePath}'`, function(res)
    if res.exitCode == 0 then
      noctalia.notify("Daily Wallpaper", "Wallpaper updated successfully!")
    else
      noctalia.log(`DailyWallpaper: Failed to set wallpaper. exitCode: {res.exitCode}`)
    end
  end)
end

local function downloadImage(prefix, dateStr, primaryUrl, fallbackUrl, destDir)
  local destFile = `{destDir}/{prefix}-{dateStr}.jpg`
  noctalia.log(`DailyWallpaper: Checking if wallpaper exists: {destFile}`)

  -- Check if file already exists
  noctalia.runAsync(`test -f '{destFile}'`, function(res)
    if res.exitCode == 0 then
      noctalia.log("DailyWallpaper: Wallpaper already exists, applying cached version.")
      setWallpaper(destFile)
      running = false
      return
    end

    -- Download primary url
    noctalia.log(`DailyWallpaper: Downloading primary {primaryUrl}`)
    noctalia.runAsync(`curl -fsSL -o '{destFile}' '{primaryUrl}'`, function(res2)
      if res2.exitCode == 0 then
        setWallpaper(destFile)
        running = false
        -- Cleanup files older than 5 days
        noctalia.runAsync(`find '{destDir}' -name '{prefix}-*.jpg' -type f -mtime +5 -delete`)
      else
        if fallbackUrl and fallbackUrl ~= "" then
          noctalia.log(`DailyWallpaper: Primary failed, trying fallback {fallbackUrl}`)
          noctalia.runAsync(`curl -fsSL -o '{destFile}' '{fallbackUrl}'`, function(res3)
            if res3.exitCode == 0 then
              setWallpaper(destFile)
              running = false
              noctalia.runAsync(`find '{destDir}' -name '{prefix}-*.jpg' -type f -mtime +5 -delete`)
            else
              noctalia.log("DailyWallpaper: Fallback download failed.")
              running = false
            end
          end)
        else
          noctalia.log("DailyWallpaper: Primary download failed and no fallback provided.")
          running = false
        end
      end
    end)
  end)
end

local function fetchBing(locale, dateStr, destDir)
  local url = `https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt={locale}`
  noctalia.http({ url = url }, function(res)
    if not res.ok then
      noctalia.log(`DailyWallpaper: Bing API failed: {res.status}`)
      running = false
      return
    end

    local ok, parsed = pcall(noctalia.json.decode, res.body)
    if not ok or type(parsed) ~= "table" or not parsed.images or not parsed.images[1] then
      noctalia.log("DailyWallpaper: Failed to parse Bing JSON")
      running = false
      return
    end

    local urlbase = parsed.images[1].urlbase
    if not urlbase or urlbase == "" then
      noctalia.log("DailyWallpaper: Missing Bing urlbase")
      running = false
      return
    end

    local primaryUrl = `https://www.bing.com{urlbase}_UHD.jpg`
    local fallbackUrl = `https://www.bing.com{urlbase}_1920x1080.jpg`
    downloadImage("bing", dateStr, primaryUrl, fallbackUrl, destDir)
  end)
end

local function fetchNasa(dateStr, destDir)
  local url = "https://www.nasa.gov/image-of-the-day/"
  noctalia.http({ url = url }, function(res)
    if not res.ok then
      noctalia.log(`DailyWallpaper: NASA page fetch failed: {res.status}`)
      running = false
      return
    end

    local page = res.body or ""
    -- Regex match for class="hds-gallery-image"
    local primaryUrl = page:match('<[^>]*class="[^"]*hds-gallery-image[^"]*"[^>]*>%s*<img[^>]*src="([^"]+)"')
    if not primaryUrl then
      primaryUrl = page:match('<img[^>]*class="[^"]*hds-gallery-image[^"]*"[^>]*src="([^"]+)"')
    end

    local fallbackUrl = page:match('<meta%s+property="og:image"%s+content="([^"]+)"')
    if not fallbackUrl then
      fallbackUrl = page:match('<meta%s+name="twitter:image"%s+content="([^"]+)"')
    end

    if not primaryUrl and not fallbackUrl then
      noctalia.log("DailyWallpaper: Failed to parse NASA images")
      running = false
      return
    end

    downloadImage("nasa", dateStr, primaryUrl or fallbackUrl, fallbackUrl or "", destDir)
  end)
end

local function checkWallpaper()
  if running then return end

  local today = todayString()
  if today == lastDate then
    -- Already checked today
    return
  end

  running = true
  lastDate = today

  local home = os.getenv("HOME") or "/tmp"
  local destDir = `{home}/.config/noctalia/plugins/daily-wallpaper/downloads`

  noctalia.runAsync(`mkdir -p '{destDir}'`, function(res)
    if res.exitCode ~= 0 then
      noctalia.log("DailyWallpaper: Failed to create download directory")
      running = false
      return
    end

    local source = noctalia.getConfig("source") or "bing"
    local rawLocale = noctalia.getConfig("locale") or "en-us"
    local locale = normalizeLocale(rawLocale)

    if source == "nasa" then
      fetchNasa(today, destDir)
    else
      fetchBing(locale, today, destDir)
    end
  end)
end

noctalia.state.watch("command", function(cmd)
  if cmd == "refresh" then
    noctalia.state.set("command", nil)
    lastDate = "" -- force refresh
    checkWallpaper()
  end
end)

function update()
  checkWallpaper()
end

-- Trigger on startup
checkWallpaper()
