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

local NAME = 'videoclip'
local mp = require('mp')
local mpopt = require('mp.options')
local utils = require('mp.utils')
local OSD = require('osd_styler')

-- Options can be changed here or in a separate config file.
-- Config path: ~/.config/mpv/script-opts/videoclip.conf
local config = {
    -- absolute paths
    -- relative paths (e.g. ~ for home dir) do NOT work.
    video_folder_path = string.format('%s/Videos/', os.getenv("HOME") or os.getenv('USERPROFILE')),
    audio_folder_path = string.format('%s/Music/', os.getenv("HOME") or os.getenv('USERPROFILE')),
    -- The range of the CRF scale is 0–51, where 0 is lossless,
    -- 23 is the default, and 51 is worst quality possible.
    -- Insane values like 9999 still work but produce the worst quality.
    video_quality = 23,
    -- Use the slowest preset that you have patience for.
    -- https://trac.ffmpeg.org/wiki/Encode/H.264
    preset = 'faster',
    video_format = 'mp4', -- mp4, vp9, vp8
    video_bitrate = '1M',
    video_width = -2,
    video_height = 480,
    video_fps = 'auto',
    audio_format = 'opus', -- aac, opus
    audio_bitrate = '32k', -- 32k, 64k, 128k, 256k. aac requires higher bitrates.
    font_size = 24,
    clean_filename = true,
}

mpopt.read_options(config, NAME)
local main_menu
local pref_menu
local encoder
local Timings

local allowed_presets = {
    ultrafast = true,
    superfast = true,
    veryfast = true,
    faster = true,
    fast = true,
    medium = true,
    slow = true,
    slower = true,
    veryslow = true,
}

------------------------------------------------------------
-- Utility functions

local function remove_extension(filename)
    return filename:gsub('%.%w+$', '')
end

local function remove_text_in_brackets(str)
    return str:gsub('%b[]', '')
end

local function remove_special_characters(str)
    return str:gsub('[%-_]', ' '):gsub('[%c%p]', ''):gsub('%s+', ' ')
end

local function human_readable_time(seconds)
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

local function construct_filename()
    local filename = mp.get_property("filename") -- filename without path

    filename = remove_extension(filename)

    if config.clean_filename then
        filename = remove_text_in_brackets(filename)
        filename = remove_special_characters(filename)
    end

    filename = string.format(
            '%s (%s-%s)',
            filename,
            human_readable_time(main_menu.timings['start']),
            human_readable_time(main_menu.timings['end'])
    )

    return filename
end

local function subprocess_async(args, on_complete)
    local command_table = {
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        capture_stderr = true,
        args = args
    }
    return mp.command_native_async(command_table, on_complete)
end

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

local function set_encoding_settings()
    if config.video_format == 'mp4' then
        config.video_codec = 'libx264'
        config.video_extension = '.mp4'
    elseif config.video_format == 'vp9' then
        config.video_codec = 'libvpx-vp9'
        config.video_extension = '.webm'
    else
        config.video_codec = 'libvpx'
        config.video_extension = '.webm'
    end

    if config.audio_format == 'aac' then
        config.audio_codec = 'aac'
        config.audio_extension = '.aac'
    else
        config.audio_codec = 'libopus'
        config.audio_extension = '.opus'
    end
end

local function validate_config()
    if not config.audio_bitrate:match('^%d+[kK]$') then
        config.audio_bitrate = (tonumber(config.audio_bitrate) or 32) .. 'k'
    end

    if not config.video_bitrate:match('^%d+[kKmM]$') then
        config.video_bitrate = '1M'
    end

    if not allowed_presets[config.preset] then
        config.preset = 'faster'
    end

    set_encoding_settings()
end

local function notify(message, level, duration)
    level = level or 'info'
    duration = duration or 1
    mp.msg[level](message)
    mp.osd_message(message, duration)
end

------------------------------------------------------------
-- Provides interface for creating audio/video clips

encoder = {}

function encoder.get_active_track(track_type)
    local track_list = mp.get_property_native('track-list')
    for _, track in pairs(track_list) do
        if track.type == track_type and track.selected == true then
            return track
        end
    end
    return nil
end

function encoder.get_ext_subs_fp()
    local track = encoder.get_active_track('sub')

    if track and track.external == true then
        return track['external-filename']
    end
end

