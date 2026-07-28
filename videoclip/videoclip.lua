--[[
Videoclip - mp4/webm clips creator for mpv.

Copyright (C) 2021 Ren Tatsumoto

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
]]

local mp = require('mp')
local OSD = require('osd_styler')
local p = require('platform')
local h = require('helpers')
local make_encoder = require('encoder.encoder')
local Timings = require('timings_mgr')
local cfg_mgr = require("config.config")

------------------------------------------------------------
-- System-dependent variables

-- Options can be changed in the config file.
-- Config path: ~/.config/mpv/script-opts/videoclip.conf
local config = cfg_mgr.read_config_file()
local encoder = make_encoder.new()
local main_menu
local pref_menu

------------------------------------------------------------
-- Utility functions

local function force_resolution(width, height, clip_fn, ...)
    local cached_prefs = {
        video_width = config.video_width,
        video_height = config.video_height,
    }
    config.video_width = width
    config.video_height = height
    clip_fn(...)
    config.video_width = cached_prefs.video_width
    config.video_height = cached_prefs.video_height
end

local function upload_to_catbox(outfile)
    local endpoint = config.litterbox and 'https://litterbox.catbox.moe/resources/internals/api.php' or 'https://catbox.moe/user/api.php'
    h.notify("Uploading to " .. (config.litterbox and "litterbox.catbox.moe..." or "catbox.moe..."), "info", 9999)

    -- This uses cURL to send a request to the cat-/litterbox API.
    -- cURL is included on Windows 10 and up, most Linux distributions and macOS.

    local r = h.subprocess({ -- This is technically blocking, but I don't think it has any real consequences ..?
        p.curl_exe, '-s',
        '-F', 'reqtype=fileupload',
        '-F', 'time=' .. config['litterbox_expire'],
        '-F', 'fileToUpload=@"' .. outfile .. '"',
        endpoint
    })

    -- Exit codes in the range [0, 99] are returned by cURL itself.
    -- Any other exit code means the shell failed to execute cURL.
    if r.status < 0 or r.status > 99 then
        h.notify_error("Error: Failed to upload. Make sure cURL is installed and in your PATH.", "error", 3)
        return
    elseif r.status ~= 0 then
        h.notify_error("Error: Failed to upload to " .. (config.litterbox and "litterbox.catbox.moe" or "catbox.moe"), "error", 2)
        return
    end

    mp.msg.info("Catbox URL: " .. r.stdout)
    -- Copy to clipboard
    p.copy_or_open_url(r.stdout)
end

local function upload_to_custom(outfile)
    h.notify("Upload to custom destination", "info", 9999)

    local raw_args = h.parse_command_args(config.custom_upload_command)
    local exec_args = {}

    for _, arg in ipairs(raw_args) do
        local clean_arg = arg:gsub('%%f', function()
            return outfile
        end)
        table.insert(exec_args, clean_arg)
    end

    local r = h.subprocess(exec_args)

    if r.status ~= 0 then
        h.notify_error("Error: Upload failed with exit code " .. r.status, "error", 2)
        mp.msg.error("Upload stderr: " .. (r.stderr or ""))
        return
    end

    -- Assumes the command outputs the URL to stdout
    mp.msg.info("Upload URL: " .. r.stdout)
    local url = h.strip(r.stdout)
    p.copy_or_open_url(url)
end

local function upload_video(outfile)
    if config.custom_upload_command ~= '' then
        upload_to_custom(outfile)
    else
        upload_to_catbox(outfile)
    end
end

local function fmt_upload_dest()
    local upload_dest
    if config.custom_upload_command ~= '' then
        upload_dest = 'custom upload'
    elseif config.litterbox then
        upload_dest = 'litterbox.catbox.moe (' .. config.litterbox_expire .. ')'
    else
        upload_dest = 'catbox.moe'
    end

    return upload_dest
end

------------------------------------------------------------
-- Menu interface

local Menu = {}
Menu.__index = Menu

function Menu:new(parent)
    local o = {
        parent = parent,
        overlay = parent and parent.overlay or mp.create_osd_overlay('ass-events'),
        keybindings = { },
    }
    return setmetatable(o, self)
end

