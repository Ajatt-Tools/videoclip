# videoclip
Easily create videoclips with mpv in a few keypresses.

## Installation
### Install as a part of your [dotfiles](https://wiki.archlinux.org/index.php/Dotfiles#Tracking_dotfiles_directly_with_Git)
```
$ config submodule add 'https://github.com/Ajatt-Tools/videoclip.git' ~/.config/mpv/scripts/videoclip
```
### Install by cloning the repo
```
$ git clone 'https://github.com/Ajatt-Tools/videoclip.git' ~/.config/mpv/scripts/videoclip
```
Open or create  ```~/.config/mpv/scripts/modules.lua``` and add these lines:
```
local mpv_scripts_dir_path = os.getenv("HOME") ..  "/.config/mpv/scripts/"
function load(relative_path) dofile(mpv_scripts_dir_path .. relative_path) end
load("videoclip/videoclip.lua")
```
