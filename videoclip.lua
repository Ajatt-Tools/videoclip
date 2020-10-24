local mpopt = require('mp.options')
local utils = require('mp.utils')

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
    audio_bitrate = '32k',
    mute_audio = false,
    font_size = 24,
}

mpopt.read_options(config, 'videoclip')
local main_menu
local pref_menu
local encoder
local OSD
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
    return str:gsub('[%c%p%s]', '')
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
    filename = remove_text_in_brackets(filename)
    filename = remove_special_characters(filename)

    filename = string.format(
            '%s_(%s-%s)',
            filename,
            human_readable_time(main_menu.timings['start']),
            human_readable_time(main_menu.timings['end'])
    )

    return filename
end

local function subprocess(args)
    return mp.command_native {
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        capture_stderr = true,
        args = args
    }
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

local function set_video_settings()
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

    set_video_settings()
end

------------------------------------------------------------
-- Provides interface for creating audio/video clips

encoder = {}

encoder.create_videoclip = function(clip_filename)
    local clip_path = utils.join_path(config.video_folder_path, clip_filename .. config.video_extension)
    return subprocess {
        'mpv',
        mp.get_property('path'),
        '--loop-file=no',
        '--no-ocopy-metadata',
        '--no-sub',
        '--audio-channels=2',
        '--oac=libopus',
        '--oacopts-add=vbr=on',
        '--oacopts-add=application=voip',
        '--oacopts-add=compression_level=10',
        table.concat { '--ovc=', config.video_codec },
        table.concat { '--start=', main_menu.timings['start'] },
        table.concat { '--end=', main_menu.timings['end'] },
        table.concat { '--aid=', config.mute_audio and 'no' or mp.get_property("aid") }, -- track number
        table.concat { '--volume=', mp.get_property('volume') },
        table.concat { '--ovcopts-add=b=', config.video_bitrate },
        table.concat { '--oacopts-add=b=', config.audio_bitrate },
        table.concat { '--ovcopts-add=crf=', config.video_quality },
        table.concat { '--ovcopts-add=preset=', config.preset },
        table.concat { '--vf-add=scale=', config.video_width, ':', config.video_height },
        table.concat { '-o=', clip_path }
    }
end

encoder.create_audioclip = function(clip_filename)
    local clip_path = utils.join_path(config.audio_folder_path, clip_filename .. '.ogg')
    return subprocess {
        'mpv',
        mp.get_property('path'),
        '--loop-file=no',
        '--no-ocopy-metadata',
        '--no-sub',
        '--audio-channels=2',
        '--video=no',
        '--oac=libopus',
        '--oacopts-add=vbr=on',
        '--oacopts-add=application=voip',
        '--oacopts-add=compression_level=10',
        table.concat { '--start=', main_menu.timings['start'] },
        table.concat { '--end=', main_menu.timings['end'] },
        table.concat { '--volume=', mp.get_property('volume') },
        table.concat { '--aid=', mp.get_property("aid") }, -- track number
        table.concat { '--oacopts-add=b=', config.audio_bitrate },
        table.concat { '-o=', clip_path }
    }
end

encoder.create_clip = function(clip_type)
    main_menu:close();
    if clip_type == nil then
        return
    end

    if not main_menu.timings:validate() then
        mp.osd_message("Wrong timings. Aborting.", 2)
        return
    end

    local clip_filename = construct_filename()
    mp.osd_message("Please wait...", 9999)

    local ret
    local location

    if clip_type == 'video' then
        location = config.video_folder_path
        ret = encoder.create_videoclip(clip_filename)
    else
        location = config.audio_folder_path
        ret = encoder.create_audioclip(clip_filename)
    end

    if ret.status ~= 0 or string.match(ret.stdout, "could not open") then
        mp.osd_message(string.format("Error: couldn't create the clip.\nDoes %s exist?", location), 5)
    else
        mp.osd_message(string.format("Clip saved to %s.", location), 2)
    end
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
        mp.osd_message("Warning: No subtitles visible.", 2)
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
    osd:bold('Clip creator'):newline()
    osd:tab():bold('Start time: '):append(human_readable_time(self.timings['start'])):newline()
    osd:tab():bold('End time: '):append(human_readable_time(self.timings['end'])):newline()
    osd:bold('Timings: '):italics('(+shift use sub timings)'):newline()
    osd:tab():bold('s: '):append('Set start'):newline()
    osd:tab():bold('e: '):append('Set end'):newline()
    osd:tab():bold('r: '):append('Reset'):newline()
    osd:bold('Create clip: '):italics('(+shift to force fullHD preset)'):newline()
    osd:tab():bold('c: '):append('video clip'):newline()
    osd:tab():bold('a: '):append('audio clip'):newline()
    osd:bold('Options: '):newline()
    osd:tab():bold('p: '):append('Open preferences'):newline()
    osd:tab():bold('o: '):append('Open streamable.com'):newline()
    osd:tab():bold('ESC: '):append('Close'):newline()

    self:overlay_draw(osd:get_text())