function Menu:overlay_draw(text)
    self.overlay.data = text
    self.overlay:update()
end

function Menu:open()
    if self.parent then
        self.parent:close()
    end
    for _, val in pairs(self.keybindings) do
        mp.add_forced_key_binding(val.key, val.key, val.fn)
    end
    self:update()
end

function Menu:close()
    for _, val in pairs(self.keybindings) do
        mp.remove_key_binding(val.key)
    end
    if self.parent then
        self.parent:open()
    else
        self.overlay:remove()
    end
end

function Menu:update()
    local osd = OSD:new():config(config)
    osd:append('Dummy menu.'):newline()
    self:overlay_draw(osd:get_text())
end

------------------------------------------------------------
-- Main menu

main_menu = Menu:new()
main_menu.timings = Timings:new()

main_menu.keybindings = {
    { key = 's', fn = function()
        main_menu:set_time('start')
    end },
    { key = 'e', fn = function()
        main_menu:set_time('end')
    end },
    { key = 'S', fn = function()
        main_menu:set_time_sub('start')
    end },
    { key = 'E', fn = function()
        main_menu:set_time_sub('end')
    end },
    { key = 'r', fn = function()
        main_menu:reset_timings()
    end },
    { key = 'c', fn = function()
        main_menu:create_clip('video')
    end },
    { key = 'C', fn = function()
        force_resolution(1920, -2, encoder.create_clip, 'video')
    end },
    { key = 'a', fn = function()
        main_menu:create_clip('audio')
    end },
    { key = 'x', fn = function()
        main_menu:create_clip('video', upload_video)
    end },
    { key = 'X', fn = function()
        force_resolution(1920, -2, main_menu.create_clip, 'video', upload_video)
    end },
    { key = 'p', fn = function()
        pref_menu:open()
    end },
    { key = 'o', fn = function()
        p.open('https://streamable.com/')
    end },
    { key = 'ESC', fn = function()
        main_menu:close()
    end },
}

function main_menu:set_time(property)
    self.timings[property] = math.max(0, mp.get_property_number('time-pos'))
    self:update()
end

function main_menu:set_time_sub(property)
    local sub_delay = mp.get_property_native("sub-delay")
    local time_pos = mp.get_property_number(string.format("sub-%s", property))

    if time_pos == nil then
        h.notify_error("Warning: No subtitles visible.", "warn", 2)
        return
    end

    self.timings[property] = math.max(0, time_pos + sub_delay)
    self:update()
end

function main_menu:reset_timings()
    self.timings:reset()
    self:update()
end

main_menu.open = function()
    Menu.open(main_menu)
end

function main_menu:update()
    local osd = OSD:new():config(config)
    if not encoder.is_alive("mpv") then
        osd:red("Error: "):append("mpv is not found in the PATH."):newline()
    end
    if (config.use_ffmpeg or config.copy_streams) and not encoder.is_alive("ffmpeg") then
        osd:red("Error: "):append("ffmpeg is not found in the PATH. FFmpeg encoder is unavailable."):newline()
    end
    osd:submenu('Timings '):italics('(+shift use sub timings)'):newline()
    osd:tab():item('s: '):append('start time '):item(h.human_readable_time(self.timings['start'])):newline()
    osd:tab():item('e: '):append('end time '):item(h.human_readable_time(self.timings['end'])):newline()
    osd:tab():item('r: '):append('reset'):newline()
    osd:submenu('Create clip '):italics('(+shift to force fullHD preset)'):newline()
    osd:tab():item('c: '):append('video clip'):newline()
    osd:tab():item('a: '):append('audio clip'):newline()
    osd:tab():item('x: '):append('video clip to ' .. fmt_upload_dest()):newline()

    osd:submenu('Options '):newline()
    osd:tab():item('p: '):append('Open preferences'):newline()
    osd:tab():item('o: '):append('Open streamable.com'):newline()
    osd:tab():item('ESC: '):append('Close'):newline()

    self:overlay_draw(osd:get_text())
end

function main_menu:create_clip(clip_type, on_complete_fn)
    self:close()
    encoder.create_clip(clip_type, on_complete_fn)
end

------------------------------------------------------------
-- Preferences

