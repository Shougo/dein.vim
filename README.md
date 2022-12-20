# Dein.vim

[![Gitter](https://img.shields.io/gitter/room/Shougo/dein.vim?color=mediumaquamarine)](https://gitter.im/Shougo/dein.vim)
![GitHub release (latest by date)](https://img.shields.io/github/v/release/Shougo/dein.vim?color=mediumaquamarine)
[![GitHub issues](https://img.shields.io/github/issues/shougo/dein.vim?color=mediumaquamarine)](https://github.com/Shougo/dein.vim/issues)


**Dein.vim** is a dark powered Vim/Neovim plugin manager.

To learn more details, visit [here](doc/dein.txt).

<details>
 <summary><strong>Table of contents</strong></summary>
 <br/>

<!-- vim-markdown-toc GFM -->

- [Dein.vim](#deinvim)
  - [Features](#features)
  - [Getting started](#getting-started)
    - [Prerequisites](#prerequisites)
    - [Basic installation](#basic-installation)
    - [Command line installation](#command-line-installation)
    - [Config example](#config-example)
  - [Q\&A](#qa)
      - [Dein has an user interface like vim-plug?](#dein-has-an-user-interface-like-vim-plug)
  - [Feedback](#feedback)
  - [Tasks](#tasks)
  - [License](#license)

<!-- vim-markdown-toc -->

<br/>
</details>


## Features

- **Fast** - Faster than NeoBundle.
- **Simple** - Function API and familiar patterns, without commands or
  dependency hell.
- **Async** - Clean asynchronous installation supported.
- **Extendable** - Supports plugins from local or remote sources, and also
  Non-Github plugins.
- **Consistent** - Go-like directory structure (eg.
  github.com/{_author_}/{_repository_})
- **Practical** - Automatically merge plugins directories to avoid long
  **runtimepath**


## Getting started


### Prerequisites

- **Vim** (v8.2 or higher) or **NeoVim** (v0.5.0 or higher)
- **Git** should be installed (v2.4.11 or higher)
- **xcopy** installed or **Python3** interface (on Windows)

**Note:** If you use **Vim** (lower than 8.2) or **NeoVim** (lower than 0.5),
please use **dein.vim** `v2.2` instead.


### Basic installation

You can install dein.vim by your vimrc/init.vim.

```vim
let $CACHE = expand('~/.cache')
if !isdirectory($CACHE)
  call mkdir($CACHE, 'p')
endif
if &runtimepath !~# '/dein.vim'
  let s:dein_dir = fnamemodify('dein.vim', ':p')
  if !isdirectory(s:dein_dir)
    let s:dein_dir = $CACHE . '/dein/repos/github.com/Shougo/dein.vim'
    if !isdirectory(s:dein_dir)
      execute '!git clone https://github.com/Shougo/dein.vim' s:dein_dir
    endif
  endif
  execute 'set runtimepath^=' . substitute(
        \ fnamemodify(s:dein_dir, ':p') , '[/\\]$', '', '')
endif
```


### Command line installation

Please use [dein-installer.vim](https://github.com/Shougo/dein-installer.vim).


### Config example

<details>
  <summary>
    Show a UNIX installation example using <strong>"~/.cache/dein"</strong> as
    the base path location.
  </summary>

```vim
" Ward off unexpected things that your distro might have made, as
" well as sanely reset options when re-sourcing .vimrc
set nocompatible

" Set dein base path (required)
let s:dein_base = '~/.cache/dein/'

" Set dein source path (required)
let s:dein_src = '~/.cache/dein/repos/github.com/Shougo/dein.vim'

" Set dein runtime path (required)
execute 'set runtimepath+=' . s:dein_src

" Call dein initialization (required)
call dein#begin(s:dein_base)

call dein#add(s:dein_src)

" Your plugins go here:
"call dein#add('Shougo/neosnippet.vim')
"call dein#add('Shougo/neosnippet-snippets')

" Finish dein initialization (required)
call dein#end()

" Attempt to determine the type of a file based on its name and possibly its
" contents. Use this to allow intelligent auto-indenting for each filetype,
" and for plugins that are filetype specific.
if has('filetype')
  filetype indent plugin on
endif

" Enable syntax highlighting
if has('syntax')
  syntax on
endif

" Uncomment if you want to install not-installed plugins on startup.
"if dein#check_install()
" call dein#install()
"endif
```
</details>


## Q&A


#### Dein has an user interface like vim-plug?

- Built-in Dein **does not** have one, but if you want one, we recommend using
  [github.com/wsdjeg/dein-ui.vim](https://github.com/wsdjeg/dein-ui.vim)


## Feedback

- [Chat with the community](https://gitter.im/Shougo/dein.vim)
- [Create an issue](https://github.com/Shougo/dein.vim/issues)


## Tasks

This is where Dein future plans or TODOS are listed:

- Other types support (zip, svn, hg, ...)
- Metadata repository support


## License

Licensed under the [MIT](LICENSE) license.
