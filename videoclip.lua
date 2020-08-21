local util =  require('mp.utils')
local msg =   require('mp.msg')
local mpopt = require('mp.options')

-- Options can be changed here or in a separate config file.
-- Config path: ~/.config/mpv/script-opts/videoclip.conf
local config = {
    -- absolute path
	-- relative paths (e.g. ~ for home dir) do NOT work.
    media_path = string.format('%s/Videos/', os.getenv("HOME")),

    font_size = 20,

    audio_bitrate = '32k',

    -- The range of the CRF scale is 0–51, where 0 is lossless,
    -- 23 is the default, and 51 is worst quality possible.
    video_quality = 23,

    -- Use the slowest preset that you have patience for.
    -- https://trac.ffmpeg.org/wiki/Encode/H.264
    preset = 'faster',

    video_width = -2,
    video_height = 480,
}

mpopt.read_options(config, 'videoclip')

local overlay = mp.create_osd_overlay('ass-events')

------------------------------------------------------------
-- utility functions

function add_extension(filename, extension)
    return filename .. extension
end

function remove_extension(filename)
    return filename:gsub('%.%w+$','')
end

function remove_text_in_brackets(str)
    return str:gsub('%b[]','')
end

function remove_special_characters(str)
    return str:gsub('[%c%p%s]','')
end

local function format_time(seconds)
    if seconds < 0 then
        return 'empty'
    end

    local time = string.format('.%03d', seconds * 1000 % 1000);
    time = string.format('%02d:%02d%s', seconds / 60 % 60, seconds % 60, time)

    if seconds > 3600 then
        time = string.format('%02d:%s', seconds / 3600, time)
    end

    return time
end

function construct_filename()
    local filename = mp.get_property("filename") -- filename without path

    filename = remove_extension(filename)
    filename = remove_text_in_brackets(filename)
    filename = remove_special_characters(filename)

    filename = string.format(
        '%s_(%s-%s)',
        filename,
        format_time(timings['start']),
        format_time(timings['end'])
    )

    filename = add_extension(filename, '.mp4')

    return filename
end

function get_audio_track_number()
    local audio_track_number = 0
    local tracks_count = mp.get_property_number("track-list/count")

    for i = 1, tracks_count do
        local track_type = mp.get_property(string.format("track-list/%d/type", i))
        local track_index = mp.get_property_number(string.format("track-list/%d/ff-index", i))
        local track_selected = mp.get_property(string.format("track-list/%d/selected", i))

        if track_type == "audio" and track_selected == "yes" then
            audio_track_number = track_index - 1
            break
        end
    end
    return audio_track_number
end

------------------------------------------------------------
-- ffmpeg helper

ffmpeg = {prefix = {"ffmpeg", "-hide_banner", "-nostdin", "-y", "-loglevel", "quiet"}}

ffmpeg.execute = function(args)
    if next(args) == nil then
        return
    end

    for i, value in ipairs(ffmpeg.prefix) do
        table.insert(args, i, value)
    end

    mp.commandv("run", unpack(args))
end

ffmpeg.create_videoclip = function(fn)
    if not timings:validate() then
        return
    end

    local clip_filename = construct_filename()

    local video_path = mp.get_property("path")
    local clip_path = config.media_path .. clip_filename
    local track_number = get_audio_track_number()

    ffmpeg.execute{'-ss', tostring(timings['start']),
                    '-to', tostring(timings['end']),
                    '-i', video_path,
                    '-map_metadata', '-1',
                    '-map', string.format("0:a:%d", track_number),
                    '-map', '0:v:0',
                    '-codec:a', 'libopus',
                    '-codec:v', 'libx264',
                    '-preset', config.preset,
                    '-vbr', 'on',
                    '-compression_level', '10',
                    '-application', 'voip',
                    '-ac', '2',
                    '-b:a', tostring(config.audio_bitrate),
                    '-crf', tostring(config.video_quality),
                    '-vf', string.format("scale=%d:%d", config.video_width, config.video_height),
                    clip_path
    }
end

------------------------------------------------------------
-- main menu

menu = {}

menu.keybinds = {
    { key = 's', fn = function() menu.set_time('start') end },
    { key = 'e', fn = function() menu.set_time('end') end },
    { key = 'S', fn = function() menu.set_time_sub('start') end },
    { key = 'E', fn = function() menu.set_time_sub('end') end },
    { key = 'c', fn = function() menu.commit() end },
    { key = 'o', fn = function() mp.commandv('run', 'xdg-open', 'https://streamable.com/') end },
    { key = 'ESC', fn = function() menu.close() end },
}

menu.set_time = function(property)
    timings[property] = mp.get_property_number('time-pos')
    menu.update()
end

menu.set_time_sub = function(property)
    local sub_delay = mp.get_property_native("sub-delay")
    local time_pos = mp.get_property_number(string.format("sub-%s", property))

    if time_pos == nil then
        menu.update("Warning: No subtitles visible.")
        return
    end

    timings[property] = time_pos + sub_delay
    menu.update()
end

menu.update = function(message)
    local osd = OSD:new():size(config.font_size):bold('Video clip crator'):newline():newline()

    osd:bold('Start time: '):append(format_time(timings['start'])):newline()
    osd:bold('End time: '):append(format_time(timings['end'])):newline():newline()

    osd:bold('Bindings:'):newline()
    osd:tab():bold('s: '):append('Set start time'):newline()
    osd:tab():bold('e: '):append('Set end time'):newline()
    osd:newline()
    osd:tab():bold('S: '):append('Set start time based on subtitles'):newline()
    osd:tab():bold('E: '):append('Set end time based on subtitles'):newline()
    osd:newline()
    osd:tab():bold('c: '):append('Create video clip'):newline()
    osd:tab():bold('o: '):append('Open `streamable.com`'):newline()
    osd:tab():bold('ESC: '):append('Close'):newline()

    if message ~= nil then
        osd:newline():append(message):newline()
    end

    osd:draw()
end

menu.commit = function()
    ffmpeg.create_videoclip()
    menu.close()
end

menu.close = function()
    for _, val in pairs(menu.keybinds) do
        mp.remove_key_binding(val.key)
    end
    overlay:remove()
    timings:reset()
end

menu.open = function()
    for _, val in pairs(menu.keybinds) do
        mp.add_key_binding(val.key, val.key, val.fn)
    end
    menu.update()
end

------------------------------------------------------------
-- Helper class for styling OSD messages

OSD = {}
OSD.__index = OSD

function OSD:new()
    return setmetatable({text=''}, self)
end

function OSD:append(s)
    self.text = self.text .. s
    return self
end

function OSD:bold(s)
    return self:append('{\\b1}' .. s .. '{\\b0}')
end

function OSD:newline()
    return self:append('\\N')
end

function OSD:tab()
    return self:append('\\h\\h\\h\\h')
end

function OSD:size(size)
    return self:append('{\\fs' .. size .. '}')
end

function OSD:draw()
    overlay.data = self.text
    overlay:update()
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
    self['end']   = -1
end

function Timings:validate()
    return self['start'] > 0 and self['start'] < self['end']
end

------------------------------------------------------------
-- Finally, set an 'entry point' in mpv

timings = Timings:new()
mp.add_key_binding('c', 'menu-open', menu.open)
