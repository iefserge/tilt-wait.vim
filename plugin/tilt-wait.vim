" tilt-wait.vim - Async tilt wait plugin for Vim/Neovim
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
let s:clear_timer = v:null
let s:status = ''
let s:status_type = ''
let g:tilt_wait_initial_delay = get(g:, 'tilt_wait_initial_delay', 2000)
let g:tilt_wait_poll_interval = get(g:, 'tilt_wait_poll_interval', 500)
let g:tilt_wait_status_clear = get(g:, 'tilt_wait_status_clear', 30000)
let g:tilt_wait_lightline = get(g:, 'tilt_wait_lightline', 0)

function! TiltWaitStatusline() abort
  return s:status
endfunction

function! TiltWaitStatuslineWarning() abort
  return s:status_type == 'warning' ? s:status : ''
endfunction

function! TiltWaitStatuslineOk() abort
  return s:status_type == 'ok' ? s:status : ''
endfunction

function! TiltWaitStatuslineError() abort
  return s:status_type == 'error' ? s:status : ''
endfunction

let s:check_job = v:null
let s:check_output = ''

function! s:OnCheckOutput(channel, msg) abort
  " Vim sends string per line
  let s:check_output .= a:msg
endfunction

function! s:OnCheckOutputNvim(job_id, data, event) abort
  " Neovim sends list of lines
  let s:check_output .= join(a:data, "\n")
endfunction

function! s:OnCheckExit(channel, code) abort
  let s:check_job = v:null
  let l:result = trim(s:check_output)

  if a:code != 0
    call s:Finish(1, 'tilt not running')
    return
  endif

  if empty(l:result)
    call s:CheckForErrors()
  endif
endfunction

function! s:OnCheckExitNvim(job_id, code, event) abort
  call s:OnCheckExit(a:job_id, a:code)
endfunction

function! s:CheckForErrors() abort
  let s:check_output = ''
  let l:cmd = ['tilt', 'get', 'session', 'Tiltfile', '-o', 'jsonpath={.status.targets[*].state.terminated.error}']

  if has('nvim')
    let s:check_job = jobstart(l:cmd, {
          \ 'on_stdout': function('s:OnCheckOutputNvim'),
          \ 'on_exit': function('s:OnErrorCheckExitNvim'),
          \ })
  else
    let s:check_job = job_start(l:cmd, {
          \ 'out_cb': function('s:OnCheckOutput'),
          \ 'exit_cb': function('s:OnErrorCheckExit'),
          \ })
  endif
endfunction

function! s:OnErrorCheckExit(channel, code) abort
  let s:check_job = v:null
  let l:result = trim(s:check_output)

  if empty(l:result)
    call s:Finish(0, '')
  else
    call s:Finish(1, 'build errors')
  endif
endfunction

function! s:OnErrorCheckExitNvim(job_id, code, event) abort
  call s:OnErrorCheckExit(a:job_id, a:code)
endfunction

function! s:CheckDone(timer) abort
  if s:check_job != v:null
    return " Previous check still running
  endif

  let s:check_output = ''
  let l:cmd = ['tilt', 'get', 'session', 'Tiltfile', '-o', 'jsonpath={.status.targets[*].state.waiting}']

  if has('nvim')
    let s:check_job = jobstart(l:cmd, {
          \ 'on_stdout': function('s:OnCheckOutputNvim'),
          \ 'on_exit': function('s:OnCheckExitNvim'),
          \ })
  else
    let s:check_job = job_start(l:cmd, {
          \ 'out_cb': function('s:OnCheckOutput'),
          \ 'exit_cb': function('s:OnCheckExit'),
          \ })
  endif
endfunction

function! s:StartPolling(timer) abort
  call s:CheckDone(0)
  " Only continue polling if CheckDone didn't finish
  if s:poll_timer != v:null
    let s:poll_timer = timer_start(g:tilt_wait_poll_interval, function('s:CheckDone'), {'repeat': -1})
  endif
endfunction

function! s:UpdateStatusline() abort
  if g:tilt_wait_lightline && exists('*lightline#update')
    call lightline#update()
  endif
endfunction

function! s:ClearStatus(timer) abort
  let s:status = ''
  let s:status_type = ''
  call s:UpdateStatusline()
endfunction

function! s:Finish(code, msg) abort
  if s:poll_timer != v:null
    call timer_stop(s:poll_timer)
    let s:poll_timer = v:null
  endif
  let s:check_job = v:null

  let l:elapsed = (localtime() - s:start_time)

  redraw
  if a:code == 0
    let s:status = 'tilt ready'
    let s:status_type = 'ok'
    echohl DiffAdd
    echo '[TiltWait] Resources ready! (' . l:elapsed . 's)'
    echohl None
    silent! doautocmd User TiltWaitReady
  else
    let s:status = 'tilt failed'
    let s:status_type = 'error'
    echohl ErrorMsg
    echo '[TiltWait] Failed: ' . a:msg . ' (' . l:elapsed . 's)'
    echohl None
    silent! doautocmd User TiltWaitFailed
  endif

  call s:UpdateStatusline()

  if g:tilt_wait_lightline
    let s:clear_timer = timer_start(g:tilt_wait_status_clear, function('s:ClearStatus'))
  endif
endfunction

function! TiltWaitStart() abort
  if s:poll_timer != v:null
    redraw
    echo '[TiltWait] Already waiting...'
    return
  endif

  let s:status = 'tilt waiting'
  let s:status_type = 'warning'
  call s:UpdateStatusline()
  redraw
  echo '[TiltWait] Waiting for tilt...'
  let s:start_time = localtime()
  let s:poll_timer = timer_start(g:tilt_wait_initial_delay, function('s:StartPolling'))
  if s:clear_timer != v:null
    call timer_stop(s:clear_timer)
    let s:clear_timer = v:null
  endif
endfunction

function! TiltWaitStop() abort
  if s:poll_timer == v:null
    echo '[TiltWait] Not running'
    return
  endif
  call timer_stop(s:poll_timer)
  let s:poll_timer = v:null
  if s:clear_timer != v:null
    call timer_stop(s:clear_timer)
    let s:clear_timer = v:null
  endif
  if s:check_job != v:null
    if has('nvim')
      call jobstop(s:check_job)
    else
      call job_stop(s:check_job)
    endif
    let s:check_job = v:null
  endif
  let s:status = ''
  let s:status_type = ''
  call s:UpdateStatusline()
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
