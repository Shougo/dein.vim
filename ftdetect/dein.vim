function! s:DetectHelpFileType() abort
  " NOTE ':help' command sets "help" filetype automatically
  const ext = expand('<afile>')->fnamemodify(':e')
  if ext ==# 'md' || ext ==# 'mkd'
    autocmd dein BufWinEnter <buffer> ++once setfiletype markdown
  endif
endfunction

autocmd dein FileType help call s:DetectHelpFileType()
