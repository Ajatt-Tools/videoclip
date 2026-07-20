--[[
Copyright: Ajatt-Tools and contributors; https://github.com/Ajatt-Tools
License: GNU GPL, version 3 or later; http://www.gnu.org/licenses/gpl.html

Make default config.
]]

local p = require('platform')
local this = {}

this.get_default = function()
    return {
        -- absolute paths
        -- relative paths (e.g. ~ for home dir) do NOT work.
        video_folder_path = p.default_video_folder,
        audio_folder_path = p.default_audio_folder,
        -- The range of the CRF scale is 0–51, where 0 is lossless,
        -- 23 is the default, and 51 is worst quality possible.
        -- Insane values like 9999 still work but produce the worst quality.
        video_quality = 23,
        -- Use the slowest preset that you have patience for.
        -- https://trac.ffmpeg.org/wiki/Encode/H.264
        preset = 'faster',
        video_format = 'mp4', -- mp4, vp9, vp8
        video_bitrate = '1M',
        video_width = -2,
        video_height = 480,
        video_fps = 'auto',
        hdr_to_sdr = false,
        use_ffmpeg = false,
        copy_streams = false,
        audio_format = 'opus', -- aac, opus
        audio_bitrate = '32k', -- 32k, 64k, 128k, 256k. aac requires higher bitrates.
        font_size = 24,
        osd_align = 7, -- https://aegisub.org/docs/3.2/ASS_Tags/#\an
        osd_outline = 1.5,
        clean_filename = true,
        -- Whether to upload to catbox (permanent) or litterbox (temporary)
        litterbox = true,
        -- Determines expire time of files uploaded to litterbox
        litterbox_expire = '72h', -- 1h, 12h, 24h, 72h
        sub_font = 'Noto Sans CJK JP',

        -- Custom upload command. %f will be replaced with the file path.
        -- Example for 0x0.st: curl -F'file=@%f' https://0x0.st
        custom_upload_command = '',

        -- Filename format
        -- Available tags: %n = filename, %t = title, %s = start, %e = end, %d = duration,
        --                 %Y = year, %M = months, %D = day, %H = hours (24), %I = hours (12),
        --                 %P = am/pm %N = minutes, %S = seconds
        filename_template = '%n_%s-%e',
    }
end

return this
