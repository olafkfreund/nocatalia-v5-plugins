-- Currency Exchange — launcher provider.

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

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function parseQuery(query, targetCurrency)
  -- Normalize: split "100PLN" into "100 PLN"
  local norm = query:gsub("(%d)(%a)", "%1 %2")
  local parts = {}
  for p in norm:gmatch("%S+") do
    if p ~= "TO" and p ~= "to" then
      table.insert(parts, p:upper())
    end
  end

  if #parts == 0 then
    return nil
  end

  local amount = 1.0
  local fromCurrency = nil
  local toCurrency = targetCurrency

  local firstNum = tonumber(parts[1])
  local startIdx = 1

  if firstNum and firstNum > 0 then
    amount = firstNum
    startIdx = 2
  end

  local currencies = {}
  for i = startIdx, #parts do
    table.insert(currencies, parts[i])
  end

  if #currencies == 0 then
    fromCurrency = noctalia.getConfig("sourceCurrency") or "USD"
    toCurrency = targetCurrency
  elseif #currencies == 1 then
    fromCurrency = currencies[1]
    if fromCurrency == targetCurrency then
      toCurrency = noctalia.getConfig("sourceCurrency") or "USD"
    end
  else
    fromCurrency = currencies[1]
    toCurrency = currencies[2]
  end

  return {
    amount = amount,
    from = fromCurrency,
    to = toCurrency
  }
end

function onQuery(query)
  local q = trim(query)
  local targetCurrency = noctalia.getConfig("targetCurrency") or "EUR"

  local loaded = noctalia.state.get("loaded") == true
  local loading = noctalia.state.get("loading") == true
  local rates = noctalia.state.get("rates")

  if loading then
    launcher.setResults(query, {
      {
        id = "info",
        title = noctalia.tr("launcher.loading") or "Loading exchange rates...",
        subtitle = noctalia.tr("launcher.fetching") or "Fetching from frankfurter.app",
        glyph = "refresh"
      }
    })
    return
  end

  if not loaded or not rates then
    launcher.setResults(query, {
      {
        id = "retry",
        title = noctalia.tr("panel.error") or "Could not load rates",
        subtitle = noctalia.tr("launcher.error_retry") or "Check your internet connection. Click to retry.",
        glyph = "alert-circle"
      }
    })
    return
  end

  if q == "" then
    -- Usage help
    launcher.setResults(query, {
      {
        id = "help1",
        title = "/fx 100 USD EUR",
        subtitle = noctalia.tr("launcher.convert_example") or "Convert 100 USD to EUR",
        glyph = "cash"
      },
      {
        id = "help2",
        title = `/fx 50 GBP`,
        subtitle = `Convert 50 GBP to {targetCurrency} (default)`,
        glyph = "cash"
      },
      {
        id = "help3",
        title = "/fx EUR GBP",
        subtitle = noctalia.tr("launcher.show_rate") or "Show rate for 1 EUR to GBP",
        glyph = "percentage"
      }
    })
    return
  end

  local parsed = parseQuery(q, targetCurrency)
  if not parsed or not rates[parsed.from] or (parsed.to and not rates[parsed.to]) then
    local invalid = parsed and (not rates[parsed.from] and parsed.from or parsed.to) or q
    launcher.setResults(query, {
      {
        id = "error",
        title = `Unknown currency: {invalid}`,
        subtitle = noctalia.tr("launcher.try_valid_code") or "Try a valid currency code (e.g., USD, EUR, PLN)",
        glyph = "alert-circle"
      }
    })
    return
  end

  local fromRate = rates[parsed.from]
  local toRate = rates[parsed.to]
  local rate = toRate / fromRate
  local result = parsed.amount * rate

  local resultStr = formatNumber(result)
  local rateStr = formatNumber(rate)

  local results = {
    {
      id = "copy_result",
      title = `{parsed.amount} {parsed.from} = {resultStr} {parsed.to}`,
      subtitle = `Rate: 1 {parsed.from} = {rateStr} {parsed.to} | Click to copy`,
      glyph = "cash"
    }
  }

  local reverseRate = fromRate / toRate
  table.insert(results, {
    id = "copy_reverse",
    title = `1 {parsed.to} = {formatNumber(reverseRate)} {parsed.from}`,
    subtitle = "Reverse rate | Click to copy",
    glyph = "arrows-exchange"
  })

  launcher.setResults(query, results)
end

function onActivate(id)
  local rates = noctalia.state.get("rates")
  if not rates then return end

  -- Parse active query from the launcher context
  local query = launcher.getQuery()
  local targetCurrency = noctalia.getConfig("targetCurrency") or "EUR"
  local parsed = parseQuery(query, targetCurrency)
  if not parsed then return end

  local fromRate = rates[parsed.from]
  local toRate = rates[parsed.to]
  local rate = toRate / fromRate

  if id == "copy_result" then
    local result = parsed.amount * rate
    noctalia.copyToClipboard(formatNumber(result), "text/plain")
    launcher.notify("Currency Exchange", "Result copied to clipboard")
  elseif id == "copy_reverse" then
    local reverseRate = fromRate / toRate
    noctalia.copyToClipboard(formatNumber(reverseRate), "text/plain")
    launcher.notify("Currency Exchange", "Reverse rate copied to clipboard")
  elseif id == "retry" then
    noctalia.state.set("command", "refresh")
  end
end
