" set verbose=1

let s:suite = themis#suite('parse')
let s:assert = themis#helper('assert')

let s:path = tempname()

function! s:suite.before_each() abort "{{{
  call dein#_init()
endfunction"}}}

function! s:suite.after_each() abort "{{{
endfunction"}}}

function! s:suite.parse_dict() abort "{{{
  call dein#begin(s:path)

  let plugin = {'name': 'baz'}
  let parsed_plugin = dein#parse#_dict(plugin)
  call s:assert.equals(parsed_plugin.name, 'baz')

  let plugin = {'name': 'baz'}
  let parsed_plugin = dein#parse#_dict(plugin)
  call s:assert.equals(parsed_plugin.rtp, s:path.'/repos/baz')
  call s:assert.equals(parsed_plugin.path, s:path.'/repos/baz')

  let plugin = {'name': 'baz', 'rev': 'bar'}
  let parsed_plugin = dein#parse#_dict(plugin)
  call s:assert.equals(parsed_plugin.rtp, s:path.'/repos/baz_bar')
  call s:assert.equals(parsed_plugin.path, s:path.'/repos/baz_bar')

  let plugin = {'name': 'baz', 'if': '1'}
  let parsed_plugin = dein#parse#_dict(plugin)
  call s:assert.equals(parsed_plugin.merged, 0)

  call dein#end()
endfunction"}}}

function! s:suite.name_conversion() abort "{{{
  let g:dein#enable_name_conversion = 1

  let plugin = dein#parse#_dict({'repo':
        \ 'https://github.com/Shougo/dein.vim.git'})
  call s:assert.equals(plugin.name, 'dein')

  let plugin = dein#parse#_dict({'repo':
        \ 'https://bitbucket.org/kh3phr3n/vim-qt-syntax.git'})
  call s:assert.equals(plugin.name, 'qt-syntax')

  let plugin = dein#parse#_dict({'repo':
        \ 'https://bitbucket.org/kh3phr3n/qt-syntax-vim.git'})
  call s:assert.equals(plugin.name, 'qt-syntax')

  let plugin = dein#parse#_dict({'repo':
        \ 'https://bitbucket.org/kh3phr3n/vim-qt-syntax.git',
        \ 'name': 'vim-qt-syntax'})
  call s:assert.equals(plugin.name, 'vim-qt-syntax')

  let g:dein#enable_name_conversion = 0
endfunction"}}}

function! s:suite.load_toml() abort "{{{
  let toml = tempname()
  call writefile([
        \ '# TOML sample',
        \ 'hook_add = "let g:foo = 0"',
        \ '',
        \ '[ftplugin]',
        \ 'c = "let g:bar = 0"',
        \ '',
        \ '[[plugins]]',
        \ '# repository name is required.',
        \ "repo = 'kana/vim-niceblock'",
        \ "on_map = '<Plug>'",
        \ '[[plugins]]',
        \ "repo = 'Shougo/neosnippet.vim'",
        \ 'on_i = 1',
        \ "on_ft = 'snippet'",
        \ "hook_add = '''",
        \ '"echo',
        \ '"comment',
        \ "echo",
        \ "'''",
        \ "hook_source = '''",
        \ "echo",
        \ '\',
        \ "echo",
        \ "'''",
        \ ], toml)

  call dein#begin(s:path)
  call s:assert.equals(g:dein#_hook_add, '')
  call s:assert.equals(g:dein#_ftplugin, {})
  call s:assert.equals(dein#load_toml(toml), 0)
  call s:assert.equals(g:dein#_hook_add, "\nlet g:foo = 0")
  call s:assert.equals(g:dein#_ftplugin, {'c': 'let g:bar = 0'})
  call dein#end()

  call s:assert.equals(dein#get('neosnippet.vim').on_i, 1)
  call s:assert.equals(dein#get('neosnippet.vim').hook_add,
        \ "\necho\n")
  call s:assert.equals(dein#get('neosnippet.vim').hook_source,
        \ "echo\necho\n")
endfunction"}}}

function! s:suite.error_toml() abort "{{{
  let toml = tempname()
  call writefile([
        \ '# TOML sample',
        \ '[[plugins]]',
        \ '# repository name is required.',
        \ "on_map = '<Plug>'",
        \ '[[plugins]]',
        \ 'on_i = 1',
        \ "on_ft = 'snippet'",
        \ ], toml)

  call dein#begin(s:path)
  call s:assert.equals(dein#load_toml(toml), 1)
  call dein#end()
endfunction"}}}

function! s:suite.load_dict() abort "{{{
  call dein#begin(s:path)
  call s:assert.equals(dein#load_dict({
        \ 'Shougo/unite.vim': {},
        \ 'Shougo/neocomplete.vim': {'name': 'neocomplete'}
        \ }, {'lazy': 1}), 0)
  call dein#end()

  call s:assert.not_equals(dein#get('unite.vim'), {})
  call s:assert.equals(dein#get('neocomplete').lazy, 1)
endfunction"}}}

function! s:suite.plugins2toml() abort "{{{
  let parsed_plugin = dein#parse#_init('Shougo/unite.vim', {})
  let parsed_plugin2 = dein#parse#_init('Shougo/deoplete.nvim',
        \ {'on_ft': ['vim'], 'hook_add': "hoge\npiyo"})
  call s:assert.equals(dein#plugins2toml(
        \ [parsed_plugin, parsed_plugin2]), [
        \ "[[plugins]]",
        \ "repo = 'Shougo/deoplete.nvim'",
        \ "hook_add = '''",
        \ "hoge",
        \ "piyo",
        \ "'''",
        \ "on_ft = 'vim'",
        \ "",
        \ "[[plugins]]",
        \ "repo = 'Shougo/unite.vim'",
        \ "",
        \ ])
endfunction"}}}

" vim:foldmethod=marker:fen:
