--[[
Copyright: Ren Tatsumoto and contributors
License: GNU GPL, version 3 or later; http://www.gnu.org/licenses/gpl.html

Various helper functions.
]]

local mp = require('mp')
local this = {}

this.is_wayland = function()
    return os.getenv('WAYLAND_DISPLAY') ~= nil
end

this.is_win = function()
    return mp.get_property('options/vo-mmcss-profile') ~= nil
end

this.is_mac = function()
    return mp.get_property('options/macos-force-dedicated-gpu') ~= nil
end

this.notify = function(message, level, duration)
    level = level or 'info'
    duration = duration or 1
    mp.msg[level](message)
    mp.osd_message(message, duration)
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

return this
