" set verbose=1

const s:suite = themis#suite('parse')
const s:assert = themis#helper('assert')

const s:path = tempname()

function! s:suite.before_each() abort
  call dein#min#_init()
endfunction

function! s:suite.after_each() abort
endfunction

function! s:suite.parse_dict() abort
  call dein#begin(s:path)

  let plugin = #{ name: 'baz' }
  let parsed_plugin = dein#parse#_dict(dein#parse#_init('', plugin))
  call s:assert.equals(parsed_plugin.name, 'baz')

  let plugin = #{ name: 'baz', if: '1' }
  let parsed_plugin = dein#parse#_dict(dein#parse#_init('', plugin))
  call s:assert.equals(parsed_plugin.merged, 0)

  let plugin = #{ name: 'baz', rev: 'foo' }
  let parsed_plugin = dein#parse#_dict(dein#parse#_init('foo', plugin))
  call s:assert.equals(parsed_plugin.path, '_foo')

  let plugin = #{ name: 'baz', rev: 'foo/bar' }
  let parsed_plugin = dein#parse#_dict(dein#parse#_init('foo', plugin))
  call s:assert.equals(parsed_plugin.path, '_foo_bar')

  let $BAZDIR = '/baz'
  const repo = '$BAZDIR/foo'
  let plugin = #{ repo: repo }
  let parsed_plugin = dein#parse#_dict(dein#parse#_init(repo, plugin))
  call s:assert.equals(parsed_plugin.repo, '/baz/foo')

  call dein#end()
endfunction

function! s:suite.name_conversion() abort
  let g:dein#enable_name_conversion = v:true

  let plugin = dein#parse#_dict(
        \ #{ repo: 'https://github.com/Shougo/dein.vim.git' })
  call s:assert.equals(plugin.name, 'dein')

  let plugin = dein#parse#_dict(
        \ #{ repo: 'https://bitbucket.org/kh3phr3n/vim-qt-syntax.git' })
  call s:assert.equals(plugin.name, 'qt-syntax')

  let plugin = dein#parse#_dict(
        \ #{ repo: 'https://bitbucket.org/kh3phr3n/qt-syntax-vim.git' })
  call s:assert.equals(plugin.name, 'qt-syntax')

  let plugin = dein#parse#_dict(#{
        \   repo: 'https://bitbucket.org/kh3phr3n/vim-qt-syntax.git',
        \   name: 'vim-qt-syntax',
        \ })
  call s:assert.equals(plugin.name, 'vim-qt-syntax')

  let g:dein#enable_name_conversion = v:false
endfunction

