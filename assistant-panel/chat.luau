-- Assistant Panel — AI Chat launcher provider.
-- Communicates with Gemini, OpenAI, Claude, or Ollama.

local lastResponse = ""

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function hintRow(title, subtitle, glyph)
  return { id = "hint", title = title, subtitle = subtitle, glyph = glyph }
end

local function resultRows(text)
  local rows = {}
  table.insert(rows, {
    id = "copy_all",
    title = "Copy Response",
    subtitle = "Copy all output to clipboard",
    glyph = "copy",
  })

  local lineCount = 0
  for line in text:gmatch("[^\r\n]+") do
    if line:gsub("%s+", "") ~= "" then
      lineCount += 1
      if lineCount > 10 then
        table.insert(rows, {
          id = "more_lines",
          title = "...",
          subtitle = "More output available. Press Copy above.",
          glyph = "more-horizontal",
        })
        break
      end
      table.insert(rows, {
        id = `line_{lineCount}`,
        title = line,
        subtitle = `Line {lineCount}`,
        glyph = "align-left",
      })
    end
  end

  if lineCount == 0 then
    table.insert(rows, {
      id = "empty",
      title = "Empty response",
      subtitle = "",
      glyph = "alert-circle",
    })
  end

  return rows
end

local function callGemini(prompt, apiKey, model, temp, systemPrompt, callback)
  local url = `https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={apiKey}`
  local fullPrompt = systemPrompt .. "\n\nQuery: " .. prompt
  local body = noctalia.json.encode({
    contents = {
      {
        role = "user",
        parts = { { text = fullPrompt } }
      }
    },
    generationConfig = {
      temperature = temp
    }
  })

  noctalia.http({
    url = url,
    method = "POST",
    headers = { ["Content-Type"] = "application/json" },
    body = body
  }, function(res)
    if not res.ok then
      callback(nil, `HTTP error {res.status}: {res.body or "Unknown error"}`)
      return
    end
    local ok, parsed = pcall(noctalia.json.decode, res.body)
    if not ok or type(parsed) ~= "table" then
      callback(nil, "Failed to decode response JSON")
      return
    end

    local text = nil
    if parsed.candidates and parsed.candidates[1] and parsed.candidates[1].content and parsed.candidates[1].content.parts and parsed.candidates[1].content.parts[1] then
      text = parsed.candidates[1].content.parts[1].text
    end

    if text then
      callback(text, nil)
    else
      callback(nil, "Response did not contain text content")
    end
  end)
end

local function callOpenAI(prompt, apiKey, model, temp, systemPrompt, callback)
  local url = "https://api.openai.com/v1/chat/completions"
  local body = noctalia.json.encode({
    model = model,
    messages = {
      { role = "system", content = systemPrompt },
      { role = "user", content = prompt }
    },
    temperature = temp
  })

  noctalia.http({
    url = url,
    method = "POST",
    headers = {
      ["Content-Type"] = "application/json",
      ["Authorization"] = "Bearer " .. apiKey
    },
    body = body
  }, function(res)
    if not res.ok then
      callback(nil, `HTTP error {res.status}: {res.body or "Unknown error"}`)
      return
    end
    local ok, parsed = pcall(noctalia.json.decode, res.body)
    if not ok or type(parsed) ~= "table" then
      callback(nil, "Failed to decode response JSON")
      return
    end

    local text = nil
    if parsed.choices and parsed.choices[1] and parsed.choices[1].message then
      text = parsed.choices[1].message.content
    end

    if text then
      callback(text, nil)
    else
      callback(nil, "Response did not contain message content")
    end
  end)
end

