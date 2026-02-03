# tilt-wait.vim

Print a message in Vim status line when [Tilt](https://tilt.dev) is done updating.

Tiny helpful plugin to avoid context switches between Vim and Tilt CLI/UI.

## Install

```bash
Plug 'iefserge/tilt-wait.vim'
```

## Usage

- This plugin automatically searches for `Tiltfile` in the current and parent directories on buffer load
- Runs `:TiltWait` on save which polls Tilt API until no targets are waiting. You can adjust initial and polling
    intervals.
- Prints success/failure message

## Commands

| Command | Action |
|---------|--------|
| `:TiltWait` | Manually trigger wait |
| `:TiltWaitStop` | Cancel waiting |
| `:TiltWaitStatus` | Show status |

## Config

```vim
let g:tilt_wait_on_save = 1           " Auto-run on save (default: 1)
let g:tilt_wait_initial_delay = 2000  " Initial wait delay ms (default: 2000ms)
let g:tilt_wait_poll_interval = 500   " Interval between polls (default: 500ms)
```

## Hooks

```vim
autocmd User TiltWaitReady echo "Ready!"
autocmd User TiltWaitFailed echo "Failed!"
```

## Requirements

- Vim 8+
- `tilt` CLI in `$PATH`
