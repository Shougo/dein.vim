function! dein#min#_init() abort
  let g:dein#name = ''
  let g:dein#plugin = {}
  let g:dein#ftplugin = {}
  let g:dein#_cache_version = 420
  let g:dein#_plugins = {}
  let g:dein#_multiple_plugins = []
  let g:dein#_base_path = ''
  let g:dein#_cache_path = ''
  let g:dein#_runtime_path = ''
  let g:dein#_hook_add = ''
  let g:dein#_called_lua = {}
  let g:dein#_off1 = ''
  let g:dein#_off2 = ''
  let g:dein#_vimrcs = []
  let g:dein#_block_level = 0
  let g:dein#_event_plugins = {}
  let g:dein#_on_lua_plugins = {}
  let g:dein#_is_sudo = $SUDO_USER !=# '' && $USER !=# $SUDO_USER
        \ && $HOME !=# ('~'.$USER)->expand()
        \ && $HOME ==# ('~'.$SUDO_USER)->expand()
  let g:dein#_progname = has('nvim') && exists('$NVIM_APPNAME') ?
        \ $NVIM_APPNAME : v:progname->fnamemodify(':r')
  let g:dein#_init_runtimepath = &runtimepath
  let g:dein#_loaded_rplugins = v:false

  if g:->get('dein#lazy_rplugins', v:false)
    " Disable remote plugin loading
    let g:loaded_remote_plugins = 1
  endif

  augroup dein
    autocmd!
    autocmd FuncUndefined *
          \ if '<afile>'->expand()->stridx('remote#') != 0 |
          \   call dein#autoload#_on_func('<afile>'->expand()) |
          \ endif
    autocmd BufRead *? call dein#autoload#_on_default_event('BufRead')
    autocmd BufNew,BufNewFile *? call dein#autoload#_on_default_event('BufNew')
    autocmd VimEnter *? call dein#autoload#_on_default_event('VimEnter')
    autocmd FileType *? call dein#autoload#_on_default_event('FileType')
    autocmd BufWritePost *.lua,*.vim,*.toml,vimrc,.vimrc
          \ call dein#util#_check_vimrcs()
    autocmd CmdUndefined * call dein#autoload#_on_pre_cmd('<afile>'->expand())
  augroup END
  augroup dein-events | augroup END

  if !has('nvim') | return | endif
  lua <<END
table.insert(package.loaders, 1, (function()
  return function(mod_name)
    mod_root = string.match(mod_name, '^[^./]+')
    if vim.g['dein#_on_lua_plugins'][mod_root] then
      vim.fn['dein#autoload#_on_lua'](mod_name)
    end
    -- NOTE: If loaded module at hook, must return loaded module at this point.
    -- because native loaded check was skipped.
    if package.loaded[mod_name] ~= nil then
      local m = package.loaded[mod_name]
      return function()
        return m
      end
    end
    return nil
  end
end)())
END
endfunction
function! dein#min#_load_cache_raw(vimrcs) abort
  let g:dein#_vimrcs = a:vimrcs
  const cache = g:->get('dein#cache_directory', g:dein#_base_path)
        \ .. '/cache_' .. g:dein#_progname
  const time = cache->getftime()
  if !(g:dein#_vimrcs->copy()
        \ ->map({ _, val -> getftime(expand(val)) })
        \ ->filter({ _, val -> time < val })->empty())
    return [{}, {}]
  endif
  return has('nvim') ? cache->readfile()->json_decode()
        \ : cache->readfile()[0]->js_decode()
endfunction
function! dein#min#load_state(path) abort
  if !('#dein'->exists())
    call dein#min#_init()
  endif
  if g:dein#_is_sudo | return 1 | endif
  let g:dein#_base_path = a:path->expand()

  const state = g:->get('dein#cache_directory', g:dein#_base_path)
        \ .. '/state_' .. g:dein#_progname .. '.vim'
  if !(state->filereadable()) | return 1 | endif
  try
    execute 'source' state->fnameescape()
  catch
    if v:exception !=# 'Cache loading error'
      call dein#util#_error('Loading state error: ' .. v:exception)
    endif
    call dein#clear_state()
    return 1
  endtry
endfunction
