--[[
Copyright: Ajatt-Tools and contributors; https://github.com/Ajatt-Tools
License: GNU GPL, version 3 or later; http://www.gnu.org/licenses/gpl.html

Encoder utilities shared between the mpv and ffmpeg backends.
]]

local mp = require('mp')
local utils = require('mp.utils')

local this = {}

--- Trim timestamp down to milliseconds.
function this.toms(timestamp)
    return string.format("%.3f", timestamp)
end

--- Extract the file extension from a source path.
--- Returns default_ext if no extension can be determined.
--- Examples:
---    "file.txt?x=1" → "file.txt"
---    "file.txt#section" → "file.txt"
---    "file.txt?x=1#section" → "file.txt"
function this.source_extension(src_path, default_ext)
    src_path = src_path or ''
    -- Strip query strings and fragments that appear in URLs.
    local cleaned = src_path:gsub('[?#].*$', '')
    local ext = cleaned:match('%.(%w+)$')
    if ext and #ext > 0 and #ext <= 5 then
        return string.lower(ext)
    end
    return default_ext
end

--- Return the ffmpeg stream index of the currently selected track of the given type.
--- Returns nil when the property is unavailable.
function this.current_track_ff_index(track_type)
    local value = mp.get_property_native(string.format("current-tracks/%s/ff-index", track_type))
    if value == nil then
        return nil
    end
    return tostring(value)
end

--- Build a `-map` argument for the selected track of the given type.
--- Uses the fallback (e.g. "0:v:0") when the selected track is unknown.
function this.ffmpeg_stream_map(track_type, fallback)
    local ff_index = this.current_track_ff_index(track_type)
    if ff_index ~= nil then
        return string.format("0:%s", ff_index)
    end
    return fallback
end

--- Map a codec name reported by mpv to a sensible audio container extension.
function this.audio_codec_to_extension(codec)
    codec = (codec or ''):lower()
    if codec == 'aac' then
        return '.m4a'
    elseif codec == 'opus' then
        return '.opus'
    elseif codec == 'mp3' then
        return '.mp3'
    elseif codec == 'vorbis' then
        return '.ogg'
    elseif codec == 'ac3' then
        return '.ac3'
    elseif codec == 'eac3' then
        return '.eac3'
    elseif codec == 'flac' then
        return '.flac'
    end
    return '.mka'
end

return this