function! s:suite.load_toml() abort
  const filename = tempname()
  let toml =<< trim END
    # TOML sample
    lua_add = "foo"

    hook_add = "let g:foo = 0"
    [ftplugin]
    c = """
    let g:bar = 0
    " Comment line"""
    lua_d = """
    foo = 0
    -- Comment line"""

    [[plugins]]
    # repository name is required.
    repo = 'Shougo/denite.nvim'
    on_map = '<Plug>'
    [[plugins]]
    repo = 'Shougo/neosnippet.vim'
    on_ft = 'snippet'
    hook_add = '''
    echo
    "comment
    echo
    '''
    hook_source = '''
    echo
          \
    echo
    '''
    lua_source = '''
    foo
    bar
    '''
    [plugins.ftplugin]
    c = "let g:bar = 0"
    lua_cpp = "bar = 0"
    [[multiple_plugins]]
    plugins = ['foo', 'bar']
    hook_add = 'foo'
  END

  call writefile(toml, filename)

  call dein#begin(s:path)
  call s:assert.equals(g:dein#_hook_add, '')
  call s:assert.equals(g:dein#ftplugin, {})
  call s:assert.equals(dein#load_toml(filename), 0)
  call s:assert.equals(g:dein#_hook_add,
        \ "\nlua <<EOF\nfoo\nEOF\nlet g:foo = 0")
  call s:assert.equals(g:dein#ftplugin, #{
        \   c: "let g:bar = 0\n\" Comment line\nlet g:bar = 0",
        \   cpp: "lua <<EOF\nbar = 0\nEOF",
        \   d: "lua <<EOF\nfoo = 0\n-- Comment line\nEOF",
        \ })
  call s:assert.equals(g:dein#_multiple_plugins, [
        \   #{ plugins: ['foo', 'bar'], hook_add: 'foo' },
        \ ])
  call dein#end()

  call s:assert.equals(dein#get('neosnippet.vim').hook_add,
        \ "echo\n\"comment\necho\n")
  call s:assert.equals(dein#get('neosnippet.vim').hook_source,
        \ "lua <<EOF\nfoo\nbar\n\nEOF\necho\necho\n")
endfunction

function! s:suite.error_toml() abort
  const filename = tempname()
  let toml =<< trim END
    # TOML sample
    [[plugins]]
    # repository name is required.
    on_map = '<Plug>'
    [[plugins]]
    on_ft = 'snippet'
  END

  call writefile(toml, filename)

  call dein#begin(s:path)
  call s:assert.equals(dein#load_toml(filename), 1)
  call dein#end()
endfunction

function! s:suite.load_dict() abort
  call dein#begin(s:path)
  call s:assert.equals(dein#load_dict({
        \ 'Shougo/denite.nvim': {},
        \ 'Shougo/deoplete.nvim': #{ name: 'deoplete' }
        \ }, #{ lazy: 1 }), 0)
  call dein#end()

  call s:assert.not_equals(dein#get('denite.nvim'), {})
  call s:assert.equals(dein#get('deoplete').lazy, 1)
endfunction

function! s:suite.disable() abort
  call dein#begin(s:path)
  call dein#load_dict({
        \ 'Shougo/denite.nvim': #{ on_cmd: 'Unite' }
        \ })
  call s:assert.false(!exists(':Unite'))
  call dein#disable('denite.nvim')
  call s:assert.false(exists(':Unite'))
  call dein#end()

  call s:assert.equals(dein#get('denite.nvim'), {})
endfunction

function! s:suite.config() abort
  call dein#begin(s:path)
  call dein#load_dict({
        \ 'Shougo/denite.nvim': {}
        \ })
  let g:dein#name = 'denite.nvim'
  call dein#config(#{ on_event: ['InsertEnter'] })
  call dein#end()
  call dein#config('unite', #{ on_event: ['InsertEnter'] })

  call s:assert.equals(dein#get('denite.nvim').on_event, ['InsertEnter'])
endfunction

function! s:suite.skip_overwrite() abort
  call dein#begin(s:path)
  call dein#add('Shougo/denite.nvim', #{ on_event: [] })
  call dein#add('Shougo/denite.nvim', #{ on_event: ['InsertEnter'] })
  call dein#end()

  call s:assert.equals(dein#get('denite.nvim').on_event, [])
endfunction

function! s:suite.overwrite() abort
  call dein#begin(s:path)
  call dein#add('Shougo/denite.nvim', #{ on_event: [] })
  call dein#add('Shougo/denite.nvim', #{
        \   on_event: ['InsertEnter'],
        \   overwrite: 1,
        \ })
  call dein#end()

  call s:assert.equals(dein#get('denite.nvim').on_event, ['InsertEnter'])
endfunction

function! s:suite.plugins2toml() abort
  const parsed_plugin = dein#parse#_init('Shougo/denite.nvim', {})
  const parsed_plugin2 = dein#parse#_init('Shougo/deoplete.nvim',
        \ #{ on_ft: ['vim'], hook_add: "hoge\npiyo" })
  const parsed_plugin3 = dein#parse#_init('Shougo/deoppet.nvim',
        \ #{ on_map: #{ n: ['a', 'b'] } })
  call s:assert.equals(dein#plugins2toml(
        \ [parsed_plugin, parsed_plugin2, parsed_plugin3]), [
        \ "[[plugins]]",
        \ "repo = 'Shougo/denite.nvim'",
        \ "",
        \ "[[plugins]]",
        \ "repo = 'Shougo/deoplete.nvim'",
        \ "hook_add = '''",
        \ "hoge",
        \ "piyo",
        \ "'''",
        \ "on_ft = 'vim'",
        \ "",
        \ "[[plugins]]",
        \ "repo = 'Shougo/deoppet.nvim'",
        \ "on_map = {'n': ['a', 'b']}",
        \ "",
        \ ])
endfunction

function! s:suite.trusted() abort
  const sudo = g:dein#_is_sudo
  let g:dein#_is_sudo = 1

  let parsed_plugin = dein#parse#_add(
        \ 'Shougo/deoplete.nvim', {}, v:false)
  call s:assert.equals(parsed_plugin.rtp, '')

  let parsed_plugin = dein#parse#_add(
        \ 'Shougo/denite.nvim', #{ trusted: 1 }, v:false)
  call s:assert.not_equals(parsed_plugin.rtp, '')

  let g:dein#_is_sudo = sudo
endfunction

function! s:suite.hooks_file() abort
  const filename = tempname()
  let hooks_file =<< trim END
    " hook_add {{{
    hoge
    }}}
    " hook_source {{{
    piyo
    }}}
  END

  call writefile(hooks_file, filename)

  call s:assert.equals(dein#parse#_hooks_file(filename), #{
        \   hook_add : 'hoge',
        \   hook_source : 'piyo',
        \ })

  let hooks_file =<< trim END
    " c {{{
    hogera
    }}}
    " hook_source {{{
    piyo
    }}}
  END

  call writefile(hooks_file, filename)

  call s:assert.equals(dein#parse#_hooks_file(filename), #{
        \   hook_source : 'piyo',
        \   ftplugin: #{ c: 'hogera' },
        \ })

  " Invalid line
  let hooks_file =<< trim END
    " {{{
    hogera
    }}}
    " hook_source {{{
    piyo
    }}}
  END

  call writefile(hooks_file, filename)

  call s:assert.equals(dein#parse#_hooks_file(filename), #{
        \   hook_source: 'piyo',
        \ })

  let hooks_file =<< trim END
    " hook_source {{{
    piyo
    " {{{
    hogera
    " }}}
    " }}}
  END

  call writefile(hooks_file, filename)

  call s:assert.equals(dein#parse#_hooks_file(filename), #{
        \   hook_source: "piyo\n" . '" {{{' . "\n" . 'hogera' . "\n" . '" }}}',
        \ })

  let hooks_file =<< trim END
    -- lua_source {{{
    piyo
    -- }}}
  END
  call writefile(hooks_file, filename)

  call dein#begin(s:path)
  call dein#add('Shougo/ddc.vim', #{ hooks_file: filename })
  call dein#end()

  call s:assert.equals(dein#get('ddc.vim').hook_source,
        \ "lua <<EOF\npiyo\nEOF\n")
endfunction
