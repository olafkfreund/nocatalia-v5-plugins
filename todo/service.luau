-- Todo List — background service.
-- Handles loading, saving, modifications, and exporting of todo items.

noctalia.setUpdateInterval(5000) -- Occasional state sync if needed

local todos = {}
local pages = { { id = 0, name = "General" } }
local current_page_id = 0
local loaded = false

local function publishState()
  noctalia.state.set("todos", todos)
  noctalia.state.set("pages", pages)
  noctalia.state.set("current_page_id", current_page_id)
  
  local total = #todos
  local active = 0
  local completed = 0
  for _, t in todos do
    if t.completed then
      completed += 1
    else
      active += 1
    end
  end
  noctalia.state.set("active_count", active)
  noctalia.state.set("total_count", total)
  noctalia.state.set("completed_count", completed)
end

local function save()
  if not loaded then return end
  local home = noctalia.getenv("HOME") or "/tmp"
  local dir = `{home}/.cache/noctalia/plugins/todo`
  local path = `{dir}/todos.json`
  local payload = noctalia.json.encode({
    todos = todos,
    pages = pages,
    current_page_id = current_page_id
  })
  noctalia.runAsync(`mkdir -p '{dir}'`, function()
    noctalia.runAsync(`bash -c "printf '%s' '$1' > '$2'" -- '{payload:gsub("'", "'\\''")}' '{path}'`, function()
      publishState()
    end)
  end)
end

local function load()
  local home = noctalia.getenv("HOME") or "/tmp"
  local path = `{home}/.cache/noctalia/plugins/todo/todos.json`
  noctalia.runAsync(`test -f '{path}'`, function(res)
    if res.exitCode == 0 then
      noctalia.runAsync(`cat '{path}'`, function(catRes)
        local success, parsed = pcall(noctalia.json.decode, catRes.stdout or catRes.body)
        if success and type(parsed) == "table" then
          if type(parsed.todos) == "table" then
            todos = parsed.todos
          end
          if type(parsed.pages) == "table" then
            pages = parsed.pages
          end
          if type(parsed.current_page_id) == "number" then
            current_page_id = parsed.current_page_id
          end
        end
        loaded = true
        publishState()
      end)
    else
      loaded = true
      publishState()
    end
  end)
end

-- Initialize
load()

local function moveTodoToCorrectPosition(todoId)
  local index = nil
  for i, t in todos do
    if t.id == todoId then
      index = i
      break
    end
  end
  if not index then return end
  
  local movedTodo = table.remove(todos, index)
  local todoPageId = movedTodo.pageId
  
  local insertIndex = nil
  if movedTodo.completed then
    insertIndex = #todos + 1
  else
    insertIndex = 1
    for i, t in todos do
      if t.pageId == todoPageId then
        if t.completed then
          insertIndex = i
          break
        end
      end
      insertIndex = i + 1
    end
  end
  table.insert(todos, insertIndex, movedTodo)
end

local function getPriorityLabel(priority)
  if priority == "high" then
    return noctalia.tr("main.priority_high")
  elseif priority == "low" then
    return noctalia.tr("main.priority_low")
  else
    return noctalia.tr("main.priority_medium")
  end
end

