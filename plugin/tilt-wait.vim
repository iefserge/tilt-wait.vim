" tilt-wait.vim - Async tilt wait plugin for Vim
" Waits for tilt resources to become ready and notifies on completion

if exists('g:loaded_tilt_wait')
  finish
endif
let g:loaded_tilt_wait = 1

let g:tilt_wait_on_save = get(g:, 'tilt_wait_on_save', 1)

function! s:FindTiltfile() abort
  let l:dir = expand('%:p:h')
  while l:dir != '/'
    if filereadable(l:dir . '/Tiltfile')
      return l:dir . '/Tiltfile'
    endif
    let l:dir = fnamemodify(l:dir, ':h')
  endwhile
  return ''
endfunction

function! s:SetupBuffer() abort
  if !g:tilt_wait_on_save
    return
  endif
  if empty(s:FindTiltfile())
    return
  endif
  let b:tilt_wait_enabled = 1
  augroup TiltWaitBuffer
    autocmd! BufWritePost <buffer> call TiltWaitStart()
  augroup END
endfunction

augroup TiltWaitSetup
  autocmd!
  autocmd BufReadPost,BufNewFile * call s:SetupBuffer()
augroup END

let s:start_time = 0
let s:poll_timer = v:null
let g:tilt_wait_initial_delay = get(g:, 'tilt_wait_initial_delay', 2000)
let g:tilt_wait_poll_interval = get(g:, 'tilt_wait_poll_interval', 500)

function! s:CheckDone(timer) abort
  let l:cmd = 'tilt get session Tiltfile -o jsonpath="{.status.targets[*].state.waiting}" 2>/dev/null'
  let l:result = trim(system(l:cmd))

  if v:shell_error != 0
    call s:Finish(1, 'tilt not running')
    return
  endif

  if empty(l:result)
    call s:Finish(0, '')
  endif
  " Otherwise keep polling
endfunction

function! s:StartPolling(timer) abort
  call s:CheckDone(0)
  " Only continue polling if CheckDone didn't finish
  if s:poll_timer != v:null
    let s:poll_timer = timer_start(g:tilt_wait_poll_interval, function('s:CheckDone'), {'repeat': -1})
  endif
endfunction

function! s:Finish(code, msg) abort
  if s:poll_timer != v:null
    call timer_stop(s:poll_timer)
    let s:poll_timer = v:null
  endif

  let l:elapsed = (localtime() - s:start_time)

  redraw
  if a:code == 0
    echohl DiffAdd
    echo '[TiltWait] Resources ready! (' . l:elapsed . 's)'
    echohl None
    silent! doautocmd User TiltWaitReady
  else
    echohl ErrorMsg
    echo '[TiltWait] Failed: ' . a:msg . ' (' . l:elapsed . 's)'
    echohl None
    silent! doautocmd User TiltWaitFailed
  endif
endfunction

function! TiltWaitStart() abort
  if s:poll_timer != v:null
    redraw
    echo '[TiltWait] Already waiting...'
    return
  endif

  redraw
  echo '[TiltWait] Waiting for tilt...'
  let s:start_time = localtime()
  let s:poll_timer = timer_start(g:tilt_wait_initial_delay, function('s:StartPolling'))
endfunction

function! TiltWaitStop() abort
  if s:poll_timer == v:null
    echo '[TiltWait] Not running'
    return
  endif
  call timer_stop(s:poll_timer)
  let s:poll_timer = v:null
  echo '[TiltWait] Cancelled'
endfunction

function! TiltWaitStatus() abort
  if s:poll_timer == v:null
    echo '[TiltWait] Not running'
  else
    echo '[TiltWait] Waiting... (' . (localtime() - s:start_time) . 's)'
  endif
endfunction

command! TiltWait call TiltWaitStart()
command! TiltWaitStop call TiltWaitStop()
command! TiltWaitStatus call TiltWaitStatus()
