-- Translator — launcher provider.
-- Translates text to the target language via Google Translate or DeepL.

local LANGUAGES = {
  fr = { name = "french", aliases = { "french", "français", "fr" } },
  en = { name = "english", aliases = { "english", "anglais", "en" } },
  es = { name = "spanish", aliases = { "spanish", "espagnol", "es" } },
  de = { name = "german", aliases = { "german", "allemand", "de" } },
  it = { name = "italian", aliases = { "italian", "italien", "it" } },
  pt = { name = "portuguese", aliases = { "portuguese", "portugais", "pt" } },
  ru = { name = "russian", aliases = { "russian", "russe", "ru" } },
  ja = { name = "japanese", aliases = { "japanese", "japonais", "ja" } },
  zh = { name = "chinese", aliases = { "chinese", "chinois", "zh" } },
  ko = { name = "korean", aliases = { "korean", "coréen", "ko" } },
  ar = { name = "arabic", aliases = { "arabic", "arabe", "ar" } },
  hi = { name = "hindi", aliases = { "hindi", "hi" } },
  nl = { name = "dutch", aliases = { "dutch", "néerlandais", "hollandais", "nl" } },
  pl = { name = "polish", aliases = { "polish", "polonais", "pl" } },
  sv = { name = "swedish", aliases = { "swedish", "suédois", "sv" } },
  da = { name = "danish", aliases = { "danish", "danois", "da" } },
  no = { name = "norwegian", aliases = { "norwegian", "norvégien", "no" } },
  fi = { name = "finnish", aliases = { "finnish", "finnois", "fi" } },
  cs = { name = "czech", aliases = { "czech", "tchèque", "cs" } },
  hu = { name = "hungarian", aliases = { "hungarian", "hongrois", "hu" } },
  ro = { name = "romanian", aliases = { "romanian", "roumain", "ro" } },
  tr = { name = "turkish", aliases = { "turkish", "turc", "tr" } },
  uk = { name = "ukrainian", aliases = { "ukrainian", "ukrainien", "uk" } },
  vi = { name = "vietnamese", aliases = { "vietnamese", "vietnamien", "vi" } },
  th = { name = "thai", aliases = { "thai", "thaï", "th" } },
  id = { name = "indonesian", aliases = { "indonesian", "indonésien", "id" } },
  el = { name = "greek", aliases = { "greek", "grec", "el" } },
  he = { name = "hebrew", aliases = { "hebrew", "hébreu", "he" } },
  bg = { name = "bulgarian", aliases = { "bulgarian", "bulgare", "bg" } },
  hr = { name = "croatian", aliases = { "croatian", "croate", "hr" } },
  sr = { name = "serbian", aliases = { "serbian", "serbe", "sr" } },
  sk = { name = "slovak", aliases = { "slovak", "slovaque", "sk" } },
  sl = { name = "slovenian", aliases = { "slovenian", "slovène", "sl" } },
  et = { name = "estonian", aliases = { "estonian", "estonien", "et" } },
  lv = { name = "latvian", aliases = { "latvian", "letton", "lv" } },
  lt = { name = "lithuanian", aliases = { "lithuanian", "lituanien", "lt" } },
  ca = { name = "catalan", aliases = { "catalan", "ca" } },
  is = { name = "icelandic", aliases = { "icelandic", "islandais", "is" } },
  mt = { name = "maltese", aliases = { "maltese", "maltais", "mt" } },
  bn = { name = "bengali", aliases = { "bengali", "bn" } },
  ur = { name = "urdu", aliases = { "urdu", "ourdou", "ur" } },
  fa = { name = "persian", aliases = { "persian", "persan", "farsi", "fa" } },
  sw = { name = "swahili", aliases = { "swahili", "sw" } },
  ms = { name = "malay", aliases = { "malay", "malais", "ms" } },
  tl = { name = "filipino", aliases = { "filipino", "tagalog", "philippin", "tl" } },
  af = { name = "afrikaans", aliases = { "afrikaans", "af" } },
  sq = { name = "albanian", aliases = { "albanian", "albanais", "sq" } },
  az = { name = "azerbaijani", aliases = { "azerbaijani", "azerbaïdjanais", "az" } },
  eu = { name = "basque", aliases = { "basque", "eu" } },
  be = { name = "belarusian", aliases = { "belarusian", "biélorusse", "be" } },
  bs = { name = "bosnian", aliases = { "bosnian", "bosniaque", "bs" } },
  gl = { name = "galician", aliases = { "galician", "galicien", "gl" } },
  ka = { name = "georgian", aliases = { "georgian", "géorgien", "ka" } },
  gu = { name = "gujarati", aliases = { "gujarati", "gu" } },
  ha = { name = "hausa", aliases = { "hausa", "haoussa", "ha" } },
  iw = { name = "hebrew", aliases = { "hebrew", "hébreu", "iw" } },
  hmn = { name = "hmong", aliases = { "hmong", "hmn" } },
  ig = { name = "igbo", aliases = { "igbo", "ig" } },
  ga = { name = "irish", aliases = { "irish", "irlandais", "ga" } },
  jw = { name = "javanese", aliases = { "javanese", "javanais", "jw" } },
  kk = { name = "kazakh", aliases = { "kazakh", "kk" } },
  km = { name = "khmer", aliases = { "khmer", "km" } },
  rw = { name = "kinyarwanda", aliases = { "kinyarwanda", "rw" } },
  ky = { name = "kyrgyz", aliases = { "kyrgyz", "kirghiz", "ky" } },
  lo = { name = "lao", aliases = { "lao", "lo" } },
  lb = { name = "luxembourgish", aliases = { "luxembourgish", "luxembourgeois", "lb" } },
  mk = { name = "macedonian", aliases = { "macedonian", "macédonien", "mk" } },
  mg = { name = "malagasy", aliases = { "malagasy", "malgache", "mg" } },
  ml = { name = "malayalam", aliases = { "malayalam", "ml" } },
  mi = { name = "maori", aliases = { "maori", "mi" } },
  mr = { name = "marathi", aliases = { "marathi", "mr" } },
  mn = { name = "mongolian", aliases = { "mongolian", "mongol", "mn" } },
  my = { name = "myanmar", aliases = { "myanmar", "birman", "my" } },
  ne = { name = "nepali", aliases = { "nepali", "népalais", "ne" } },
  ny = { name = "chichewa", aliases = { "chichewa", "ny" } },
  ps = { name = "pashto", aliases = { "pashto", "pachto", "ps" } },
  pa = { name = "punjabi", aliases = { "punjabi", "pendjabi", "pa" } },
  sm = { name = "samoan", aliases = { "samoan", "sm" } },
  gd = { name = "scots", aliases = { "scots", "écossais", "gd" } },
  sn = { name = "shona", aliases = { "shona", "sn" } },
  sd = { name = "sindhi", aliases = { "sindhi", "sd" } },
  si = { name = "sinhala", aliases = { "sinhala", "cingalais", "si" } },
  so = { name = "somali", aliases = { "somali", "so" } },
  su = { name = "sundanese", aliases = { "sundanese", "soundanais", "su" } },
  tg = { name = "tajik", aliases = { "tajik", "tadjik", "tg" } },
  ta = { name = "tamil", aliases = { "tamil", "tamoul", "ta" } },
  tt = { name = "tatar", aliases = { "tatar", "tt" } },
  te = { name = "telugu", aliases = { "telugu", "télougou", "te" } },
  uz = { name = "uzbek", aliases = { "uzbek", "ouzbek", "uz" } },
  cy = { name = "welsh", aliases = { "welsh", "gallois", "cy" } },
  xh = { name = "xhosa", aliases = { "xhosa", "xh" } },
  yi = { name = "yiddish", aliases = { "yiddish", "yi" } },
  yo = { name = "yoruba", aliases = { "yoruba", "yo" } },
  zu = { name = "zulu", aliases = { "zulu", "zoulou", "zu" } }
}

