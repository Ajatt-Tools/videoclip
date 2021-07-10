![screenshot](https://user-images.githubusercontent.com/69171671/97077527-0836ef00-15d4-11eb-92a5-bfa236a6b118.png)

# videoclip

[![Chat](https://img.shields.io/badge/chat-join-green)](https://tatsumoto-ren.github.io/blog/join-our-community.html)
![GitHub](https://img.shields.io/github/license/Ajatt-Tools/videoclip)
![GitHub top language](https://img.shields.io/github/languages/top/Ajatt-Tools/videoclip)
![Lines of code](https://img.shields.io/tokei/lines/github/Ajatt-Tools/videoclip)

Easily create video and audio clips with mpv in a few keypresses.
Videoclips are saved as `.mp4` or `.webm`.
Subtitles can be embedded into the clips.

## Installation

### Manually

Download
[the repository](https://github.com/Ajatt-Tools/videoclip/archive/refs/heads/master.zip)
and extract the folder containing
`videoclip.lua`
to your [mpv scripts](https://github.com/mpv-player/mpv/wiki/User-Scripts) directory:

| OS | Location |
| --- | --- |
| GNU/Linux | `~/.config/mpv/scripts/` |
| Windows | `C:/Users/Username/AppData/Roaming/mpv/scripts/` |

Note: in [Celluloid](https://www.archlinux.org/packages/community/x86_64/celluloid/)
user scripts are installed by switching to the "Plugins" tab
in the preferences dialog and dropping the files there.

<details>

<summary>Expected directory tree</summary>

```
~/.config/mpv/scripts
|-- other_addon_1
|-- other_addon_2
`-- videoclip
    |-- main.lua
    |-- ...
    `-- videoclip.lua
```

</details>

### Using git

If you already have your dotfiles set up according to
[Arch Wiki recommendations](https://wiki.archlinux.org/index.php/Dotfiles#Tracking_dotfiles_directly_with_Git), execute:
```
$ config submodule add 'https://github.com/Ajatt-Tools/videoclip.git' ~/.config/mpv/scripts/videoclip
```

If not, either proceed to Arch Wiki and come back when you're done, or simply clone the repo:
```
$ git clone 'https://github.com/Ajatt-Tools/videoclip.git' ~/.config/mpv/scripts/videoclip
```

### Updating with git

| Install method | Command |
| --- | --- |
| Submodules | `$ config submodule update --remote --merge` |
| Plain git | `$ cd ~/.config/mpv/scripts/videoclip && git pull` |

## Configuration

The config file should be created by the user, if needed.

| OS | Config location |
| --- | --- |
| GNU/Linux | `~/.config/mpv/script-opts/videoclip.conf` |
| Windows | `C:/Users/Username/AppData/Roaming/mpv/script-opts/videoclip.conf` |

If a parameter is not specified in the config file, the default value will be used.
mpv doesn't tolerate spaces before and after `=`.

Example configuration file:

```
# Absolute paths to the folders where generated clips will be placed.
# `~` or `$HOME` are not supported due to mpv limitations.
video_folder_path=/home/user/Videos
audio_folder_path=/home/user/Music

# Menu size
font_size=24

# Video settings
video_width=-2
video_height=480
video_bitrate=1M
# Available video formats: mp4, vp9, vp8
video_format=mp4
# The range of the scale is 0–51, where 0 is lossless,
# 23 is the default, and 51 is worst quality possible.
# Insane values like 9999 still work but produce the worst quality.
video_quality=23
# Use the slowest preset that you have patience for.
# https://trac.ffmpeg.org/wiki/Encode/H.264
preset=faster

# Audio settings
# Available formats: opus or aac
audio_format=opus
# Opus sounds good at low bitrates 32-64k, but aac requires 128-256k.
audio_bitrate=32k
```

### Key bindings

| OS | Config location |
| --- | --- |
| GNU/Linux | `~/.config/mpv/input.conf` |
| Windows | `C:/Users/Username/AppData/Roaming/mpv/input.conf` |

Add this line if you want to change the key that opens the script's menu.

```
c script-binding videoclip-menu-open
```

## Usage

- Open a file in mpv and press `c` to open the script menu.
- Follow the onscreen instructions. You need to set the `start point`,
`end point`, and then press `c` to create the clip.

It is possible to create silent videoclips.
To do that, first mute audio in mpv.
The default key binding is `m`.

If a video has visible subtitles, they will be embedded automatically.
Toggle them off in mpv if you don't want any subtitles to be visible.
The default key binding is `v`.
