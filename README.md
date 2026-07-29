![screenshot](https://github.com/Lemmmy/videoclip/assets/858456/855bff15-b0cd-4c12-a9ac-40a5e01d3b83)

# videoclip

[![Chat](https://img.shields.io/badge/chat-join-green)](https://tatsumoto-ren.github.io/blog/join-our-community.html)
![GitHub](https://img.shields.io/github/license/Ajatt-Tools/videoclip)
![GitHub top language](https://img.shields.io/github/languages/top/Ajatt-Tools/videoclip)
[![Patreon](https://img.shields.io/badge/support-patreon-orange)](https://tatsumoto.neocities.org/blog/donating-to-tatsumoto.html)

Easily create video and audio clips with mpv in a few keypresses.
Videoclips are saved as `.mp4` or `.webm`.
Subtitles can be embedded into the clips.

## Prerequisites

1) [Install mpv](https://mpv.io/installation/).
2) Add the directory where `mpv` is installed
   to the [PATH](https://www.mojeek.com/search?q=path+variable).

   If you're using GNU/Linux, this step is likely unnecessary
   because package managers (`apt`, `pacman`, etc.)
   place executable files to `/usr/bin` which is already added to the `PATH`.
   If you have installed `mpv` to a non-standard location,
   or if you're not using the GNU operating system,
   you need to make sure that `mpv` is added to the `PATH`.

## Installation

### Using git

Clone the repository to the `mpv/scripts` directory.
The command below works on the GNU operating system with `git` installed.

``` bash
git clone 'https://github.com/Ajatt-Tools/videoclip.git' ~/.config/mpv/scripts/videoclip
```

To update the user-script on demand later, you can execute:

``` bash
cd ~/.config/mpv/scripts/videoclip && git pull
```

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

## Configuration

The config file should be created by the user, if needed.

| OS | Config location |
| --- | --- |
| GNU/Linux | `~/.config/mpv/script-opts/videoclip.conf` |
| Windows | `C:/Users/Username/AppData/Roaming/mpv/script-opts/videoclip.conf` |

If a parameter is not specified in the config file, the default value will be used.
mpv doesn't tolerate spaces before and after `=`.

The example configuration file is stored in
[`videoclip/config/default_config.conf`](videoclip/config/default_config.conf).
Release pages also provide it as `videoclip.conf`.

Copy it to your `script-opts` directory and edit it as needed.

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

## Running tests

Run tests without mpv or a media file:

```bash
lua tests/run.lua
luajit tests/run.lua
```

Run tests inside a real mpv instance with a local media file:

```bash
VIDEOCLIP_TEST=TRUE mpv --msg-level=all=no,videoclip=warn "/path/to/video.mkv"
```