local translationCache = {}
local pendingTranslations = {}

local function getLanguageCode(input)
  if not input or input:gsub("%s+", "") == "" then return nil end
  local lower = input:lower():gsub("^%s+", ""):gsub("%s+$", "")
  for code, lang in LANGUAGES do
    if code == lower then return code end
    for _, alias in lang.aliases do
      if alias == lower then return code end
    end
  end
  if lower:match("^%a%a%a?$") then
    return lower
  end
  return nil
end

local function getDefaultLanguages()
  local list = {}
  local translatePrefix = noctalia.tr("translatePrefix") or "Translate to "
  for code, lang in LANGUAGES do
    local displayName = noctalia.tr("languageNames." .. lang.name) or (lang.name:sub(1,1):upper() .. lang.name:sub(2))
    table.insert(list, {
      code = code,
      name = displayName,
      desc = translatePrefix .. displayName
    })
  end
  table.sort(list, function(a, b) return a.name < b.name end)
  return list
end

local function urlEncode(s)
  return (s:gsub("[^%w%-_%.~]", function(c)
    return string.format("%%%02X", c:byte())
  end))
end

local function translateGoogle(text, targetLang, onDone)
  local url = "https://translate.google.com/translate_a/single?client=gtx&sl=auto&tl=" .. urlEncode(targetLang) .. "&dt=t&q=" .. urlEncode(text)
  noctalia.http({ url = url }, function(res)
    if not res.ok then
      onDone(nil, "messages.connectionError")
      return
    end
    local ok, decoded = pcall(noctalia.json.decode, res.body)
    if ok and type(decoded) == "table" and type(decoded[1]) == "table" then
      local parts = {}
      for _, segment in decoded[1] do
        if type(segment) == "table" and type(segment[1]) == "string" then
          table.insert(parts, segment[1])
        end
      end
      if #parts > 0 then
        onDone(table.concat(parts), nil)
      else
        onDone(nil, "messages.error")
      end
    else
      onDone(nil, "messages.error")
    end
  end)
