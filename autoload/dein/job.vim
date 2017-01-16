" Based on: https://github.com/lambdalisue/gina.vim/blob/master/autoload/vital/__gina__/System/Job.vim

" License
"
" The MIT License (MIT)
"
" Copyright (c) 2017 Alisue, hashnote.net
"
" Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
"
" The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
"
" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE."

if has('nvim')
  function! dein#job#start(args, ...) abort
    " Build options for jobstart
    let options = get(a:000, 0, {})
    let job_options = extend(copy(options), s:options)
    if has_key(options, 'on_exit')
      let job_options._on_exit = options.on_exit
    endif
    " Start job and return a job instance
    let args = type(a:args) == type([]) ?
          \ a:args : [&shell, &shellcmdflag, a:args]
    let jobid = jobstart(args, job_options)
    let job = extend(copy(s:job), {
          \ 'args': a:args,
          \ '_id': jobid,
          \ '_status': jobid > 0 ? 'run' : 'fail',
          \})
    let job_options._job = job
    return job
  endfunction


  " Instance -------------------------------------------------------------------
  let s:options = {}

  function! s:options.on_exit(jobid, msg, event) abort
    " Update job status
    let self._job._status = 'dead'
    let self._job._exitval = a:msg
    " Call user specified callback if exists
    if has_key(self, '_on_exit')
      call call(self._on_exit, [a:jobid, a:msg, a:event], self)
    endif
  endfunction


  let s:job = { '_status': 'fail', '_exitval': -1 }

  function! s:job.status() abort
    return self._status
  endfunction

  function! s:job.exitval() abort
    return self._exitval
  endfunction

  function! s:job.send(data) abort
    return jobsend(self._id, a:data)
  endfunction

  function! s:job.wait(...) abort
    let timeout = get(a:000, 0, v:null)
    if timeout is v:null
      return jobwait([self._id])[0]
    else
      return jobwait([self._id], timeout)[0]
    endif
  endfunction

  function! s:job.stop() abort
    return jobstop(self._id)
  endfunction
else
  function! dein#job#start(args, ...) abort
    let job = extend(copy(s:job), get(a:000, 0, {}))
    let job_options = {
          \ 'mode': 'raw',
          \ 'timeout': 10000,
          \}
    if has_key(job, 'on_stdout')
      let job_options.out_cb = function('s:_job_callback', ['stdout', job])
    endif
    if has_key(job, 'on_stderr')
      let job_options.err_cb = function('s:_job_callback', ['stderr', job])
    endif
    if has_key(job, 'on_exit')
      let job_options.exit_cb = function('s:_job_callback', ['exit', job])
    endif
    try
      " Note: In Windows, job_start() does not work in shellslash.
      let shellslash = 0
      if exists('+shellslash')
        let shellslash = &shellslash
        set noshellslash
      endif
      let args = type(a:args) == v:t_list ?
            \ a:args : [&shell, &shellcmdflag, a:args]
      let job._job = job_start(args, job_options)
    finally
      if exists('+shellslash')
        let &shellslash = shellslash
      endif
    endtry
    let job.args = a:args
    return job
  endfunction

  function! s:_job_callback(event, options, channel, ...) abort
    let raw = get(a:000, 0, '')
    let msg = type(raw) == v:t_string ? split(raw, '\n', 1) : raw
    call call(
          \ a:options['on_' . a:event],
          \ [a:channel, msg, a:event],
          \ a:options
          \)
  endfunction

  function! s:_read_stdout(job) abort
    return split(ch_read(a:job), '\n', 1)
  endfunction

  function! s:_read_stderr(job) abort
    return split(ch_read(a:job, {'part': 'err'}), '\n', 1)
  endfunction


  " Instance -------------------------------------------------------------------
  let s:job = { '_exitval': -1 }

  function! s:job.status() abort
    return job_status(self._job)
  endfunction

  function! s:job.exitval() abort
    return self._exitval
  endfunction

  function! s:job.send(data) abort
    let channel = job_getchannel(self._job)
    return ch_sendexpr(channel, a:data)
  endfunction

  function! s:job.stop() abort
    return job_stop(self._job)
  endfunction

  function! s:job.wait(...) abort
    let timeout = get(a:000, 0, v:null)
    let start_time = reltimefloat(reltime())
    let cnt = 0
    while timeout is v:null || start_time + timeout > reltimefloat(reltime())
      let status = self.status()
      if status ==# 'run'
        let stdout = ch_read(self._job)
        let stderr = ch_read(self._job, {'part': 'err'})
        if has_key(self, 'on_stdout') && !empty(stdout)
          call s:_job_callback('stdout', self, self._job, stdout)
        endif
        if has_key(self, 'on_stderr') && !empty(stderr)
          call s:_job_callback('stderr', self, self._job, stderr)
        endif
      elseif status ==# 'dead'
        sleep 1ms
        let info = job_info(self._job)
        let self._exitval = info.exitval
        return info.exitval
      else
        return -3
      endif
      let cnt += 1
      if cnt > 10
        sleep 1ms
      endif
    endwhile
    return -1
  endfunction
endif
