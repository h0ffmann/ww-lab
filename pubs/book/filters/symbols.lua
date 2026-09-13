-- symbols.lua — DejaVu Serif has no dingbats / misc symbols / emoji; set those characters in
-- the Sans face (\symbolfont, defined in template.tex) so xelatex never drops a glyph.
local function is_symbol(cp)
  return (cp >= 0x2600 and cp <= 0x27BF) or (cp >= 0x1F300 and cp <= 0x1FAFF) or (cp >= 0x2B00 and cp <= 0x2BFF)
end

local function split(s)
  local out, buf, insym = {}, {}, nil
  for _, cp in utf8.codes(s) do
    local sym = is_symbol(cp)
    if insym ~= nil and sym ~= insym then
      table.insert(out, { text = table.concat(buf), sym = insym }); buf = {}
    end
    table.insert(buf, utf8.char(cp)); insym = sym
  end
  if #buf > 0 then table.insert(out, { text = table.concat(buf), sym = insym }) end
  return out
end

function Str(el)
  local needs = false
  for _, cp in utf8.codes(el.text) do if is_symbol(cp) then needs = true; break end end
  if not needs then return nil end
  local inl = {}
  for _, part in ipairs(split(el.text)) do
    if part.sym then
      table.insert(inl, pandoc.RawInline("latex", "{\\symbolfont " .. part.text .. "}"))
    else
      table.insert(inl, pandoc.Str(part.text))
    end
  end
  return inl
end
