--[[
Copyright: Ren Tatsumoto and contributors
License: GNU GPL, version 3 or later; http://www.gnu.org/licenses/gpl.html

Encoder provides interface for creating audio/video clips.
]]

local mp = require('mp')
local h = require('helpers')
local utils = require('mp.utils')
local this = {}

local function toms(timestamp)
    --- Trim timestamp down to milliseconds.
    return string.format("%.3f", timestamp)
end

local function clean_filename(filename)
    filename = h.remove_extension(filename)
    if this.config.clean_filename then
        filename = h.remove_text_in_brackets(filename)
        filename = h.remove_special_characters(filename)
        -- remove_text_in_brackets might leave spaces at the start or the end, so trim those
        filename = h.strip(filename)
    end
    return filename
end

local function clean_forbidden_characters(title)
    return title:gsub('[<>:"/\\|%?%*]+', '.')
end

local function construct_output_filename_noext()

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
        title = clean_forbidden_characters(title)
    end

    -- Available tags: %n = filename, %t = title, %s = start, %e = end, %d = duration,
    --                 %Y = year, %M = months, %D = day, %H = hours (24), %I = hours (12),
    --                 %P = am/pm %N = minutes, %S = seconds
    filename = this.config.filename_template
            :gsub("%%n", filename)
            :gsub("%%t", title)
            :gsub("%%s", h.human_readable_time(this.timings['start']))
            :gsub("%%e", h.human_readable_time(this.timings['end']))
            :gsub("%%d", h.human_readable_time(this.timings['end'] - this.timings['start']))
            :gsub("%%Y", date.year)
            :gsub("%%M", h.two_digit(date.month))
            :gsub("%%D", h.two_digit(date.day))
            :gsub("%%H", h.two_digit(date.hour))
            :gsub("%%I", h.two_digit(h.twelve_hour(date.hour)['hour']))
            :gsub("%%P", h.twelve_hour(date.hour)['sign'])
            :gsub("%%N", h.two_digit(date.min))
            :gsub("%%S", h.two_digit(date.sec))

    return filename
end

function this.get_ext_subs_paths()
    local track_list = mp.get_property_native('track-list')
    local external_subs_list = {}
    for _, track in pairs(track_list) do
        if track.type == 'sub' and track.external == true then
            external_subs_list[track.id] = track['external-filename']
        end
    end
    return external_subs_list
end

