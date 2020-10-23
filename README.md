# videoclip
Easily create video and audio clips with mpv in a few keypresses. Videoclips are saved as `.mp4`.
![screenshot](https://user-images.githubusercontent.com/69171671/92329784-683ff900-f059-11ea-9514-e8718e42dd5a.jpg)

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

### Install as a part of your [dotfiles](https://wiki.archlinux.org/index.php/Dotfiles#Tracking_dotfiles_directly_with_Git)
```
$ config submodule add 'https://github.com/Ajatt-Tools/videoclip.git' ~/.config/mpv/scripts/videoclip
```
### Install by cloning the repo
```
$ git clone 'https://github.com/Ajatt-Tools/videoclip.git' ~/.config/mpv/scripts/videoclip
```
### Enable the addon
After you've downloaded the addon, open or create  ```~/.config/mpv/scripts/modules.lua``` and add these lines:
```
local mpv_scripts_dir_path = os.getenv("HOME") ..  "/.config/mpv/scripts/"
function load(relative_path) dofile(mpv_scripts_dir_path .. relative_path) end
load("videoclip/videoclip.lua")
```
## Updating
Submodules are updated using standard git commands:
```
$ config submodule update --remote --merge
```
or
```
$ cd ~/.config/mpv/scripts/videoclip && git pull
```
## Configuration
Configuration file is located at ```~/.config/mpv/script-opts/videoclip.conf```
and should be created by the user if needed. If a parameter is not specified
in the config file, the default value will be used.
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
Key bindings are configured in ```~/.config/mpv/input.conf```.
This step is not necessary.
```
c script-binding videoclip-menu-open
```
## Usage
- Open a file in mpv and press `c` to open the script menu.
- Follow the onscreen instructions. You need to set the `start point`,
`end point`, and then press `c` to create the clip.
