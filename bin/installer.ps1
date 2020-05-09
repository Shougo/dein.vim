param(
    [Parameter(Mandatory=$true)][String]$PluginDir
)
$DEIN_VIM_REPO = "https://github.com/Shougo/dein.vim"

# Convert the installation directory to absolute path and create plugin directory
$PluginDir = (New-Item -Directory -Force $PluginDir).FullName

$INSTALL_DIR = Join-Path $PluginDir "repos/github.com/Shougo/dein.vim"
Write-Output "Install to `"$INSTALL_DIR`"..."
if (Test-Path $INSTALL_DIR) {
    Write-Output "`"$INSTALL_DIR`" already exists!"
}

Write-Output ""

# check git command
if (!(Get-Command git -ErrorAction SilentlyContinue -OutVariable $_)) {
    throw 'Please install git or update your path to include the git executable!'
}
Write-Output ""

# make plugin dir and fetch dein
New-Item -Type Directory -Force $INSTALL_DIR
Write-Output "Begin fetching dein..."
git clone $DEIN_VIM_REPO $INSTALL_DIR
Write-Output "Done.`n"
    
Write-Output "Please add the following settings for dein to the top of your vimrc (Vim) or init.vim (NeoVim) file:"

Write-Output ""
Write-Output ""
Write-Output "`"dein Scripts-----------------------------"
Write-Output "if &compatible"
Write-Output "  set nocompatible               `" Be iMproved"
Write-Output "endif"
Write-Output ""
Write-Output "`" Required:"
Write-Output "set runtimepath+=$INSTALL_DIR"
Write-Output ""
Write-Output "`" Required:"
Write-Output "if dein#load_state('$PLUGIN_DIR')"
Write-Output "  call dein#begin('$PLUGIN_DIR')"
Write-Output ""
Write-Output "  `" Let dein manage dein"
Write-Output "  `" Required:"
Write-Output "  call dein#add('$INSTALL_DIR')"
Write-Output ""
Write-Output "  `" Add or remove your plugins here like this:"
Write-Output "  `"call dein#add('Shougo/neosnippet.vim')"
Write-Output "  `"call dein#add('Shougo/neosnippet-snippets')"
Write-Output ""
Write-Output "  `" Required:"
Write-Output "  call dein#end()"
Write-Output "  call dein#save_state()"
Write-Output "endif"
Write-Output ""
Write-Output "`" Required:"
Write-Output "filetype plugin indent on"
Write-Output "syntax enable"
Write-Output ""
Write-Output "`" If you want to install not installed plugins on startup."
Write-Output "`"if dein#check_install()"
Write-Output "`"  call dein#install()"
Write-Output "`"endif"
Write-Output ""
Write-Output "`"End dein Scripts-------------------------"
Write-Output ""
Write-Output ""

Write-Output "Done."

Write-Output "Complete setup dein!"
