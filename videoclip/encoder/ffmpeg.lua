--[[
Copyright: Ajatt-Tools and contributors; https://github.com/Ajatt-Tools
License: GNU GPL, version 3 or later; http://www.gnu.org/licenses/gpl.html

Encoder backend that uses ffmpeg.
]]

local mp = require('mp')
local h = require('helpers')
local eutils = require('encoder.utils')
local exec = require('encoder.executables')
local fixtures = require('test_fixtures')
local NAME = "ffmpeg_encoder"

local function make_ffmpeg_encoder(config, timings)
    --- Create an ffmpeg encoder backend.
    --- The backend can either re-encode clips or copy streams without re-encoding.
    local self = {
        config = config,
        timings = timings,
        alive = nil,
        player = exec.ffmpeg,
    }
    local pub = { name = NAME }

    function self.prepend_common_args(...)
        --- Return the shared ffmpeg command prefix plus extra arguments.
        return {
            self.player,
            '-hide_banner',
            '-nostdin',
            '-y',
            ...,
        }
    end

    function self.prepend_input_args(...)
        --- Return the shared ffmpeg input prefix: seek range + source path + extra args.
        return self.prepend_common_args(
                '-ss', eutils.toms(self.timings['start']),
                '-to', eutils.toms(self.timings['end']),
                '-i', mp.get_property('path'),
                ...
        )
    end

    function self.selected_video_map()
        --- Return an ffmpeg -map value for the currently selected video stream.
        return eutils.ffmpeg_stream_map('video', '0:v:0')
    end

    function self.selected_audio_map()
        --- Return an ffmpeg -map value for the currently selected audio stream.
        return eutils.ffmpeg_stream_map('audio', '0:a:0?')
    end

    function self.audio_disabled()
        --- Return true when the current mpv state should produce a video without audio.
        return mp.get_property("mute") == "yes" or mp.get_property("aid") == "no"
    end

    function self.append_common_output_args(args)
        --- Append options that prevent copying unrelated streams and metadata.
        table.insert(args, '-sn')
        table.insert(args, '-dn')
        table.insert(args, '-map_metadata')
        table.insert(args, '-1')
        table.insert(args, '-map_chapters')
        table.insert(args, '-1')
        return args
    end

    function self.make_video_filters()
        --- Return a comma-separated string of video filters.
        local video_filters = { table.concat { 'scale=', self.config.video_width, ':', self.config.video_height } }
        if self.config.video_fps ~= 'auto' then
            table.insert(video_filters, table.concat { 'fps=', self.config.video_fps })
        end
        table.insert(video_filters, 'format=yuv420p')
        return table.concat(video_filters, ',')
    end

    function self.append_video_reencode_args(args)
        --- Append video re-encoding options matching the configured video preferences.
        table.insert(args, '-c:v')
        table.insert(args, self.config.video_codec)
        table.insert(args, '-b:v')
        table.insert(args, self.config.video_bitrate)
        table.insert(args, '-crf')
        table.insert(args, tostring(self.config.video_quality))
        table.insert(args, '-preset')
        table.insert(args, self.config.preset)
        table.insert(args, '-vf')
        table.insert(args, self.make_video_filters())
        return args
    end

    function self.append_audio_reencode_args(args)
        --- Append audio re-encoding options matching the configured audio preferences.
        table.insert(args, '-c:a')
        table.insert(args, self.config.audio_codec)
        table.insert(args, '-b:a')
        table.insert(args, self.config.audio_bitrate)
        if self.config.audio_format == 'opus' then
            table.insert(args, '-application')
            table.insert(args, 'voip')
            table.insert(args, '-compression_level')
            table.insert(args, '10')
        end
        return args
    end

    function self.mkargs_video_copy(out_clip_path)
        --- Return ffmpeg args that copy the selected video and optional audio streams.
        local args = self.prepend_input_args(
                '-map', self.selected_video_map(),
                '-c:v', 'copy'
        )
        if self.audio_disabled() then
            table.insert(args, '-an')
        else
            table.insert(args, '-map')
            table.insert(args, self.selected_audio_map())
            table.insert(args, '-c:a')
            table.insert(args, 'copy')
        end
        table.insert(args, '-avoid_negative_ts')
        table.insert(args, 'make_zero')
        args = self.append_common_output_args(args)
        table.insert(args, out_clip_path)
        return args
    end

    function self.mkargs_video_reencode(out_clip_path)
        --- Return ffmpeg args that re-encode the selected video and optional audio streams.
        local args = self.prepend_input_args(
                '-map', self.selected_video_map()
        )
        if self.audio_disabled() then
            table.insert(args, '-an')
        else
            table.insert(args, '-map')
            table.insert(args, self.selected_audio_map())
            args = self.append_audio_reencode_args(args)
        end
        args = self.append_video_reencode_args(args)
        args = self.append_common_output_args(args)
        table.insert(args, out_clip_path)
        return args
    end

    function self.mkargs_audio_copy(out_clip_path)
        --- Return ffmpeg args that copy the selected audio stream.
        local args = self.prepend_input_args(
                '-map', self.selected_audio_map(),
                '-vn',
                '-sn',
                '-dn',
                '-c:a', 'copy',
                '-avoid_negative_ts', 'make_zero',
                '-map_metadata', '-1',
                '-map_chapters', '-1'
        )
        table.insert(args, out_clip_path)
        return args
    end

    function self.mkargs_audio_reencode(out_clip_path)
        --- Return ffmpeg args that re-encode the selected audio stream.
        local args = self.prepend_input_args(
                '-map', self.selected_audio_map(),
                '-vn',
                '-sn',
                '-dn',
                '-map_metadata', '-1',
                '-map_chapters', '-1'
        )
        args = self.append_audio_reencode_args(args)
        table.insert(args, out_clip_path)
        return args
    end

    ------------------------------------------------------------
    --- Public

    function pub.mk_out_path_video(clip_filename_noext)
        --- Return the output path for a video clip.
        if self.config.copy_streams then
            return eutils.mk_out_path(
                    clip_filename_noext,
                    self.config.video_folder_path,
                    eutils.source_extension(mp.get_property('path'), 'mkv')
            )
        end
        return eutils.mk_out_path(
                clip_filename_noext,
                self.config.video_folder_path,
                self.config.video_extension
        )
    end

    function pub.mk_out_path_audio(clip_filename_noext)
        --- Return the output path for an audio clip.
        if self.config.copy_streams then
            local codec = mp.get_property_native("current-tracks/audio/codec")
            return eutils.mk_out_path(
                    clip_filename_noext,
                    self.config.audio_folder_path,
                    eutils.audio_codec_to_extension(codec)
            )
        end
        return eutils.mk_out_path(
                clip_filename_noext,
                self.config.audio_folder_path,
                self.config.audio_extension
        )
    end

    function pub.mkargs_video(out_clip_path)
        --- Return ffmpeg args for a video clip.
        if self.config.copy_streams then
            return self.mkargs_video_copy(out_clip_path)
        end
        return self.mkargs_video_reencode(out_clip_path)
    end

    function pub.mkargs_audio(out_clip_path)
        --- Return ffmpeg args for an audio clip.
        if self.config.copy_streams then
            return self.mkargs_audio_copy(out_clip_path)
        end
        return self.mkargs_audio_reencode(out_clip_path)
    end

    function pub.is_alive()
        return self.alive == true
    end

    function pub.set_alive()
        --- Set self.alive according to whether ffmpeg can be executed.
        local result = h.subprocess({ self.player, '-version' })
        local version = eutils.result_to_str(result)
        self.alive = version:match('ffmpeg version') ~= nil
    end

    return pub
