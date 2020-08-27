# videoclip
Easily create videoclips with mpv in a few keypresses.

## Requirements
* A [distribution](https://www.gnu.org/distros/free-distros.html) of
[GNU/Linux](https://www.gnu.org/gnu/about-gnu.html)
* [FFmpeg](https://wiki.archlinux.org/index.php/FFmpeg)

## Installation
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
and should be created by the user. If a parameter is not specified
in the config file, the default value will be used.
mpv doesn't tolerate spaces before and after `=`.

Example configuration file:
```
# Absolute paths to the folders where generated clips will be placed.
# `~` or `$HOME` are not supported due to mpv limitations.
video_folder_path=/home/user/Videos
audio_folder_path=/home/user/Music

# Menu size
font_size=20

# Sane values are from 16k to 32k.
audio_bitrate=32k

# The range of the scale is 0–51, where 0 is lossless,
# 23 is the default, and 51 is worst quality possible.
video_quality=23

# Use the slowest preset that you have patience for.
# https://trac.ffmpeg.org/wiki/Encode/H.264
preset=faster

# Video dimensions
video_width=-2
video_height=480
```
Key bindings are configured in ```~/.config/mpv/input.conf```.
This step is not necessary.
```
c script-binding menu-open
```
## Usage
- Open a file in mpv and press `c` to open the script menu.
- Follow the onscreen instructions. You need to set the `start point`, `end point`, and then press `c` to create the clip.
