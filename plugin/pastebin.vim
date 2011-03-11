
" Section: Plugin header
"
" loaded_pastebin is set to 1 when initialization begins, and 2 when it
" completes.
if exists('g:loaded_pastebin')
	finish
endif
let g:loaded_pastebin=1

" Section: Meat
function! s:nr2hex(nr)
  let n = a:nr
  let r = ""
  while n
    let r = '0123456789ABCDEF'[n % 16] . r
    let n = n / 16
  endwhile
  return r
endfunction

function! s:encodeURIComponent(instr)
  let instr = iconv(a:instr, &enc, "utf-8")
  let len = strlen(instr)
  let i = 0
  let outstr = ''
  while i < len
    let ch = instr[i]
    if ch =~# '[0-9A-Za-z-._~!''()*]'
      let outstr = outstr . ch
    elseif ch == ' '
      let outstr = outstr . '+'
    else
      let outstr = outstr . '%' . substitute('0' . s:nr2hex(char2nr(ch)), '^.*\(..\)$', '\1', '')
    endif
    let i = i + 1
  endwhile
  return outstr
endfunction

function! PasteBin(line1, line2)
  let content = join(getline(a:line1, a:line2), "\n")
  let query = [
    \ 'paste_name=%s',
    \ 'paste_code=%s',
    \ 'paste_format=%s',
    \ ]

  let squery = printf(join(query, '&'),
    \ s:encodeURIComponent(expand('%:p:t')),
    \ s:encodeURIComponent(content),
    \ s:encodeURIComponent(&ft))
  unlet query
  let file = tempname()
  call writefile([squery], file)
  let quote = &shellxquote == '"' ?  "'" : '"'
  let url = 'http://pastebin.com/api_public.php'
  let res = system('curl -s -d @'.quote.file.quote.' '.url)
  call delete(file)
  echo res
endfunction

command! -nargs=? -range=% PasteBin :call PasteBin(<line1>, <line2>)

" Section: Plugin completion
let g:loaded_pastebin=2
