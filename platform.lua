--[[
Copyright: Ren Tatsumoto and contributors
License: GNU GPL, version 3 or later; http://www.gnu.org/licenses/gpl.html

OS-related constants and functions.
]]

local h = require('helpers')
local mp = require('mp')
local utils = require('mp.utils')
local this = {}

this.Platform = {
    gnu_linux = "gnu_linux",
    macos = "macos",
    windows = "windows",
}
this.platform = (
        h.is_win() and this.Platform.windows
                or h.is_mac() and this.Platform.macos
                or this.Platform.gnu_linux
)
this.default_video_folder = utils.join_path(
        (os.getenv("HOME") or os.getenv("USERPROFILE")),
        (this.platform == this.Platform.macos and "Movies" or "Videos")
)
this.default_audio_folder = utils.join_path(
        (os.getenv("HOME") or os.getenv('USERPROFILE')),
        "Music"
)
this.curl_exe = (this.platform == this.Platform.windows and 'curl.exe' or 'curl')
this.open_utility = (
        this.platform == this.Platform.windows and 'explorer.exe'
                or this.platform == this.Platform.macos and 'open'
                or this.platform == this.Platform.gnu_linux and 'xdg-open'
)
this.open = function(file_or_url)
    return mp.commandv('run', this.open_utility, file_or_url)
end

this.clipboard = (function()
    local self = {}
    if this.platform == this.Platform.windows then
        self.clip_exe = "powershell.exe"
        self.copy = function(text)
            return h.subprocess({ self.clip_exe, '-command', 'Set-Clipboard -Value ' .. text })
        end
    elseif this.platform == this.Platform.macos then
        self.clip_exe = "pbcopy"
        self.copy = function(text)
            return h.subprocess({ self.clip_exe, }, text)
        end
    else
        self.clip_exe = h.is_wayland() and "wl-copy" or "xclip"
        self.copy = function(text)
            local handle = io.popen(h.is_wayland() and "wl-copy" or "xclip -i -selection clipboard", 'w')
            if handle then
                handle:write(text)
                local suc, exit, code = handle:close()
                return { status = code }
            else
                return { status = 1 }
            end
        end
    end
    return self
end)()

this.copy_or_open_url = function(url)
    local cb = this.clipboard.copy(url)
    if cb.status ~= 0 then
        local msg = string.format(
                "Failed to copy URL to clipboard, trying to open in browser instead. Make sure %s is installed.",
                this.clipboard.clip_exe
        )
        h.notify(msg, "warn", 4)
        this.open(url)
    else
        h.notify("Done! Copied URL to clipboard.", "info", 2)
    end
    return cb
end
return this