end

local function translateDeepL(text, targetLang, onDone)
  local apiKey = (launcher.getConfig("deeplApiKey") or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if apiKey == "" then
    onDone(nil, "messages.missingApiKey")
    return
  end
  local host = "api.deepl.com"
  if apiKey:sub(-3) == ":fx" then
    host = "api-free.deepl.com"
  end
  local url = "https://" .. host .. "/v2/translate"
  local body = "text=" .. urlEncode(text) .. "&target_lang=" .. targetLang:upper()

  noctalia.http({
    url = url,
    method = "POST",
    headers = {
      ["Authorization"] = "DeepL-Auth-Key " .. apiKey,
      ["Content-Type"] = "application/x-www-form-urlencoded"
    },
    body = body
  }, function(res)
    if not res.ok then
      if res.status == 403 then
        onDone(nil, "messages.invalidApiKey")
      else
        onDone(nil, "messages.connectionError")
      end
      return
    end
    local ok, parsed = pcall(noctalia.json.decode, res.body)
    if ok and type(parsed) == "table" and type(parsed.translations) == "table" and parsed.translations[1] and type(parsed.translations[1].text) == "string" then
      onDone(parsed.translations[1].text, nil)
    else
      onDone(nil, "messages.error")
    end
  end)
end

local function translateText(text, targetLang, onDone)
  local backend = launcher.getConfig("backend") or "google"
  if backend == "google" then
    translateGoogle(text, targetLang, onDone)
  elseif backend == "deepl" then
    translateDeepL(text, targetLang, onDone)
  else
    onDone(nil, "messages.error")
  end
end

function onQuery(query)
  local normalized = query:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  local first, rest = normalized:match("^(%S+)%s*(.*)$")

  local targetLang = nil
  local textToTranslate = nil

  if first then
    local code = getLanguageCode(first)
    if code then
      targetLang = code
      textToTranslate = rest
    end
  end

  if not targetLang then
    -- Show list of default languages to select (filtered by the user's input)
    local list = getDefaultLanguages()
    local results = {}
    for _, lang in list do
      if normalized == "" or lang.name:lower():find(normalized:lower(), 1, true) or lang.code:lower():find(normalized:lower(), 1, true) then
        table.insert(results, {
          id = "lang:" .. lang.code,
          title = lang.name,
          subtitle = lang.desc,
          glyph = "language"
        })
      end
    end
    
    -- Limit results to 50 to avoid overwhelming UI
    local limitedResults = {}
    for i = 1, math.min(#results, 50) do
      table.insert(limitedResults, results[i])
    end
    launcher.setResults(query, limitedResults)
    return
  end

  -- A target language was parsed. Check if text to translate is empty.
  if textToTranslate == "" then
    local fmt = noctalia.tr("messages.targetLanguage") or "Target language: {code}"
    local desc = string.gsub(fmt, "{code}", targetLang)
    launcher.setResults(query, {
      {
        id = "enter_text",
        title = noctalia.tr("messages.enterText") or "Type text to translate...",
        subtitle = desc,
        glyph = "language"
      }
    })
    return
  end

  -- Text is present. Retrieve or fetch translation.
  local cacheKey = targetLang .. "|" .. textToTranslate
  local cached = translationCache[cacheKey]

  if cached then
    local fmt = noctalia.tr("messages.translation") or "Translation ({code})"
    local desc = string.gsub(fmt, "{code}", targetLang)
    launcher.setResults(query, {
      {
        id = "copy:" .. cacheKey,
        title = cached,
        subtitle = desc .. " — Press Enter to copy",
        glyph = "language"
      }
    })
    return
  end

  if pendingTranslations[cacheKey] then
    launcher.setResults(query, {
      {
        id = "translating",
        title = noctalia.tr("messages.translating") or "Translating...",
        subtitle = textToTranslate,
        glyph = "loader"
      }
    })
    return
  end

  local realTime = launcher.getConfig("realTimeTranslation") ~= false
  if realTime then
    pendingTranslations[cacheKey] = true
    launcher.setResults(query, {
      {
        id = "translating",
        title = noctalia.tr("messages.translating") or "Translating...",
        subtitle = textToTranslate,
        glyph = "loader"
      }
    })

    translateText(textToTranslate, targetLang, function(translated, err)
      pendingTranslations[cacheKey] = nil
      if err then
        local fmt = noctalia.tr(err) or err
        launcher.setResults(query, {
          {
            id = "error:" .. cacheKey,
            title = fmt,
            subtitle = textToTranslate,
            glyph = "alert-circle"
          }
        })
      else
        translationCache[cacheKey] = translated
        local fmt = noctalia.tr("messages.translation") or "Translation ({code})"
        local desc = string.gsub(fmt, "{code}", targetLang)
        launcher.setResults(query, {
          {
            id = "copy:" .. cacheKey,
            title = translated,
            subtitle = desc .. " — Press Enter to copy",
            glyph = "language"
          }
        })
      end
    end)
  else
    launcher.setResults(query, {
      {
        id = "press_enter:" .. cacheKey,
        title = noctalia.tr("messages.pressEnter") or "Press Enter to translate",
        subtitle = textToTranslate,
        glyph = "language"
      }
    })
  end
end

function onActivate(id)
  if id:sub(1, 5) == "lang:" then
    local code = id:sub(6)
    launcher.setSearchText(">translate " .. code .. " ")
  elseif id:sub(1, 5) == "copy:" then
    local cacheKey = id:sub(6)
    local translated = translationCache[cacheKey]
    if translated then
      local escaped = translated:gsub("'", "'\\''")
      noctalia.runAsync("printf '%s' '" .. escaped .. "' | wl-copy", function()
        local title = noctalia.tr("launcher.title") or "Translator"
        launcher.notify(title, "Translation copied to clipboard")
      end)
    end
  elseif id:sub(1, 12) == "press_enter:" then
    local cacheKey = id:sub(13)
    local targetLang, textToTranslate = cacheKey:match("^([^|]+)|(.*)$")
    if targetLang and textToTranslate then
      pendingTranslations[cacheKey] = true
      onQuery(launcher.getQuery())

      translateText(textToTranslate, targetLang, function(translated, err)
        pendingTranslations[cacheKey] = nil
        if err then
          local fmt = noctalia.tr(err) or err
          launcher.setResults(launcher.getQuery(), {
            {
              id = "error:" .. cacheKey,
              title = fmt,
              subtitle = textToTranslate,
              glyph = "alert-circle"
            }
          })
        else
          translationCache[cacheKey] = translated
          onQuery(launcher.getQuery())
        end
      end)
    end
  elseif id:sub(1, 6) == "error:" then
    local cacheKey = id:sub(7)
    local targetLang, textToTranslate = cacheKey:match("^([^|]+)|(.*)$")
    if targetLang and textToTranslate then
      pendingTranslations[cacheKey] = true
      onQuery(launcher.getQuery())

      translateText(textToTranslate, targetLang, function(translated, err)
        pendingTranslations[cacheKey] = nil
        if err then
          local fmt = noctalia.tr(err) or err
          launcher.setResults(launcher.getQuery(), {
            {
              id = "error:" .. cacheKey,
              title = fmt,
              subtitle = textToTranslate,
              glyph = "alert-circle"
            }
          })
        else
          translationCache[cacheKey] = translated
          onQuery(launcher.getQuery())
        end
      end)
    end
  end
end