local function callAnthropic(prompt, apiKey, model, temp, systemPrompt, callback)
  local url = "https://api.anthropic.com/v1/messages"
  local body = noctalia.json.encode({
    model = model,
    system = systemPrompt,
    messages = {
      { role = "user", content = prompt }
    },
    max_tokens = 1024,
    temperature = temp
  })

  noctalia.http({
    url = url,
    method = "POST",
    headers = {
      ["Content-Type"] = "application/json",
      ["x-api-key"] = apiKey,
      ["anthropic-version"] = "2023-06-01"
    },
    body = body
  }, function(res)
    if not res.ok then
      callback(nil, `HTTP error {res.status}: {res.body or "Unknown error"}`)
      return
    end
    local ok, parsed = pcall(noctalia.json.decode, res.body)
    if not ok or type(parsed) ~= "table" then
      callback(nil, "Failed to decode response JSON")
      return
    end

    local text = nil
    if parsed.content and parsed.content[1] then
      text = parsed.content[1].text
    end

    if text then
      callback(text, nil)
    else
      callback(nil, "Response did not contain content text")
    end
  end)
end

local function callOllama(prompt, model, temp, systemPrompt, callback)
  local url = "http://localhost:11434/api/chat"
  local body = noctalia.json.encode({
    model = model,
    messages = {
      { role = "system", content = systemPrompt },
      { role = "user", content = prompt }
    },
    options = {
      temperature = temp
    },
    stream = false
  })

  noctalia.http({
    url = url,
    method = "POST",
    headers = { ["Content-Type"] = "application/json" },
    body = body
  }, function(res)
    if not res.ok then
      callback(nil, `HTTP error {res.status}: Ollama not running or model not found?`)
      return
    end
    local ok, parsed = pcall(noctalia.json.decode, res.body)
    if not ok or type(parsed) ~= "table" then
      callback(nil, "Failed to decode response JSON")
      return
    end

    local text = nil
    if parsed.message then
      text = parsed.message.content
    end

    if text then
      callback(text, nil)
    else
      callback(nil, "Response did not contain message content")
    end
  end)
end

function onQuery(query)
  local prompt = trim(query)
  if prompt == "" then
    launcher.setResults(query, {
      hintRow("Ask AI Assistant", "Type your question...", "message-code")
    })
    return
  end

  local provider = launcher.getConfig("ai_provider") or "google"
  local apiKey = launcher.getConfig("ai_apiKey") or ""
  local model = launcher.getConfig("ai_model") or "gemini-2.5-flash"
  local tempVal = tonumber(launcher.getConfig("ai_temperature")) or 0.7
  local systemPrompt = launcher.getConfig("ai_systemPrompt") or "You are a helpful assistant."

  -- Check API Key
  if provider ~= "ollama" and apiKey == "" then
    launcher.setResults(query, {
      {
        id = "error",
        title = "API Key Missing",
        subtitle = `Please set the API Key for {provider} in Plugin Settings`,
        glyph = "alert-triangle"
      }
    })
    return
  end

  launcher.setResults(query, {
    hintRow("AI is thinking...", prompt, "loader")
  })

  local function handleResponse(text, err)
    if err then
      lastResponse = err
      launcher.setResults(query, {
        {
          id = "error",
          title = "AI Error",
          subtitle = err,
          glyph = "alert-triangle"
        }
      })
    else
      lastResponse = text
      launcher.setResults(query, resultRows(text))
    end
  end

  if provider == "google" then
    callGemini(prompt, apiKey, model, tempVal, systemPrompt, handleResponse)
  elseif provider == "openai" then
    callOpenAI(prompt, apiKey, model, tempVal, systemPrompt, handleResponse)
  elseif provider == "anthropic" then
    callAnthropic(prompt, apiKey, model, tempVal, systemPrompt, handleResponse)
  elseif provider == "ollama" then
    callOllama(prompt, model, tempVal, systemPrompt, handleResponse)
  else
    handleResponse(nil, "Invalid AI provider configured")
  end
end

function onActivate(id)
  if id == "copy_all" and lastResponse ~= "" then
    noctalia.copyToClipboard(lastResponse, "text/plain")
    launcher.notify("Assistant Panel", "Response copied to clipboard")
  end
end