local function generateExportMarkdown()
  local lines = {}
  local INDENT = "  "
  local ITEM_PREFIX = "- "
  local SUB_ITEM_PREFIX = INDENT .. "- "
  local DETAIL_PREFIX = INDENT .. INDENT .. "- "
  local showEmptySections = noctalia.getConfig("exportEmptySections") == true

  local totalCount = #todos
  local activeCount = 0
  for _, t in todos do
    if not t.completed then
      activeCount += 1
    end
  end
  local completedCount = totalCount - activeCount
  local exportDate = os.date("!%Y-%m-%dT%H:%M:%SZ")

  table.insert(lines, "---")
  table.insert(lines, "export_date: " .. exportDate)
  table.insert(lines, "total: " .. tostring(totalCount))
  table.insert(lines, "active: " .. tostring(activeCount))
  table.insert(lines, "completed: " .. tostring(completedCount))
  table.insert(lines, "---")
  table.insert(lines, "")
  table.insert(lines, "# " .. noctalia.tr("main.export_title"))
  table.insert(lines, "")

  for _, page in pages do
    local pageId = page.id
    local pageName = page.name

    local pageTodos = {}
    local activeTodos = {}
    local completedTodos = {}
    for _, t in todos do
      if t.pageId == pageId then
        table.insert(pageTodos, t)
        if t.completed then
          table.insert(completedTodos, t)
        else
          table.insert(activeTodos, t)
        end
      end
    end

    if showEmptySections or #pageTodos > 0 then
      local pageHeader = noctalia.tr("main.export_page_header"):gsub("{pageName}", pageName)
      table.insert(lines, "## " .. pageHeader)
      table.insert(lines, "")

      if showEmptySections or #activeTodos > 0 then
        local activeSection = noctalia.tr("main.export_active_section"):gsub("{count}", tostring(#activeTodos))
        table.insert(lines, "### " .. activeSection)
        table.insert(lines, "")
        for _, todo in activeTodos do
          local checkbox = "[ ]"
          local priorityLabel = getPriorityLabel(todo.priority)
          table.insert(lines, ITEM_PREFIX .. checkbox .. " " .. todo.text)
          table.insert(lines, SUB_ITEM_PREFIX .. noctalia.tr("main.export_priority") .. ": " .. priorityLabel)
          if todo.createdAt then
            local matchedDate = todo.createdAt:match("^[^T]+") or todo.createdAt
            table.insert(lines, SUB_ITEM_PREFIX .. noctalia.tr("main.export_created") .. ": " .. matchedDate)
          end
          if todo.details and todo.details:match("%S") then
            table.insert(lines, SUB_ITEM_PREFIX .. noctalia.tr("main.export_details") .. ":")
            for detailLine in todo.details:gmatch("[^\r\n]+") do
              table.insert(lines, DETAIL_PREFIX .. detailLine)
            end
          end
          table.insert(lines, "")
        end
      end

      if showEmptySections or #completedTodos > 0 then
        local completedSection = noctalia.tr("main.export_completed_section"):gsub("{count}", tostring(#completedTodos))
        table.insert(lines, "### " .. completedSection)
        table.insert(lines, "")
        for _, todo in completedTodos do
          local checkbox = "[x]"
          local priorityLabel = getPriorityLabel(todo.priority)
          table.insert(lines, ITEM_PREFIX .. checkbox .. " " .. todo.text)
          table.insert(lines, SUB_ITEM_PREFIX .. noctalia.tr("main.export_priority") .. ": " .. priorityLabel)
          if todo.createdAt then
            local matchedDate = todo.createdAt:match("^[^T]+") or todo.createdAt
            table.insert(lines, SUB_ITEM_PREFIX .. noctalia.tr("main.export_created") .. ": " .. matchedDate)
          end
          if todo.details and todo.details:match("%S") then
            table.insert(lines, SUB_ITEM_PREFIX .. noctalia.tr("main.export_details") .. ":")
            for detailLine in todo.details:gmatch("[^\r\n]+") do
              table.insert(lines, DETAIL_PREFIX .. detailLine)
            end
          end
          table.insert(lines, "")
        end
      end

      table.insert(lines, "---")
      table.insert(lines, "")
    end
  end

  return table.concat(lines, "\n")
end

local function exportTodos()
  local format = noctalia.getConfig("exportFormat") or "markdown"
  local content = ""
  local ext = ".md"

  if format == "json" then
    content = noctalia.json.encode(todos)
    ext = ".json"
  else
    content = generateExportMarkdown()
    ext = ".md"
  end

  local timestamp = os.date("%Y-%m-%d")
  local timeSuffix = os.date("%H-%M-%S")
  local fileName = `todo_{timestamp}_{timeSuffix}{ext}`
  local exportPath = noctalia.getConfig("exportPath") or "~/Documents"
  local expandedPath = noctalia.expandPath(exportPath)
  if expandedPath:sub(-1) == "/" then
    expandedPath = expandedPath:sub(1, -2)
  end
  local filePath = `{expandedPath}/{fileName}`

  noctalia.runAsync(`mkdir -p '{expandedPath}'`, function()
    noctalia.runAsync(`bash -c "printf '%s' '$1' > '$2'" -- '{content:gsub("'", "'\\''")}' '{filePath}'`, function(res)
      if res.exitCode == 0 then
        noctalia.notify("Exported successfully", filePath)
      else
        noctalia.notifyError("Export failed", "Failed to write export file")
      end
    end)
  end)
end

noctalia.state.watch("command", function(cmd)
  if type(cmd) ~= "table" then return end
  
  if cmd.action == "add" then
    local text = cmd.text
    if not text or not text:match("%S") then return end
    local priority = cmd.priority or "medium"
    local pageId = cmd.pageId or current_page_id
    
    local id = tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))
    local newTodo = {
      id = id,
      text = text,
      completed = false,
      createdAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
      pageId = pageId,
      priority = priority,
      details = ""
    }
    
    local insertIndex = 1
    for i, t in todos do
      if t.pageId == pageId then
        if t.completed then
          insertIndex = i
          break
        end
      end
      insertIndex = i + 1
    end
    table.insert(todos, insertIndex, newTodo)
    save()
    noctalia.notify(noctalia.tr("main.added_new_todo") .. text)
  
  elseif cmd.action == "toggle" then
    local id = cmd.id
    for _, t in todos do
      if t.id == id then
        t.completed = not t.completed
        moveTodoToCorrectPosition(id)
        local status = if t.completed then noctalia.tr("main.todo_completed") else noctalia.tr("main.todo_marked_incomplete")
        noctalia.notify(noctalia.tr("main.todo_status_changed") .. status)
        save()
        break
      end
    end
    
  elseif cmd.action == "delete" then
    local id = cmd.id
    for i, t in todos do
      if t.id == id then
        table.remove(todos, i)
        save()
        noctalia.notify(noctalia.tr("main.removed_todo"))
        break
      end
    end
    
  elseif cmd.action == "clear_completed" then
    local pageId = cmd.pageId or current_page_id
    local active = {}
    local cleared = 0
    for _, t in todos do
      if t.pageId == pageId and t.completed then
        cleared += 1
      else
        table.insert(active, t)
      end
    end
    todos = active
    save()
    noctalia.notify(noctalia.tr("main.cleared_completed_todos") .. tostring(cleared) .. noctalia.tr("main.completed_todos_suffix"))
    
  elseif cmd.action == "clear_all" then
    todos = {}
    save()
    noctalia.notify(noctalia.tr("main.cleared_all_todos"))
    
  elseif cmd.action == "change_priority" then
    local id = cmd.id
    local priority = cmd.priority
    for _, t in todos do
      if t.id == id then
        t.priority = priority
        save()
        noctalia.notify(noctalia.tr("main.updated_todo_priority"))
        break
      end
    end
    
  elseif cmd.action == "edit_text" then
    local id = cmd.id
    local text = cmd.text
    for _, t in todos do
      if t.id == id then
        t.text = text
        save()
        noctalia.notify(noctalia.tr("main.updated_todo"))
        break
      end
    end
    
  elseif cmd.action == "edit_details" then
    local id = cmd.id
    local details = cmd.details
    for _, t in todos do
      if t.id == id then
        t.details = details
        save()
        noctalia.notify(noctalia.tr("main.updated_todo"))
        break
      end
    end
    
  elseif cmd.action == "set_page" then
    current_page_id = cmd.pageId
    save()
    
  elseif cmd.action == "add_page" then
    local name = cmd.name
    if not name or not name:match("%S") then return end
    local exists = false
    local maxId = 0
    for _, p in pages do
      if p.name:lower() == name:lower() then
        exists = true
      end
      if p.id > maxId then
        maxId = p.id
      end
    end
    if exists then
      noctalia.notifyError("Page exists", "A page with that name already exists")
    else
      table.insert(pages, { id = maxId + 1, name = name })
      save()
      noctalia.notify("Page added: " .. name)
    end
    
  elseif cmd.action == "delete_page" then
    local pageId = cmd.pageId
    if pageId == 0 then
      noctalia.notifyError("Error", "Cannot delete default page")
      return
    end
    for _, t in todos do
      if t.pageId == pageId then
        t.pageId = 0
      end
    end
    for i, p in pages do
      if p.id == pageId then
        table.remove(pages, i)
        break
      end
    end
    if current_page_id == pageId then
      current_page_id = 0
    end
    save()
    noctalia.notify("Page deleted")
    
  elseif cmd.action == "rename_page" then
    local pageId = cmd.pageId
    local name = cmd.name
    if not name or not name:match("%S") then return end
    local exists = false
    for _, p in pages do
      if p.id ~= pageId and p.name:lower() == name:lower() then
        exists = true
      end
    end
    if exists then
      noctalia.notifyError("Page exists", "A page with that name already exists")
    else
      for _, p in pages do
        if p.id == pageId then
          p.name = name
          break
        end
      end
      save()
      noctalia.notify("Page renamed to " .. name)
    end
    
  elseif cmd.action == "export" then
    exportTodos()
  end
end)

function update()
  -- No periodic work necessary beyond on-demand commands, but keep service ticking
end
