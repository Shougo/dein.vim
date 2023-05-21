function! s:DetectHelpFileType() abort
  " NOTE ':help' command sets "help" filetype automatically
  const ext = expand('<afile>')->fnamemodify(':e')
  if ext ==# 'md' || ext ==# 'mkd'
    autocmd BufWinEnter <buffer> ++once setfiletype markdown
  endif
endfunction

autocmd FileType help call s:DetectHelpFileType()
