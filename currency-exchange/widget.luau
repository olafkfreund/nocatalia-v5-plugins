-- Currency Exchange — bar widget.

local function formatNumber(num)
  if not num then return "0" end
  if num >= 1000 then
    return string.format("%.2f", num)
  elseif num >= 1 then
    return string.format("%.2f", num)
  elseif num > 0 then
    return string.format("%.4f", num)
  end
  return "0"
end

local function render()
  local loading = noctalia.state.get("loading") == true
  local loaded = noctalia.state.get("loaded") == true
  local rates = noctalia.state.get("rates")

  local fromCurrency = noctalia.getConfig("sourceCurrency") or "USD"
  local toCurrency = noctalia.getConfig("targetCurrency") or "EUR"
  local displayMode = noctalia.getConfig("widgetDisplayMode") or "icon"

  local text = ""
  local tooltip = ""

  if loading then
    text = "..."
    tooltip = noctalia.tr("widget.loading") or "Loading exchange rates..."
  elseif not loaded or not rates then
    text = "--"
    tooltip = noctalia.tr("widget.error") or "Could not load rates"
  else
    local fromRate = rates[fromCurrency]
    local toRate = rates[toCurrency]
    if fromRate and toRate then
      local rate = toRate / fromRate
      if displayMode == "compact" then
        text = formatNumber(rate)
      elseif displayMode == "full" then
        text = `1 {fromCurrency} = {formatNumber(rate)} {toCurrency}`
      end
      tooltip = `1 {fromCurrency} = {formatNumber(rate)} {toCurrency}\n{noctalia.tr("widget.click_to_open") or "Click to open converter"}`
    else
      text = "--"
      tooltip = `Unknown currency: {not rates[fromCurrency] and fromCurrency or toCurrency}`
    end
  end

  barWidget.setGlyph("cash")
  barWidget.setTooltip(tooltip)
  if displayMode == "icon" then
    barWidget.setText("")
  else
    barWidget.setText(text)
  end
end

function onClick()
  -- Open launcher on click
  noctalia.toggleLauncher()
end

noctalia.state.watch("rates", render)
noctalia.state.watch("loading", render)
noctalia.state.watch("loaded", render)

function update()
  render()
end
