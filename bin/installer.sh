#!/bin/sh

set -e

# Control if the script should overwrite or not an existent config
KEEP_CONFIG=yes

# Store the dein.vim base path location (eg. '~/.cache/dein')
BASE=none

# Store the vim config path location (eg. '~/.vimrc')
VIMRC=none

# Store the dein.vim path location (eg. '~/.cache/dein/repos/github.com/Shougo/dein.vim')
DEIN=none

AUTHOR="Shougo"
VERSION="3.0"
LICENSE="MIT License"
BRANCH="master"
REMOTE="https://github.com/Shougo/dein.vim.git"

# The script will need to handle the creation of the
# directories automatically which requires two things:
#
# USER - The username of the current user
# HOME - The home path of the current user
#
# To handle edge cases and allow the usage with an diversity
# of systems this script uses the following commands:
#
# 1. id - to get the most accurate username.
# 2. getent - to get the home path instead of ~ or pwd
# 3. eval - to get home path in macOS
USER=${USER:-$(id -u -n)}
HOME=${HOME:-$(getent passwd "$USER" 2>/dev/null | cut -d: -f6)}
HOME=${HOME:-$(eval echo ~"$USER")}

# Improve user experience formatting messages with colors.
# Usage: printf "$(ansi 32)"
# 0: reset; 1: bold; 22: no bold; 31: red; 32: green; 33: yellow; 35: magenta; 36: cyan;
ansi() {
  [ $# -gt 0 ] || return
  printf "\033[%sm" "$@"
}
# If stdout is not a terminal ignore all formatting
[ -t 1 ] || ansi() { :; }

# Reset the terminal. Used to clear the screen in each step of
# the installation process.
reset_clb() {
  printf "\33c\033[3J"
}

# This function handle the format of the script messages.
typography() {
  case $1 in
  "title")
    reset_clb
    printf "%s_______________________________________________________________\n\n" "$(ansi 1 32)"
    printf " #######  ######## ### ###  ###       ###  ### ### ###########\n"
    printf " ##!  ### ##!      ##! ##!#!###       ##!  ### ##! ##! ##! ##!\n"
    printf " #!#  !#! #!!!:!   !!# #!##!!#!       #!#  !#! !!# #!! !#! #!#\n"
    printf " !!:  !!! !!:      !!: !!:  !!!        !:..:!  !!: !!:     !!:\n"
    printf " ::::::   :::::::: ::: :::   ::   ::     ::    ::: :::     :::\n"
    printf "\n              %sby $AUTHOR %s•%s $LICENSE %s•%s v$VERSION%s\n" "$(ansi 0)" "$(ansi 1 32)" "$(ansi 0)" "$(ansi 1 32)" "$(ansi 0)" "$(ansi 1 32)"
    printf "_______________________________________________________________%s\n\n\n" "$(ansi 0)"
    ;;
  "header")
    reset_clb
    printf "\n\n%s[ $2 ] %s\n" "$(ansi 1)" "$(ansi 1 0)"
    ;;
  "end")
    printf "%s➤%s Installation finished.%s\n" "$(ansi 36)" "$(ansi 0)" "$(ansi 0)"
    printf "%s➤%s Run %s'cat $DEIN/doc/dein.txt'%s for more usage information.%s\n" "$(ansi 36)" "$(ansi 0)" "$(ansi 36)" "$(ansi 0)" "$(ansi 0)"
    ;;
  "output") printf "%s\n$2\n%s\n" "$(ansi 32)" "$(ansi 0)" ;;
  "input_opt") printf "%s$2%s %s$3%s %s$4%s %s$5%s\n" "$(ansi 1 35)" "$(ansi 0)" "$(ansi 36)" "$(ansi 0)" "$(ansi 0 34)" "$(ansi 0)" "$(ansi 1 35)" "$(ansi 0)" ;;
  "input") printf "\n%s%s$2\n" "$(ansi 32)" "$(ansi 0)";;
  "action") printf "%s%s $2 %s$3%s\n" "$(ansi 36)" "$(ansi 0)" "$(ansi 36)" "$(ansi 0)" ;;
  "error") printf "%sError: $2%s\n" "$(ansi 31)" "$(ansi 0)" ;;
  "warning") printf "%sWarning: $2%s\n" "$(ansi 33)" "$(ansi 0)";;
  *) printf "" ;;
  esac
}

# Make sure git is installed and is executable
command -v git >>/dev/null 2>&1 || {
  typography error "Please install git or update your path to include the git executable! Exit error."
  exit 1
}

