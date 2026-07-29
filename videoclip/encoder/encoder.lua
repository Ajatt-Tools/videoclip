--[[
Copyright: Ajatt-Tools and contributors; https://github.com/Ajatt-Tools
License: GNU GPL, version 3 or later; http://www.gnu.org/licenses/gpl.html

Encoder facade that routes clip creation to mpv or ffmpeg backends.
]]

local mp = require('mp')
local utils = require('mp.utils')
local h = require('helpers')
local mpv_encoder = require('encoder.mpv')
local ffmpeg_encoder = require('encoder.ffmpeg')
local fixtures = require('test_fixtures')

--- Expand a filename template by substituting the available tags.
--- Available tags: %n = filename, %t = title, %s = start, %e = end, %d = duration,
---                 %Y = year, %M = month, %D = day, %H = hours (24), %I = hours (12),
---                 %P = am/pm, %N = minutes, %S = seconds.
--- Examples:
---    expand_filename_template('%n_%s-%e', 'video', 'video', {start=0, ['end']=1}, os.date('*t'))
local function expand_filename_template(template, filename, title, timings, date)
    local twelve = h.twelve_hour(date.hour)
    return (template
            :gsub("%%n", h.truncate_utf8_bytes(filename, 200))
            :gsub("%%t", h.truncate_utf8_bytes(title, 200))
            :gsub("%%s", h.human_readable_time(timings['start']))
            :gsub("%%e", h.human_readable_time(timings['end']))
            :gsub("%%d", h.human_readable_time(timings['end'] - timings['start']))
            :gsub("%%Y", tostring(date.year))
            :gsub("%%M", h.two_digit(date.month))
            :gsub("%%D", h.two_digit(date.day))
            :gsub("%%H", h.two_digit(date.hour))
            :gsub("%%I", h.two_digit(twelve.hour))
            :gsub("%%P", twelve.sign)
            :gsub("%%N", h.two_digit(date.min))
            :gsub("%%S", h.two_digit(date.sec)))
end

local function clip_result_failed(ret)
    --- Return true when the encoder process did not produce a successful result.
    return ret == nil or ret.status ~= 0 or string.match(ret.stdout or "", "could not open") ~= nil
end

