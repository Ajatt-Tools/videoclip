![screenshot](https://user-images.githubusercontent.com/69171671/97077527-0836ef00-15d4-11eb-92a5-bfa236a6b118.png)

# videoclip

![GitHub](https://img.shields.io/github/license/Ajatt-Tools/videoclip)
![GitHub top language](https://img.shields.io/github/languages/top/Ajatt-Tools/videoclip)
![Lines of code](https://img.shields.io/tokei/lines/github/Ajatt-Tools/videoclip)
[![Matrix](https://img.shields.io/badge/Japanese_study_room-join-green.svg)](https://app.element.io/#/room/#djt:g33k.se)

Easily create video and audio clips with mpv in a few keypresses.
Videoclips are saved as `.mp4` or `.webm`.

## Installation
### Manually

Save [videoclip.lua](https://raw.githubusercontent.com/Ajatt-Tools/videoclip/master/videoclip.lua)
in  the [mpv scripts](https://github.com/mpv-player/mpv/wiki/User-Scripts) folder:

| OS | Location |
| --- | --- |
| GNU/Linux | `~/.config/mpv/scripts/` |
| Windows | `C:/Users/Username/AppData/Roaming/mpv/scripts/` |

Note: in [Celluloid](https://www.archlinux.org/packages/community/x86_64/celluloid/)
user scripts are installed by switching to the "Plugins" tab
in the preferences dialog and dropping the files there.

### Using curl
```
$ curl -o ~/.config/mpv/scripts/videoclip.lua 'https://raw.githubusercontent.com/Ajatt-Tools/videoclip/master/videoclip.lua'
```
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
Since you've just cloned the script to its own subfolder,
you need to tell mpv where to look for it.
Open or create  `~/.config/mpv/scripts/modules.lua` and add these lines:
```
local mpv_scripts_dir_path = os.getenv("HOME") ..  "/.config/mpv/scripts/"
function load(relative_path) dofile(mpv_scripts_dir_path .. relative_path) end
load("videoclip/videoclip.lua")
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
# Sane values for audio bitrate are from 16k to 64k.
audio_bitrate=32k
# Create silent videoclips by default. Possble values: `yes` or `no`.
mute_audio=yes
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
