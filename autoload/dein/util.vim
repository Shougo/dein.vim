"=============================================================================
" FILE: util.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" License: MIT license
"=============================================================================

let s:is_windows = has('win32') || has('win64')

function! dein#util#_init() abort
endfunction

function! dein#util#_set_default(var, val, ...) abort
  if !exists(a:var) || type({a:var}) != type(a:val)
    let alternate_var = get(a:000, 0, '')

    let {a:var} = exists(alternate_var) ?
          \ {alternate_var} : a:val
  endif
endfunction

function! dein#util#_is_windows() abort
  return s:is_windows
endfunction
function! dein#util#_is_mac() abort
  return !s:is_windows && !has('win32unix')
      \ && (has('mac') || has('macunix') || has('gui_macvim') ||
      \   (!isdirectory('/proc') && executable('sw_vers')))
endfunction
function! dein#util#_is_cygwin() abort
  return has('win32unix')
endfunction

function! dein#util#_is_sudo() abort
  return $SUDO_USER != '' && $USER !=# $SUDO_USER
      \ && $HOME !=# expand('~'.$USER)
      \ && $HOME ==# expand('~'.$SUDO_USER)
endfunction

function! dein#util#_get_base_path() abort
  return g:dein#_base_path
endfunction
function! dein#util#_get_runtime_path() abort
  if g:dein#_runtime_path != ''
    if !isdirectory(g:dein#_runtime_path)
      call mkdir(g:dein#_runtime_path, 'p')
    endif
    return g:dein#_runtime_path
  endif

  let g:dein#_runtime_path = dein#util#_get_cache_path() . '/.dein'
  if !isdirectory(g:dein#_runtime_path)
    call mkdir(g:dein#_runtime_path, 'p')
  endif
  return g:dein#_runtime_path
endfunction
function! dein#util#_get_cache_path() abort
  if g:dein#_cache_path != ''
    return g:dein#_cache_path
  endif

  let g:dein#_cache_path = get(g:,
        \ 'dein#cache_directory', g:dein#_base_path)
        \ . '/.cache/' . fnamemodify(dein#util#_get_myvimrc(), ':t')
  if !isdirectory(g:dein#_cache_path)
    call mkdir(g:dein#_cache_path, 'p')
  endif
  return g:dein#_cache_path
endfunction
function! dein#util#_get_vimrcs(vimrcs) abort
  return !empty(a:vimrcs) ?
        \ dein#util#_convert2list(a:vimrcs) : [dein#util#_get_myvimrc()]
endfunction
function! dein#util#_get_myvimrc() abort
  return $MYVIMRC != '' ? $MYVIMRC :
        \ matchstr(split(dein#util#_redir('scriptnames'), '\n')[0],
        \  '^\s*\d\+:\s\zs.*')
endfunction

function! dein#util#_error(msg) abort
  for mes in s:msg2list(a:msg)
    echohl WarningMsg | echomsg '[dein] ' . mes | echohl None
  endfor
endfunction
function! dein#util#_notify(msg) abort
  call dein#util#_error(a:msg)

  call dein#util#_set_default(
        \ 'g:dein#enable_notification', 0)
  call dein#util#_set_default(
        \ 'g:dein#notification_icon', '')
  call dein#util#_set_default(
        \ 'g:dein#notification_time', 2)

  if !g:dein#enable_notification || a:msg == ''
    return
  endif

  let icon = dein#util#_expand(g:dein#notification_icon)

  let title = '[dein]'
  let cmd = ''
  if executable('notify-send')
    let cmd = printf('notify-send --expire-time=%d',
          \ g:dein#notification_time * 1000)
    if icon != ''
      let cmd .= ' --icon=' . string(icon)
    endif
    let cmd .= ' ' . string(title) . ' ' . string(a:msg)
  elseif dein#util#_is_windows() && executable('Snarl_CMD')
    let cmd = printf('Snarl_CMD snShowMessage %d "%s" "%s"',
          \ g:dein#notification_time, title, a:msg)
    if icon != ''
      let cmd .= ' "' . icon . '"'
    endif
  elseif dein#util#_is_mac()
    let cmd = ''
    if exists('$TMUX')
      if !executable('reattach-to-user-namespace')
        call dein#util#_error(
              \ 'Please install "reattach-to-user-namespace" command'
              \ . 'to use notification in tmux.')
        return
      endif

      " Use reattach-to-user-namespace in tmux
      let cmd .= 'reattach-to-user-namespace '
    endif
    if executable('terminal-notifier')
      let cmd .= 'terminal-notifier -title '
            \ . string(title) . ' -message ' . string(a:msg)
      if icon != ''
        let cmd .= ' -appIcon ' . string(icon)
      endif
    else
      let cmd .= printf("osascript -e 'display notification "
            \        ."\"%s\" with title \"%s\"'", a:msg, title)
    endif
  endif

  if cmd != ''
    call dein#install#_system(cmd)
  endif
endfunction

function! dein#util#_chomp(str) abort
  return a:str != '' && a:str[-1:] == '/' ? a:str[: -2] : a:str
endfunction

function! dein#util#_uniq(list) abort
  let list = copy(a:list)
  let i = 0
  let seen = {}
  while i < len(list)
    let key = list[i]
    if key != '' && has_key(seen, key)
      call remove(list, i)
    else
      if key != ''
        let seen[key] = 1
      endif
      let i += 1
    endif
  endwhile
  return list
endfunction

function! dein#util#_has_vimproc() abort
  if !exists('*vimproc#version')
    try
      call vimproc#version()
    catch
    endtry
  endif

  return exists('*vimproc#version')
endfunction
function! dein#util#_is_fish() abort
  return (dein#install#_is_async() || !dein#util#_has_vimproc())
        \ && fnamemodify(&shell, ':t:r') ==# 'fish'
endfunction

function! dein#util#_check_lazy_plugins() abort
  return map(filter(dein#util#_get_lazy_plugins(),
        \   "isdirectory(v:val.rtp)
        \    && get(v:val, 'hook_source', '') == ''
        \    && !isdirectory(v:val.rtp . '/plugin')
        \    && !isdirectory(v:val.rtp . '/after/plugin')"),
        \   'v:val.name')
endfunction
function! dein#util#_check_clean() abort
  let plugins_directories = map(values(dein#get()), 'v:val.path')
  return filter(split(globpath(dein#util#_get_base_path(),
        \ 'repos/*/*/*'), "\n"), "isdirectory(v:val)
        \   && index(plugins_directories, v:val) < 0
        \   && empty(dein#get(fnamemodify(v:val, ':t')))")
endfunction

function! dein#util#_writefile(path, list) abort
  if dein#util#_is_sudo() || !filewritable(dein#util#_get_cache_path())
    return 1
  endif

  let path = dein#util#_get_cache_path() . '/' . a:path
  let dir = fnamemodify(path, ':h')
  if !isdirectory(dir)
    call mkdir(dir, 'p')
  endif

  return writefile(a:list, path)
endfunction

function! dein#util#_get_type(name) abort
  return get(dein#parse#_get_types(), a:name, {})
endfunction

function! dein#util#_save_cache(vimrcs, is_state, is_starting) abort
  if dein#util#_get_cache_path() == '' || !a:is_starting
    " Ignore
    return 1
  endif

  let plugins = deepcopy(dein#get())

  for plugin in values(plugins)
    if !a:is_state
      let plugin.sourced = 0
    endif
    if has_key(plugin, 'orig_opts')
      call remove(plugin, 'orig_opts')
    endif

    " Hooks
    for hook in filter([
          \ 'hook_add', 'hook_source',
          \ 'hook_post_source', 'hook_post_update',
          \ ], "has_key(plugin, v:val)
          \     && type(plugin[v:val]) == type(function('tr'))")
      call remove(plugin, hook)
    endfor
  endfor

  if !isdirectory(g:dein#_base_path)
    call mkdir(g:dein#_base_path, 'p')
  endif

  call writefile([string(a:vimrcs),
        \         dein#_vim2json(plugins), dein#_vim2json(g:dein#_ftplugin)],
        \ get(g:, 'dein#cache_directory', g:dein#_base_path)
        \ .'/cache_'.fnamemodify(v:progname, ':r'))
endfunction
function! dein#util#_check_vimrcs() abort
  let time = getftime(dein#util#_get_runtime_path())
  return !empty(filter(map(copy(g:dein#_vimrcs), 'getftime(expand(v:val))'),
        \ 'time < v:val'))
endfunction
function! dein#util#_load_merged_plugins() abort
  let path = dein#util#_get_cache_path() . '/merged'
  if !filereadable(path)
    return []
  endif
  let merged = readfile(path)
  if len(merged) != 2
    return []
  endif
  sandbox return [merged[0]] + eval(merged[1])
endfunction
function! dein#util#_save_merged_plugins(merged_plugins) abort
  call writefile([g:dein#_cache_version,
        \ string(sort(a:merged_plugins))],
        \ dein#util#_get_cache_path() . '/merged')
endfunction

function! dein#util#_save_state(is_starting) abort
  if g:dein#_block_level != 0
    call dein#util#_error('Invalid dein#save_state() usage.')
    return 1
  endif

  if dein#util#_get_cache_path() == '' || !a:is_starting
    " Ignore
    return 1
  endif

  let g:dein#_vimrcs = dein#util#_uniq(g:dein#_vimrcs)
  let &runtimepath = dein#util#_join_rtp(dein#util#_uniq(
        \ dein#util#_split_rtp(&runtimepath)), &runtimepath, '')

  call dein#util#_save_cache(g:dein#_vimrcs, 1, a:is_starting)

  " Version check

  let lines = [
        \ "if g:dein#_cache_version != " . g:dein#_cache_version .
        \      " | throw 'Cache loading error' | endif",
        \ 'let [plugins, ftplugin] = dein#load_cache_raw('.
        \      string(g:dein#_vimrcs) .')',
        \ "if empty(plugins) | throw 'Cache loading error' | endif",
        \ 'let g:dein#_plugins = plugins',
        \ 'let g:dein#_ftplugin = ftplugin',
        \ 'let g:dein#_base_path = ' . string(g:dein#_base_path),
        \ 'let g:dein#_runtime_path = ' . string(g:dein#_runtime_path),
        \ 'let g:dein#_cache_path = ' . string(g:dein#_cache_path),
        \ 'let &runtimepath = ' . string(&runtimepath),
        \ ]

  if g:dein#_off1 != ''
    call add(lines, g:dein#_off1)
  endif
  if g:dein#_off2 != ''
    call add(lines, g:dein#_off2)
  endif

  " Add dummy mappings/commands
  for plugin in dein#util#_get_lazy_plugins()
    for command in get(plugin, 'dummy_commands', [])
      call add(lines, 'silent! ' . command[1])
    endfor
    for mapping in get(plugin, 'dummy_mappings', [])
      call add(lines, 'silent! ' . mapping[2])
    endfor
  endfor

  " Add hooks
  if !empty(g:dein#_hook_add)
    let lines += s:skipempty(g:dein#_hook_add)
  endif
  for plugin in dein#util#_tsort(values(dein#get()))
    if has_key(plugin, 'hook_add') && type(plugin.hook_add) == type('')
      let lines += s:skipempty(plugin.hook_add)
    endif
  endfor

  " Add events
  for [event, plugins] in filter(items(g:dein#_event_plugins),
        \ "exists('##' . v:val[0])")
    call add(lines, printf('autocmd dein-events %s * call '
          \. 'dein#autoload#_on_event("%s", %s)',
          \ event, event, string(plugins)))
  endfor

  call writefile(lines, get(g:, 'dein#cache_directory', g:dein#_base_path)
        \ .'/state_'.fnamemodify(v:progname, ':r').'.vim')
endfunction
function! dein#util#_clear_state() abort
  for cache in dein#util#_globlist(g:dein#_base_path.'/state_*.vim')
        \ + dein#util#_globlist(g:dein#_base_path.'/cache_*')
    call delete(cache)
  endfor
endfunction

function! dein#util#_begin(path, vimrcs) abort
  if !exists('#dein')
    call dein#_init()
  endif

  if v:version < 704
    call dein#util#_error('Does not work in the Vim (' . v:version . ').')
    return 1
  endif

  if a:path == '' || g:dein#_block_level != 0
    call dein#util#_error('Invalid begin/end block usage.')
    return 1
  endif

  let g:dein#_block_level += 1
  let g:dein#_base_path = dein#util#_expand(a:path)
  if g:dein#_base_path[-1:] == '/'
    let g:dein#_base_path = g:dein#_base_path[: -2]
  endif
  call dein#util#_get_runtime_path()
  call dein#util#_get_cache_path()
  let g:dein#_vimrcs = dein#util#_get_vimrcs(a:vimrcs)
  let g:dein#_hook_add = ''

  " Filetype off
  if exists('g:did_load_filetypes') || has('nvim')
    let g:dein#_off1 = 'filetype off'
    execute g:dein#_off1
  endif
  if exists('b:did_indent') || exists('b:did_ftplugin')
    let g:dein#_off2 = 'filetype plugin indent off'
    execute g:dein#_off2
  endif

  if !has('vim_starting')
    execute 'set rtp-='.fnameescape(g:dein#_runtime_path)
    execute 'set rtp-='.fnameescape(g:dein#_runtime_path.'/after')
  endif

  " Insert dein runtimepath to the head in 'runtimepath'.
  let rtps = dein#util#_split_rtp(&runtimepath)
  let idx = index(rtps, $VIMRUNTIME)
  if idx < 0
    call dein#util#_error('Invalid runtimepath.')
    return 1
  endif
  let &runtimepath = dein#util#_join_rtp(
        \ add(insert(rtps, g:dein#_runtime_path, idx - 1),
        \     g:dein#_runtime_path.'/after'),
        \ &runtimepath, g:dein#_runtime_path)
endfunction
function! dein#util#_end() abort
  if g:dein#_block_level != 1
    call dein#util#_error('Invalid begin/end block usage.')
    return 1
  endif

  let g:dein#_block_level -= 1

  " Add runtimepath
  let rtps = dein#util#_split_rtp(&runtimepath)
  let index = index(rtps, g:dein#_runtime_path)
  if index < 0
    call dein#util#_error('Invalid runtimepath.')
    return 1
  endif

  let depends = []
  for plugin in filter(values(g:dein#_plugins),
        \ "!v:val.lazy && !v:val.sourced && v:val.rtp != ''")
    " Load dependencies
    if has_key(plugin, 'depends')
      let depends += plugin.depends
    endif

    if !plugin.merged
      call insert(rtps, plugin.rtp, index)
      if isdirectory(plugin.rtp.'/after')
        call add(rtps, plugin.rtp.'/after')
      endif
    endif

    let plugin.sourced = 1
  endfor
  let &runtimepath = dein#util#_join_rtp(rtps, &runtimepath, '')

  if dein#util#_check_vimrcs()
    if [string(g:dein#_cache_version)] +
          \ sort(map(filter(values(g:dein#_plugins),
          \      'v:val.merged'), 'v:val.repo'))
          \ !=# dein#util#_load_merged_plugins()
      silent call dein#recache_runtimepath()
    endif
  endif

  if !empty(depends)
    call dein#source(depends)
  endif

  if g:dein#_hook_add != ''
    call dein#util#_execute_hook({}, g:dein#_hook_add)
  endif

  for [event, plugins] in filter(items(g:dein#_event_plugins),
        \ "exists('##' . v:val[0])")
    execute printf('autocmd dein-events %s * call '
          \. 'dein#autoload#_on_event("%s", %s)',
          \ event, event, string(plugins))
  endfor

  if !has('vim_starting')
    call dein#call_hook('add')
    call dein#call_hook('source')
    call dein#call_hook('post_source')
  endif
endfunction
function! dein#util#_config(arg, dict) abort
  let name = type(a:arg) == type({}) ?
        \   g:dein#name : a:arg
  let dict = type(a:arg) == type({}) ?
        \   a:arg : a:dict
  if !has_key(g:dein#_plugins, name)
        \ || g:dein#_plugins[name].sourced
    return {}
  endif

  let plugin = g:dein#_plugins[name]
  let options = extend({'repo': plugin.repo}, dict)
  if has_key(plugin, 'orig_opts')
    call extend(options, copy(plugin.orig_opts), 'keep')
  endif
  return dein#parse#_add(options.repo, options)
endfunction

function! dein#util#_call_hook(hook_name, ...) abort
  let prefix = '#User#dein#'.a:hook_name.'#'
  let hook = 'hook_' . a:hook_name
  let plugins = filter(dein#util#_get_plugins((a:0 ? a:1 : [])),
        \ "v:val.sourced && (exists(prefix . v:val.name)
        \  || has_key(v:val, hook)) && isdirectory(v:val.path)")

  for plugin in dein#util#_tsort(plugins)
    let autocmd = 'dein#' . a:hook_name . '#' . plugin.name
    if exists('#User#'.autocmd)
      call dein#util#_error('#User#'.autocmd . ' is deprecated.')
      call dein#util#_error('Please use new hook feature instead.')
      execute 'doautocmd <nomodeline> User' autocmd
    endif
    if has_key(plugin, hook)
      call dein#util#_execute_hook(plugin, plugin[hook])
    endif
  endfor
endfunction
function! dein#util#_execute_hook(plugin, hook) abort
  try
    let g:dein#plugin = a:plugin

    if type(a:hook) == type('')
      let dummy = '_dein_dummy_' .
            \ substitute(reltimestr(reltime()), '\W', '_', 'g')
      execute "function! ".dummy."() abort\n"
            \ . a:hook . "\nendfunction"
      call {dummy}()
      execute 'delfunction' dummy
    else
      call call(a:hook, [])
    endif
  catch
    call dein#util#_error(
          \ 'Error occurred while executing hook: ' .
          \ get(a:plugin, 'name', ''))
    call dein#util#_error(v:exception)
  endtry
endfunction
function! dein#util#_set_hook(name, hook_name, hook) abort
  if !has_key(g:dein#_plugins, a:name)
    call dein#util#_error(a:name . ' is not found.')
    return 1
  endif
  let plugin = g:dein#_plugins[a:name]
  let plugin[a:hook_name] =
        \ type(a:hook) != type('') ? a:hook :
        \   substitute(a:hook, '\n\s*\\\|\%(^\|\n\)\s*"[^\n]*', '', 'g')
  if a:hook_name ==# 'hook_add'
    call dein#util#_execute_hook(plugin, plugin[a:hook_name])
  endif
endfunction

function! dein#util#_sort_by(list, expr) abort
  let pairs = map(a:list, printf('[v:val, %s]', a:expr))
  return map(s:sort(pairs,
  \      'a:a[1] ==# a:b[1] ? 0 : a:a[1] ># a:b[1] ? 1 : -1'), 'v:val[0]')
endfunction
function! dein#util#_tsort(plugins) abort
  let sorted = []
  let mark = {}
  for target in a:plugins
    call s:tsort_impl(target, mark, sorted)
  endfor

  return sorted
endfunction

function! dein#util#_split_rtp(runtimepath) abort
  if stridx(a:runtimepath, '\,') < 0
    return split(a:runtimepath, ',')
  endif

  let split = split(a:runtimepath, '\\\@<!\%(\\\\\)*\zs,')
  return map(split,'substitute(v:val, ''\\\([\\,]\)'', "\\1", "g")')
endfunction
function! dein#util#_join_rtp(list, runtimepath, rtp) abort
  return (stridx(a:runtimepath, '\,') < 0 && stridx(a:rtp, ',') < 0) ?
        \ join(a:list, ',') : join(map(copy(a:list), 's:escape(v:val)'), ',')
endfunction

function! dein#util#_expand(path) abort
  let path = (a:path =~ '^\~') ? fnamemodify(a:path, ':p') :
        \ (a:path =~ '^\$\h\w*') ? substitute(a:path,
        \               '^\$\h\w*', '\=eval(submatch(0))', '') :
        \ a:path
  return (s:is_windows && path =~ '\\') ?
        \ dein#util#_substitute_path(path) : path
endfunction
function! dein#util#_substitute_path(path) abort
  return (s:is_windows && a:path =~ '\\') ? tr(a:path, '\', '/') : a:path
endfunction
function! dein#util#_globlist(path) abort
  return split(glob(a:path), '\n')
endfunction

function! dein#util#_convert2list(expr) abort
  return type(a:expr) ==# type([]) ? copy(a:expr) :
        \ type(a:expr) ==# type('') ?
        \   (a:expr == '' ? [] : split(a:expr, '\r\?\n', 1))
        \ : [a:expr]
endfunction
function! dein#util#_split(expr) abort
  return type(a:expr) ==# type([]) ? copy(a:expr) :
        \ split(a:expr, '\r\?\n')
endfunction

function! dein#util#_redir(cmd) abort
  if exists('*execute')
    return execute(a:cmd)
  else
    let [save_verbose, save_verbosefile] = [&verbose, &verbosefile]
    set verbose=0 verbosefile=
    redir => res
    silent! execute a:cmd
    redir END
    let [&verbose, &verbosefile] = [save_verbose, save_verbosefile]
    return res
  endif
endfunction

function! dein#util#_get_lazy_plugins() abort
  return filter(values(g:dein#_plugins), '!v:val.sourced')
endfunction

function! dein#util#_get_plugins(plugins) abort
  return empty(a:plugins) ?
        \ values(dein#get()) :
        \ filter(map(dein#util#_convert2list(a:plugins),
        \   'type(v:val) == type({}) ? v:val : dein#get(v:val)'),
        \   '!empty(v:val)')
endfunction

function! dein#util#_disable(names) abort
  for plugin in map(filter(dein#util#_convert2list(a:names),
        \ 'has_key(g:dein#_plugins, v:val)
        \  && !g:dein#_plugins[v:val].sourced'), 'g:dein#_plugins[v:val]')
    if has_key(plugin, 'dummy_commands')
      for command in plugin.dummy_commands
        silent! execute 'delcommand' command[0]
      endfor
      let plugin.dummy_commands = []
    endif

    if has_key(plugin, 'dummy_mappings')
      for map in plugin.dummy_mappings
        silent! execute map[0].'unmap' map[1]
      endfor
      let plugin.dummy_mappings = []
    endif

    call remove(g:dein#_plugins, plugin.name)
  endfor
endfunction

function! dein#util#_download(uri, outpath) abort
  if !exists('g:dein#download_command')
    let g:dein#download_command =
          \ executable('curl') ?
          \   'curl --silent --location --output' :
          \ executable('wget') ?
          \   'wget -q -O' : ''
  endif
  if g:dein#download_command != ''
    return printf('%s "%s" "%s"',
          \ g:dein#download_command, a:outpath, a:uri)
  elseif dein#util#_is_windows()
    " Use powershell
    " Todo: Proxy support
    let pscmd = printf("(New-Object Net.WebClient).DownloadFile('%s', '%s')",
          \ a:uri, a:outpath)
    return printf('powershell -Command "%s"', pscmd)
  else
    return 'E: curl or wget command is not available!'
  endif
endfunction

function! s:tsort_impl(target, mark, sorted) abort
  if empty(a:target) || has_key(a:mark, a:target.name)
    return
  endif

  let a:mark[a:target.name] = 1
  if has_key(a:target, 'depends')
    for depend in a:target.depends
      call s:tsort_impl(dein#get(depend), a:mark, a:sorted)
    endfor
  endif

  call add(a:sorted, a:target)
endfunction

function! s:msg2list(expr) abort
  return type(a:expr) ==# type([]) ? a:expr : split(a:expr, '\n')
endfunction
function! s:skipempty(string) abort
  return filter(split(a:string, '\n'), "v:val != ''")
endfunction

function! s:escape(path) abort
  " Escape a path for runtimepath.
  return substitute(a:path, ',\|\\,\@=', '\\\0', 'g')
endfunction

function! s:sort(list, expr) abort
  if type(a:expr) == type(function('function'))
    return sort(a:list, a:expr)
  endif
  let s:expr = a:expr
  return sort(a:list, 's:_compare')
endfunction
function! s:_compare(a, b) abort
  return eval(s:expr)
endfunction