--- Create the encoder facade.
--- Routes clip creation to the mpv or ffmpeg backend based on the current config.
local function make_encoder()
    local this = {
        config = nil,
        timings = nil,
        mpv = nil,
        ffmpeg = nil,
    }
    local pub = {}

    local function clean_filename(filename)
        --- Return a sanitized filename base according to the current config.
        filename = h.remove_extension(filename)
        if this.config.clean_filename then
            filename = h.remove_text_in_brackets(filename)
            filename = h.remove_special_characters(filename)
            -- remove_text_in_brackets might leave spaces at the start or the end, so trim those
            filename = h.strip(filename)
        end
        return filename
    end

    local function construct_output_filename_noext()
        --- Construct the configured output filename without extension.
        local filename = mp.get_property("filename") -- filename without path
        local title = mp.get_property("media-title") -- if the video doesn't have a title, it will fallback to filename
        local date = os.date("*t") -- get current date and time as table

        -- Apply the same operation when the video doesn't have a title
        -- thus it will be the same as filename
        if title == filename then
            filename = clean_filename(filename)
            title = filename
        else
            filename = clean_filename(filename)
            title = h.clean_forbidden_characters(title)
        end

        return expand_filename_template(this.config.filename_template, filename, title, this.timings, date)
    end

    local function uses_ffmpeg()
        --- Return true when the current config requires the ffmpeg backend.
        return this.config.use_ffmpeg or this.config.copy_streams
    end

    local function mk_output_args(backend, clip_type)
        --- Build the output path and encoder arguments for the given clip type.
        local clip_filename_noext = construct_output_filename_noext()
        if clip_type == 'video' then
            local output_path = backend.mk_out_path_video(clip_filename_noext)
            return output_path, backend.mkargs_video(output_path)
        else
            local output_path = backend.mk_out_path_audio(clip_filename_noext)
            return output_path, backend.mkargs_audio(output_path)
        end
    end

    ------------------------------------------------------------
    --- Public

    function pub.active_backend()
        --- Return the backend selected for the current config.
        if uses_ffmpeg() then
            return this.ffmpeg
        end
        return this.mpv
    end

    function pub.create_clip(clip_type, on_complete)
        --- Create a clip of the requested type using the selected backend.
        if clip_type == nil then
            return
        end

        if not this.timings:validate() then
            h.notify_error("Wrong timings. Aborting.", "warn", 2)
            return
        end

        if uses_ffmpeg() and not pub.is_alive("ffmpeg") then
            h.notify_error("Error: ffmpeg is not found in the PATH.", "error", 5)
            return
        end

        h.notify("Please wait...", "info", 9999)

        local output_file_path, args = mk_output_args(pub.active_backend(), clip_type)

        mp.msg.info("Executing: %s", table.concat(h.quote_if_necessary(args), " "))

        local output_dir_path = utils.split_path(output_file_path)
        local location_info = utils.file_info(output_dir_path)
        if not location_info or not location_info.is_dir then
            h.notify_error(string.format("Error: location %s doesn't exist.", output_dir_path), "error", 5)
            return
        end

        local process_result = function(_, ret, err)
            if ret == nil then
                h.notify_error(string.format("Error: couldn't create clip %s.", output_file_path), "error", 5)
                mp.msg.error("Clip subprocess failed: " .. (err or "unknown error"))
                return
            end
            if ret.status ~= 0 or string.match(ret.stdout or "", "could not open") then
                h.notify_error(string.format("Error: couldn't create clip %s.", output_file_path), "error", 5)
            else
                h.notify(string.format("Clip saved to %s.", output_file_path), "info", 2)
                if on_complete then
                    on_complete(output_file_path)
                end
            end
        end

        h.subprocess_async(args, process_result)
        this.timings:reset()
    end

    function pub.is_alive(encoder_name)
        --- Return true when the named encoder ("mpv" or "ffmpeg") can be executed.
        if encoder_name == "mpv" then
            return this.mpv.is_alive()
        elseif encoder_name == "ffmpeg" then
            return this.ffmpeg.is_alive()
        end
        error("unknown encoder name: " .. encoder_name)
    end

    function pub.init(config, timings_mgr)
        --- Initialize encoder backends with shared config and timings state.
        this.config = config
        this.timings = timings_mgr
        this.mpv = mpv_encoder.new(config, timings_mgr)
        this.ffmpeg = ffmpeg_encoder.new(config, timings_mgr)
        this.mpv.set_alive()
        this.ffmpeg.set_alive()
        return pub
    end

    return pub
end

local function run_tests()
    --- Run tests for filename template expansion and backend routing.
    local fixed_date = { year = 2024, month = 3, day = 5, hour = 14, min = 7, sec = 9 }
    local timings = { ['start'] = 1.5, ['end'] = 4.25 }

    h.assert_equals(expand_filename_template('%n_%s-%e', 'video', 'video', timings, fixed_date), 'video_00m01s500ms-00m04s250ms')
    h.assert_equals(expand_filename_template('%d', 'video', 'video', timings, fixed_date), '00m02s750ms')
    h.assert_equals(expand_filename_template('%Y-%M-%D_%H-%I-%P-%N-%S', 'v', 't', timings, fixed_date), '2024-03-05_14-02-pm-07-09')
    h.assert_equals(expand_filename_template('clip_%t', 'file', 'My Title', timings, fixed_date), 'clip_My Title')

    local test_encoder = make_encoder()

    test_encoder.init(fixtures.make_config({ use_ffmpeg = false, copy_streams = false }), fixtures.make_timings())
    h.assert_equals(test_encoder.active_backend().name, mpv_encoder.name)

    test_encoder.init(fixtures.make_config({ use_ffmpeg = true, copy_streams = false }), fixtures.make_timings())
    h.assert_equals(test_encoder.active_backend().name, ffmpeg_encoder.name)

    test_encoder.init(fixtures.make_config({ use_ffmpeg = false, copy_streams = true }), fixtures.make_timings())
    h.assert_equals(test_encoder.active_backend().name, ffmpeg_encoder.name)

    h.assert_equals(clip_result_failed(nil), true)
    h.assert_equals(clip_result_failed({ status = 1, stdout = '', stderr = 'error' }), true)
    h.assert_equals(clip_result_failed({ status = 0, stdout = 'could not open file', stderr = '' }), true)
    h.assert_equals(clip_result_failed({ status = 0, stdout = '', stderr = '' }), false)
end

return {
    new = make_encoder,
    run_tests = run_tests,
}
