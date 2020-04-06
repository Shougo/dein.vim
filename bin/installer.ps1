$DEIN_VIM_REPO = "https://github.com/Shougo/dein.vim"

# Check if a cmdlet exists
# https://devblogs.microsoft.com/scripting/use-a-powershell-function-to-see-if-a-command-exists/
Function Test-CommandExists {
    Param ($command)

    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = ‘stop’

    try {
        if (Get-Command $command) {
            RETURN $true
        }
    }
    Catch {
        Write-Host “$command does not exist”
        RETURN $false
    }
    Finally {
        $ErrorActionPreference = $oldPreference
    }
}

if ($args.Count -ne 1) {
    Write-Output "You must specify the installation directory!"
    exit 1
}

# Convert the installation directory to absolute path and create plugin directory
$PLUGIN_DIR = $args[0]
if (Test-Path $PLUGIN_DIR) {
    $PLUGIN_DIR = Convert-Path $PLUGIN_DIR
}
else {
    $PLUGIN_DIR = New-Item $PLUGIN_DIR -ItemType Directory
}

$INSTALL_DIR = Join-Path $PLUGIN_DIR "repos/github.com/Shougo/dein.vim"
Write-Output "Install to `"$INSTALL_DIR`"..."
if (Test-Path $INSTALL_DIR) {
    Write-Output "`"$INSTALL_DIR`" already exists!"
}

Write-Output ""

# check git command
if (!(Test-CommandExists git)) {
    Write-Output 'Please install git or update your path to include the git executable!'
    exit 1
}
Write-Output ""

# make plugin dir and fetch dein
if (!(Test-Path $INSTALL_DIR)) {
    Write-Output "Begin fetching dein..."
    New-Item $INSTALL_DIR -ItemType Directory | Out-Null
    git clone $DEIN_VIM_REPO $INSTALL_DIR
    Write-Output "Done."
    Write-Output ""
}

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
