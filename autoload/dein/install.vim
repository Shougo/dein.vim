" Variables
let s:global_context = {}
let s:log = []
let s:updates_log = []
let s:progress = ''
let s:failed_plugins = []
let s:progress_winid = -1

" Global options definition.
let g:dein#install_max_processes =
      \ g:->get('dein#install_max_processes',
      \     dein#util#_is_windows() ? 16 : 8)
let g:dein#install_progress_type =
      \ g:->get('dein#install_progress_type', 'echo')
let g:dein#install_message_type =
      \ g:->get('dein#install_message_type', 'echo')
let g:dein#install_process_timeout =
      \ g:->get('dein#install_process_timeout', 120)
let g:dein#install_log_filename =
      \ g:->get('dein#install_log_filename', '')
let g:dein#install_github_api_token =
      \ g:->get('dein#install_github_api_token', '')
let g:dein#install_curl_command =
      \ g:->get('dein#install_curl_command', 'curl')
let g:dein#install_check_diff =
      \ g:->get('dein#install_check_diff', v:false)
let g:dein#install_check_remote_threshold =
      \ g:->get('dein#install_check_remote_threshold', 0)
let g:dein#install_copy_vim =
      \ g:->get('dein#install_copy_vim', v:true)

function! s:get_job() abort
  if !exists('s:Job')
    let s:Job = vital#dein#import('System.Job')
  endif
  return s:Job
endfunction

function! dein#install#_do(plugins, update_type, async) abort
  if g:dein#_is_sudo
    call s:error('update/install is disabled in sudo session.')
    return
  endif

  let plugins = dein#util#_get_plugins(a:plugins)

  if a:update_type ==# 'install'
    let plugins = plugins->filter({ _, val -> !(val.path->isdirectory()) })
  endif

  if a:async && !(s:global_context->empty()) &&
        \ confirm('The installation has not finished. Cancel now?',
        \         "yes\nNo", 2) != 1
    return
  endif

  " Set context.
  let context = s:init_context(plugins, a:update_type, a:async)

  call s:init_variables(context)

  if plugins->empty()
    call s:notify('Target plugins are not found.')
    call s:notify('You may have used the wrong plugin name,'.
          \ ' or all of the plugins are already installed.')
    let s:global_context = {}
    return
  endif

  if has('nvim')
    " NOTE: Some neovim plugins(ex: nvim-treesitter) needs this
    silent! filetype plugin indent on
  endif

  call s:start()

  if !a:async || has('vim_starting')
    return s:update_loop(context)
  endif

  augroup dein-install
    autocmd!
  augroup END

  if 's:timer'->exists()
    call timer_stop(s:timer)
    unlet s:timer
  endif

  let s:timer = timer_start(50,
        \ {-> dein#install#_polling()}, #{ repeat: -1 })
endfunction
function! s:update_loop(context) abort
  let errored = 0
  try
    if has('vim_starting')
      while !(s:global_context->empty())
        let errored = s:install_async(a:context)
        sleep 50ms
        redraw
      endwhile
    else
      let errored = s:install_blocking(a:context)
    endif
  catch
    call s:error(v:exception)
    call s:error(v:throwpoint)
    return 1
  endtry

  return errored
endfunction

function! dein#install#_get_updated_plugins(plugins, async) abort
  if g:dein#install_github_api_token ==# ''
    call s:error('You need to set g:dein#install_github_api_token'
          \ .. ' for the feature.')
    return []
  endif
  if !(g:dein#install_curl_command->executable())
    call s:error('curl must be executable for the feature.')
    return []
  endif

  let context = s:init_context(a:plugins, 'check_update', 0)
  call s:init_variables(context)

  const query_max = 100
  let plugins = dein#util#_get_plugins(a:plugins)
  let processes = []
  for index in range(0, plugins->len() - 1, query_max)
    call s:print_progress_message(
          \ s:get_progress_message('send query', index, len(plugins)))

    let query = ''
    for plug_index in range(index,
          \ [index + query_max, len(plugins)]->min() - 1)
      let plugin_names = plugins[plug_index].repo->split('/')
      if plugin_names->len() < 2
        " Invalid repository name.
        continue
      endif

      " NOTE: "repository" API is faster than "search" API
      let query ..= printf('a%d:repository(owner:\"%s\", name: \"%s\")'
            \ .. '{ pushedAt nameWithOwner }',
            \ plug_index, plugin_names[-2], plugin_names[-1])
    endfor

    let commands = [
          \   g:dein#install_curl_command, '-H', 'Authorization: bearer '
          \   .. g:dein#install_github_api_token,
          \   '-X', 'POST', '-d',
          \   '{ "query": "query {' .. query .. '}" }',
          \   'https://api.github.com/graphql',
          \ ]

    let process = #{ candidates: [] }
    function! process.on_out(data) abort
      let candidates = self.candidates
      if candidates->empty()
        call add(candidates, a:data[0])
      else
        let candidates[-1] ..= a:data[0]
      endif

      let candidates += a:data[1:]
    endfunction
    let process.job = s:get_job().start(
        \ s:convert_args(commands),
        \ #{ on_stdout: function(process.on_out, [], process) })

    call add(processes, process)
  endfor

  " Get outputs
  let results = []
  for process in processes
    call process.job.wait(g:dein#install_process_timeout * 1000)

    if !(process.candidates->empty())
      let result = process.candidates[0]
      try
        let json = result->json_decode()
        let results += json['data']->values()
              \ ->filter({ _, val -> val->type() == v:t_dict
              \          && val->has_key('pushedAt') })
      catch
        call s:error('json output decode error: ' + result->string())
      endtry
    endif
  endfor

  " Get pushed time.

  let check_pushed = {}
  for node in results
    let format = '%Y-%m-%dT%H:%M:%SZ'
    let pushed_at = node['pushedAt']
    let check_pushed[node['nameWithOwner']]
          \ = '*strptime'->exists() ?
          \   format->strptime(pushed_at) :
          \   dein#DateTime#from_format(pushed_at, format).unix_time()
  endfor

  " Get the last updated time by rollbackfile timestamp.
  " NOTE: .git timestamp may be changed by git commands.
  const rollbacks = (s:get_rollback_directory() .. '/*')->glob(
        \ v:true, v:true)->sort()->reverse()
  const rollback_time = rollbacks->empty() ? -1 : rollbacks[0]->getftime()

  " Compare with .git directory updated time.
  let updated = []
  let index = 1
  for plugin in plugins
    if !(check_pushed->has_key(plugin.repo))
      let index += 1
      continue
    endif

    call s:print_progress_message(
          \ s:get_progress_message('compare plugin', index, plugins->len()))

    let git_path = plugin.path .. '/.git'
    let repo_time = plugin.path->isdirectory() ? git_path->getftime() : -1

    call s:log(printf('%s: pushed_time=%d, repo_time=%d, rollback_time=%d',
          \ plugin.name, check_pushed[plugin.repo], repo_time, rollback_time))

    let local_update = [repo_time, rollback_time]->min()
    if local_update < check_pushed[plugin.repo]
      call add(updated, plugin)
    elseif abs(local_update - check_pushed[plugin.repo])
          \ < g:dein#install_check_remote_threshold
      " NOTE: github Graph QL API may use cached value
      " If the repository is updated recently, use "git ls-remote" instead.
      let remote = s:system_cd(['git', 'ls-remote', 'origin', 'HEAD'],
            \ plugin.path)->matchstr('^\x\+')
      let local = s:get_revision_number(plugin)
      call s:log(printf('%s: remote=%s, local=%s',
            \ plugin.name, remote, local))
      if remote !=# '' && local !=# remote
        call add(updated, plugin)
      endif
    endif

    let index += 1
  endfor

  redraw | echo ''

  if s:progress_winid > 0
    call timer_start(1000, { -> s:close_progress_popup() })
  endif

  " Clear global context
  let s:global_context = {}

  return updated
endfunction
function! dein#install#_check_update(plugins, force, async) abort
  const updated = dein#install#_get_updated_plugins(a:plugins, a:async)
  if updated->empty()
    call s:notify(strftime('Done: (%Y/%m/%d %H:%M:%S)'))
    return
  endif

  const updated_msg = 'Updated plugins: '
        \ .. updated->copy()->map({ _, val -> val.name })->string()
  call s:log(updated_msg)

  " NOTE: Use echomsg to display it in confirm
  call s:echo(updated_msg, 'echomsg')
  if !a:force && confirm(
        \ 'Updated plugins are exists. Update now?', "yes\nNo", 2) != 1
    return
  endif

  call dein#install#_do(updated, 'update', a:async)
endfunction

function! dein#install#_reinstall(plugins) abort
  if g:dein#_is_sudo
    call s:error('update/install is disabled in sudo session.')
    return
  endif

  let plugins = dein#util#_get_plugins(a:plugins)

  for plugin in plugins
    " Remove the plugin
    if plugin.type ==# 'none'
          \ || plugin->get('local', 0)
          \ || (plugin.sourced &&
          \     ['dein']->index(plugin.normalized_name) >= 0)
      call dein#util#_error(
            \ printf('|%s| Cannot reinstall the plugin!', plugin.name))
      continue
    endif

    " Reinstall.
    call s:print_progress_message(printf('|%s| Reinstalling...', plugin.name))

    if plugin.path->isdirectory()
      call dein#install#_rm(plugin.path)
    endif
  endfor

  call dein#install#_do(dein#util#_convert2list(a:plugins), 'install', 0)
endfunction
function! dein#install#_direct_install(repo, options) abort
  if g:dein#_is_sudo
    call s:error('update/install is disabled in sudo session.')
    return
  endif

  let options = a:options->copy()
  let options.merged = 0

  let plugin = dein#add(a:repo, options)
  if plugin->empty()
    return
  endif

  call dein#install#_do(plugin.name, 'install', 0)
  call dein#source(plugin.name)

  " Add to direct_install.vim
  const file = dein#get_direct_plugins_path()
  const line = printf('call dein#add(%s, %s)',
        \ a:repo->string(), options->string())
  if !(file->filereadable())
    call dein#util#_safe_writefile([line], file)
  else
    call dein#util#_safe_writefile(file->readfile()->add(line), file)
  endif
endfunction
function! dein#install#_rollback(date, plugins) abort
  if g:dein#_is_sudo
    call s:error('update/install is disabled in sudo session.')
    return
  endif

  const glob = s:get_rollback_directory() .. '/' .. a:date .. '*'
  const rollbacks = glob->glob(v:true, v:true)->sort()->reverse()
  if rollbacks->empty()
    return
  endif

  call dein#install#_load_rollback(rollbacks[0], a:plugins)
endfunction

function! dein#install#_recache_runtimepath() abort
  if g:dein#_is_sudo
    return
  endif

  const start = reltime()

  " Clear runtime path.
  call s:clear_runtimepath()

  let plugins = dein#get()->values()

  let merged_plugins = plugins->copy()->filter({ _, val -> val.merged })
  let lazy_merged_plugins = merged_plugins->copy()
        \ ->filter({ _, val -> val.lazy })
  let nolazy_merged_plugins = merged_plugins->copy()
        \ ->filter({ _, val -> !val.lazy })
  let merge_ftdetect_plugins = plugins->copy()
        \ ->filter({ _, val -> val->get('merge_ftdetect', 0)
        \          || (val.merged && !val.lazy) })

  call s:copy_files(lazy_merged_plugins, '')

  const runtime = dein#util#_get_runtime_path()

  " Remove plugin directory
  call dein#install#_rm(runtime .. '/plugin')
  call dein#install#_rm(runtime .. '/after/plugin')

  call s:copy_files(nolazy_merged_plugins, '')

  call s:helptags()

  call s:generate_ftplugin()

  " Clear ftdetect and after/ftdetect directories.
  call dein#install#_rm(runtime .. '/ftdetect')
  call dein#install#_rm(runtime .. '/after/ftdetect')

  call s:merge_files(merge_ftdetect_plugins, 'ftdetect')
  call s:merge_files(merge_ftdetect_plugins, 'after/ftdetect')

  if g:->get('dein#auto_remote_plugins', v:true)
    silent call dein#remote_plugins()
  endif

  call dein#call_hook('post_source')

  call dein#install#_save_rollback(
        \ s:get_rollback_directory() ..
        \ '/' .. '%Y%m%d%H%M%S'->strftime(), [])

  call dein#util#_clear_state()

  call s:log('Runtimepath updated: (%Y/%m/%d %H:%M:%S)'->strftime())
  call s:log('recache_runtimepath: ' ..
        \ start->reltime()->reltimestr()->split()[0])
endfunction
function! s:clear_runtimepath() abort
  if dein#util#_get_cache_path() ==# ''
    call dein#util#_error('Invalid base path.')
    return
  endif

  const runtimepath = dein#util#_get_runtime_path()

  " Remove runtime path
  call dein#install#_rm(runtimepath)

  if !isdirectory(runtimepath)
    " Create runtime path
    call dein#util#_safe_mkdir(runtimepath)
  endif
endfunction

" args:
"   - path: string
" return: [{ title: string, pattern: string }]
function! s:detect_tags_in_markdown(path) abort
  let tags = []
  for line in a:path->readfile()
    " Match to markdown's (# title) or html's (<h1>title</h1>) pattern.
    let matches = line->matchlist(
          \ '\v(^#+\s*(.+)\s*$|\<h[1-6][^>]+\>\s*(.+)\s*\</h[1-6]\>)')
    if matches->len() <= 3
      continue
    endif

    " matches[2]: markdown subpattern
    " matches[3]: html subpattern
    let title = matches[2] !=# '' ? matches[2] : matches[3]
    let pattern = matches[1]
    call add(tags, #{
          \   title: title->substitute('\s\+', '-', 'g'),
          \   pattern: '/' .. pattern
          \       ->substitute('\s\+', '\\s\\+', 'g')
          \       ->substitute('\/', '\\/', 'g')
          \       ->substitute('\.', '\\.', 'g')
          \ })
  endfor
  return tags
endfunction
function! s:helptags() abort
  if g:dein#_runtime_path ==# ''
    return ''
  endif

  const doc_dir = dein#util#_get_runtime_path() .. '/doc'
  const tagfile = doc_dir .. '/tags'
  if !(doc_dir->isdirectory())
    call mkdir(doc_dir, 'p')
  endif
  call writefile([], tagfile)

  let plugins = dein#get()->values()

  try
    call dein#util#_safe_mkdir(doc_dir)
    call s:copy_files(plugins->filter({ _, val -> !val.merged }), 'doc')
    silent execute 'helptags' doc_dir->fnameescape()
  catch /^Vim(helptags):E151:/
    " Ignore an error that occurs when there is no help file
  catch
    call s:error('Error generating helptags:')
    call s:error(v:exception)
    call s:error(v:throwpoint)
  endtry

  let taglines = []
  for plugin in plugins
        \ ->filter({ _, val -> !((val.rtp .. '/doc')->isdirectory()) })
    for path in ['README.md', 'README.mkd']
          \ ->map({ _, val -> plugin.rtp .. '/' .. val })
          \ ->filter({ _, val -> val->filereadable() })
      " Add the filename to tags
      for tag in s:detect_tags_in_markdown(path)
        " If tag name equals to plugin name, use plugin name for tag name
        let title = plugin.name ==? tag.title
              \ ? plugin.name
              \ : printf("%s-%s", plugin.name, tag.title)
        call add(taglines, printf("%s\t%s\t%s", title, path, tag.pattern))
      endfor
    endfor
  endfor
  if !(taglines->empty())
    " NOTE: tagfile must be sorted
    call writefile(sort(readfile(tagfile) + taglines), tagfile)
  endif
endfunction
function! s:copy_files(plugins, directory) abort
  const directory = (a:directory ==# '' ? '' : '/' .. a:directory)
  const srcs = a:plugins->copy()
        \ ->map({ _, val -> val.rtp .. directory })
        \ ->filter({ _, val -> val->isdirectory() })
  const stride = 50
  for start in range(0, srcs->len(), stride)
    call dein#install#_copy_directories(srcs[start : start + stride-1],
          \ dein#util#_get_runtime_path() .. directory)
  endfor
endfunction
function! s:merge_files(plugins, directory) abort
  let vimfiles = []
  let luafiles = []
  for plugin in a:plugins
    for file in (a:directory.'/**/*')
          \ ->globpath(plugin.rtp, v:true, v:true)
          \ ->filter({ _, val -> !(val->isdirectory()) })
      if file->fnamemodify(':e') ==# 'vim'
        let vimfiles += file->readfile(':t')
      elseif file->fnamemodify(':e') ==# 'lua'
        let luafiles += file->readfile(':t')
      endif
    endfor
  endfor

  if !(vimfiles->empty())
    call dein#util#_cache_writefile(vimfiles,
          \ printf('.dein/%s/%s.vim', a:directory, a:directory))
  endif
  if !(luafiles->empty())
    call dein#util#_cache_writefile(luafiles,
          \ printf('.dein/%s/%s.lua', a:directory, a:directory))
  endif
endfunction
function! dein#install#_save_rollback(rollbackfile, plugins) abort
  let revisions = {}
  for plugin in dein#util#_get_plugins(a:plugins)
        \ ->filter({ _, val -> s:check_rollback(val) })
    let rev = s:get_revision_number(plugin)
    if rev !=# ''
      let revisions[plugin.name] = rev
    endif
  endfor

  call dein#util#_safe_writefile(
        \ [revisions->json_encode()], a:rollbackfile->expand())
endfunction
function! dein#install#_load_rollback(rollbackfile, plugins) abort
  let revisions = a:rollbackfile->readfile()[0]->json_decode()

  let plugins = dein#util#_get_plugins(a:plugins)
  call filter(plugins, { _, val -> revisions->has_key(val.name)
        \ && dein#util#_get_type(val.type)->has_key('get_rollback_command')
        \ && s:check_rollback(val)
        \ && s:get_revision_number(val) !=# revisions[val.name]
        \ })
  if plugins->empty()
    return
  endif

  for plugin in plugins
    let type = dein#util#_get_type(plugin.type)
    let cmd = type.get_rollback_command(
          \ dein#util#_get_type(plugin.type), revisions[plugin.name])
    call dein#install#_each(cmd, plugin)
  endfor

  call dein#recache_runtimepath()
  call s:error('Rollback to ' ..
        \ a:rollbackfile->fnamemodify(':t') .. ' version.')
endfunction
function! s:get_rollback_directory() abort
  const parent = printf('%s/rollbacks/%s',
        \ dein#util#_get_cache_path(), g:dein#_progname)
  call dein#util#_safe_mkdir(parent)

  return parent
endfunction
function! s:check_rollback(plugin) abort
  return !(a:plugin->has_key('local')) && !(a:plugin->get('frozen', 0))
endfunction

function! dein#install#_get_default_ftplugin() abort
  let default_ftplugin =<< trim END
    if exists('g:did_load_after_ftplugin')
      finish
    endif
    let g:did_load_after_ftplugin = 1

    augroup filetypeplugin
      autocmd!
      autocmd FileType * call s:ftplugin()
    augroup END

    function! s:ftplugin()
      if 'b:undo_ftplugin'->exists()
        silent! execute b:undo_ftplugin
        unlet! b:undo_ftplugin b:did_ftplugin
      endif

      let filetype = '<amatch>'->expand()
      if filetype !=# ''
        if &cpoptions =~# 'S' && 'b:did_ftplugin'->exists()
          unlet b:did_ftplugin
        endif
        for ft in filetype->split('\.')
          execute 'runtime!'
          \ 'ftplugin/' .. ft .. '.vim'
          \ 'ftplugin/' .. ft .. '_*.vim'
          \ 'ftplugin/' .. ft .. '/*.vim'
          if has('nvim')
            execute 'runtime!'
            \ 'ftplugin/' .. ft .. '.lua'
            \ 'ftplugin/' .. ft .. '_*.lua'
            \ 'ftplugin/' .. ft .. '/*.lua'
          endif
        endfor
      endif
      call s:after_ftplugin()
    endfunction

  END
  return default_ftplugin
endfunction
function! s:generate_ftplugin() abort
  if g:dein#ftplugin->empty()
    return
  endif

  " Create after/ftplugin
  const after = dein#util#_get_runtime_path() .. '/after/ftplugin'
  call dein#util#_safe_mkdir(after)

  " Merge g:dein#ftplugin
  let ftplugin = {}
  for [key, string] in g:dein#ftplugin->items()
    for ft in (key ==# '_' ? ['_'] : key->split('_'))
      if !(ftplugin->has_key(ft))
        if ft ==# '_'
          let ftplugin[ft] = []
        else
          let ftplugin[ft] =<< trim END
            if 'b:undo_ftplugin'->exists()
              let b:undo_ftplugin ..= '|'
            else
              let b:undo_ftplugin = ''
            endif
          END
        endif
      endif
      let ftplugin[ft] += string->split('\n')
    endfor
  endfor

  " Generate ftplugin.vim
  let ftplugin_generated = dein#install#_get_default_ftplugin()
  let ftplugin_generated += ['function! s:after_ftplugin()']
  let ftplugin_generated += ftplugin->get('_', [])
  let ftplugin_generated += ['endfunction']
  call dein#util#_safe_writefile(ftplugin_generated,
        \ dein#util#_get_runtime_path() .. '/after/ftplugin.vim')

  " Generate after/ftplugin
  for [filetype, list] in ftplugin->items()
        \ ->filter({ _, val -> val[0] !=# '_' })
    call dein#util#_safe_writefile(list, printf('%s/%s.vim', after, filetype))
  endfor
endfunction

function! dein#install#_is_async() abort
  return g:dein#install_max_processes > 1
endfunction

function! dein#install#_polling() abort
  if '+guioptions'->exists()
    " NOTE: guioptions-! does not work in async state
    const save_guioptions = &guioptions
    set guioptions-=!
  endif

  call s:install_async(s:global_context)

  if '+guioptions'->exists()
    let &guioptions = save_guioptions
  endif
endfunction

function! dein#install#_remote_plugins() abort
  if !has('nvim') || g:dein#_is_sudo
    return
  endif

  if has('vim_starting')
    " NOTE: UpdateRemotePlugins is not defined in vim_starting
    autocmd dein VimEnter * silent call dein#remote_plugins()
    return
  endif

  if ':UpdateRemotePlugins'->exists() != 2
    return
  endif

  " Load not loaded neovim remote plugins
  let remote_plugins = dein#get()->values()
        \ ->filter({ _, val ->
        \  (val.rtp .. '/rplugin')->isdirectory() && !val.sourced
        \  && !((val.rtp .. '/rplugin/*/*/__init__.py')->glob(1, 1)->empty())
        \ })
  if remote_plugins->empty()
    return
  endif

  call dein#autoload#_source(remote_plugins)

  call s:log('loaded remote plugins: ' ..
        \ remote_plugins->copy()->map({ _, val -> val.name })->string())

  let &runtimepath = dein#util#_join_rtp(dein#util#_uniq(
        \ dein#util#_split_rtp(&runtimepath)), &runtimepath, '')

  let result = 'UpdateRemotePlugins'->execute('')
  call s:log(result)
endfunction

function! dein#install#_each(cmd, plugins) abort
  let plugins = filter(dein#util#_get_plugins(a:plugins),
        \ { _, val -> val.path->isdirectory() })

  let global_context_save = s:global_context

  let context = s:init_context(plugins, 'each', 0)
  call s:init_variables(context)

  const cwd = getcwd()
  let error = 0
  try
    for plugin in plugins
      call dein#install#_cd(plugin.path)

      if dein#install#_execute(a:cmd)
        let error = 1
      endif
    endfor
  catch
    call s:error(v:exception .. ' ' .. v:throwpoint)
    return 1
  finally
    let s:global_context = global_context_save
    call dein#install#_cd(cwd)
  endtry

  return error
endfunction
function! dein#install#_build(plugins) abort
  let error = 0
  for plugin in dein#util#_get_plugins(a:plugins)
        \ ->filter({ _, val ->
        \          val.path->isdirectory() && val->has_key('build') })
    call s:print_progress_message('Building: ' .. plugin.name)
    if dein#install#_each(plugin.build, plugin)
      let error = 1
    endif
  endfor
  return error
endfunction

function! dein#install#_get_log() abort
  return s:log
endfunction
function! dein#install#_get_updates_log() abort
  return s:updates_log
endfunction
function! dein#install#_get_context() abort
  return s:global_context
endfunction
function! dein#install#_get_progress() abort
  return s:progress
endfunction
function! dein#install#_get_failed_plugins() abort
  return s:failed_plugins
endfunction

function! s:get_progress_message(name, number, max) abort
  const len = a:max->len()
  return printf('(%' .. len .. 'd/%' .. len .. 'd) [%s%s] %s',
        \ a:number, a:max,
        \ '+'->repeat(a:number * 20 / a:max),
        \ '-'->repeat(20 - (a:number * 20 / a:max)),
        \ a:name)
endfunction
function! s:get_plugin_message(plugin, number, max, message) abort
  return printf('(%' .. a:max->len() .. 'd/%d) |%-20s| %s',
        \ a:number, a:max, a:plugin.name, a:message)
endfunction
function! s:get_short_message(plugin, number, max, message) abort
  return printf('(%' .. a:max->len() .. 'd/%d) %s', a:number, a:max, a:message)
endfunction
function! s:get_sync_command(plugin, update_type, number, max) abort "{{{i
  const type = dein#util#_get_type(a:plugin.type)

  if type->has_key('get_sync_command')
    const cmd = type.get_sync_command(a:plugin)
  else
    return ['', '']
  endif

  if cmd->empty()
    return ['', '']
  endif

  const message = s:get_plugin_message(
        \ a:plugin, a:number, a:max, cmd->string())

  return [cmd, message]
endfunction
function! s:get_revision_number(plugin) abort
  if !(a:plugin.path->isdirectory())
    return ''
  endif

  const type = dein#util#_get_type(a:plugin.type)

  if type->has_key('get_revision_number')
    return type.get_revision_number(a:plugin)
  endif

  if !(type->has_key('get_revision_number_command'))
    return ''
  endif

  const cmd = type.get_revision_number_command(a:plugin)
  if cmd->empty()
    return ''
  endif

  const rev = s:system_cd(cmd, a:plugin.path)

  " If rev contains spaces, it is error message
  if rev =~# '\s'
    call s:error(a:plugin.name)
    call s:error('Error revision number: ' .. rev)
    return ''
  elseif rev ==# ''
    call s:error(a:plugin.name)
    call s:error('Empty revision number: ' .. rev)
    return ''
  endif
  return rev
endfunction
function! s:get_updated_log_message(plugin, new_rev, old_rev) abort
  const type = dein#util#_get_type(a:plugin.type)

  const cmd = type->has_key('get_log_command') ?
        \ type.get_log_command(a:plugin, a:new_rev, a:old_rev) : ''
  const log = cmd->empty() ? '' : s:system_cd(cmd, a:plugin.path)
  return log !=# '' ? log :
        \            (a:old_rev  == a:new_rev) ? ''
        \            : printf('%s -> %s', a:old_rev, a:new_rev)
endfunction
function! s:lock_revision(process, context) abort
  const num = a:process.number
  const max = a:context.max_plugins
  let plugin = a:process.plugin

  const type = dein#util#_get_type(plugin.type)
  if !(type->has_key('get_revision_lock_command'))
    return 0
  endif

  const cmd = type.get_revision_lock_command(plugin)

  if cmd->empty()
    " Skipped.
    return 0
  elseif cmd->type() == v:t_string && cmd =~# '^E: '
    " Errored.
    call s:error(plugin.path)
    call s:error(cmd[3:])
    return -1
  endif

  if plugin->get('rev', '') !=# ''
    call s:log(s:get_plugin_message(plugin, num, max, 'Locked'))
  endif

  const result = s:system_cd(cmd, plugin.path)
  const status = dein#install#_status()

  if status
    call s:error(plugin.path)
    call s:error(result)
    return -1
  endif
endfunction
function! s:get_updated_message(context, plugins) abort
  " Diff check
  if g:dein#install_check_diff
    call s:check_diff(a:plugins)
  endif

  return "Updated plugins:\n".
        \ a:plugins->copy()
        \ ->map({ _, val -> '  ' .. val.name .. (val.commit_count == 0 ? ''
        \                     : printf('(%d change%s)',
        \                              val.commit_count,
        \                              (val.commit_count == 1 ? '' : 's')))
        \    .. ((val.old_rev !=# ''
        \        && val.uri =~# '^\h\w*://github.com/') ? "\n"
        \        .. printf('    %s/compare/%s...%s',
        \        val.uri->substitute('\.git$', '', '')
        \        ->substitute('^\h\w*:', 'https:', ''),
        \        val.old_rev, val.new_rev) : '')
        \ })->join("\n")
endfunction
function! s:get_errored_message(plugins) abort
  if a:plugins->empty()
    return ''
  endif

  let msg = "Error installing plugins:\n".
        \ a:plugins->copy()->map({ _, val -> '  ' .. val.name })->join("\n")
  let msg ..= "\n"
  let msg ..= "Please read the error message log with the :message command.\n"

  return msg
endfunction
function! s:get_breaking_message(plugins) abort
  if a:plugins->empty()
    return ''
  endif

  let msg = "Breaking updated plugins:\n".join(
        \ a:plugins->copy()
        \ ->map({ _, val -> printf("  %s\n%s", val.name, v:val.log_message)
        \ }), "\n")
  let msg ..= "\n"
  let msg ..= "Please read the plugins documentation."

  return msg
endfunction

function! s:check_diff(plugins) abort
  for plugin in a:plugins
    let type = dein#util#_get_type(plugin.type)
    if !(type->has_key('get_diff_command')) || plugin.old_rev ==# ''
      continue
    endif

    " NOTE: execute diff command in background
    let cmd = type.get_diff_command(plugin, plugin.old_rev, plugin.new_rev)
    let cwd = getcwd()
    try
      call dein#install#_cd(plugin.path)
      call s:get_job().start(
            \ s:convert_args(cmd), #{
            \   on_stdout: function('s:check_diff_on_out'),
            \ })
    finally
      call dein#install#_cd(cwd)
    endtry
  endfor
endfunction
function! s:check_diff_on_out(data) abort
  const bufname = 'dein-diff'
  if !(bufname->bufexists())
    let bufnr = bufname->bufadd()
  else
    let bufnr = bufname->bufnr()
  endif

  if bufnr->bufwinnr() < 0
    const cmd = 'setlocal bufhidden=wipe filetype=diff buftype=nofile nolist'
          \ .. '| syntax enable'
    execute printf('sbuffer +%s', cmd->escape(' ')) bufnr
  endif

  const current = bufnr->getbufline('$')[0]
  call setbufline(bufnr, '$', current .. a:data[0])
  call appendbufline(bufnr, '$', a:data[1:])
endfunction


" Helper functions
function! dein#install#_cd(path) abort
  if !(a:path->isdirectory())
    return
  endif

  try
    noautocmd execute (haslocaldir() ? 'lcd' : 'cd') a:path->fnameescape()
  catch
    call s:error('Error cd to: ' .. a:path)
    call s:error('Current directory: ' .. getcwd())
    call s:error(v:exception)
    call s:error(v:throwpoint)
  endtry
endfunction

function! dein#install#_system(command) abort
  return s:job_system.system(a:command)
endfunction
let s:job_system = {}
function! s:job_system.on_out(data) abort
  let candidates = s:job_system.candidates
  if candidates->empty()
    call add(candidates, a:data[0])
  else
    let candidates[-1] ..= a:data[0]
  endif
  let candidates += a:data[1:]
endfunction
function! s:job_system.system(cmd) abort
  let self.candidates = []

  let job = s:get_job().start(
        \ s:convert_args(a:cmd), #{
        \   on_stdout: self.on_out,
        \   on_stderr: self.on_out,
        \ })
  let s:job_system.status = job.wait(
        \ g:dein#install_process_timeout * 1000)
  return s:job_system.candidates->join("\n")->substitute('\r\n', '\n', 'g')
endfunction
function! dein#install#_status() abort
  return s:job_system.status
endfunction
function! s:system_cd(command, path) abort
  const cwd = getcwd()
  try
    call dein#install#_cd(a:path)
    return dein#install#_system(a:command)
  finally
    call dein#install#_cd(cwd)
  endtry
  return ''
endfunction

function! dein#install#_execute(command) abort
  return s:job_execute.execute(a:command)
endfunction
let s:job_execute = {}
function! s:job_execute.on_out(data) abort
  for line in a:data
    echo line
  endfor

  let candidates = s:job_execute.candidates
  if candidates->empty()
    call add(candidates, a:data[0])
  else
    let candidates[-1] ..= a:data[0]
  endif
  let candidates += a:data[1:]
endfunction
function! s:job_execute.execute(cmd) abort
  let self.candidates = []

  let job = s:get_job().start(
        \ s:convert_args(a:cmd),
        \ #{ on_stdout: self.on_out} )

  return job.wait(g:dein#install_process_timeout * 1000)
endfunction

function! dein#install#_rm(path) abort
  if !(a:path->isdirectory()) && !(a:path->filereadable())
    return
  endif

  try
    call delete(a:path, 'rf')
  catch
    call s:error('Error deleting directory: ' .. a:path)
    call s:error(v:exception)
    call s:error(v:throwpoint)
  endtry
endfunction

function! dein#install#_copy_directories(srcs, dest) abort
  if a:srcs->empty()
    return 0
  endif

  if g:dein#install_copy_vim
    return dein#install#_copy_directories_vim(a:srcs, a:dest)
  endif

  let status = 0

  if dein#util#_is_windows()
    call dein#util#_error('robocopy copy is not supported.')
    call dein#util#_error('Please enable "g:dein#install_copy_vim".')
    return 1
  endif

  let srcs = a:srcs->copy()
        \ ->filter({ _, val -> len(glob(val .. '/*', v:true, v:true)) })
        \ ->map({ _, val -> shellescape(val .. '/') })

  if 'rsync'->executable()
    let cmdline = printf("rsync -a -q --exclude '/.git/' %s %s",
          \ srcs->join(), a:dest->shellescape())
    let result = dein#install#_system(cmdline)
    let status = dein#install#_status()
  else
    for src in srcs
      let cmdline = printf('cp -Ra %s* %s', src, a:dest->shellescape())
      let result = dein#install#_system(cmdline)
      let status = dein#install#_status()
      if status
        break
      endif
    endfor
  endif

  if status
    call dein#util#_error('copy command failed.')
    call dein#util#_error(result)
    call dein#util#_error('cmdline: ' .. cmdline)
  endif

  return status
endfunction
function! dein#install#_copy_directories_vim(srcs, dest) abort
  const dest = dein#util#_substitute_path(a:dest)

  for src in a:srcs
    let src = dein#util#_substitute_path(src)

    for srcpath in (src .. '/**/*')->glob(1, 1)
      let srcpath = dein#util#_substitute_path(srcpath)
      let destpath = srcpath->substitute(
            \ dein#util#escape_match(src),
            \ dein#util#escape_match(dest), '')
      let parent = destpath->fnamemodify(':p:h')
      if !(parent->isdirectory())
        call mkdir(parent, 'p')
      endif

      if srcpath->isdirectory()
        call mkdir(destpath, 'p')
      elseif srcpath !~# 'tags\%(-\w*\)\?$'
        " Ignore tags
        call dein#install#_copy_file_vim(srcpath, destpath)
      endif
    endfor
  endfor
endfunction
function! dein#install#_copy_file_vim(src, dest) abort
  " NOTE: For neovim, vim.loop.fs_{sym}link is faster
  if has('nvim')
    " NOTE: In Windows, v:lua.vim.loop.fs_symlink does not work.
    if dein#util#_is_windows()
      call v:lua.vim.loop.fs_link(a:src, a:dest)
    else
      call v:lua.vim.loop.fs_symlink(a:src, a:dest)
    endif
  elseif '*filecopy'->exists()
    call filecopy(a:src, a:dest)
  else
    call writefile(a:src->readfile('b'), a:dest, 'b')

    " NOTE: setfperm() is needed.  The file permission may be checked.
    call setfperm(a:dest, getfperm(a:src))
  endif
endfunction

function! dein#install#_deno_cache(plugins = []) abort
  if !('deno'->executable())
    return
  endif

  let plugins = dein#util#_get_plugins(a:plugins)

  for plugin in plugins
    if !((plugin.rtp .. '/denops')->isdirectory())
      continue
    endif

    call dein#install#_system(
          \ ['deno', 'cache', '--no-check'] +
          \ (plugin.rtp .. '/denops/**/*.ts')->glob(1, 1))
  endfor
endfunction

function! dein#install#_post_sync(plugins) abort
  if a:plugins->empty()
    return
  endif

  call dein#install#_recache_runtimepath()

  call dein#install#_deno_cache(a:plugins)

  " Execute done_update hooks
  let done_update_plugins = dein#util#_get_plugins(a:plugins)
  if !(done_update_plugins->empty())
    if has('vim_starting')
      let s:done_updated_plugins = done_update_plugins
      autocmd dein VimEnter * call s:call_done_update_hooks(
            \ s:done_updated_plugins)
    else
      call s:call_done_update_hooks(done_update_plugins)
    endif
  endif
endfunction

function! s:install_blocking(context) abort
  try
    while 1
      call s:check_loop(a:context)

      if a:context.processes->empty()
            \ && a:context.number == a:context.max_plugins
        break
      endif
    endwhile
  finally
    call s:done(a:context)
  endtry

  return a:context.errored_plugins->len()
endfunction
function! s:install_async(context) abort
  if a:context->empty()
    return
  endif

  call s:check_loop(a:context)

  if a:context.processes->empty()
        \ && a:context.number == a:context.max_plugins
    call s:done(a:context)
  elseif a:context.number != a:context.prev_number
        \ && a:context.number < a:context.plugins->len()
    let plugin = a:context.plugins[a:context.number]
    call s:print_progress_message(
          \ s:get_progress_message(plugin.name,
          \   a:context.number, a:context.max_plugins))
    let a:context.prev_number = a:context.number
  endif

  return a:context.errored_plugins->len()
endfunction
function! s:check_loop(context) abort
  while a:context.number < a:context.max_plugins
        \ && a:context.processes->len() < g:dein#install_max_processes

    let plugin = a:context.plugins[a:context.number]
    call s:sync(plugin, a:context)

    if !a:context.async
      call s:print_progress_message(
            \ s:get_progress_message(plugin.name,
            \   a:context.number, a:context.max_plugins))
    endif
  endwhile

  for process in a:context.processes
    call s:check_output(a:context, process)
  endfor

  " Filter eof processes.
  call filter(a:context.processes, { _, val -> !val.eof })
endfunction
function! s:restore_view(context) abort
  if a:context.progress_type ==# 'tabline'
    let &g:showtabline = a:context.showtabline
    let &g:tabline = a:context.tabline
  elseif a:context.progress_type ==# 'title'
    let &g:title = a:context.title
    let &g:titlestring = a:context.titlestring
  endif
endfunction
function! s:init_context(plugins, update_type, async) abort
  let context = {}
  let context.update_type = a:update_type
  let context.async = a:async
  let context.synced_plugins = []
  let context.errored_plugins = []
  let context.breaking_plugins = []
  let context.processes = []
  let context.number = 0
  let context.prev_number = -1
  let context.plugins = a:plugins
  let context.max_plugins = context.plugins->len()
  let context.progress_type = (has('vim_starting')
        \ && g:dein#install_progress_type !=# 'none') ?
        \ 'echo' : g:dein#install_progress_type
  if !has('nvim') && context.progress_type ==# 'title'
    let context.progress_type = 'echo'
  endif
  let context.message_type = (has('vim_starting')
        \ && g:dein#install_message_type !=# 'none') ?
        \ 'echo' : g:dein#install_message_type
  let context.laststatus = &g:laststatus
  let context.showtabline = &g:showtabline
  let context.tabline = &g:tabline
  let context.title = &g:title
  let context.titlestring = &g:titlestring
  return context
endfunction
function! s:init_variables(context) abort
  let s:progress = ''
  let s:global_context = a:context
  let s:log = []
  let s:updates_log = []
endfunction
function! s:convert_args(args) abort
  let args = s:iconv(a:args, &encoding, 'char')
  if args->type() != v:t_list
    let args = &shell->split() + &shellcmdflag->split() + [args]
  endif
  return args
endfunction
function! s:start() abort
  call s:notify('Update started: (%Y/%m/%d %H:%M:%S)'->strftime())
endfunction
function! s:close_progress_popup() abort
  if s:progress_winid->winbufnr() < 0
    return
  endif

  if has('nvim')
    silent! call nvim_win_close(s:progress_winid, v:true)
  else
    silent! call popup_close(s:progress_winid)
  endif
  let s:progress_winid = -1
endfunction
function! s:done(context) abort
  call s:restore_view(a:context)

  let s:failed_plugins = a:context.errored_plugins->copy()
        \ ->map({ _, val -> val.name })

  if !empty(a:context.synced_plugins)
    let names = a:context.synced_plugins->copy()->map({ _, val -> val.name })
    call dein#install#_post_sync(names)
  endif

  if !has('vim_starting')
    call s:notify(s:get_updated_message(a:context, a:context.synced_plugins))
    call s:notify(s:get_errored_message(a:context.errored_plugins))
    call s:error(s:get_breaking_message(a:context.breaking_plugins))
  endif

  redraw | echo ''

  if s:progress_winid > 0
    call timer_start(1000, { -> s:close_progress_popup() })
  endif

  call s:notify('Done: (%Y/%m/%d %H:%M:%S)'->strftime())

  " Disable installation handler
  let s:global_context = {}
  let s:progress = ''
  augroup dein-install
    autocmd!
  augroup END
  if 's:timer'->exists()
    call timer_stop(s:timer)
    unlet s:timer
  endif
endfunction
function! s:call_done_update_hooks(updated_plugins) abort
  const cwd = getcwd()
  try
    for plugin in a:updated_plugins->copy()->filter({
          \   _, val -> val->has_key('hook_done_update')
          \ })
      call dein#install#_cd(plugin.path)
      call dein#source(plugin)
      call dein#call_hook('done_update', plugin)
    endfor

    for plugin in dein#get()->values()->filter({ _, val ->
          \   !(val->get('depends', [])->empty())
          \   && val->has_key('hook_depends_update')
          \   && a:updated_plugins->copy()->filter({ _, updated ->
          \        val.depends->index(updated.name) >= 0
          \      })->len() >= 0
          \ })
      call dein#install#_cd(plugin.path)
      call dein#source(plugin)
      call dein#call_hook('depends_update', plugin)
    endfor
  finally
    call dein#install#_cd(cwd)
  endtry
endfunction

function! s:sync(plugin, context) abort
  let a:context.number += 1

  const num = a:context.number
  const max = a:context.max_plugins

  if a:plugin.path->isdirectory() && a:plugin->get('frozen', 0)
    " Skip frozen plugin
    call s:log(s:get_plugin_message(a:plugin, num, max, 'is frozen.'))
    return
  endif

  const [cmd, message] = s:get_sync_command(
        \   a:plugin, a:context.update_type,
        \   a:context.number, a:context.max_plugins)

  if cmd->empty()
    " Skip
    call s:log(s:get_plugin_message(a:plugin, num, max, message))
    return
  endif

  if cmd->type() == v:t_string && cmd =~# '^E: '
    " Errored.

    call s:print_progress_message(s:get_plugin_message(
          \ a:plugin, num, max, 'Error'))
    call s:error(cmd[3:])
    call add(a:context.errored_plugins,
          \ a:plugin)
    return
  endif

  if !a:context.async
    call s:print_progress_message(message)
  endif

  let process = s:init_process(a:plugin, a:context, cmd)
  if !(process->empty())
    call add(a:context.processes, process)
  endif
endfunction
function! s:init_process(plugin, context, cmd) abort
  let process = {}

  const cwd = getcwd()
  const lang_save = $LANG
  const prompt_save = $GIT_TERMINAL_PROMPT
  try
    let $LANG = 'C'
    " Disable git prompt (git version >= 2.3.0)
    let $GIT_TERMINAL_PROMPT = 0

    call dein#install#_cd(a:plugin.path)

    const rev = s:get_revision_number(a:plugin)

    let process = #{
          \   number: a:context.number,
          \   max_plugins: a:context.max_plugins,
          \   rev: rev,
          \   plugin: a:plugin,
          \   output: '',
          \   status: -1,
          \   eof: 0,
          \   installed: a:plugin.path->isdirectory(),
          \ }

    const rev_save = a:plugin->get('rev', '')
    if a:plugin.path->isdirectory()
          \ && !(a:plugin->get('local', 0))
          \ && rev_save !=# ''
      try
        " Force checkout HEAD revision.
        " The repository may be checked out.
        let a:plugin.rev = ''

        call s:lock_revision(process, a:context)
      finally
        let a:plugin.rev = rev_save
      endtry
    endif

    call s:init_job(process, a:context, a:cmd)
  finally
    let $LANG = lang_save
    let $GIT_TERMINAL_PROMPT = prompt_save
    call dein#install#_cd(cwd)
  endtry

  return process
endfunction
function! s:init_job(process, context, cmd) abort
  let a:process.start_time = localtime()

  if !a:context.async
    let a:process.output = dein#install#_system(a:cmd)
    let a:process.status = dein#install#_status()
    return
  endif

  let a:process.async = #{ eof: 0 }
  function! a:process.async.job_handler(data) abort
    if !(self->has_key('candidates'))
      let self.candidates = []
    endif
    let candidates = self.candidates
    if candidates->empty()
      call add(candidates, a:data[0])
    else
      let candidates[-1] ..= a:data[0]
    endif

    call s:print_progress_message(candidates[-1])

    let candidates += a:data[1:]
  endfunction

  function! a:process.async.on_exit(exitval) abort
    let self.exitval = a:exitval
  endfunction

  function! a:process.async.get(process) abort
    " Check job status
    let status = -1
    if a:process.job->has_key('exitval')
      let self.eof = 1
      let status = a:process.job.exitval
    endif

    let candidates = a:process.job->get('candidates', [])
    let output = (self.eof ? candidates : candidates[: -2])->join("\n")
    if output !=# '' && a:process.output !=# output
      let a:process.output = output
      let a:process.start_time = localtime()
    endif
    let self.candidates = self.eof ? [] : candidates[-1:]

    let is_timeout = (localtime() - a:process.start_time)
          \             >= a:process.plugin->get(
          \                'timeout', g:dein#install_process_timeout)

    if self.eof
      let is_timeout = 0
      let is_skip = 0
    else
      let is_skip = 1
    endif

    if is_timeout
      call a:process.job.stop()
      let status = -1
    endif

    return [is_timeout, is_skip, status]
  endfunction

  let a:process.job = s:get_job().start(
        \ s:convert_args(a:cmd), #{
        \   on_stdout: a:process.async.job_handler,
        \   on_stderr: a:process.async.job_handler,
        \   on_exit: a:process.async.on_exit,
        \ })
  let a:process.id = a:process.job.pid()
  let a:process.job.candidates = []
endfunction
function! s:check_output(context, process) abort
  if a:context.async
    let [is_timeout, is_skip, status] = a:process.async.get(a:process)
  else
    let [is_timeout, is_skip, status] = [0, 0, a:process.status]
  endif

  if is_skip && !is_timeout
    return
  endif

  const num = a:process.number
  const max = a:context.max_plugins
  let plugin = a:process.plugin

  if plugin.path->isdirectory()
       \ && plugin->get('rev', '') !=# ''
       \ && !(plugin->get('local', 0))
    " Restore revision.
    const cwd = getcwd()
    try
      call dein#install#_cd(plugin.path)

      call s:lock_revision(a:process, a:context)
    finally
      call dein#install#_cd(cwd)
    endtry
  endif

  const new_rev = s:get_revision_number(plugin)

  if is_timeout || status
    call s:log(s:get_plugin_message(plugin, num, max, 'Error'))
    call s:error(plugin.path)
    if !a:process.installed
      if !(plugin.path->isdirectory())
        call s:error('Maybe wrong username or repository.')
      elseif plugin.path->isdirectory()
        call s:error('Remove the installed directory:' .. plugin.path)
        call dein#install#_rm(plugin.path)
      endif
    endif

    call s:error((is_timeout ?
          \    'Process timeout: (%Y/%m/%d %H:%M:%S)'->strftime() :
          \    a:process.output->split('\r\?\n')
          \ ))

    call add(a:context.errored_plugins, plugin)
  elseif a:process.rev ==# new_rev
    call s:log(s:get_plugin_message(
          \ plugin, num, max, 'Same revision'))
  else
    call s:log(s:get_plugin_message(plugin, num, max, 'Updated'))

    const log_message = s:get_updated_log_message(
          \ plugin, new_rev, a:process.rev)
    let log_messages = log_message->split('\r\?\n')
    let plugin.commit_count = log_messages->len()
    call s:log(log_messages
          \ ->map({ _, val -> s:get_short_message(plugin, num, max, val) }))

    let plugin.old_rev = a:process.rev
    let plugin.new_rev = new_rev

    " Execute "post_update" before "build"
    if plugin->has_key('hook_post_update')
      " To load plugin is needed to execute "post_update"
      call dein#source(plugin.name)
      call dein#call_hook('post_update', plugin)
    endif

    const type = dein#util#_get_type(plugin.type)
    let plugin.uri = type->has_key('get_uri') ?
          \ type.get_uri(plugin.repo, plugin) : ''

    if dein#install#_build([plugin.name])
      call s:log(s:get_plugin_message(plugin, num, max, 'Build failed'))
      call s:error(plugin.path)
      " Remove.
      call add(a:context.errored_plugins, plugin)
    else
      call add(a:context.synced_plugins, plugin)
    endif

    " If it has breaking changes commit message
    " https://www.conventionalcommits.org/en/v1.0.0/
    if log_message =~# '.*!.*:\|BREAKING CHANGE:'
      call add(a:context.breaking_plugins, #{
            \   name: plugin.name,
            \   log_message: log_message,
            \ })
    endif
  endif

  let a:process.eof = 1
endfunction

function! s:iconv(expr, from, to) abort
  if a:from ==# '' || a:to ==# '' || a:from ==? a:to
    return a:expr
  endif

  if a:expr->type() == v:t_list
    return a:expr->copy()->map({ _, val -> iconv(val, a:from, a:to) })
  else
    let result = a:expr->iconv(a:from, a:to)
    return result !=# '' ? result : a:expr
  endif
endfunction
function! s:print_progress_message(msg) abort
  const msg = dein#util#_convert2list(a:msg)
        \ ->map({ _, val -> val->substitute('\r', '\n', 'g') })
  let context = s:global_context
  if msg->empty() || context->empty()
    return
  endif

  redraw

  const progress_type = context.progress_type
  let lines = msg->join("\n")
  if progress_type ==# 'tabline'
    set showtabline=2
    let &g:tabline = lines
  elseif progress_type ==# 'title'
    set title
    let &g:titlestring = lines
  elseif progress_type ==# 'floating'
    if s:progress_winid <= 0
      let s:progress_winid = s:new_progress_window()
    endif

    let bufnr = s:progress_winid->winbufnr()
    if bufnr->getbufline(1) ==# ['']
      call setbufline(bufnr, 1, msg)
    else
      call appendbufline(bufnr, '$', msg)
    endif
    call win_execute(s:progress_winid, "call cursor('$', 0) | redraw")
  elseif progress_type ==# 'echo'
    call s:echo(msg, 'echo')
  endif

  call s:log(msg)

  let s:progress = lines
endfunction
function! s:new_progress_window() abort
  const winrow = 0
  const wincol = &columns / 4
  const winwidth = 80
  const winheight = 20

  if has('nvim')
    const winid = nvim_open_win(nvim_create_buf(v:false, v:true), v:true, #{
          \   relative: 'editor',
          \   row: winrow,
          \   col: wincol,
          \   focusable: v:false,
          \   noautocmd: v:true,
          \   style: 'minimal',
          \   width: winwidth,
          \   height: winheight,
          \})
  else
    const winid = popup_create([], #{
          \   pos: 'topleft',
          \   line: winrow + 1,
          \   col: wincol + 1,
          \   minwidth: winwidth,
          \   minheight: winheight,
          \   wrap: 0,
          \ })
  endif

  return winid
endfunction
function! s:error(msg) abort
  const msg = dein#util#_convert2list(a:msg)
  if msg->empty()
    return
  endif

  call s:echo(msg, 'error')

  call s:updates_log(msg)
endfunction
function! s:notify(msg) abort
  const msg = dein#util#_convert2list(a:msg)
  let context = s:global_context
  if msg->empty()
    return
  endif

  call s:updates_log(msg)
  let s:progress = join(msg, "\n")

  if context->empty()
    return
  endif

  if context.message_type ==# 'echo'
    call dein#util#_notify(a:msg)
  endif
endfunction
function! s:updates_log(msg) abort
  const msg = dein#util#_convert2list(a:msg)

  let s:updates_log += msg
  call s:log(msg)
endfunction
function! s:log(msg) abort
  const msg = dein#util#_convert2list(a:msg)
  let s:log += msg
  call s:append_log_file(msg)
endfunction
function! s:append_log_file(msg) abort
  const logfile = dein#util#_expand(g:dein#install_log_filename)
  if logfile ==# ''
    return
  endif

  let msg = a:msg
  " Appends to log file.
  if logfile->filereadable()
    let msg = logfile->readfile() + msg
  endif

  call dein#util#_safe_writefile(msg, logfile)
endfunction


function! s:echo(expr, mode) abort
  const msg = dein#util#_convert2list(a:expr)
        \ ->filter({ _, val -> val !=# '' })
        \ ->map({ _, val -> '[dein] ' ..  val })
  if msg->empty()
    return
  endif

  const more_save = &more
  const showcmd_save = &showcmd
  const ruler_save = &ruler
  try
    set nomore
    set noshowcmd
    set noruler

    const height = [1, &cmdheight]->max()
    echo ''
    for i in range(0, msg->len() - 1, height)
      redraw

      let m = msg[i : i+height-1]->join("\n")
      call s:echo_mode(m, a:mode)
      if has('vim_starting')
        echo ''
      endif
    endfor
  finally
    let &more = more_save
    let &showcmd = showcmd_save
    let &ruler = ruler_save
  endtry
endfunction
function! s:echo_mode(m, mode) abort
  for m in a:m->split('\r\?\n', 1)
    if !has('vim_starting') && a:mode !=# 'error'
      let m = s:truncate_skipping(m, &columns - 1, &columns/3, '...')
    endif

    if a:mode ==# 'error'
      echohl WarningMsg | echomsg m | echohl None
    elseif a:mode ==# 'echomsg'
      echomsg m
    else
      echo m
    endif
  endfor
endfunction

function! s:truncate_skipping(str, max, footer_width, separator) abort
  const width = a:str->strwidth()
  if width <= a:max
    const ret = a:str
  else
    const header_width = a:max - a:separator->strwidth() - a:footer_width
    const ret = s:strwidthpart(a:str, header_width) .. a:separator
          \ .. s:strwidthpart_reverse(a:str, a:footer_width)
  endif

  return ret
endfunction
function! s:strwidthpart(str, width) abort
  if a:width <= 0
    return ''
  endif
  let ret = a:str
  let width = a:str->strwidth()
  while width > a:width
    let char = ret->matchstr('.$')
    let ret = ret[: -1 - char->len()]
    let width -= char->strwidth()
  endwhile

  return ret
endfunction
function! s:strwidthpart_reverse(str, width) abort
  if a:width <= 0
    return ''
  endif
  let ret = a:str
  let width = a:str->strwidth()
  while width > a:width
    let char = ret->matchstr('^.')
    let ret = ret[char->len() :]
    let width -= char->strwidth()
  endwhile

  return ret
endfunction
