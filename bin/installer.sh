#!/bin/sh

set -e

# Control if the script should overwrite or not an existent config
KEEP_CONFIG=yes

# Store the dein.vim base path location (eg. '~/.cache/dein')
BASE=none

# Store the dein.vim path location (eg. '~/.cache/dein/repos/github.com/Shougo/dein.vim')
DEIN=none

# Store the Vim or Neovim config file (eg. 'init.vim')
CONFIG_FILENAME=none

# Store the path of the Vim or Neovim config file (eg. '~/.config/nvim')
CONFIG_LOCATION=none

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
    printf "%s_______________________________________________________________\n\n" "$(ansi 1 32)"
    printf " #######  ######## ### ###  ###       ###  ### ### ###########\n"
    printf " ##!  ### ##!      ##! ##!#!###       ##!  ### ##! ##! ##! ##!\n"
    printf " #!#  !#! #!!!:!   !!# #!##!!#!       #!#  !#! !!# #!! !#! #!#\n"
    printf " !!:  !!! !!:      !!: !!:  !!!        !:..:!  !!: !!:     !!:\n"
    printf " ::::::   :::::::: ::: :::   ::   ::     ::    ::: :::     :::%s\n" "$(ansi 0)"
    printf "\n              by $AUTHOR %s•%s $LICENSE %s•%s v$VERSION\n" "$(ansi 1 32)" "$(ansi 0)" "$(ansi 1 32)" "$(ansi 0)"
    printf "%s_______________________________________________________________%s\n\n" "$(ansi 1 32)" "$(ansi 0)"
    ;;
  "header")
    reset_clb
    printf "\n\n%s[ $2 ] %s\n\n" "$(ansi 1)" "$(ansi 0)"
    ;;
  "end")
    printf "All done. Look at your %s$CONFIG_FILENAME%s file to set plugins, themes, and more.\n\n" "$(ansi 1 34)" "$(ansi 0)"
    printf "%s●%s Documentation:%s $DEIN/doc/dein.txt %s\n" "$(ansi 32)" "$(ansi 0)" "$(ansi 35)" "$(ansi 0)"
    printf "%s●%s Chat with the community:%s https://gitter.im/Shougo/dein.vim %s\n" "$(ansi 32)" "$(ansi 0)" "$(ansi 35)" "$(ansi 0)"
    printf "%s●%s Report issues:%s https://github.com/Shougo/dein.vim/issues %s\n" "$(ansi 32)" "$(ansi 0)" "$(ansi 35)" "$(ansi 0)"
    ;;
  "input_opt") printf "%s$2%s %s$3%s %s$4%s %s$5%s\n" "$(ansi 1 35)" "$(ansi 0)" "$(ansi 36)" "$(ansi 0)" "$(ansi 0 34)" "$(ansi 0)" "$(ansi 1 35)" "$(ansi 0)" ;;
  "input") printf "\n%s\n" "$2" ;;
  "action") printf "%s$2%s\n" "$(ansi 36)" "$(ansi 0)" ;;
  "action_warn") printf "%s$2%s %s$3%s\n" "$(ansi 33)" "$(ansi 0)" "$(ansi 36)" "$(ansi 0)" ;;
  "error") printf "%sError:  $2%s\n" "$(ansi 31)" "$(ansi 0)" ;;
  *) printf "" ;;
  esac
}

# Make sure git is installed and is executable
command -v git >>/dev/null 2>&1 || {
  typography error "Couldn't find 'git' command. Make sure 'git' is installed and is executable before continue."
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

# Handle the cleanup before exiting error. It should be used with caution.
cleanup() {
  # Remove cloned Dein.vim repository, if any.
  [ ! -d "$DEIN" ] || {
    rm -rf "$DEIN" >>/dev/null 2>&1
  }
}

# Handle the backup of existing config files.
config_backup() {
  CONFIG=$1
  BACKUP_ID="pre-dein-vim"

  # When an backup already exist, apply timestamp to the filename.
  if [ -e "$CONFIG.$BACKUP_ID" ]; then
    BACKUP_FILE="$CONFIG-$(date +%m-%d-%Y-%H-%M-%S).$BACKUP_ID"
  fi

  BACKUP_FILE=${BACKUP_FILE:-"$CONFIG.$BACKUP_ID"}

  typography action_warn "Found $CONFIG_FILENAME." "Creating backup in '$BACKUP_FILE'..."

  command mv "$CONFIG" "$BACKUP_FILE" >>/dev/null 2>&1 || {
    cleanup
    typography error "Failed to create backup of '$CONFIG' in '$BACKUP_FILE'."
    exit 1
  }
}

# Prompt the user for the vim config path location.
config_prompt() {
  while
    typography header "CONFIG LOCATION" &&
      typography input_opt "1" "vim" "path" "(~/.vimrc)" &&
      typography input_opt "2" "neovim" "path" "(~/.config/nvim/init.vim)" &&
      typography input "Select your editor config location (eg. 1 or 2)" &&
      read -r OPT_CL
  do
    case $OPT_CL in
    1)
      CONFIG_LOCATION="$HOME"
      CONFIG_FILENAME=".vimrc"
      break
      ;;
    2)
      CONFIG_LOCATION="$HOME/.config/nvim"
      CONFIG_FILENAME="init.vim"
      break
      ;;
    esac
  done
}

