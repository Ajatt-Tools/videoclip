--[[
Copyright: Ren Tatsumoto and contributors
License: GNU GPL, version 3 or later; http://www.gnu.org/licenses/gpl.html

Various helper functions.
]]

local mp = require('mp')
local this = {}
local ass_start = mp.get_property_osd("osd-ass-cc/0")

this.is_wayland = function()
    return os.getenv('WAYLAND_DISPLAY') ~= nil
end

this.is_win = function()
    return mp.get_property("platform") == "windows"
end

this.is_mac = function()
    return mp.get_property("platform") == "darwin"
end

this.notify = function(message, level, duration)
    level = level or 'info'
    duration = duration or 1
    mp.msg[level](message)
    mp.osd_message(ass_start .. "{\\fs12}{\\bord0.75}" .. message, duration)
end

this.notify_error = function(message, level, duration)
    this.notify("{\\c&H7171f8&}" .. message, level, duration)
end

this.subprocess = function(args, stdin)
    local command_table = {
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        capture_stderr = true,
        args = args,
        stdin_data = (stdin or ""),
    }
    return mp.command_native(command_table)
end

this.subprocess_async = function(args, on_complete)
    local command_table = {
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        capture_stderr = true,
        args = args
    }
    return mp.command_native_async(command_table, on_complete)
end

this.remove_extension = function(filename)
    return filename:gsub('%.%w+$', '')
end

this.remove_text_in_brackets = function(str)
    return str:gsub('%b[]', '')
end

this.remove_special_characters = function(str)
    return str:gsub('[%-_]', ' '):gsub('[%c%p]', ''):gsub('%s+', ' ')
end

this.strip = function(str)
    return str:gsub("^%s*(.-)%s*$", "%1")
end

this.two_digit = function(num)
    return string.format("%02d", num)
end

this.twelve_hour = function(num)
  local sign = "pm"
  local hour = num

  if num > 12 then
      hour = hour - 12
  else
      sign = "am"
  end

  return { sign = sign, hour = hour }
end

this.expand_path = function (str)
    return mp.command_native({"expand-path", str})
end

this.human_readable_time = function(seconds)
    if type(seconds) ~= 'number' or seconds < 0 then
        return 'empty'
    end

    local parts = {}

    parts.h = math.floor(seconds / 3600)
    parts.m = math.floor(seconds / 60) % 60
    parts.s = math.floor(seconds % 60)
    parts.ms = math.floor((seconds * 1000) % 1000)

    local ret = string.format("%02dm%02ds%03dms", parts.m, parts.s, parts.ms)

    if parts.h > 0 then
        ret = string.format('%dh%s', parts.h, ret)
    end

    return ret
end

this.quote_if_necessary = function(args)
    local ret = {}
    for _, v in ipairs(args) do
        if v:find(" ", 1, true) or v:find("[", 1, true) then
            table.insert(ret, (v:find("'") and string.format('"%s"', v) or string.format("'%s'", v)))
        else
            table.insert(ret, v)
        end
    end
    return ret
end

this.query_xdg_user_dir = function(name)
    local r = this.subprocess({ "xdg-user-dir", name })
    if r.status == 0 then
        return this.strip(r.stdout)
    end
    return nil
end

this.query_user_home_dir = function()
    --- "USERPROFILE" is used on ReactOS and other Windows-like systems.
    return os.getenv("HOME") or os.getenv("USERPROFILE")
end

this.clean_forbidden_characters = function(title)
    return title:gsub('[<>:"/\\|%?%*]+', '.')
end

this.truncate_utf8_bytes = function(s, max_bytes)
    local size = #s
    local idx = 1

    if size <= max_bytes then
        return s
    end

    while idx <= size do
        local b = s:byte(idx)
        local char_len = 1
        if not b then
            break
        end

        if b <= 0x7F then
            char_len = 1
        elseif b >= 0xC2 and b <= 0xDF then
            char_len = 2
        elseif b >= 0xE0 and b <= 0xEF then
            char_len = 3
        elseif b >= 0xF0 and b <= 0xF4 then
            char_len = 4
        else
            break
        end

        if idx-1 + char_len > max_bytes then
            break
        end

        idx = idx + char_len
    end

    if idx <= 1 then
        return "new_file"
    end
    return s:sub(1, idx-1)
end

return this
