-- Todo List — desktop widget.

local todos = {}
local pages = { { id = 0, name = "General" } }
local current_page_id = 0

local clickFuncs = {}

local function promptInput(title, text, defaultVal, callback)
  local cmd = `zenity --entry --title='{title:gsub("'", "'\\''")}' --text='{text:gsub("'", "'\\''")}' --entry-text='{defaultVal:gsub("'", "'\\''")}' 2>/dev/null || kdialog --inputbox '{text:gsub("'", "'\\''")}' '{defaultVal:gsub("'", "'\\''")}' --title '{title:gsub("'", "'\\''")}' 2>/dev/null`
  noctalia.runAsync(cmd, function(res)
    if res.exitCode == 0 then
      local val = (res.stdout or res.body or ""):gsub("[\r\n]+$", "")
      if val ~= "" then
        callback(val)
      end
    end
  end)
end

function addTaskPrompt()
  promptInput("Add To-Do", "Task description:", "", function(val)
    noctalia.state.set("command", { action = "add", text = val, priority = "medium", pageId = current_page_id })
  end)
end

function addPagePrompt()
  promptInput("Add Page", "Page name:", "", function(val)
    noctalia.state.set("command", { action = "add_page", name = val })
  end)
end

function renamePagePrompt()
  local currentPageName = "Page"
  for _, p in pages do
    if p.id == current_page_id then
      currentPageName = p.name
      break
    end
  end
  promptInput("Rename Page", "New page name:", currentPageName, function(val)
    noctalia.state.set("command", { action = "rename_page", pageId = current_page_id, name = val })
  end)
end

function deleteCurrentPage()
  noctalia.state.set("command", { action = "delete_page", pageId = current_page_id })
end

function clearCompletedTasks()
  noctalia.state.set("command", { action = "clear_completed", pageId = current_page_id })
end

function exportAllTasks()
  noctalia.state.set("command", { action = "export" })
end

local function render()
  -- Clear previous dynamic callbacks
  for name, _ in clickFuncs do
    _G[name] = nil
  end
  clickFuncs = {}

  local pageTodos = {}
  for _, t in todos do
    if t.pageId == current_page_id then
      table.insert(pageTodos, t)
    end
  end

  local activeCount = 0
  for _, t in pageTodos do
    if not t.completed then
      activeCount += 1
    end
  end

  -- Build pages row
  local pageButtons = {}
  for _, page in pages do
    local selectPageName = `select_page_{page.id}`
    _G[selectPageName] = function()
      noctalia.state.set("command", { action = "set_page", pageId = page.id })
    end
    clickFuncs[selectPageName] = true

    table.insert(pageButtons, ui.button({
      text = page.name,
      variant = if page.id == current_page_id then "primary" else "outline",
      onClick = selectPageName
    }))
  end

  -- Build todo rows
  local todoRows = {}
  if #pageTodos == 0 then
    table.insert(todoRows, ui.label({
      text = noctalia.tr("desktop_widget.empty_state") or "No to-dos",
      fontSize = 13,
      color = "on_surface_variant",
      align = "center"
    }))
  else
    for _, todo in pageTodos do
      local toggleName = `toggle_todo_{todo.id}`
      _G[toggleName] = function()
        noctalia.state.set("command", { action = "toggle", id = todo.id })
      end
      clickFuncs[toggleName] = true

      local deleteName = `delete_todo_{todo.id}`
      _G[deleteName] = function()
        noctalia.state.set("command", { action = "delete", id = todo.id })
      end
      clickFuncs[deleteName] = true

      local cyclePriorityName = `cycle_priority_{todo.id}`
      _G[cyclePriorityName] = function()
        local nextPriority = "medium"
        if todo.priority == "high" then
          nextPriority = "medium"
        elseif todo.priority == "medium" then
          nextPriority = "low"
        elseif todo.priority == "low" then
          nextPriority = "high"
        end
        noctalia.state.set("command", { action = "change_priority", id = todo.id, priority = nextPriority })
      end
      clickFuncs[cyclePriorityName] = true

      local editTextName = `edit_text_{todo.id}`
      _G[editTextName] = function()
        promptInput("Edit To-Do", "Update task description:", todo.text, function(val)
          noctalia.state.set("command", { action = "edit_text", id = todo.id, text = val })
        end)
      end
      clickFuncs[editTextName] = true

      local checkboxText = if todo.completed then "✓" else "○"
      local priorityText = "M"
      local priorityVariant = "outline"
      if todo.priority == "high" then
        priorityText = "H"
        priorityVariant = "primary"
      elseif todo.priority == "low" then
        priorityText = "L"
        priorityVariant = "flat"
      end

      table.insert(todoRows, ui.row({ gap = 8, align = "center" }, {
        ui.button({
          text = checkboxText,
          variant = if todo.completed then "flat" else "outline",
          onClick = toggleName
        }),
        ui.label({
          text = todo.text,
          fontSize = 13,
          color = if todo.completed then "on_surface_variant" else "on_surface"
        }),
        ui.button({
          text = priorityText,
          variant = priorityVariant,
          onClick = cyclePriorityName
        }),
        ui.button({
          text = "✎",
          variant = "flat",
          onClick = editTextName
        }),
        ui.button({
          text = "✕",
          variant = "flat",
          onClick = deleteName
        })
      }))
    end
  end

  local statusText = ""
  if #pageTodos > 0 then
    statusText = (noctalia.tr("desktop_widget.items_count") or "{active} of {total} items")
      :gsub("{active}", tostring(activeCount))
      :gsub("{total}", tostring(#pageTodos))
  end

  -- Main Layout
  desktopWidget.render(ui.column({ gap = 12, padding = 16 }, {
    ui.row({ gap = 8, align = "center" }, {
      ui.label({
        text = noctalia.tr("desktop_widget.header_title") or "To-Do List",
        fontSize = 18,
        fontWeight = "bold",
        color = "primary"
      }),
      ui.label({
        text = statusText,
        fontSize = 11,
        color = "on_surface_variant"
      })
    }),
    ui.row({ gap = 6 }, pageButtons),
    ui.row({ gap = 6 }, {
      ui.button({ text = "+ Page", variant = "flat", onClick = "addPagePrompt" }),
      ui.button({ text = "Rename", variant = "flat", onClick = "renamePagePrompt" }),
      ui.button({ text = "Delete", variant = "flat", onClick = "deleteCurrentPage" })
    }),
    ui.column({ gap = 6 }, todoRows),
    ui.row({ gap = 8 }, {
      ui.button({ text = "+ Add Task", variant = "primary", onClick = "addTaskPrompt" }),
      ui.button({ text = "Clear Completed", variant = "outline", onClick = "clearCompletedTasks" }),
      ui.button({ text = "Export", variant = "outline", onClick = "exportAllTasks" })
    })
  }))
end

noctalia.state.watch("todos", function(val)
  todos = if type(val) == "table" then val else {}
  render()
end)

noctalia.state.watch("pages", function(val)
  pages = if type(val) == "table" then val else { { id = 0, name = "General" } }
  render()
end)

noctalia.state.watch("current_page_id", function(val)
  current_page_id = tonumber(val) or 0
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
