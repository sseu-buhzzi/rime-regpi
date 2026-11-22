local data = require("regsp_preedit_data")

local function spell_zhusinh(initial, final_key)
  local override = data.overrides[initial]
  if override ~= nil and override[final_key] ~= nil then
    return override[final_key]
  end

  local final = data.final_by_key[final_key]
  local final_override = data.final_overrides[final]
  if final_override ~= nil and final_override.initials[initial] == true then
    final = final_override.final
  end

  local initial_zhusinh = data.initial_zhusinh[initial]
  local final_zhusinh = data.final_zhusinh[final]

  return initial_zhusinh .. final_zhusinh
end

local function build_trie()
  local trie = {}
  local function insert(word, value)
    local node = trie
    for i = 1, #word do
      local ch = word:sub(i, i)
      local child = node[ch]
      if child == nil then
        child = {}
        node[ch] = child
      end
      node = child
    end
    node.value = value
  end

  for initial_key, initial in pairs(data.initial_by_key) do
    local initial_zhusinh = data.initial_zhusinh[initial]
    if initial_zhusinh ~= nil then
      insert(initial_key, initial_zhusinh)
      for final_key in pairs(data.final_by_key) do
        local zhusinh = spell_zhusinh(initial, final_key)
        insert(initial_key .. final_key, zhusinh)
        for tone_key, tone_mark in pairs(data.tone_marks) do
          insert(initial_key .. final_key .. tone_key, zhusinh .. tone_mark)
        end
      end
    end
  end
  return trie
end

local trie = build_trie()

local function is_boundary(ch)
  return ch == " " or ch == "'"
end

local function deepest_match(text, i)
  local node = trie
  local value = nil
  local length = 0
  local j = i
  while j <= #text do
    local child = node[text:sub(j, j)]
    if child == nil then
      break
    end
    node = child
    j = j + 1
    if node.value ~= nil then
      value = node.value
      length = j - i
    end
  end
  return value, length
end

local function decode(text)
  local out = {}
  local i = 1
  while i <= #text do
    local ch = text:sub(i, i)
    if is_boundary(ch) then
      table.insert(out, " ")
      i = i + 1
    else
      local value, length = deepest_match(text, i)
      if value ~= nil then
        table.insert(out, value)
        i = i + length
      else
        table.insert(out, ch)
        i = i + 1
      end
    end
  end
  return table.concat(out)
end

local function filter(input, env)
  local cache = {}
  for cand in input:iter() do
    local text = cand.preedit
    if text == nil or text == "" then
      text = env.engine.context.input
    end
    local decoded = cache[text]
    if decoded == nil then
      decoded = decode(text)
      cache[text] = decoded
    end
    cand:get_genuine().preedit = decoded
    yield(cand)
  end
end

return { func = filter }
