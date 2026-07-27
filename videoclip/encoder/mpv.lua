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
    local pub = {name = NAME}

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

        table.insert(args, #args, table.concat { '--vf-add=scale=', self.config.video_width, ':', self.config.video_height })

        if self.config.video_fps ~= 'auto' then
            table.insert(args, #args, table.concat { '--vf-add=fps=', self.config.video_fps })
        end

        table.insert(args, #args, '--vf-add=format=yuv420p')

        return args
    end

    ------------------------------------------------------------
    --- Public

    function pub.is_alive()
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
        return {
            self.player,
            mp.get_property('path'),
            '--loop-file=no',
            '--keep-open=no',
            '--no-ocopy-metadata',
            '--no-sub',
            '--audio-channels=2',
            '--video=no',
            '--oacopts-add=vbr=on',
            '--oacopts-add=application=voip',
            '--oacopts-add=compression_level=10',
            table.concat { '--oac=', self.config.audio_codec },
            table.concat { '--start=', eutils.toms(self.timings['start']) },
            table.concat { '--end=', eutils.toms(self.timings['end']) },
            table.concat { '--volume=', mp.get_property('volume') },
            table.concat { '--aid=', mp.get_property("aid") }, -- track number
            table.concat { '--oacopts-add=b=', self.config.audio_bitrate },
            table.concat { '--ytdl-format=', mp.get_property("ytdl-format") },
            table.concat { '--o=', out_clip_path }
        }
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
        local args = {
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
            table.concat { '--sub-back-color=', mp.get_property("sub-back-color") },
        }
        if mp.get_property("sub-border-style", nil) ~= nil then
            table.insert(args, #args, table.concat { '--sub-border-style=', mp.get_property("sub-border-style") })
        end

        args = self.append_video_filter_args(args)
        args = self.append_embed_subs_args(args)

        return args
    end

    return pub
end

local function run_tests()
    --- Run tests for the mpv encoder backend.
    local test_encoder = make_mpv_encoder(fixtures.make_config({ hdr_to_sdr = true }), fixtures.make_timings())
    local args = test_encoder.mkargs_video('/tmp/out.mp4')
    h.assert_equals(fixtures.contains(args, '--hwdec=no'), true)
    h.assert_equals(fixtures.contains(args, '--tone-mapping=bt.2390'), true)
    h.assert_equals(fixtures.contains(args, '--target-trc=bt.1886'), true)
    h.assert_equals(fixtures.contains(args, '--target-prim=bt.709'), true)
    h.assert_equals(fixtures.contains(args, '--vf-add=gpu'), true)
    h.assert_equals(fixtures.index_of(args, '--vf-add=gpu') < fixtures.index_of(args, '--vf-add=scale=-2:480'), true)
    h.assert_equals(fixtures.index_of(args, '--vf-add=scale=-2:480') < fixtures.index_of(args, '--vf-add=format=yuv420p'), true)
end

return {
    new = make_mpv_encoder,
    run_tests = run_tests,
    name = NAME,
}