# Prompt the user for the dein.vim base path location.
base_prompt() {
  while
    typography header "DEIN.VIM LOCATION" &&
      typography input_opt "1" "cache" "path" "(~/.cache/dein)" &&
      typography input_opt "2" "local" "path" "(~/.local/share/dein)" &&
      typography input "Select dein.vim location to clone with git (eg. 1 or 2)" &&
      read -r OPT_DL
  do
    case $OPT_DL in
    1)
      BASE="$HOME/.cache/dein"
      break
      ;;
    2)
      BASE="$HOME/.local/share/dein"
      break
      ;;
    esac
  done
}

# To setup dein.vim and support older git versions
# this function will manually clone the repository.
dein_setup() {
  typography action "Cloning Dein.vim into '$DEIN'..."

  command git init -q "$DEIN" &&
    command cd "$DEIN" >>/dev/null 2>&1 &&
    command git config fsck.zeroPaddedFilemode ignore &&
    command git config fetch.fsck.zeroPaddedFilemode ignore &&
    command git config receive.fsck.zeroPaddedFilemode ignore &&
    command git config core.eol lf &&
    command git config core.autocrlf false &&
    command git remote add origin "$REMOTE" &&
    command git fetch --depth=1 origin "$BRANCH" &&
    command git checkout "$BRANCH" -q ||
    {
      cd -
      cleanup
      typography error "Git clone of dein.vim repo failed"
      exit 1
    }

  command cd - >>/dev/null 2>&1 || {
    typography error "Failed to exit installation directory"
    exit 1
  }
}

# This function will generate the initial config for the user.
# Required for an more conventional user experience.
editor_setup() {
  typography action "Looking for an existing '$CONFIG_FILENAME' config..."

  EDITOR_CONFIG="$CONFIG_LOCATION/$CONFIG_FILENAME"

  if [ -e "$EDITOR_CONFIG" ] && [ $KEEP_CONFIG = "yes" ]; then
    config_backup "$EDITOR_CONFIG"
  else
    case $EDITOR_CONFIG in
    *.config/nvim/init.vim)
      # Create the Neovim config folder if it doesn't exist already.
      command mkdir -p "$CONFIG_LOCATION" >>/dev/null 2>&1 || {
        cleanup
        typography error "Failed to create Neovim folder, try creating '$CONFIG_LOCATION' folder manually before continue."
        exit 1
      }
      ;;
    esac
  fi

  typography action "Using the Dein.vim config example and adding it to '$EDITOR_CONFIG'..."

  command echo "$(generate_vimrc)" >"$EDITOR_CONFIG" || {
    cleanup
    typography error "Failed to generate '$CONFIG_FILENAME' file. Make sure the directory exists and you have access to it.\n     at editor-config ($CONFIG_LOCATION)"
    exit 1
  }
}

dein() {
  # Handle script arguments
  while [ $# -gt 0 ]; do
    case $1 in
    --overwrite-config | -oWC) KEEP_CONFIG=no ;;
    *./* | */home/* | *~/*) BASE=$(eval echo "${1%/}") ;;
    --use-vim-config | -uVC)
      CONFIG_LOCATION="$HOME"
      CONFIG_FILENAME=".vimrc"
      ;;
    --use-neovim-config | -uNC)
      CONFIG_LOCATION="$HOME/.config/nvim"
      CONFIG_FILENAME="init.vim"
      ;;
    *)
      typography error "Invalid '$1' command line argument given."
      exit 1
      ;;
    esac
    shift
  done

  case $BASE in
  none)
    base_prompt
    reset_clb
    ;;
  *.vim/plugin* | *.config/nvim/plugin*)
    typography error "Invalid base path location, the '$BASE' directory is restricted and cannot be used."
    exit 1
    ;;
  esac

  if [ "$CONFIG_FILENAME" = "none" ] || [ "$CONFIG_LOCATION" = "none" ]; then
    config_prompt
    reset_clb
  fi

  DEIN="${BASE}/repos/github.com/Shougo/dein.vim"

  if [ -d "$DEIN" ]; then
    typography error "Folder already exists. Move or delete the '$DEIN' folder to continue."
    exit 1
  fi

  dein_setup
  editor_setup

  typography title
  typography end
}

dein "$@"

exit 0
