local M = {}

local preview_script_path = os.getenv("HOME") .. "/.config/yazi/plugins/preview.yazi/preview.sh"

function string:startswith(start)
  return self:sub(1, #start) == start
end

function M:split_area(arg)
  local x, y, w, h = self.area.x, self.area.y, self.area.w, self.area.h
  local top = ui.Rect({ x = x, y = y, w = w, h = h * arg })
  local bottom = ui.Rect({ x = x, y = y + h * arg, w = w, h = h * (1 - arg) })
  return top, bottom
end

function M:peek()
  local limit = self.area.h
  local offset = self.skip
  local text_offset = self.skip * (self.area.h / 2)
  local child = Command(preview_script_path)
    -- local child = Command.new("echo")
    :args({
      "--path",
      tostring(self.file.url),
      -- tostring(self.file.cha.is_dir),
      "--width",
      tostring(self.area.w),
      "--height",
      tostring(self.area.h),
      "--offset",
      tostring(offset),
      -- tostring(self.file.mime()),
    })
    :stdout(Command.PIPED)
    :stderr(Command.PIPED)
    :spawn()

  local text_area = self.area
  local i, lines, disable_peek = 0, {}, false
  repeat
    local line, event = child:read_line()
    if event ~= 0 and event ~= 1 then
      break
    end

    if i == 0 then
      local image_path = line:match("^__preview__image__path__ (.+)\n")
      if image_path then
        text_offset = 1
        disable_peek = true
        limit = limit / 2
        local top, bottom = self:split_area(0.4)
        text_area = bottom
        ya.image_show(Url(image_path), top)
      elseif line == "__disable_auto_peek__\n" then
        disable_peek = true
        text_offset = 1
      end
    end

    i = i + 1
    if i > text_offset then
      table.insert(lines, line)
    end
  until i >= text_offset + limit

  if i < limit then
    local status = child:wait()
    local code = status and status:code() or 0

    if code == 3 then
      -- 3 表示: 预览滚动溢出,需要往上退一下
      ya.manager_emit(
        "peek",
        { tostring(math.max(0, offset - 1)), only_if = tostring(self.file.url), upper_bound = "" }
      )
      return
    end
  else
    child:start_kill()
  end

  if not disable_peek and text_offset > 0 and i < text_offset + limit / 2 then
    ya.manager_emit("peek", { tostring(math.max(0, offset - 1)), only_if = tostring(self.file.url), upper_bound = "" })
  else
    ya.preview_widgets(self, { ui.Paragraph.parse(text_area, table.concat(lines, ""):gsub("\t", "  ")) })
  end
end

function M:seek(units)
  local h = cx.active.current.hovered
  if h and h.url == self.file.url then
    ya.manager_emit("peek", {
      tostring(math.max(0, cx.active.preview.skip + (units > 0 and 1 or -1))),
      only_if = tostring(self.file.url),
    })
  end
end

return M
