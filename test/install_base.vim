" set verbose=1

const s:suite = themis#suite('install_base')
const s:assert = themis#helper('assert')

function! s:suite.rm() abort
  const temp = tempname()
  call writefile([], temp)

  call dein#install#_rm(temp)

  call s:assert.equals(temp->filereadable(), 0)
endfunction

function! s:suite.copy_directories() abort
  const temp = tempname()
  const temp2 = tempname()
  const temp3 = tempname()

  call mkdir(temp)
  call mkdir(temp2)
  call mkdir(temp3)
  call writefile([], temp.'/foo')
  call writefile([], temp3.'/bar')
  call s:assert.true((temp.'/foo')->filereadable())
  call s:assert.true((temp3.'/bar')->filereadable())

  call dein#install#_copy_directories([temp, temp3], temp2)

  call s:assert.true(temp2->isdirectory())
  call s:assert.true((temp2.'/foo')->filereadable())
  call s:assert.true((temp2.'/bar')->filereadable())
endfunction
