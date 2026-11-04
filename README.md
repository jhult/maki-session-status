# maki-session-status

A maki plugin that lets any status bar show what each maki session is doing.

maki runs sessions. A status bar cannot see them. This plugin writes one small
file per maki process, and the bar reads it. Nothing else is shared.

## What it writes

One file per process, at `$MAKI_STATE_DIR/statusbar/<pid>.status`. The file
holds one character per live session, in the order maki reports them:

| character | meaning |
|---|---|
| `1` | working |
| `0` | idle, or waiting for input |

The plugin writes with an atomic rename, so a reader never sees a half-written
file.

## How it stays cheap

The plugin does not poll maki. It subscribes to `SessionStatusChanged` and
`SessionEnd`, and those callbacks only set a flag. One coroutine owns every
yielding call, because a callback cannot yield across maki's `require` boundary.

The coroutine wakes once a second. It writes when the flag is set, and writes a
heartbeat every third wake. That is the whole cost.

On `SessionEnd` the plugin deletes its own file, so the directory does not
accumulate one file per dead process.

## Using it from a status bar

The bar resolves `pid` to a workspace, then reads the file. It knows nothing
about maki, and the plugin knows nothing about the bar. That is the point: the
bar does not link against maki and maki does not spawn the bar.

Look at [swaybar.c](https://github.com/zipadoodlez/a_swaybar) for a complete
consumer. It paints one coloured block per session, ordered by workspace.

## Install

Place `plugin.toml`, `init.lua` and `statusbar.lua` in your maki config as a
plugin, then restart maki.

## Known limit

`needs_input` shares the `0` code with `idle`. If you want the bar to show
"waiting for me" apart from "asleep", give it its own character and add a
colour in the bar.
