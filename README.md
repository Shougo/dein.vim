## About

[![Join the chat at https://gitter.im/Shougo/dein.vim](https://badges.gitter.im/Shougo/dein.vim.svg)](https://gitter.im/Shougo/dein.vim?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge) [![Build Status](https://travis-ci.org/Shougo/dein.vim.svg?branch=master)](https://travis-ci.org/Shougo/dein.vim)

Dein.vim is a dark powered Vim/Neovim plugin manager.


## Requirements

* Vim 7.4 or above or NeoVim.
* "xcopy" command in $PATH (Windows)
* "git" command in $PATH (if you want to install github or vim.org plugins)

## Quick start

#### If you are using Unix/Linux or Mac OS X.

1. Run below script.

     ```
     $ curl https://raw.githubusercontent.com/Shougo/dein.vim/master/bin/installer.sh > installer.sh
     $ sh ./installer.sh {specify the installation directory}
     ```

2. Edit your .vimrc like this.

    ```vim
    if &compatible
      set nocompatible
    endif
    set runtimepath+={path to dein.vim directory}

    if dein#load_state({path to plugin base path directory})
      call dein#begin({path to plugin base path directory})

      call dein#add({path to dein.vim directory})
      call dein#add('Shougo/neocomplete.vim')
      ...

      call dein#end()
      call dein#save_state()
    endif

    filetype plugin indent on
    syntax enable
    ```

3. Open vim and install dein

    ```vim
    :call dein#install()
    ```

## Installing Plugins
Append these instructions to the end of your `~/.vimrc` file. 

1. Open `~/.vimrc`

2. Add vim plugins without dependencies to your `~/.vimrc` file.
   ```vim
   call dein#add('mileszs/ack.vim')
   ```

3. Add vim plugins with dependencies this line to your `~/.vimrc file. Repeat for as many plugins as you want to install.
   ```vim 
   call dein#add('mattn/gist-vim', {'depends': 'mattn/webapi-vim'})```

4. Reload Vim
   ```bash
   :so ~/.vimrc
   ```

5. Install plugins on Vim
   ```bash
   :call dein#install()
   ```

## Concept

* Faster than NeoBundle

* Simple

* No commands, Functions only to simplify the implementation

* Easy to test and maintain

* No Vundle/NeoBundle compatibility

* neovim/Vim8 asynchronous API installation support

## Future works (not implemented yet)

* Other types support (zip, svn, hg, ...)

* Metadata repository support

### Options

Some common options. For a more detailed list, run `:h dein-options`

| Option    | Type               | Description                                                                           |
|-----------|--------------------|---------------------------------------------------------------------------------------|
| `name`    | `string`           | A name for the plugin. If it is omitted, the tail of the repository name will be used |
| `rev`     | `string`           | The revision number or branch/tag name for the repo                                   |
| `build`   | `string`           | Command to run after the plugin is installed                                          |
| `on_ft`   | `string` or `list` | Load a plugin for the current filetype                                                |
| `on_cmd`  | `string` or `list` | Load the plugin for these commands                                                    |

