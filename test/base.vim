"set verbose=1

let s:suite = themis#suite('base')
let s:assert = themis#helper('assert')

let s:path = tempname()

function! s:suite.before_each() abort
  call dein#min#_init()
endfunction

function! s:suite.block_normal() abort
  call s:assert.equals(dein#begin(s:path), 0)
  call s:assert.equals(dein#end(), 0)

  call s:assert.equals(dein#begin(s:path), 0)
  call s:assert.equals(dein#end(), 0)
endfunction

function! s:suite.begin_invalid() abort
  call s:assert.equals(dein#begin(s:path), 0)
  call s:assert.equals(dein#begin(s:path), 1)

  call dein#min#_init()
  call s:assert.equals(dein#end(), 1)

  call s:assert.equals(dein#end(), 1)

  call s:assert.equals(dein#begin(getcwd() . '/plugin'), 1)
endfunction

function! s:suite.end_invalid() abort
  call s:assert.equals(dein#end(), 1)
endfunction

function! s:suite.add_normal() abort
  call s:assert.equals(dein#begin(s:path), 0)

  call dein#add('foo', {})
  call s:assert.equals(g:dein#_plugins.foo.name, 'foo')
  call dein#add('bar')
  call s:assert.equals(g:dein#_plugins.bar.name, 'bar')

  call s:assert.equals(dein#end(), 0)
endfunction

function! s:suite.add_overwrite() abort
  call s:assert.equals(dein#begin(s:path), 0)

  call dein#parse#_add('foo', {}, v:true)
  call s:assert.equals(g:dein#_plugins.foo.sourced, 0)

  call dein#parse#_add('foo', { 'sourced': 1 }, v:true)
  call s:assert.equals(g:dein#_plugins.foo.sourced, 1)

  call dein#parse#_add('foo', { 'sourced': 2 }, v:false)
  call s:assert.equals(g:dein#_plugins.foo.sourced, 1)

  call s:assert.equals(dein#end(), 0)
endfunction

function! s:suite.get() abort
  let plugins = { 'foo': {'name': 'bar'} }

  call dein#begin(s:path)
  call dein#add('foo', { 'name': 'bar' })
  call s:assert.equals(dein#get('bar').name, 'bar')
  call dein#add('foo')
  call s:assert.equals(dein#get('foo').name, 'foo')
  call dein#end()
endfunction

function! s:suite.expand() abort
  call s:assert.equals(dein#util#_expand('~'),
        \ dein#util#_substitute_path(fnamemodify('~', ':p')))
  call s:assert.equals(dein#util#_expand('$HOME'),
        \ dein#util#_substitute_path($HOME))
endfunction

function! s:suite.lua() abort
  call dein#begin(s:path)
  call dein#parse#_add('foo', { 'name': 'bar', 'lua_add': 'foo', 'rtp': 'foo' }, v:true)
  call dein#end()
  call s:assert.equals(dein#get('bar').hook_add, "lua <<EOF\nfoo\nEOF\n")
endfunction

function! s:suite.add_normal_lua() abort
  if !has('nvim')
    return
  endif

  let g:path = s:path

  lua <<END
  local dein = require('dein')

  dein.setup {
    auto_remote_plugins = false,
    enable_notification = true,
  }

  dein.begin(vim.g['path'])
  dein.add('foo', { on_ft = 'vim' })
  dein.add('bar')
  dein.end_()
END

  call s:assert.equals(g:dein#_plugins.foo.name, 'foo')
  call s:assert.equals(g:dein#_plugins.foo.on_ft, 'vim')
  call s:assert.equals(g:dein#_plugins.bar.name, 'bar')
endfunction

function! s:suite.options() abort
  call dein#options(#{
        \   lazy_plugins: v:true,
        \   install_progress_type: 'floating',
        \ })

  call s:assert.equals(g:dein#lazy_plugins, v:true)
  call s:assert.equals(g:dein#install_progress_type, 'floating')
endfunction
