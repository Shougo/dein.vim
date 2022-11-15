#!/bin/sh

set -e

# Control if the script should overwrite or not an existent config
KEEP_CONFIG=yes

# Store the dein.bim base path location (eg. '~/.cache/dein')
BASE=none

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
# 1. id - to get most accurrate username.
# 2. getent - to get the home path instead of ~ or pwd
# 3. eval - to get home path in macOS
USER=${USER:-$(id -u -n)}
HOME=${HOME:-$(getent passwd $USER 2>/dev/null | cut -d: -f6)}
HOME=${HOME:-$(eval echo ~$USER)}

# Improve user experience formatting messages with colors.
# Usage: echo -ne "$(ansi 32)"
# 0: reset; 1: bold; 22: no bold; 30: grey; 31: red; 32: green; 33: yellow; 35: magenta; 36: cyan;
ansi() {
  [ $# -gt 0 ] || return
  printf "\x1B[%sm" $*
}
# If stdout is not a terminal ignore all formatting
[ -t 1 ] || ansi() { :; }

# Reset the terminal. Used to clear the screen in each step of
# the installation process.
reset_clb() {
  printf '\33c\x1B[3J'
}

# This function handle the format of the script messages.
typography() {
  case $1 in
  "title")
    reset_clb
    echo -e "$(ansi 1 30)"
    echo -ne "_______________________________________________________________\n"
    echo -ne "$(ansi 1 32)"
    echo -e " #######  ######## ### ###  ###       ###  ### ### ########### "
    echo -e " ##!  ### ##!      ##! ##!#!###       ##!  ### ##! ##! ##! ##!"
    echo -e " #!#  !#! #!!!:!   !!# #!##!!#!       #!#  !#! !!# #!! !#! #!#"
    echo -e " !!:  !!! !!:      !!: !!:  !!!        !:..:!  !!: !!:     !!:"
    echo -e " ::::::   :::::::: ::: :::   ::   ::     ::    ::: :::     :::"
    echo -ne "$(ansi 1 30)"
    echo -e "\n              $(ansi 0)by $AUTHOR$(ansi 30) • $(ansi 0)$LICENSE$(ansi 30) • $(ansi 0)v$VERSION$(ansi 30)"
    echo -e "_______________________________________________________________"
    echo -ne "$(ansi 0)\n\n"
    ;;
  "header")
    reset_clb
    echo -e "\n\n$(ansi 1)[ $2 ]$(ansi 1 0)\n"
    ;;
  'end')
    echo -e "$(ansi 36)➤$(ansi 0) Installation finished.$(ansi 0)"
    echo -e "$(ansi 36)➤$(ansi 0) Run $(ansi 36)'cat $DEIN/doc/dein.txt'$(ansi 0) for more usage information.$(ansi 0)"
    ;;
  "output") echo -e "$(ansi 32)\n$2\n$(ansi 0)" ;;
  "input_opt") echo -e "$(ansi 1 35)$2$(ansi 0) $(ansi 36)$3$(ansi 0) $4" ;;
  "input") echo -e "\n$(ansi 32)➤$(ansi 0) $2" ;;
  'action') echo -e "$(ansi 36)➤$(ansi 0) $2 $(ansi 36)$3$(ansi 0)" ;;
  'error') echo -e "$(ansi 31)Error: $2$(ansi 0)" ;;
  'warning') echo -e "$(ansi 33)Warning: $2$(ansi 0)" ;;
  *) echo "" ;;
  esac
}

# Make sure git is installed and is executable
command -v git >/dev/null 2>&1 || {
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

" Set dein runtime path (required)
set runtimepath+=$DEIN

" Call dein initialization (required)
call dein#begin('$BASE')

call dein#add('$DEIN')

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
EOF
}

# Prompt the user for the vim config path location.
config_prompt() {
  while typography header "CONFIG LOCATION" &&
    typography input_opt "1" "vim" "$(ansi 0 34)path$(ansi 0) $(ansi 30)(~/.vimrc)$(ansi 0)" &&
    typography input_opt "2" "neovim" "$(ansi 0 34)path$(ansi 0) $(ansi 30)(~/.config/nvim/init.vim)$(ansi 0)" &&
    typography input "Select your editor config location (eg. 1 or 2)" && read -p "$(ansi 32)➤$(ansi 0) " OPT_CL; do
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
    typography input_opt "1" "cache" "$(ansi 0 34)path$(ansi 0) $(ansi 30)(~/.cache/dein)$(ansi 0)" &&
    typography input_opt "2" "local" "$(ansi 0 34)path$(ansi 0) $(ansi 30)(~/.local/share/dein)$(ansi 0)" &&
    typography input "Select dein.vim location to clone with git (eg. 1 or 2)" &&
    read -p "$(ansi 32)➤$(ansi 0) " OPT_DL; do
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
      rm -rf "$DEIN" &>/dev/null
    }
    typography error "Git clone of dein.vim repo failed"
    exit 1
  }

  command cd - &>/dev/null || {
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

  if command echo "$(generate_vimrc)" >$OUTDIR; then
    typography action "Config file created successfully! $(ansi 30)" "($OUTDIR)"
  else
    typography error "Failed to generate vim config file. ($OUTDIR)"
    exit 1
  fi
}

dein() {
  # Handle script arguments
  while [ $# -gt 0 ]; do
    case $1 in
    --overwrite-config | -oWC) KEEP_CONFIG=no ;;
    ./* | /home/* | ~/*) BASE=$(echo $1) ;;
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

  if [ -d $DEIN ]; then
    typography warning "The DEIN folder already exists ($DEIN).\nYou'll need to move or remove it."
    exit 1
  fi

  config_prompt

  typography title
  dein_setup
  editor_setup
  typography end
}

dein "$@"

exit 0
