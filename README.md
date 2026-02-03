# tilt-wait.vim

Print a message in Vim/Neovim when [Tilt](https://tilt.dev) is done updating.

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
let g:tilt_wait_lightline = 0         " Enable lightline integration (default: 0)
let g:tilt_wait_status_clear = 30000  " Remove status after delay (default: 30000)
```

## Hooks

Optional, if you'd like to run additional actions on each event:

```vim
autocmd User TiltWaitReady echo "Ready!"
autocmd User TiltWaitFailed echo "Failed!"
```

## Statusline integration

This plugin can optionally integrate with [lightline](https://github.com/itchyny/lightline.vim) to show
status in the status line. This status is temporary and will be hidden after 30 seconds (by default).

Enable integration:

```vim
let g:tilt_wait_lightline = 1
```

Add components to your `lightline` config:

```vim
let g:lightline = {
  \ 'active': {
  \   'right': [ [ 'lineinfo' ],
  \              [ 'percent' ],
  \              [ 'fileformat', 'fileencoding', 'filetype', 'charvaluehex' ],
  \              [ 'tilt_w', 'tilt_ok', 'tilt_err'] ]
  \   },
  \   'component_expand': {
  \     'tilt_w': 'TiltWaitStatuslineWarning',
  \     'tilt_ok': 'TiltWaitStatuslineOk',
  \     'tilt_err': 'TiltWaitStatuslineError'
  \   },
  \   'component_type': {
  \     'tilt_w': 'warning',
  \     'tilt_ok': 'ok',
  \     'tilt_err': 'error'
  \   }
  \ }
```

## Requirements

- Vim 8+ or Neovim
- `tilt` CLI in `$PATH`
