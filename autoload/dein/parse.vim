" Global options definition."
let g:dein#enable_name_conversion =
      \ g:->get('dein#enable_name_conversion', v:false)
let g:dein#default_options =
      \ g:->get('dein#default_options', {})


let s:git = dein#types#git#define()

function! dein#parse#_add(repo, options, overwrite) abort
  let plugin = dein#parse#_dict(dein#parse#_init(a:repo, a:options))
  const plugin_check = g:dein#_plugins->get(plugin.name, {})
  const overwrite = a:options->get('overwrite', a:overwrite)
  if plugin_check->get('sourced', 0)
    " Skip already loaded plugin.
    return {}
  endif

  " Duplicated plugins check
  if !(plugin_check->empty())
    if !overwrite
      if has('vim_starting')
        " Only warning when starting
        call dein#util#_error(printf(
              \ 'Plugin name "%s" is already defined.', plugin.name))
      endif
      return {}
    endif

    " Overwrite
    " NOTE: reparse is needed.
    let options = a:options->extend(
          \ g:dein#_plugins[plugin.name]->get('orig_opts', {}), 'keep')
    let plugin = dein#parse#_dict(dein#parse#_init(a:repo, options))
  endif

  let g:dein#_plugins[plugin.name] = plugin

  if plugin.rtp !=# ''
    if plugin.lazy
      call s:parse_lazy(plugin)
    endif

    " Convert lua_xxx keys
    for [key, val] in plugin->items()->filter({ _, v -> v[0] =~# '^lua_' })
      let hook_key = key->substitute('^lua_', 'hook_', '')
      let plugin[hook_key] = printf(
            \ "lua <<EOF\n%s\nEOF\n%s", val, plugin->get(hook_key, ''))
    endfor

    if plugin->has_key('hook_add')
      call dein#util#_call_hook('add', plugin)
    endif
    if plugin->has_key('ftplugin')
      call s:merge_ftplugin(plugin.ftplugin)
    endif
  endif

  return plugin
endfunction
function! dein#parse#_init(repo, options) abort
  const repo = dein#util#_expand(a:repo)
  let plugin = a:options->has_key('type') ?
        \ dein#util#_get_type(a:options.type).init(repo, a:options) :
        \ s:git.init(repo, a:options)
  if plugin->empty()
    let plugin = s:check_type(repo, a:options)
  endif
  call extend(plugin, a:options)
  if !(g:dein#default_options->empty())
    call extend(plugin, g:dein#default_options, 'keep')
  endif
  let plugin.repo = repo
  if !(a:options->empty())
    let plugin.orig_opts = a:options->deepcopy()
  endif
  return plugin
endfunction
function! dein#parse#_dict(plugin) abort
  let plugin = #{
        \   rtp: '',
        \   sourced: 0,
        \ }
  call extend(plugin, a:plugin)

  if !(plugin->has_key('name'))
    let plugin.name = dein#parse#_name_conversion(plugin.repo)
  endif

  if !(plugin->has_key('normalized_name'))
    let plugin.normalized_name = plugin.name->fnamemodify(':r')->substitute(
          \ '\c^\%(n\?vim\|dps\|denops\)[_-]\|[_-]n\?vim$', '', 'g')
  endif

  if !(a:plugin->has_key('name')) && g:dein#enable_name_conversion
    " Use normalized name.
    let plugin.name = plugin.normalized_name
  endif

  if !(plugin->has_key('path'))
    let plugin.path = (plugin.repo =~# '^/\|^\a:[/\\]') ?
          \ plugin.repo : dein#util#_get_base_path().'/repos/'.plugin.name
  endif

  let plugin.path = dein#util#_chomp(dein#util#_expand(plugin.path))
  if plugin->get('rev', '') !=# ''
    " Add revision path
    let plugin.path ..= '_' .. plugin.rev->substitute(
          \ '[^[:alnum:].-]', '_', 'g')
  endif

  " Check relative path
  if (!(a:plugin->has_key('rtp')) || a:plugin.rtp !=# '')
        \ && plugin.rtp !~# '^\%([~/]\|\a\+:\)'
    let plugin.rtp = plugin.path.'/'.plugin.rtp
  endif
  if plugin.rtp[0:] ==# '~'
    let plugin.rtp = dein#util#_expand(plugin.rtp)
  endif
  let plugin.rtp = dein#util#_chomp(plugin.rtp)
  if g:dein#_is_sudo && !(plugin->get('trusted', 0))
    let plugin.rtp = ''
  endif

  if plugin->has_key('script_type')
    " Add script_type.
    let plugin.path ..= '/' .. plugin.script_type
  endif

  if plugin->has_key('depends') && plugin.depends->type() != v:t_list
    let plugin.depends = [plugin.depends]
  endif

  " Deprecated check.
  for key in ['directory', 'base']
        \ ->filter({ _, val -> plugin->has_key(val) })
    call dein#util#_error('plugin name = ' .. plugin.name)
    call dein#util#_error(key->string() .. ' is deprecated.')
  endfor

  if !(plugin->has_key('lazy'))
    let plugin.lazy =
          \    plugin->has_key('on_ft')
          \ || plugin->has_key('on_cmd')
          \ || plugin->has_key('on_func')
          \ || plugin->has_key('on_lua')
          \ || plugin->has_key('on_map')
          \ || plugin->has_key('on_path')
          \ || plugin->has_key('on_if')
          \ || plugin->has_key('on_event')
          \ || plugin->has_key('on_source')
  endif

  if !(a:plugin->has_key('merged'))
    let plugin.merged = !plugin.lazy
          \ && plugin.normalized_name !=# 'dein'
          \ && !(plugin->has_key('local'))
          \ && !(plugin->has_key('build'))
          \ && !(plugin->has_key('if'))
          \ && !(plugin->has_key('hook_post_update'))
          \ && plugin.rtp->stridx(dein#util#_get_base_path()) == 0
  endif

  const hooks_file = dein#util#_expand(get(plugin, 'hooks_file', ''))
  if hooks_file->filereadable()
    call extend(plugin, dein#parse#_hooks_file(hooks_file))
  endif

  " Hooks
  for hook in [
        \ 'hook_add', 'hook_source',
        \ 'hook_post_source', 'hook_post_update',
        \ ]->filter({ _, val -> plugin->has_key(val)
        \                && plugin[val]->type() == v:t_string })
    " NOTE: line continuation must be converted.
    " execute() does not support it.
    let plugin[hook] = plugin[hook]->substitute('\n\s*\\', '', 'g')
  endfor

  return plugin
endfunction
function! dein#parse#_load_toml(filename, default) abort
  try
    let toml = dein#toml#parse_file(dein#util#_expand(a:filename))
  catch /Text.TOML:/
    call dein#util#_error('Invalid toml format: ' .. a:filename)
    call dein#util#_error(v:exception)
    return 1
  endtry
  if toml->type() != v:t_dict
    call dein#util#_error('Invalid toml file: ' .. a:filename)
    return 1
  endif

  " Parse.
  if toml->has_key('lua_add')
    let g:dein#_hook_add ..= printf("\nlua <<EOF\n%s\nEOF", toml.lua_add)
  endif
  if toml->has_key('hook_add')
    let g:dein#_hook_add ..= printf("\n%s",
          \   toml.hook_add->substitute('\n\s*\\', '', 'g'),
          \ )
  endif
  if toml->has_key('ftplugin')
    call s:merge_ftplugin(toml.ftplugin)
  endif
  if toml->has_key('multiple_plugins')
    for multi in toml.multiple_plugins
      if !(multi->has_key('plugins'))
        call dein#util#_error('Invalid multiple_plugins: ' .. a:filename)
        return 1
      endif

      call add(g:dein#_multiple_plugins, multi)
    endfor
  endif

  if toml->has_key('plugins')
    for plugin in toml.plugins
      if !(plugin->has_key('repo'))
        call dein#util#_error('No repository plugin data: ' .. a:filename)
        return 1
      endif

      let options = extend(plugin, a:default, 'keep')
      call dein#add(plugin.repo, options)
    endfor
  endif

  " Add to g:dein#_vimrcs
  call add(g:dein#_vimrcs, dein#util#_expand(a:filename))
endfunction
function! dein#parse#_plugins2toml(plugins) abort
  let toml = []

  let default = dein#parse#_dict(dein#parse#_init('', {}))
  let default.if = ''
  let default.frozen = 0
  let default.local = 0
  let default.depends = []
  let default.on_ft = []
  let default.on_cmd = []
  let default.on_func = []
  let default.on_lua = []
  let default.on_map = []
  let default.on_path = []
  let default.on_source = []
  let default.build = ''
  let default.hook_add = ''
  let default.hook_source = ''
  let default.hook_post_source = ''
  let default.hook_post_update = ''

  let skip_default = #{
        \   type: 1,
        \   path: 1,
        \   rtp: 1,
        \   sourced: 1,
        \   orig_opts: 1,
        \   repo: 1,
        \ }

  for plugin in a:plugins->sort(
        \ { a, b -> a.repo ==# b.repo ? 0 : a.repo ># b.repo ? 1 : -1 })
    let toml += ['[[plugins]]',
          \ 'repo = ' .. plugin.repo->string()]

    for key in default->keys()->sort()
          \ ->filter({ _, val ->
          \          !(skip_default->has_key(val)) && plugin->has_key(val)
          \          && (plugin[val]->type() !=# default[val]->type()
          \              || plugin[val] !=# default[val])
          \ })
      let val = plugin[key]
      if key =~# '^hook_'
        call add(toml, key .. " = '''")
        let toml += val->split('\n')
        call add(toml, "'''")
      else
        call add(toml, key .. ' = '
              \ .. (val->type() == v:t_list
              \     && val->len() == 1 ? val[0] : val)->string())
      endif
      unlet! val
    endfor

    call add(toml, '')
  endfor

  return toml
endfunction
function! dein#parse#_load_dict(dict, default) abort
  for [repo, options] in a:dict->items()
    call dein#add(repo, options->copy()->extend(a:default, 'keep'))
  endfor
endfunction
function! dein#parse#_local(localdir, options, includes) abort
  const base = fnamemodify(dein#util#_expand(a:localdir), ':p')
  let directories = []
  for glob in a:includes
    let directories += (base .. glob)->glob(v:true, v:true)
          \ ->filter({ _, val -> val->isdirectory() })
          \ ->map({ _, val -> dein#util#_substitute_path(
          \       val->fnamemodify(':p'))->substitute('/$', '', '')
          \ })
  endfor

  for dir in dein#util#_uniq(directories)
    let options = extend({
          \ 'repo': dir, 'local': 1, 'path': dir,
          \ 'name': dir->fnamemodify(':t')
          \ }, a:options)

    if g:dein#_plugins->has_key(options.name)
      call dein#config(options.name, options)
    else
      call dein#parse#_add(dir, options, v:true)
    endif
  endfor
endfunction
function! s:parse_lazy(plugin) abort
  " Auto convert2list.
  for key in [
        \ 'on_ft', 'on_path', 'on_cmd', 'on_func', 'on_map',
        \ 'on_lua', 'on_source', 'on_event',
        \ ]->filter({ _, val -> a:plugin->has_key(val)
        \     && a:plugin[val]->type() != v:t_list
        \     && a:plugin[val]->type() != v:t_dict })
    let a:plugin[key] = [a:plugin[key]]
  endfor

  if a:plugin->has_key('on_event')
    for event in a:plugin.on_event
      if !(g:dein#_event_plugins->has_key(event))
        let g:dein#_event_plugins[event] = [a:plugin.name]
      else
        call add(g:dein#_event_plugins[event], a:plugin.name)
        let g:dein#_event_plugins[event] = dein#util#_uniq(
              \ g:dein#_event_plugins[event])
      endif
    endfor
  endif

  if a:plugin->has_key('on_cmd')
    call s:generate_dummy_commands(a:plugin)
  endif
  if a:plugin->has_key('on_map')
    call s:generate_dummy_mappings(a:plugin)
  endif

  if a:plugin->has_key('on_lua')
    " NOTE: Use module root
    for mod in a:plugin.on_lua->map({ _, val -> val->matchstr('^[^./]\+') })
      let g:dein#_on_lua_plugins[mod] = v:true
    endfor
  endif
endfunction
function! s:generate_dummy_commands(plugin) abort
  let a:plugin.dummy_commands = []
  for name in a:plugin.on_cmd
    " Define dummy commands.
    let raw_cmd = 'command '
          \ .. '-complete=customlist,dein#autoload#_dummy_complete'
          \ .. ' -bang -bar -range -nargs=* '. name
          \ .. printf(" call dein#autoload#_on_cmd(%s, %s, <q-args>,
          \  '<bang>'->expand(), '<line1>'->expand(), '<line2>'->expand())",
          \   name->string(), a:plugin.name->string())

    call add(a:plugin.dummy_commands, [name, raw_cmd])
    silent! execute raw_cmd
  endfor
endfunction
function! s:generate_dummy_mappings(plugin) abort
  let a:plugin.dummy_mappings = []
  let items = a:plugin.on_map->type() == v:t_dict ?
        \ a:plugin.on_map->items()
        \ ->map({ _, val -> [val[0]->split('\zs'),
        \       dein#util#_convert2list(val[1])]}) :
        \ a:plugin.on_map->copy()
        \ ->map({ _, val -> type(val) == v:t_list ?
        \       [val[0]->split('\zs'), val[1:]] :
        \       [['n', 'x', 'o'], [val]]
        \  })
  for [modes, mappings] in items
    if mappings ==# ['<Plug>']
      " Use plugin name.
      let mappings = ['<Plug>(' .. a:plugin.normalized_name]
      if a:plugin.normalized_name->stridx('-') >= 0
        " The plugin mappings may use "_" instead of "-".
        call add(mappings, '<Plug>('
              \ .. a:plugin.normalized_name->substitute('-', '_', 'g'))
      endif
    endif

    for mapping in mappings
      " Define dummy mappings.
      let prefix = printf('dein#autoload#_on_map(%s, %s,',
            \ mapping->substitute('<', '<lt>', 'g')->string(),
            \ a:plugin.name->string())
      for mode in modes
        let raw_map = mode.'noremap <unique><silent> '.mapping
              \ .. (mode ==# 'c' ? " \<C-r>=" :
              \    mode ==# 'i' ? " \<C-o>:call " : " :\<C-u>call ")
              \ .. prefix .. mode->string() .. ')<CR>'
        call add(a:plugin.dummy_mappings, [mode, mapping, raw_map])
        silent! execute raw_map
      endfor
    endfor
  endfor
endfunction
function! s:merge_ftplugin(ftplugin) abort
  const pattern = '\n\s*\\\|\%(^\|\n\)\s*"[^\n]*'
  for [ft, val] in a:ftplugin->items()
    if ft->stridx('lua_') == 0
      " Convert lua_xxx keys
      let ft = ft->substitute('^lua_', '', '')
      let val = "lua <<EOF\n" .. val .. "\nEOF"
    endif

    if !(g:dein#ftplugin->has_key(ft))
      let g:dein#ftplugin[ft] = val
    else
      let g:dein#ftplugin[ft] ..= "\n" .. val
    endif
  endfor
  call map(g:dein#ftplugin, { _, val -> val->substitute(pattern, '', 'g') })
endfunction

function! dein#parse#_get_types() abort
  if !('s:types'->exists())
    " Load types.
    let s:types = {}
    for type in 'autoload/dein/types/*.vim'
          \ ->globpath(&runtimepath, v:true, v:true)
          \ ->map({ _, val -> dein#types#{val->fnamemodify(':t:r')}#define()})
          \ ->filter({ _, val -> !(val->empty()) })
      let s:types[type.name] = type
    endfor
  endif
  return s:types
endfunction
function! s:check_type(repo, options) abort
  let plugin = {}
  for type in dein#parse#_get_types()->values()
    let plugin = type.init(a:repo, a:options)
    if !(plugin->empty())
      break
    endif
  endfor

  if plugin->empty()
    let plugin.type = 'none'
    let plugin.local = 1
    let plugin.path = a:repo->isdirectory() ? a:repo : ''
  endif

  return plugin
endfunction

function! dein#parse#_name_conversion(path) abort
  return a:path->split(':')->get(-1, '')
        \ ->fnamemodify(':s?/$??:t:s?\c\.git\s*$??')
endfunction

function! dein#parse#_hooks_file(filename) abort
  let start_marker = &l:foldmarker->split(',')[0]
  let end_marker = &l:foldmarker->split(',')[1]
  let hook_name = ''
  let options = {}

  for line in a:filename->readfile()
    if hook_name ==# ''
      let marker_pos = strridx(line, start_marker)
      if strridx(line, start_marker) < 0
        continue
      endif

      " Get hook_name
      let hook_name = line[: marker_pos]->matchstr(
            \ '\s\+\zs[[:alnum:]_-]\+\ze\s*')
      if hook_name == ''
        call dein#util#_error(
              \ printf('Invalid hook name %s: %s', a:filename, line))
        return {}
      endif
      if hook_name->stridx('hook_') == 0 || hook_name->stridx('lua_') == 0
        let dest = options
      else
        if !(options->has_key('ftplugin'))
          let options['ftplugin'] = {}
        endif
        let dest = options['ftplugin']
      endif
    else
      if strridx(line, end_marker) >= 0
        let hook_name = ''
        continue
      endif

      " Concat
      if dest->has_key(hook_name)
        let dest[hook_name] ..= "\n" .. line
      else
        let dest[hook_name] = line
      endif
    endif
  endfor

  " Add to g:dein#_vimrcs
  call add(g:dein#_vimrcs, a:filename)

  return options
endfunction
