--[[
Copyright: Ajatt-Tools and contributors; https://github.com/Ajatt-Tools
License: GNU GPL, version 3 or later; http://www.gnu.org/licenses/gpl.html

Encoder backend that uses mpv's encoding mode.
]]

local mp = require('mp')
local h = require('helpers')
local eutils = require('encoder.utils')
local exec = require('encoder.executables')
local fixtures = require('test_fixtures')

local HDR_TO_SDR_TONE_MAPPING = 'bt.2390'
local SDR_TRANSFER_CHARACTERISTICS = 'bt.1886'
local SDR_COLOR_PRIMARIES = 'bt.709'
local NAME = "mpv_encoder"

--- Create an mpv encoder backend.
--- The backend uses mpv's built-in encoding mode for video and audio clips.
local function make_mpv_encoder(config, timings)
    local self = {
        config = config,
        timings = timings,
        alive = nil,
        player = exec.mpv,
    }
    local pub = { name = NAME }

    function self.prepend_common_args(...)
        --- Return the shared mpv command prefix plus extra arguments.
        return {
            self.player,
            mp.get_property('path'),
            '--loop-file=no',
            '--keep-open=no',
            '--no-ocopy-metadata',
            '--no-sub',
            '--audio-channels=2',
            '--oacopts-add=vbr=on',
            '--oacopts-add=application=voip',
            '--oacopts-add=compression_level=10',
            ...,
        }
    end

    function self.get_ext_subs_paths()
        --- Return external subtitle paths keyed by track ID.
        local track_list = mp.get_property_native('track-list')
        local external_subs_list = {}
        for _, track in pairs(track_list) do
            if track.type == 'sub' and track.external == true then
                external_subs_list[track.id] = track['external-filename']
            end
        end
        return external_subs_list
    end

    function self.append_embed_subs_args(args)
        --- Append arguments for embedding external subtitle files.
        local ext_subs_paths = self.get_ext_subs_paths()
        for _, ext_subs_path in pairs(ext_subs_paths) do
            table.insert(args, #args, table.concat { '--sub-files-append=', ext_subs_path, })
        end
        return args
    end

    function self.append_video_filter_args(args)
        --- Append configured mpv video filter arguments.
        if self.config.hdr_to_sdr then
            table.insert(args, #args, '--hwdec=no')
            table.insert(args, #args, table.concat { '--tone-mapping=', HDR_TO_SDR_TONE_MAPPING })
            table.insert(args, #args, table.concat { '--target-trc=', SDR_TRANSFER_CHARACTERISTICS })
            table.insert(args, #args, table.concat { '--target-prim=', SDR_COLOR_PRIMARIES })
            table.insert(args, #args, '--vf-add=gpu')
        end

        for _, filter in ipairs(eutils.video_filter_chain(self.config)) do
            table.insert(args, #args, '--vf-add=' .. filter)
        end

        return args
    end

    ------------------------------------------------------------
    --- Public

    function pub.is_alive()
        --- Return true when mpv or mpvnet can be executed.
        return self.alive == true
    end

    function pub.mk_out_path_audio(clip_filename_noext)
        --- Return the output path for a re-encoded audio clip.
        return eutils.mk_out_path(
                clip_filename_noext,
                self.config.audio_folder_path,
                self.config.audio_extension
        )
    end

    function pub.mk_out_path_video(clip_filename_noext)
        --- Return the output path for a re-encoded video clip.
        return eutils.mk_out_path(
                clip_filename_noext,
                self.config.video_folder_path,
                self.config.video_extension
        )
    end

    function pub.mkargs_audio(out_clip_path)
        --- Return mpv arguments for creating a re-encoded audio clip.
        return self.prepend_common_args(
                '--video=no',
                table.concat { '--oac=', self.config.audio_codec },
                table.concat { '--start=', eutils.toms(self.timings['start']) },
                table.concat { '--end=', eutils.toms(self.timings['end']) },
                table.concat { '--volume=', mp.get_property('volume') },
                table.concat { '--aid=', mp.get_property("aid") }, -- track number
                table.concat { '--oacopts-add=b=', self.config.audio_bitrate },
                table.concat { '--ytdl-format=', mp.get_property("ytdl-format") },
                table.concat { '--o=', out_clip_path }
        )
    end

    function pub.set_alive()
        --- Set self.alive according to whether mpv or mpvnet can be executed.
        local mpv_version = eutils.result_to_str(h.subprocess({ exec.mpv, '--version' }))
        if mpv_version:match('mpv') ~= nil then
            self.alive = true
            self.player = exec.mpv
            return
        end

        local mpvnet_version = eutils.result_to_str(h.subprocess({ exec.mpvnet, '--version' }))
        self.alive = #mpvnet_version > 0
        self.player = exec.mpvnet
    end

    function pub.mkargs_video(out_clip_path)
        --- Return mpv arguments for creating a re-encoded video clip.
        --- --sub-back-color is passed last so the #args inserts below (sub-border-style,
        --- video filters, external subs) stay before it, matching the expected arg order.
        local args = self.prepend_common_args(
                '--sub-font-provider=auto',
                '--embeddedfonts=yes',
                table.concat { '--sub-font=', self.config.sub_font },
                table.concat { '--ovc=', self.config.video_codec },
                table.concat { '--oac=', self.config.audio_codec },
                table.concat { '--start=', eutils.toms(self.timings['start']) },
                table.concat { '--end=', eutils.toms(self.timings['end']) },
                table.concat { '--aid=', mp.get_property("aid") }, -- track number
                table.concat { '--mute=', mp.get_property("mute") },
                table.concat { '--volume=', mp.get_property('volume') },
                table.concat { '--ovcopts-add=b=', self.config.video_bitrate },
                table.concat { '--oacopts-add=b=', self.config.audio_bitrate },
                table.concat { '--ovcopts-add=crf=', self.config.video_quality },
                table.concat { '--ovcopts-add=preset=', self.config.preset },
                table.concat { '--ytdl-format=', mp.get_property("ytdl-format") },
                table.concat { '--o=', out_clip_path },
                table.concat { '--sid=', mp.get_property("sid") },
                table.concat { '--secondary-sid=', mp.get_property("secondary-sid") },
                table.concat { '--sub-delay=', mp.get_property("sub-delay") },
                table.concat { '--sub-visibility=', mp.get_property("sub-visibility") },
                table.concat { '--secondary-sub-visibility=', mp.get_property("secondary-sub-visibility") },
                table.concat { '--sub-back-color=', mp.get_property("sub-back-color") }
        )
        if mp.get_property("sub-border-style", nil) ~= nil then
            table.insert(args, #args, table.concat { '--sub-border-style=', mp.get_property("sub-border-style") })
        end

        args = self.append_video_filter_args(args)
        args = self.append_embed_subs_args(args)

        return args
    end

    return pub
end

local function test_mkargs_video(opts)
    --- Test video argument generation with exact list equality.
    opts = opts or {}
    local config = fixtures.make_config({
        hdr_to_sdr = opts.hdr_to_sdr or false,
        video_fps = opts.video_fps or 'auto',
        audio_format = opts.audio_format or 'opus',
    })
    local test_encoder = make_mpv_encoder(config, fixtures.make_timings())
    local source_path = mp.get_property('path')
    local mute = opts.mute or 'no'
    local args, volume, sub_delay = fixtures.with_properties(
            function()
                return test_encoder.mkargs_video('/tmp/out.mp4'), mp.get_property('volume'), mp.get_property('sub-delay')
            end,
            fixtures.make_pinned_properties(mute)
    )
    h.assert_equals(args, fixtures.expected_video_args({
        hdr_to_sdr = opts.hdr_to_sdr or false,
        mute = mute,
        volume = volume,
        sub_delay = sub_delay,
        video_fps = opts.video_fps or 'auto',
        audio_format = opts.audio_format or 'opus',
        source_path = source_path,
    }))
end

local function test_mkargs_audio(opts)
    --- Test audio argument generation with exact list equality.
    opts = opts or {}
    local out_path = opts.out_path or '/tmp/out.opus'
    local config = fixtures.make_config({ audio_format = opts.audio_format or 'opus' })
    local test_encoder = make_mpv_encoder(config, fixtures.make_timings())
    local source_path = mp.get_property('path')
    local args, volume = fixtures.with_properties(
            function()
                return test_encoder.mkargs_audio(out_path), mp.get_property('volume')
            end,
            { aid = '1', volume = '100', ['ytdl-format'] = '' }
    )
    h.assert_equals(args, fixtures.expected_audio_args({
        audio_format = opts.audio_format or 'opus',
        out_path = out_path,
        volume = volume,
        source_path = source_path,
    }))
end

local function run_tests()
    --- Run tests for the mpv encoder backend.
    test_mkargs_video({ hdr_to_sdr = true, mute = 'no' })
    test_mkargs_video({ hdr_to_sdr = true, mute = 'yes' })
    test_mkargs_video({ hdr_to_sdr = false, mute = 'no' })
    test_mkargs_video({ hdr_to_sdr = false, mute = 'yes' })
    test_mkargs_video({ video_fps = '60' })
    test_mkargs_video({ audio_format = 'aac' })

    test_mkargs_audio({ audio_format = 'opus', out_path = '/tmp/out.opus' })
    test_mkargs_audio({ audio_format = 'aac', out_path = '/tmp/out.aac' })
end

return {
    new = make_mpv_encoder,
    run_tests = run_tests,
    name = NAME,
}