function this.append_embed_subs_args(args)
    local ext_subs_paths = this.get_ext_subs_paths()
    for _, ext_subs_path in pairs(ext_subs_paths) do
        table.insert(args, #args, table.concat { '--sub-files-append=', ext_subs_path, })
    end
    return args
end

this.mk_out_path_video = function(clip_filename_noext)
    return utils.join_path(h.expand_path(this.config.video_folder_path), clip_filename_noext .. this.config.video_extension)
end

this.mkargs_video = function(out_clip_path)
    local args = {
        this.player,
        mp.get_property('path'),
        '--loop-file=no',
        '--keep-open=no',
        '--no-ocopy-metadata',
        '--no-sub',
        '--audio-channels=2',
        '--oacopts-add=vbr=on',
        '--oacopts-add=application=voip',
        '--oacopts-add=compression_level=10',
        '--vf-add=format=yuv420p',
        '--sub-font-provider=auto',
        '--embeddedfonts=yes',
        table.concat { '--sub-font=', this.config.sub_font },
        table.concat { '--ovc=', this.config.video_codec },
        table.concat { '--oac=', this.config.audio_codec },
        table.concat { '--start=', toms(this.timings['start']) },
        table.concat { '--end=', toms(this.timings['end']) },
        table.concat { '--aid=', mp.get_property("aid") }, -- track number
        table.concat { '--mute=', mp.get_property("mute") },
        table.concat { '--volume=', mp.get_property('volume') },
        table.concat { '--ovcopts-add=b=', this.config.video_bitrate },
        table.concat { '--oacopts-add=b=', this.config.audio_bitrate },
        table.concat { '--ovcopts-add=crf=', this.config.video_quality },
        table.concat { '--ovcopts-add=preset=', this.config.preset },
        table.concat { '--vf-add=scale=', this.config.video_width, ':', this.config.video_height },
        table.concat { '--ytdl-format=', mp.get_property("ytdl-format") },
        table.concat { '--o=', out_clip_path },
        table.concat { '--sid=', mp.get_property("sid") },
        table.concat { '--secondary-sid=', mp.get_property("secondary-sid") },
        table.concat { '--sub-delay=', mp.get_property("sub-delay") },
        table.concat { '--sub-visibility=', mp.get_property("sub-visibility") },
        table.concat { '--secondary-sub-visibility=', mp.get_property("secondary-sub-visibility") },
        table.concat { '--sub-back-color=', mp.get_property("sub-back-color") },
        table.concat { '--sub-border-style=', mp.get_property("sub-border-style") },
    }

    if this.config.video_fps ~= 'auto' then
        table.insert(args, #args, table.concat { '--vf-add=fps=', this.config.video_fps })
    end

    args = this.append_embed_subs_args(args)

    return args
end

this.mk_out_path_audio = function(clip_filename_noext)
    return utils.join_path(h.expand_path(this.config.audio_folder_path), clip_filename_noext .. this.config.audio_extension)
end

this.mkargs_audio = function(out_clip_path)
    return {
        this.player,
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
        table.concat { '--oac=', this.config.audio_codec },
        table.concat { '--start=', toms(this.timings['start']) },
        table.concat { '--end=', toms(this.timings['end']) },
        table.concat { '--volume=', mp.get_property('volume') },
        table.concat { '--aid=', mp.get_property("aid") }, -- track number
        table.concat { '--oacopts-add=b=', this.config.audio_bitrate },
        table.concat { '--ytdl-format=', mp.get_property("ytdl-format") },
        table.concat { '--o=', out_clip_path }
    }
end

this.create_clip = function(clip_type, on_complete)
    if clip_type == nil then
        return
    end

    if not this.timings:validate() then
        h.notify_error("Wrong timings. Aborting.", "warn", 2)
        return
    end

    h.notify("Please wait...", "info", 9999)

    local output_file_path, args = (function()
        local clip_filename_noext = construct_output_filename_noext()
        if clip_type == 'video' then
            local output_path = this.mk_out_path_video(clip_filename_noext)
            return output_path, this.mkargs_video(output_path)
        else
            local output_path = this.mk_out_path_audio(clip_filename_noext)
            return output_path, this.mkargs_audio(output_path)
        end
    end)()

    print("The following args will be executed:", table.concat(h.quote_if_necessary(args), " "))

    local output_dir_path = utils.split_path(output_file_path)
    local location_info = utils.file_info(output_dir_path)
    if not location_info or not location_info.is_dir then
        h.notify_error(string.format("Error: location %s doesn't exist.", output_dir_path), "error", 5)
        return
    end

    local process_result = function(_, ret, _)
        if ret.status ~= 0 or string.match(ret.stdout, "could not open") then
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

this.set_encoder_alive = function()
    local args_mpvnet = { 'mpvnet', '--version' }
    local process_result_mpvnet = function(_, ret, _)
        --  for some reason stdout is empty
        if ret.status ~= 0 then
            this.alive = false
        else
            this.alive = true
            this.player = 'mpvnet'
        end
    end

    local args = { 'mpv', '--version' }
    local process_result = function(_, ret, _)
        if ret.status ~= 0 or string.match(ret.stdout, "mpv") == nil then
            h.subprocess_async(args_mpvnet, process_result_mpvnet)
        else
            this.alive = true
            this.player = 'mpv'
        end
    end
    h.subprocess_async(args, process_result)
end

this.init = function(config, timings_mgr)
    this.config = config
    this.timings = timings_mgr
    this.set_encoder_alive()
end

return this