end

------------------------------------------------------------
-- Preferences

pref_menu = Menu:new(main_menu)

pref_menu.keybindings = {
    { key = 'f', fn = function() pref_menu:cycle_video_formats() end },
    { key = 'm', fn = function() pref_menu:toggle_mute_audio() end },
    { key = 'r', fn = function() pref_menu:cycle_resolutions() end },
    { key = 'ESC', fn = function() pref_menu:close() end },
}

pref_menu.resolutions = {
    { w = config.video_width, h = config.video_height, },
    { w = -2, h = 240, },
    { w = -2, h = 360, },
    { w = -2, h = 480, },
    { w = -2, h = 720, },
    { w = -2, h = 1080, },
    { w = -2, h = 1440, },
    { w = -2, h = 2160, },
    selected = 1,
}

pref_menu.formats = { 'mp4', 'vp9', 'vp8' }

function pref_menu:get_selected_resolution()
    local w = config.video_width
    local h = config.video_height
    w = w ~= -2 and w or 'auto'
    h = h ~= -2 and h or 'auto'
    return string.format('%s x %s', w, h)
end

function pref_menu:cycle_resolutions()
    self.resolutions.selected = self.resolutions.selected + 1 > #self.resolutions and 1 or self.resolutions.selected + 1
    local res = self.resolutions[self.resolutions.selected]
    config.video_width = res.w
    config.video_height = res.h
    self:update()
end

function pref_menu:cycle_video_formats()
    local selected = 1
    for i, v in ipairs(pref_menu.formats) do
        if config.video_format == v then
            selected = i
        end
    end
    config.video_format = pref_menu.formats[selected + 1] or pref_menu.formats[1]
    set_video_settings()
    self:update()
end

function pref_menu:toggle_mute_audio()
    config.mute_audio = not config.mute_audio
    self:update()
end

function pref_menu:update()
    local osd = OSD:new():size(config.font_size):align(4)
    osd:bold('Preferences'):newline()
    osd:bold('Video resolution: '):append(self:get_selected_resolution()):newline()
    osd:bold('Video format: '):append(config.video_format):newline()
    osd:bold('Mute audio: '):append(config.mute_audio and 'yes' or 'no'):newline()
    osd:newline()
    osd:bold('Bindings:'):newline()
    osd:tab():bold('r: '):append('Cycle video resolutions'):newline()
    osd:tab():bold('f: '):append('Cycle video formats'):newline()
    osd:tab():bold('m: '):append('Toggle mute audio'):newline()

    self:overlay_draw(osd:get_text())
end

------------------------------------------------------------
-- Helper class for styling OSD messages
-- http://docs.aegisub.org/3.2/ASS_Tags/

OSD = {}
OSD.__index = OSD

function OSD:new()
    return setmetatable({ text = {} }, self)
end

function OSD:append(s)
    table.insert(self.text, s)
    return self
end

function OSD:bold(s)
    return self:append(string.format([[{\b1}%s{\b0}]], s))
end

function OSD:italics(s)
    return self:append('{\\i1}'):append(s):append('{\\i0}')
end

function OSD:newline()
    return self:append([[\N]])
end

function OSD:tab()
    return self:append([[\h\h\h\h]])
end

function OSD:size(size)
    return self:append(string.format([[{\fs%s}]], size))
end

function OSD:align(number)
    return self:append(string.format([[{\an%s}]], number))
end

function OSD:get_text()
    return table.concat(self.text)
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