pref_menu = Menu:new(main_menu)

pref_menu.keybindings = {
    { key = 'f', fn = function()
        pref_menu:cycle_video_formats()
    end },
    { key = 'a', fn = function()
        pref_menu:cycle_audio_formats()
    end },
    { key = 'm', fn = function()
        pref_menu:toggle_mute_audio()
    end },
    { key = 'r', fn = function()
        pref_menu:cycle_resolutions()
    end },
    { key = 'b', fn = function()
        pref_menu:cycle_video_bitrates()
    end },
    { key = 'B', fn = function()
        pref_menu:cycle_audio_bitrates()
    end },
    { key = 'e', fn = function()
        pref_menu:toggle_embed_subtitles()
    end },
    { key = 'g', fn = function()
        pref_menu:toggle_use_ffmpeg()
    end },
    { key = 'C', fn = function()
        pref_menu:toggle_copy_streams()
    end },
    { key = 'x', fn = function()
        pref_menu:toggle_catbox()
    end },
    { key = 'z', fn = function()
        pref_menu:cycle_litterbox_expiration()
    end },
    { key = 's', fn = function()
        pref_menu:save()
    end },
    { key = 'c', fn = function()
    end },
    { key = 'ESC', fn = function()
        pref_menu:close()
    end },
    { key = 'q', fn = function()
        pref_menu:close()
    end },
}

pref_menu.resolutions = {
    { w = config.video_width, h = config.video_height, },
    { w = -2, h = -2, },
    { w = -2, h = 240, },
    { w = -2, h = 360, },
    { w = -2, h = 480, },
    { w = -2, h = 720, },
    { w = -2, h = 1080, },
    { w = -2, h = 1440, },
    { w = -2, h = 2160, },
    selected = 1,
}
pref_menu.audio_bitrates = {
    config.audio_bitrate,
    '32k',
    '64k',
    '128k',
    '192k',
    '256k',
    '384k',
    selected = 1,
}
pref_menu.video_bitrates = {
    config.video_bitrate,
    '500k',
    '1M',
    '2M',
    '4M',
    '8M',
    '16M',
    selected = 1,
}

pref_menu.vid_formats = { 'mp4', 'vp9', 'vp8', }
pref_menu.aud_formats = { 'aac', 'opus', }
pref_menu.litterbox_expirations = { '1h', '12h', '24h', '72h', }

function pref_menu:get_selected_resolution()
    return string.format(
            '%s x %s',
            config.video_width == -2 and 'auto' or config.video_width,
            config.video_height == -2 and 'auto' or config.video_height
    )
end

function pref_menu:cycle_resolutions()
    self.resolutions.selected = self.resolutions.selected + 1 > #self.resolutions and 1 or self.resolutions.selected + 1
    local res = self.resolutions[self.resolutions.selected]
    config.video_width = res.w
    config.video_height = res.h
    self:update()
end

--- Cycle through a list of bitrate presets and update the corresponding config value.
--- @param bitrates_key string key into self (e.g. 'audio_bitrates', 'video_bitrates')
--- @param config_key string key into config (e.g. 'audio_bitrate', 'video_bitrate')
function pref_menu:cycle_bitrates(bitrates_key, config_key)
    self[bitrates_key].selected = self[bitrates_key].selected + 1 > #self[bitrates_key] and 1 or self[bitrates_key].selected + 1
    config[config_key] = self[bitrates_key][self[bitrates_key].selected]
    self:update()
end

function pref_menu:cycle_audio_bitrates()
    self:cycle_bitrates('audio_bitrates', 'audio_bitrate')
end

function pref_menu:cycle_video_bitrates()
    self:cycle_bitrates('video_bitrates', 'video_bitrate')
end

function pref_menu:cycle_formats(config_type)
    local formats
    if config_type == 'video_format' then
        formats = pref_menu.vid_formats
    else
        formats = pref_menu.aud_formats
    end

    local selected = 1
    for i, format in ipairs(formats) do
        if config[config_type] == format then
            selected = i
            break
        end
    end
    config[config_type] = formats[selected + 1] or formats[1]
    cfg_mgr.set_encoding_settings(config)
    self:update()