end

local function test_copy_mode(source_path, video_map, audio_map)
    local copy_backend = make_ffmpeg_encoder(fixtures.make_config({ copy_streams = true }), fixtures.make_timings())

    -- Video, stream copy, unmuted.
    h.assert_equals(copy_backend.mkargs_video('/tmp/out.mkv'), {
        exec.ffmpeg,
        '-hide_banner',
        '-nostdin',
        '-y',
        '-ss', '1.000',
        '-to', '2.000',
        '-i', source_path,
        '-map', video_map,
        '-c:v', 'copy',
        '-map', audio_map,
        '-c:a', 'copy',
        '-avoid_negative_ts', 'make_zero',
        '-sn',
        '-dn',
        '-map_metadata', '-1',
        '-map_chapters', '-1',
        '/tmp/out.mkv',
    })

    -- Video, stream copy, muted.
    h.assert_equals(
            fixtures.with_properties(h.partial(copy_backend.mkargs_video, '/tmp/out.mkv'), { mute = 'yes' }),
            {
                exec.ffmpeg,
                '-hide_banner',
                '-nostdin',
                '-y',
                '-ss', '1.000',
                '-to', '2.000',
                '-i', source_path,
                '-map', video_map,
                '-c:v', 'copy',
                '-an',
                '-avoid_negative_ts', 'make_zero',
                '-sn',
                '-dn',
                '-map_metadata', '-1',
                '-map_chapters', '-1',
                '/tmp/out.mkv',
            }
    )

    -- Audio, stream copy.
    h.assert_equals(copy_backend.mkargs_audio('/tmp/out.m4a'), {
        exec.ffmpeg,
        '-hide_banner',
        '-nostdin',
        '-y',
        '-ss', '1.000',
        '-to', '2.000',
        '-i', source_path,
        '-map', audio_map,
        '-vn',
        '-sn',
        '-dn',
        '-c:a', 'copy',
        '-avoid_negative_ts', 'make_zero',
        '-map_metadata', '-1',
        '-map_chapters', '-1',
        '/tmp/out.m4a',
    })