function encoder.append_embed_subs_args(args)
    local ext_subs_fp = encoder.get_ext_subs_fp()
    if ext_subs_fp then
        table.insert(args, #args, table.concat { '--sub-files-append=', ext_subs_fp })
    end
    table.insert(args, #args, table.concat { '--sid=', mp.get_property("sid") })
    table.insert(args, #args, table.concat { '--sub-delay=', mp.get_property("sub-delay") })
    return args
end

encoder.mkargs_video = function(clip_filename)
    local clip_path = utils.join_path(config.video_folder_path, clip_filename .. config.video_extension)
    local args = {
        'mpv',
        mp.get_property('path'),
        '--loop-file=no',
        '--no-ocopy-metadata',
        '--no-sub',
        '--audio-channels=2',
        '--oacopts-add=vbr=on',
        '--oacopts-add=application=voip',
        '--oacopts-add=compression_level=10',
        '--vf-add=format=yuv420p',
        table.concat { '--ovc=', config.video_codec },
        table.concat { '--oac=', config.audio_codec },
        table.concat { '--start=', main_menu.timings['start'] },
        table.concat { '--end=', main_menu.timings['end'] },
        table.concat { '--aid=', mp.get_property("aid") }, -- track number
        table.concat { '--mute=', mp.get_property("mute") },
        table.concat { '--volume=', mp.get_property('volume') },
        table.concat { '--ovcopts-add=b=', config.video_bitrate },
        table.concat { '--oacopts-add=b=', config.audio_bitrate },
        table.concat { '--ovcopts-add=crf=', config.video_quality },
        table.concat { '--ovcopts-add=preset=', config.preset },
        table.concat { '--vf-add=scale=', config.video_width, ':', config.video_height },
        table.concat { '--ytdl-format=', mp.get_property("ytdl-format") },
        table.concat { '-o=', clip_path }
    }

    if config.video_fps ~= 'auto' then
        table.insert(args, #args, table.concat { '--vf-add=fps=', config.video_fps })
    end

    if mp.get_property_bool("sub-visibility") == true then
        args = encoder.append_embed_subs_args(args)
    end

    return args
end

encoder.mkargs_audio = function(clip_filename)
    local clip_path = utils.join_path(config.audio_folder_path, clip_filename .. config.audio_extension)
    return {
        'mpv',
        mp.get_property('path'),
        '--loop-file=no',
        '--no-ocopy-metadata',
        '--no-sub',
        '--audio-channels=2',
        '--video=no',
        '--oacopts-add=vbr=on',
        '--oacopts-add=application=voip',
        '--oacopts-add=compression_level=10',
        table.concat { '--oac=', config.audio_codec },
        table.concat { '--start=', main_menu.timings['start'] },
        table.concat { '--end=', main_menu.timings['end'] },
        table.concat { '--volume=', mp.get_property('volume') },
        table.concat { '--aid=', mp.get_property("aid") }, -- track number
        table.concat { '--oacopts-add=b=', config.audio_bitrate },
        table.concat { '--ytdl-format=', mp.get_property("ytdl-format") },
        table.concat { '-o=', clip_path }
    }
end

encoder.create_clip = function(clip_type)
    main_menu:close();
    if clip_type == nil then
        return
    end

    if not main_menu.timings:validate() then
        notify("Wrong timings. Aborting.", "warn", 2)
        return
    end

    local clip_filename = construct_filename()
    notify("Please wait...", "info", 9999)

    local args
    local location

    if clip_type == 'video' then
        args = encoder.mkargs_video(clip_filename)
        location = config.video_folder_path
    else
        args = encoder.mkargs_audio(clip_filename)
        location = config.audio_folder_path
    end

    local process_result = function(_, ret, _)
        if ret.status ~= 0 or string.match(ret.stdout, "could not open") then
            notify(string.format("Error: couldn't create the clip.\nDoes %s exist?", location), "error", 5)
        else
            notify(string.format("Clip saved to %s.", location), "info", 2)
        end
    end

    subprocess_async(args, process_result)
    main_menu.timings:reset()
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
    local osd = OSD:new():size(config.font_size):align(4)
    osd:append('Dummy menu.'):newline()
    self:overlay_draw(osd:get_text())
end

------------------------------------------------------------
-- Main menu

main_menu = Menu:new()

main_menu.keybindings = {
    { key = 's', fn = function() main_menu:set_time('start') end },
    { key = 'e', fn = function() main_menu:set_time('end') end },
    { key = 'S', fn = function() main_menu:set_time_sub('start') end },
    { key = 'E', fn = function() main_menu:set_time_sub('end') end },
    { key = 'r', fn = function() main_menu:reset_timings() end },
    { key = 'c', fn = function() encoder.create_clip('video') end },
    { key = 'C', fn = function() force_resolution(1920, -2, encoder.create_clip, 'video') end },
    { key = 'a', fn = function() encoder.create_clip('audio') end },
    { key = 'p', fn = function() pref_menu:open() end },
    { key = 'o', fn = function() mp.commandv('run', 'xdg-open', 'https://streamable.com/') end },
    { key = 'ESC', fn = function() main_menu:close() end },
}

function main_menu:set_time(property)
    self.timings[property] = mp.get_property_number('time-pos')
    self:update()
end

function main_menu:set_time_sub(property)
    local sub_delay = mp.get_property_native("sub-delay")
    local time_pos = mp.get_property_number(string.format("sub-%s", property))

    if time_pos == nil then
        notify("Warning: No subtitles visible.", "warn", 2)
        return
    end

    self.timings[property] = time_pos + sub_delay
    self:update()
end

function main_menu:reset_timings()
    self.timings = Timings:new()
    self:update()
end

main_menu.open = function()
    main_menu.timings = main_menu.timings or Timings:new()
    Menu.open(main_menu)
end

function main_menu:update()
    local osd = OSD:new():size(config.font_size):align(4)
    osd:submenu('Clip creator'):newline()
    osd:tab():item('Start time: '):append(human_readable_time(self.timings['start'])):newline()
    osd:tab():item('End time: '):append(human_readable_time(self.timings['end'])):newline()
    osd:submenu('Timings '):italics('(+shift use sub timings)'):newline()
    osd:tab():item('s: '):append('Set start'):newline()
    osd:tab():item('e: '):append('Set end'):newline()
    osd:tab():item('r: '):append('Reset'):newline()
    osd:submenu('Create clip '):italics('(+shift to force fullHD preset)'):newline()
    osd:tab():item('c: '):append('video clip'):newline()
    osd:tab():item('a: '):append('audio clip'):newline()
    osd:submenu('Options '):newline()
    osd:tab():item('p: '):append('Open preferences'):newline()
    osd:tab():item('o: '):append('Open streamable.com'):newline()
    osd:tab():item('ESC: '):append('Close'):newline()

    self:overlay_draw(osd:get_text())
end

------------------------------------------------------------
-- Preferences

pref_menu = Menu:new(main_menu)

pref_menu.keybindings = {
    { key = 'f', fn = function() pref_menu:cycle_video_formats() end },
    { key = 'a', fn = function() pref_menu:cycle_audio_formats() end },
    { key = 'm', fn = function() pref_menu:toggle_mute_audio() end },
    { key = 'r', fn = function() pref_menu:cycle_resolutions() end },
    { key = 'b', fn = function() pref_menu:cycle_audio_bitrates() end },
    { key = 'e', fn = function() pref_menu:toggle_embed_subtitles() end },
    { key = 's', fn = function() pref_menu:save() end },
    { key = 'c', fn = function() end },
    { key = 'ESC', fn = function() pref_menu:close() end },
    { key = 'q', fn = function() pref_menu:close() end },
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
    '256k',
    '384k',
    selected = 1,
}

pref_menu.vid_formats = { 'mp4', 'vp9', 'vp8', }
pref_menu.aud_formats = { 'aac', 'opus', }

function pref_menu:get_selected_resolution()
    local w = config.video_width
    local h = config.video_height
    w = w == -2 and 'auto' or w
    h = h == -2 and 'auto' or h
    return string.format('%s x %s', w, h)
end

function pref_menu:cycle_resolutions()
    self.resolutions.selected = self.resolutions.selected + 1 > #self.resolutions and 1 or self.resolutions.selected + 1
    local res = self.resolutions[self.resolutions.selected]
    config.video_width = res.w
    config.video_height = res.h
    self:update()
end

function pref_menu:cycle_audio_bitrates()
    self.audio_bitrates.selected = self.audio_bitrates.selected + 1 > #self.audio_bitrates and 1 or self.audio_bitrates.selected + 1
    config.audio_bitrate = self.audio_bitrates[self.audio_bitrates.selected]
    self:update()
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
    set_encoding_settings()
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

function pref_menu:update()
    local osd = OSD:new():size(config.font_size):align(4)
    osd:submenu('Preferences'):newline()
    osd:tab():item('r: Video resolution: '):append(self:get_selected_resolution()):newline()
    osd:tab():item('f: Video format: '):append(config.video_format):newline()
    osd:tab():item('a: Audio format: '):append(config.audio_format):newline()
    osd:tab():item('b: Audio bitrate: '):append(config.audio_bitrate):newline()
    osd:tab():item('m: Mute audio: '):append(mp.get_property("mute")):newline()
    osd:tab():item('e: Embed subtitles: '):append(mp.get_property("sub-visibility")):newline()
    osd:tab():item('s: Save preferences'):newline()
    self:overlay_draw(osd:get_text())
end

function pref_menu:save()
    local function lua_to_mpv(config_value)
        if type(config_value) == 'boolean' then
            return config_value and 'yes' or 'no'
        else
            return config_value
        end
    end
    local ignore_list = {
        video_extension = true,
        audio_extension = true,
        video_codec = true,
        audio_codec = true,
    }
    local mpv_dirpath = string.gsub(mp.get_script_directory(), "scripts/%w+", "")
    local config_filepath = utils.join_path(mpv_dirpath, string.format('script-opts/%s.conf', NAME))
    local handle = io.open(config_filepath, 'w')
    if handle ~= nil then
        handle:write(string.format("# Written by %s on %s.\n", NAME, os.date()))
        for key, value in pairs(config) do
            if ignore_list[key] == nil then
                handle:write(string.format('%s=%s\n', key, lua_to_mpv(value)))
            end
        end
        handle:close()
        notify("Settings saved.", "info", 2)
    else
        notify(string.format("Couldn't open %s.", config_filepath), "error", 4)
    end
end

------------------------------------------------------------
-- Timings class

Timings = {
    ['start'] = -1,
    ['end'] = -1,
}

function Timings:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Timings:reset()
    self['start'] = -1
    self['end'] = -1
end

function Timings:validate()
    return self['start'] >= 0 and self['start'] < self['end']
end

------------------------------------------------------------
-- Finally, set an 'entry point' in mpv

validate_config()
mp.add_key_binding('c', 'videoclip-menu-open', main_menu.open)
