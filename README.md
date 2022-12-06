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
      - [Wget](#wget)
      - [Curl](#curl)
      - [Manual inspection](#manual-inspection)
      - [Additional Notes](#additional-notes)
    - [Powershell (Windows)](#powershell-windows)
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

To install dein.vim on **UNIX** systems, you should run the install script. To
do that, you may either download and run the script manually, or use the
following **wget** or **curl** command:


#### Wget

```sh
sh -c "$(wget -O- https://raw.githubusercontent.com/Shougo/dein.vim/master/bin/installer.sh)"
```


#### Curl

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/Shougo/dein.vim/master/bin/installer.sh)"
```


#### Manual inspection

> **Note:** _"It's a good idea to inspect the install script from projects you
> don't know."_

You can do that by downloading the install script, then looking through it to
check if the code is safe:

```sh
$ wget https://raw.githubusercontent.com/Shougo/dein.vim/master/bin/installer.sh
$ less installer.sh
$ sh installer.sh
```

The script code is well formatted, so you can better understand all the code.
The script can take some arguments that are listed in **Additional Notes**
section below.


#### Additional Notes

- If you want to overwrite an existent `.vimrc` or `init.vim` config, pass the
  `--overwrite-config` (or in short `-oWC`) argument to the installation
  script. By default, if there's one config already, the new config is
  generated inside the base path.

- The `installer` script has prompt menus that helps you setup everything.
  However, if you want install **Dein.vim** into an different path location,
  pass the location to the end of the script like `sh installer.sh
  ~/.vim/bundle`.

- If you want to complete the setup without the `installer` script prompting,
  Select your editor config location and pass the `--use-vim-config` (or in short `-uVC`) or
  `--use-neovim-config` (or in short `-uNC`) argument to the installation script.


### Powershell (Windows)

> The support for Windows requires Powershell.

Open your Powershell and download the script:

```powershell
Invoke-WebRequest https://raw.githubusercontent.com/Shougo/dein.vim/master/bin/installer.ps1 -OutFile installer.ps1
```

After checking the code, allow it to be executed properly:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Lastly, for an installation at the `~/.cache/dein` directory execute:

```powershell
./installer.ps1 ~/.cache/dein
```


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
set runtimepath+=s:dein_src

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
