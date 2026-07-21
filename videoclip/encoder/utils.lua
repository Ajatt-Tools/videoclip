--[[
Copyright: Ajatt-Tools and contributors; https://github.com/Ajatt-Tools
License: GNU GPL, version 3 or later; http://www.gnu.org/licenses/gpl.html

Encoder utilities shared between the mpv and ffmpeg backends.
]]

local mp = require('mp')
local h = require('helpers')

local this = {}

--- Trim timestamp down to milliseconds.
--- Examples:
---    1 → "1.000"
---    1.23456 → "1.235"
function this.toms(timestamp)
    return string.format("%.3f", timestamp)
end

--- Strip URL query and fragment suffixes from a source path.
--- Examples:
---    "file.txt?x=1" → "file.txt"
---    "file.txt#section" → "file.txt"
---    "file.txt?x=1#section" → "file.txt"
function this.strip_url_suffix(src_path)
    return (src_path or ''):gsub('[?#].*$', '')
end

--- Extract the file extension from a source path after stripping URL suffixes.
--- Returns default_ext if no extension can be determined.
--- Examples:
---    "file.txt?x=1" → "txt"
---    "file.txt#section" → "txt"
---    "file.txt?x=1#section" → "txt"
function this.source_extension(src_path, default_ext)
    local cleaned = this.strip_url_suffix(src_path)
    local ext = cleaned:match('%.(%w+)$')
    if ext and #ext > 0 and #ext <= 5 then
        return string.lower(ext)
    end
    return default_ext
end

--- Return the ffmpeg stream index of the currently selected track of the given type.
--- Returns nil when the property is unavailable.
--- Examples:
---    current_track_ff_index("audio") → "1"
---    current_track_ff_index("video") → "0"
function this.current_track_ff_index(track_type)
    local value = mp.get_property_native(string.format("current-tracks/%s/ff-index", track_type))
    if value == nil then
        return nil
    end
    return tostring(value)
end

--- Build a `-map` argument for the selected track of the given type.
--- Uses the fallback (e.g. "0:v:0") when the selected track is unknown.
--- Examples:
---    ffmpeg_stream_map("audio", "0:a:0?") → "0:1"
---    ffmpeg_stream_map("video", "0:v:0") → "0:v:0"
function this.ffmpeg_stream_map(track_type, fallback)
    local ff_index = this.current_track_ff_index(track_type)
    if ff_index ~= nil then
        return string.format("0:%s", ff_index)
    end
    return fallback
end

--- Map a codec name reported by mpv to a sensible audio container extension.
--- Examples:
---    "aac" → ".m4a"
---    "opus" → ".opus"
---    "unknown" → ".mka"
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

--- Convert a subprocess result to combined stdout and stderr text on success.
--- Returns an empty string when the command failed.
--- Examples:
---    { status = 0, stdout = "ok", stderr = "" } → "ok"
---    { status = 1, stdout = "", stderr = "err" } → ""
function this.result_to_str(result)
    if result and result.status == 0 then
        return (result.stdout or "") .. (result.stderr or "")
    end
    return ""
end

function this.run_tests()
    --- Run unit tests for encoder utility functions.
    h.assert_equals(this.toms(1), "1.000")
    h.assert_equals(this.toms(1.23456), "1.235")

    h.assert_equals(this.strip_url_suffix("file.txt?x=1"), "file.txt")
    h.assert_equals(this.strip_url_suffix("file.txt#section"), "file.txt")
    h.assert_equals(this.strip_url_suffix("file.txt?x=1#section"), "file.txt")

    h.assert_equals(this.source_extension("file.txt?x=1", "mkv"), "txt")
    h.assert_equals(this.source_extension("file.txt#section", "mkv"), "txt")
    h.assert_equals(this.source_extension("file.txt?x=1#section", "mkv"), "txt")
    h.assert_equals(this.source_extension("file", "mkv"), "mkv")

    local audio_index = this.current_track_ff_index("audio")
    local video_index = this.current_track_ff_index("video")

    if not h.is_empty(audio_index) then
        h.assert_equals(this.ffmpeg_stream_map("audio", "0:a:0?"), "0:" .. audio_index)
    end
    if not h.is_empty(video_index) then
        h.assert_equals(this.ffmpeg_stream_map("video", "0:v:0"), "0:" .. video_index)
    end

    h.assert_equals(this.audio_codec_to_extension("aac"), ".m4a")
    h.assert_equals(this.audio_codec_to_extension("opus"), ".opus")
    h.assert_equals(this.audio_codec_to_extension("mp3"), ".mp3")
    h.assert_equals(this.audio_codec_to_extension("unknown"), ".mka")

    h.assert_equals(this.result_to_str({ status = 0, stdout = "ok", stderr = "" }), "ok")
    h.assert_equals(this.result_to_str({ status = 0, stdout = "", stderr = "err" }), "err")
    h.assert_equals(this.result_to_str({ status = 1, stdout = "bad", stderr = "err" }), "")
end

return this