end

function pref_menu:cycle_video_formats()
    pref_menu:cycle_formats('video_format')
end

function pref_menu:cycle_audio_formats()
    pref_menu:cycle_formats('audio_format')
end

function pref_menu:toggle_mute_audio()
    mp.commandv("cycle", "mute")
    self:update()
end

function pref_menu:toggle_embed_subtitles()
    mp.commandv("cycle", "sub-visibility")
    self:update()
end

function pref_menu:toggle_use_ffmpeg()
    config.use_ffmpeg = not config.use_ffmpeg
    self:update()
end

function pref_menu:toggle_copy_streams()
    config.copy_streams = not config.copy_streams
    self:update()
end

function pref_menu:toggle_catbox()
    config['litterbox'] = not config['litterbox']
    self:update()
end

function pref_menu:cycle_litterbox_expiration()
    if not config['litterbox'] then
        return
    end
    local expirations = pref_menu.litterbox_expirations

    local selected = 1
    for i, expiration in ipairs(expirations) do
        if config['litterbox_expire'] == expiration then
            selected = i
            break
        end
    end
    config['litterbox_expire'] = expirations[selected + 1] or expirations[1]
    self:update()
end

function pref_menu:update()
    local osd = OSD:new():config(config)
    osd:submenu('Preferences'):newline()
    osd:tab():item('r: Video resolution: '):append(self:get_selected_resolution()):newline()
    osd:tab():item('b: Video bitrate: '):append(config.video_bitrate):newline()
    osd:tab():item('f: Video format: '):append(config.video_format):newline()
    osd:tab():item('a: Audio format: '):append(config.audio_format):newline()
    osd:tab():item('B: Audio bitrate: '):append(config.audio_bitrate):newline()
    osd:tab():item('g: Use FFmpeg: '):append(config.use_ffmpeg and 'yes' or 'no'):newline()
    osd:tab():item('C: Copy streams: '):append(config.copy_streams and 'yes' or 'no'):newline()
    osd:tab():item('m: Mute audio: '):append(mp.get_property("mute")):newline()
    osd:tab():item('e: Embed subtitles: '):append(mp.get_property("sub-visibility")):newline()
    osd:submenu('Catbox'):newline()
    osd:tab():item('x: Using: '):append(config.litterbox and 'Litterbox (temporary)' or 'Catbox (permanent)'):newline()
    if config.litterbox then
        osd:tab():item('z: Litterbox expires after: '):append(config.litterbox_expire):newline()
    else
        osd:tab():color("b0b0b0"):text('x: Litterbox expires after: '):append("N/A"):newline()
    end
    osd:submenu('Save'):newline()
    osd:tab():item('s: Save preferences'):newline()
    self:overlay_draw(osd:get_text())
end

function pref_menu:save()
    local result, error = cfg_mgr.save_config_file(config)
    if h.is_empty(error) then
        h.notify(result, "info", 4)
    else
        h.notify(error, "error", 4)
    end
end

------------------------------------------------------------
-- Tests

local function run_tests()
    h.run_tests()
    require('encoder.utils').run_tests()
    require('encoder.mpv').run_tests()
    require('encoder.ffmpeg').run_tests()
    make_encoder.run_tests()
end

local function pcall_tests()
    if os.getenv("VIDEOCLIP_TEST") == "TRUE" then
        mp.msg.warn("RUNNING TESTS")
        local success, err = pcall(run_tests)
        if success then
            mp.msg.warn("TESTS PASSED")
        else
            mp.msg.error("TESTS FAILED")
            mp.msg.error(err)
        end
        mp.commandv("quit")
    end
end

------------------------------------------------------------
-- Finally, set an 'entry point' in mpv

local main = (function()
    local main_executed = false
    return function()
        if main_executed then
            main_menu.timings:reset()
            return
        else
            main_executed = true
        end

        cfg_mgr.validate_config(config)
        encoder.init(config, main_menu.timings)
        pcall_tests()
        mp.add_key_binding('c', 'videoclip-menu-open', main_menu.open)
        mp.msg.warn("Press 'c' to open the videoclip menu.")
    end
end)()

mp.register_event("file-loaded", main)
