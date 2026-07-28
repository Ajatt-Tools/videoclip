--[[
Copyright: Ajatt-Tools and contributors; https://github.com/Ajatt-Tools
License: GNU GPL, version 3 or later; http://www.gnu.org/licenses/gpl.html

Read/save config file.
]]

local mp = require('mp')
local mpopt = require('mp.options')
local defaults = require("config.defaults")
local h = require('helpers')
local msg = require('mp.msg')
local utils = require('mp.utils')

local this = {}
local NAME = 'videoclip'

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

local FALLBACK_VIDEO_FPS = 30

local function lua_to_mpv(config_value)
    --- Convert a Lua config value into its mpv config file representation.
    --- Examples:
    ---    true → "yes"
    ---    false → "no"
    ---    "32k" → "32k"
    if type(config_value) == 'boolean' then
        return config_value and 'yes' or 'no'
    else
        return config_value
    end
end

local function normalize_video_fps(video_fps)
    --- Return a safe video_fps value. "auto" keeps the input video's source FPS.
    --- Numeric values are truncated to whole numbers; anything else falls back.
    --- Examples:
    ---    "auto" → "auto"
    ---    "60" → 60
    ---    60 → 60
    ---    "60.5" → 60
    ---    "23.976" → 23
    ---    "abc" → 30 (fallback)
    ---    "0" → 30 (fallback)
    if video_fps == 'auto' then
        return video_fps
    end

    local numeric_video_fps = tonumber(video_fps)
    if h.is_empty(numeric_video_fps) then
        return FALLBACK_VIDEO_FPS
    end

    numeric_video_fps = math.floor(numeric_video_fps)
    if numeric_video_fps < 1 then
        return FALLBACK_VIDEO_FPS
    end
    return numeric_video_fps
end

function this.read_config_file()
    --- Reads the config file and returns a new copy of the config dict.
    local config = defaults.get_default()
    mpopt.read_options(config, NAME)
    msg.info("Read config file: " .. NAME .. ".conf")
    return config
end

function this.save_config_file(config)
    --- Write the config table to ~/.config/mpv/script-opts/videoclip.conf.
    --- Derived values (codecs and extensions) are not written.
    --- Returns a success message, or nil plus an error message on failure.
    local ignore_list = {
        video_extension = true,
        audio_extension = true,
        video_codec = true,
        audio_codec = true,
    }
    local mpv_dirpath = string.gsub(mp.get_script_directory(), "scripts[\\/][^\\/]+", "")
    local config_filepath = utils.join_path(utils.join_path(mpv_dirpath, "script-opts"), string.format('%s.conf', NAME))
    local handle = io.open(config_filepath, 'w')
    if handle ~= nil then
        handle:write(string.format("# Written by %s on %s.\n", NAME, os.date()))
        for key, value in pairs(config) do
            if ignore_list[key] == nil then -- not ignored
                handle:write(string.format('%s=%s\n', key, lua_to_mpv(value)))
            end
        end
        handle:close()
        return "Settings saved.", nil
    else
        return nil, string.format("Couldn't open %s.", config_filepath)
    end
end

function this.set_encoding_settings(config)
    --- Derive codec and extension fields from the configured video and audio formats.
    --- Examples:
    ---    video_format="mp4" → video_codec="libx264", video_extension=".mp4"
    ---    video_format="vp9" → video_codec="libvpx-vp9", video_extension=".webm"
    ---    audio_format="aac" → audio_codec="aac", audio_extension=".aac"
    ---    audio_format="opus" → audio_codec="libopus", audio_extension=".opus"
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

function this.validate_config(config)
    --- Normalize invalid config values in place, then derive encoding settings.
    --- Runs before encoder argument construction so encoders never see bad input.
    if not tostring(config.audio_bitrate):match('^%d+[kK]$') then
        config.audio_bitrate = (tonumber(config.audio_bitrate) or 32) .. 'k'
    end

    if not tostring(config.video_bitrate):match('^%d+[kKmM]$') then
        config.video_bitrate = '1M'
    end

    if not allowed_presets[config.preset] then
        config.preset = 'faster'
    end

    config.video_fps = normalize_video_fps(config.video_fps)

    this.set_encoding_settings(config)
end

local function test_video_fps(config_value, applied_value)
    --- Assert that validate_config normalizes config_value into applied_value.
    local test_config = defaults.get_default()
    test_config.video_fps = config_value
    this.validate_config(test_config)
    h.assert_equals(test_config.video_fps, applied_value)
end

local function test_config_field(field, config_value, applied_value)
    --- Assert that validate_config normalizes one config field into applied_value.
    local test_config = defaults.get_default()
    test_config[field] = config_value
    this.validate_config(test_config)
    h.assert_equals(test_config[field], applied_value)
end

local function test_encoding_settings(video_format, expected_video_codec, expected_video_extension)
    --- Assert codec/extension derivation for a video format and both audio formats.
    for audio_format, audio in pairs({ aac = { 'aac', '.aac' }, opus = { 'libopus', '.opus' } }) do
        local test_config = defaults.get_default()
        test_config.video_format = video_format
        test_config.audio_format = audio_format
        this.set_encoding_settings(test_config)
        h.assert_equals(test_config.video_codec, expected_video_codec)
        h.assert_equals(test_config.video_extension, expected_video_extension)
        h.assert_equals(test_config.audio_codec, audio[1])
        h.assert_equals(test_config.audio_extension, audio[2])
    end
end

function this.run_tests()
    --- Run tests for config validation.
    test_video_fps('60', 60)
    test_video_fps(60, 60)
    test_video_fps('auto', 'auto')
    -- Fractional values are truncated to whole numbers.
    test_video_fps('60.5', 60)
    test_video_fps('23.976', 23)
    -- Invalid values fall back to FALLBACK_VIDEO_FPS.
    for _, invalid_fps in ipairs({ '', 'abc', '0', '-1' }) do
        test_video_fps(invalid_fps, FALLBACK_VIDEO_FPS)
    end
    test_video_fps(nil, FALLBACK_VIDEO_FPS)

    -- Audio bitrate normalization.
    test_config_field('audio_bitrate', '32', '32k')
    test_config_field('audio_bitrate', '64k', '64k')
    test_config_field('audio_bitrate', 32, '32k')
    test_config_field('audio_bitrate', 'junk', '32k')
    -- Video bitrate validation.
    test_config_field('video_bitrate', '1M', '1M')
    test_config_field('video_bitrate', '500k', '500k')
    test_config_field('video_bitrate', 'junk', '1M')
    -- Preset validation.
    test_config_field('preset', 'slow', 'slow')
    test_config_field('preset', 'insane', 'faster')

    -- Codec/extension derivation for each supported format pair.
    test_encoding_settings('mp4', 'libx264', '.mp4')
    test_encoding_settings('vp9', 'libvpx-vp9', '.webm')
    test_encoding_settings('vp8', 'libvpx', '.webm')
end

return this
