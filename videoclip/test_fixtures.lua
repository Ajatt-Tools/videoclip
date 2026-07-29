--[[
Copyright: Ajatt-Tools and contributors; https://github.com/Ajatt-Tools
License: GNU GPL, version 3 or later; http://www.gnu.org/licenses/gpl.html

Fixtures shared by standalone and in-mpv tests.
]]

local defaults = require('config.defaults')
local cfg_mgr = require('config.config')
local mp = require('mp')
local h = require('helpers')
local exec = require('encoder.executables')

local this = {}

local function pack(...)
    return { n = select('#', ...), ... }
end

function this.contains(args, expected)
    --- Return true when args contains expected.
    for _, arg in ipairs(args) do
        if arg == expected then
            return true
        end
    end
    return false
end

function this.index_of(args, expected)
    --- Return the one-based index of expected in args, or nil when absent.
    for i, arg in ipairs(args) do
        if arg == expected then
            return i
        end
    end
    return nil
end

function this.make_config(opts)
    --- Return config for encoder tests, based on the real defaults.
    --- Values are normalized with the same validate_config pass used in production.
    opts = opts or {}
    local config = defaults.get_default()
    config.video_folder_path = opts.video_folder_path or '/tmp'
    config.audio_folder_path = opts.audio_folder_path or '/tmp'
    for key, value in pairs(opts) do
        config[key] = value
    end
    -- Normalize and derive codecs/extensions/fps, like the real config flow does.
    cfg_mgr.validate_config(config)
    return config
end

function this.with_properties(callable, properties)
    --- Temporarily set mp properties while callable runs, then restore originals.
    local original_properties = {}

    for name, value in pairs(properties) do
        table.insert(original_properties, {
            name = name,
            value = mp.get_property(name),
        })
        mp.set_property(name, value)
    end

    local result = pack(pcall(callable))

    for _, property in ipairs(original_properties) do
        if property.value ~= nil then
            mp.set_property(property.name, property.value)
        end
    end

    if result[1] == false then
        error(result[2])
    end

    return h.unpack(result, 2, result.n)
end

function this.make_timings()
    --- Return minimal timings for encoder tests.
    return { start = 1, ['end'] = 2, validate = function() return true end, reset = function() end }
end

function this.make_pinned_properties(mute)
    --- Return player properties pinned for deterministic mpv encoder tests.
    return {
        aid = '1',
        mute = mute,
        volume = '100',
        sid = 'no',
        ['secondary-sid'] = 'no',
        ['sub-delay'] = '0',
        ['sub-visibility'] = 'yes',
        ['secondary-sub-visibility'] = 'no',
        ['sub-back-color'] = '#00000000',
        ['sub-border-style'] = 'outline-and-shadow',
        ['ytdl-format'] = '',
    }
end

function this.expected_audio_args(opts)
    --- Return the exact expected mpv audio args for a test case.
    opts = opts or {}
    local audio_format = opts.audio_format or 'opus'
    local audio_codec = audio_format == 'aac' and 'aac' or 'libopus'
    local out_path = opts.out_path or '/tmp/out.opus'
    local volume = opts.volume or '100'

    return {
        exec.mpv,
        opts.source_path,
        '--loop-file=no',
        '--keep-open=no',
        '--no-ocopy-metadata',
        '--no-sub',
        '--audio-channels=2',
        '--video=no',
        '--oacopts-add=vbr=on',
        '--oacopts-add=application=voip',
        '--oacopts-add=compression_level=10',
        table.concat { '--oac=', audio_codec },
        '--start=1.000',
        '--end=2.000',
        table.concat { '--volume=', volume },
        '--aid=1',
        '--oacopts-add=b=32k',
        '--ytdl-format=',
        table.concat { '--o=', out_path },
    }
end

local function append_expected_external_subs_args(args)
    --- Append expected external subtitle args based on the currently loaded tracks.
    local external_subs_list = {}
    for _, track in pairs(mp.get_property_native('track-list') or {}) do
        if track.type == 'sub' and track.external == true then
            external_subs_list[track.id] = track['external-filename']
        end
    end
    for _, ext_subs_path in pairs(external_subs_list) do
        table.insert(args, table.concat { '--sub-files-append=', ext_subs_path })
    end
    return args
end

function this.expected_video_args(opts)
    --- Return the exact expected mpv video args for a test case.
    opts = opts or {}
    local hdr_to_sdr = opts.hdr_to_sdr or false
    local mute = opts.mute or 'no'
    local volume = opts.volume or '100'
    local sub_delay = opts.sub_delay or '0'
    local video_fps = opts.video_fps or 'auto'
    local audio_format = opts.audio_format or 'opus'
    local audio_codec = audio_format == 'aac' and 'aac' or 'libopus'

    local args = {
        exec.mpv,
        opts.source_path,
        '--loop-file=no',
        '--keep-open=no',
        '--no-ocopy-metadata',
        '--no-sub',
        '--audio-channels=2',
        '--oacopts-add=vbr=on',
        '--oacopts-add=application=voip',
        '--oacopts-add=compression_level=10',
        '--sub-font-provider=auto',
        '--embeddedfonts=yes',
        '--sub-font=Noto Sans CJK JP',
        '--ovc=libx264',
        table.concat { '--oac=', audio_codec },
        '--start=1.000',
        '--end=2.000',
        '--aid=1',
        table.concat { '--mute=', mute },
        table.concat { '--volume=', volume },
        '--ovcopts-add=b=1M',
        '--oacopts-add=b=32k',
        '--ovcopts-add=crf=23',
        '--ovcopts-add=preset=faster',
        '--ytdl-format=',
        '--o=/tmp/out.mp4',
        '--sid=no',
        '--secondary-sid=no',
        table.concat { '--sub-delay=', sub_delay },
        '--sub-visibility=yes',
        '--secondary-sub-visibility=no',
        '--sub-border-style=outline-and-shadow',
    }

    if hdr_to_sdr then
        table.insert(args, '--hwdec=no')
        table.insert(args, '--tone-mapping=bt.2390')
        table.insert(args, '--target-trc=bt.1886')
        table.insert(args, '--target-prim=bt.709')
        table.insert(args, '--vf-add=gpu')
    end

    table.insert(args, '--vf-add=scale=-2:480')
    if video_fps ~= 'auto' then
        table.insert(args, table.concat { '--vf-add=fps=', video_fps })
    end
    table.insert(args, '--vf-add=format=yuv420p')
    args = append_expected_external_subs_args(args)
    table.insert(args, '--sub-back-color=#00000000')
    return args
end

return this