end

local function test_reencode_mode(source_path, video_map, audio_map)
    local reencode_backend = make_ffmpeg_encoder(fixtures.make_config({ copy_streams = false }), fixtures.make_timings())

    -- Video, re-encode, unmuted.
    h.assert_equals(reencode_backend.mkargs_video('/tmp/out.mp4'), {
        exec.ffmpeg,
        '-hide_banner',
        '-nostdin',
        '-y',
        '-ss', '1.000',
        '-to', '2.000',
        '-i', source_path,
        '-map', video_map,
        '-map', audio_map,
        '-c:a', 'libopus',
        '-b:a', '32k',
        '-application', 'voip',
        '-compression_level', '10',
        '-c:v', 'libx264',
        '-b:v', '1M',
        '-crf', '23',
        '-preset', 'faster',
        '-vf', 'scale=-2:480,format=yuv420p',
        '-sn',
        '-dn',
        '-map_metadata', '-1',
        '-map_chapters', '-1',
        '/tmp/out.mp4',
    })

    -- Video, re-encode, muted.
    h.assert_equals(
            fixtures.with_properties(h.partial(reencode_backend.mkargs_video, '/tmp/out.mp4'), { mute = 'yes' }),
            {
                exec.ffmpeg,
                '-hide_banner',
                '-nostdin',
                '-y',
                '-ss', '1.000',
                '-to', '2.000',
                '-i', source_path,
                '-map', video_map,
                '-an',
                '-c:v', 'libx264',
                '-b:v', '1M',
                '-crf', '23',
                '-preset', 'faster',
                '-vf', 'scale=-2:480,format=yuv420p',
                '-sn',
                '-dn',
                '-map_metadata', '-1',
                '-map_chapters', '-1',
                '/tmp/out.mp4',
            }
    )

    local fixed_fps_backend = make_ffmpeg_encoder(
            fixtures.make_config({ copy_streams = false, video_fps = 60 }),
            fixtures.make_timings()
    )

    -- Video, re-encode, fixed FPS.
    h.assert_equals(fixed_fps_backend.mkargs_video('/tmp/out.mp4'), {
        exec.ffmpeg,
        '-hide_banner',
        '-nostdin',
        '-y',
        '-ss', '1.000',
        '-to', '2.000',
        '-i', source_path,
        '-map', video_map,
        '-map', audio_map,
        '-c:a', 'libopus',
        '-b:a', '32k',
        '-application', 'voip',
        '-compression_level', '10',
        '-c:v', 'libx264',
        '-b:v', '1M',
        '-crf', '23',
        '-preset', 'faster',
        '-vf', 'scale=-2:480,fps=60,format=yuv420p',
        '-sn',
        '-dn',
        '-map_metadata', '-1',
        '-map_chapters', '-1',
        '/tmp/out.mp4',
    })

    -- Audio, re-encode.
    h.assert_equals(reencode_backend.mkargs_audio('/tmp/out.opus'), {
        exec.ffmpeg,
        '-hide_banner',
        '-nostdin',
        '-y',
        '-ss', '1.000',
        '-to', '2.000',
        '-i', source_path,
        '-map', audio_map,
        '-vn',
        '-sn',
        '-dn',
        '-map_metadata', '-1',
        '-map_chapters', '-1',
        '-c:a', 'libopus',
        '-b:a', '32k',
        '-application', 'voip',
        '-compression_level', '10',
        '/tmp/out.opus',
    })
end

local function run_tests()
    --- Run tests for the ffmpeg encoder backend.
    local source_path = mp.get_property('path')
    local video_map = eutils.ffmpeg_stream_map('video', '0:v:0')
    local audio_map = eutils.ffmpeg_stream_map('audio', '0:a:0?')

    -- Stream copy mode
    test_copy_mode(source_path, video_map, audio_map)
    -- Re-encode mode
    test_reencode_mode(source_path, video_map, audio_map)
end

return {
    new = make_ffmpeg_encoder,
    run_tests = run_tests,
    name = NAME,
}
