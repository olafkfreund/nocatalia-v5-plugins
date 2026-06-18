-- Kagi Quick Search — launcher provider.
-- Queries Kagi's AI context API and displays the answer in the launcher.

local lastAnswer = ""
local lastAnsweredQuery = ""

function onQuery(query)
  local filter = query:lower():gsub("^%s+", ""):gsub("%s+$", "")
  if filter == "" then
    launcher.setResults(query, {
      {
        id = "hint",
        title = "Kagi Search",
        subtitle = "Type a query (min 10 characters) to get an answer from Kagi",
        glyph = "search"
      }
    })
    return
  end

  local token = launcher.getConfig("kagiSessionToken") or ""
  if token == "" then
    launcher.setResults(query, {
      {
        id = "error_token",
        title = "Kagi Session Token not configured",
        subtitle = "Configure kagiSessionToken in settings first",
        glyph = "alert-circle"
      }
    })
    return
  end

  if #filter < 10 then
    launcher.setResults(query, {
      {
        id = "hint_more",
        title = "Enter a longer query",
        subtitle = `Type at least {10 - #filter} more characters`,
        glyph = "search"
      }
    })
    return
  end

  if lastAnsweredQuery == filter then
    launcher.setResults(query, {
      {
        id = "answer",
        title = "Kagi Answer",
        subtitle = lastAnswer,
        glyph = "message-circle"
      }
    })
    return
  end

  launcher.setResults(query, {
    {
      id = "loading",
      title = "Searching Kagi...",
      subtitle = `Asking Kagi about: {filter}`,
      glyph = "loader"
    }
  })

  local escapedQuery = filter:gsub("'", "'\\''")
  local cmd = `curl -s -X POST -G 'https://kagi.com/mother/context' --data-urlencode 'q={escapedQuery}' `
    .. `-H 'accept: application/vnd.kagi.stream' `
    .. `-H 'accept-language: en-US,en;q=0.9' `
    .. `-H 'content-length: 0' `
    .. `-b 'kagi_session={token}' `
    .. `-H 'origin: https://kagi.com' `
    .. `--referer 'https://kagi.com/search?q={escapedQuery}' `
    .. `-H 'user-agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36' `
    .. `-H 'x-kagi-authorization: {token}' `
    .. `--output - | tail -1 | cut -d: -f2- | jq -r '.md' | sed 's/\\[\\^[0-9]*\\]//g; s/ \\././g'`

  noctalia.runAsync(cmd, function(res)
    if res.exitCode == 0 then
      local result = (res.stdout or res.body or ""):gsub("^%s+", ""):gsub("%s+$", "")
      if result ~= "" and result ~= "null" then
        lastAnswer = result
        lastAnsweredQuery = filter
        launcher.setResults(query, {
          {
            id = "answer",
            title = "Kagi Answer",
            subtitle = lastAnswer,
            glyph = "message-circle"
          }
        })
      else
        launcher.setResults(query, {
          {
            id = "no_answer",
            title = "No answer from Kagi",
            subtitle = "Kagi did not return an answer for this query.",
            glyph = "alert-circle"
          }
        })
      end
    else
      launcher.setResults(query, {
        {
          id = "error",
          title = "Kagi Search Failed",
          subtitle = `Failed to fetch answer. Exit code: {res.exitCode}`,
          glyph = "alert-circle"
        }
      })
    end
  end)
end

function onActivate(id)
  -- Copy answer to clipboard if activated
  if id == "answer" and lastAnswer ~= "" then
    local escaped = lastAnswer:gsub("'", "'\\''")
    noctalia.runAsync(`printf '%s' '{escaped}' | wl-copy`)
    launcher.notify("Kagi Search", "Answer copied to clipboard!")
  end
end