# Since dein.vim currently doesn't have a default path location,
# the execution of an function to generate an initial config is
# expected.
generate_vimrc() {
  cat <<EOF
" Ward off unexpected things that your distro might have made, as
" well as sanely reset options when re-sourcing .vimrc
set nocompatible

" Set Dein base path (required)
let s:dein_base = '$BASE'

" Set Dein source path (required)
let s:dein_src = '$DEIN'

" Set Dein runtime path (required)
execute 'set runtimepath+=' . s:dein_src

" Call Dein initialization (required)
call dein#begin(s:dein_base)

call dein#add(s:dein_src)

" Your plugins go here:
"call dein#add('Shougo/neosnippet.vim')
"call dein#add('Shougo/neosnippet-snippets')

" Finish Dein initialization (required)
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
EOF
}

# Prompt the user for the vim config path location.
config_prompt() {
  while typography header "CONFIG LOCATION" &&
    typography input_opt "1" "vim" "path" "(~/.vimrc)" &&
    typography input_opt "2" "neovim" "path" "(~/.config/nvim/init.vim)" &&
    typography input "Select your editor config location (eg. 1 or 2)" && read -r OPT_CL; do
    case $OPT_CL in
    1)
      VIMRC="${HOME}/.vimrc"
      break
      ;;
    2)
      VIMRC="${HOME}/.config/nvim/init.vim"
      break
      ;;
    esac
  done
}

# Prompt the user for the dein.vim base path location.
base_prompt() {
  while typography header "DEIN.VIM LOCATION" &&
    typography input_opt "1" "cache" "path" "(~/.cache/dein)" &&
    typography input_opt "2" "local" "path" "(~/.local/share/dein)" &&
    typography input "Select dein.vim location to clone with git (eg. 1 or 2)" &&
    read -r OPT_DL; do
    case $OPT_DL in
    1)
      BASE="${HOME}/.cache/dein"
      break
      ;;
    2)
      BASE="${HOME}/.local/share/dein"
      break
      ;;
    esac
  done
}

# To setup dein.vim and support older git versions
# this function will manually clone the repository.
dein_setup() {
  typography action "Dein.vim setup initialized..."

  git init -q "$DEIN" && cd "$DEIN" &&
    git config fsck.zeroPaddedFilemode ignore &&
    git config fetch.fsck.zeroPaddedFilemode ignore &&
    git config receive.fsck.zeroPaddedFilemode ignore &&
    git config core.eol lf &&
    git config core.autocrlf false &&
    git remote add origin "$REMOTE" &&
    git fetch --depth=1 origin -q &&
    git checkout -b "$BRANCH" "origin/$BRANCH" -q || {
    [ ! -d "$DEIN" ] || {
      cd -
      rm -rf "$DEIN" >>/dev/null 2>&1
    }
    typography error "Git clone of dein.vim repo failed"
    exit 1
  }

  command cd - >>/dev/null 2>&1 || {
    typography error "Failed to exit installation directory"
    exit 1
  }

  typography action "Git cloned dein.vim successfully!" "($DEIN)"
}

# This function will generate the initial config for the user.
# Required for an more conventional user experience.
editor_setup() {
  typography action "Editor setup initialized..."

  if [ -e "$VIMRC" ] && [ $KEEP_CONFIG = "yes" ]; then
    typography warning "Found old editor config. Generating config in the base path.\nRun 'cat $BASE/.vimrc' in your terminal to check it out."
    OUTDIR="$BASE/.vimrc"
  fi

  OUTDIR=${OUTDIR:-$VIMRC}

  if command echo "$(generate_vimrc)" >"$OUTDIR"; then
    typography action "Config file created successfully!" "($OUTDIR)"
  else
    typography error "Failed to generate vim config file. ($OUTDIR)\nMake sure the directory exists and you have access to it."
    exit 1
  fi
}

dein() {
  # Handle script arguments
  while [ $# -gt 0 ]; do
    case $1 in
    --overwrite-config | -oWC) KEEP_CONFIG=no ;;
    ./* | /home/* | ~/*) BASE=$(echo "$1") ;;
    --use-vim-config | -uVC) VIMRC="${HOME}/.vimrc" ;;
    --use-neovim-config | -uNC) VIMRC="${HOME}/.config/nvim/init.vim" ;;
    *)
      typography error "Invalid '$1' command line argument given."
      exit 1
      ;;
    esac
    shift
  done

  case $BASE in
  none) base_prompt ;;
  *.vim/plugin* | *.config/nvim/plugin*)
    typography error "The base path cannot be '$BASE'. Please, enter another directory."
    exit 1
    ;;
  esac

  DEIN="${BASE}/repos/github.com/Shougo/dein.vim"

  if [ -d "$DEIN" ]; then
    typography warning "The DEIN folder already exists ($DEIN).\nYou'll need to move or remove it."
    exit 1
  fi

  case $VIMRC in
  none) config_prompt ;;
  esac

  typography title
  dein_setup
  editor_setup
  typography end
}

dein "$@"

exit 0
