function! s:DetectHelpFileType() abort
  if !get(g:, 'dein#detect_help_filetype', v:false)
    return
  endif

  if expand('<afile>')->fnamemodify(':e') ==# 'md'
    autocmd dein BufWinEnter <buffer> ++once setfiletype markdown
  endif
endfunction

autocmd dein FileType help call s:DetectHelpFileType()
