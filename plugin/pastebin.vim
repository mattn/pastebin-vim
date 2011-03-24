"=============================================================================
" File: pastebin.vim
" Author: Yasuhiro Matsumoto <mattn.jp@gmail.com>
" Last Change: 25-Mar-2011.
" Version: 0.2
" WebPage: http://github.com/mattn/pastebin-vim
" License: BSD
"
" Thanks:
"   AD7six: bug fix & posting with auth.
"
" script type: plugin

" loaded_pastebin is set to 1 when initialization begins, and 2 when it
" completes.
if exists('g:loaded_pastebin')
  finish
endif
let g:loaded_pastebin=1

" Section: Script variables
" If you don't want pastes to open directly in your browser - define
" g:pastebin_browser_command as "" in your vimrc
if !exists('g:pastebin_browser_command')
  if exists(':OpenBrowser')
    let g:pastebin_browser_command = ":OpenBrowser %URL%"
  elseif has('win32')
    let g:pastebin_browser_command = "!start rundll32 url.dll,FileProtocolHandler %URL%"
  elseif has('mac')
    let g:pastebin_browser_command = "open %URL%"
  elseif executable('xdg-open')
    let g:pastebin_browser_command = "xdg-open %URL%"
  else
    let g:pastebin_browser_command = "firefox %URL% &"
  endif
endif

" used for both anon and authed pastes
if !exists('g:pastebin_expire_date')
  let g:pastebin_expire_date = '1H'
endif
if !exists('g:pastebin_private')
  let g:pastebin_private = 0
endif

" subdomain and email only used for anon 
if !exists('g:pastebin_subdomain')
  let g:pastebin_subdomain = ''
endif
if !exists('g:pastebin_email')
  let g:pastebin_email = ''
endif

" api key, username and password only used for authed pastes
if !exists('g:pastebin_api_dev_key')
  let g:pastebin_api_dev_key = ''
endif
if !exists('g:pastebin_api_user_name')
  let g:pastebin_api_user_name = ''
endif
if !exists('g:pastebin_api_user_password')
  let g:pastebin_api_user_password = ''
endif

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

" The public function. If you've set a pastebin_api_dev_key it'll try to use it
" Otherwise it'll post anonymously
function! PasteBin(line1, line2)
  if g:pastebin_api_dev_key == ""
    call PasteBinAnon(a:line1, a:line2)
  else
    call PasteBinAuth(a:line1, a:line2)
  endif
endfunction

" Post anonymously
function! PasteBinAnon(line1, line2)
  let content = join(getline(a:line1, a:line2), "\n")
  let query = [
    \ 'paste_expire_date=%s',
    \ 'paste_name=%s',
    \ 'paste_code=%s',
    \ 'paste_format=%s',
    \ 'paste_subdomain=%s',
    \ 'paste_email=%s'
    \ ]

  let data = printf(join(query, '&'),
    \ s:encodeURIComponent(g:pastebin_expire_date),
    \ s:encodeURIComponent(expand('%:p:t')),
    \ s:encodeURIComponent(content),
    \ s:encodeURIComponent(&ft),
    \ s:encodeURIComponent(g:pastebin_subdomain),
    \ s:encodeURIComponent(g:pastebin_email)
  \ )
  unlet query

  let url = s:post('http://pastebin.com/api_public.php', data)
  call s:finished(url)
endfunction

" Post as a specific user
function! PasteBinAuth(line1, line2)
  let api_user_key = s:PasteBinLogin()

  let content = join(getline(a:line1, a:line2), "\n")
  let query = [
    \ 'api_option=%s',
    \ 'api_user_key=%s',
    \ 'api_paste_private=%s',
    \ 'api_paste_name=%s',
    \ 'api_paste_expire_date=%s',
    \ 'api_paste_format=%s',
    \ 'api_dev_key=%s',
    \ 'api_paste_code=%s'
    \ ]

  let data = printf(join(query, '&'),
    \ s:encodeURIComponent('paste'),
    \ s:encodeURIComponent(api_user_key),
    \ s:encodeURIComponent(g:pastebin_private),
    \ s:encodeURIComponent(expand('%:p:t')),
    \ s:encodeURIComponent(g:pastebin_expire_date),
    \ s:encodeURIComponent(&ft != "" ? &ft : "text"),
    \ s:encodeURIComponent(g:pastebin_api_dev_key),
    \ s:encodeURIComponent(content)
  \ )
  unlet query

  let url = s:post('http://pastebin.com/api/api_post.php', data)
  call s:finished(url)
endfunction

" Get an auth token
function! s:PasteBinLogin()
  let query = [
    \ 'api_dev_key=%s',
    \ 'api_user_name=%s',
    \ 'api_user_password=%s'
    \ ]

  let data = printf(join(query, '&'),
    \ s:encodeURIComponent(g:pastebin_api_dev_key),
    \ s:encodeURIComponent(g:pastebin_api_user_name),
    \ s:encodeURIComponent(g:pastebin_api_user_password)
  \ )
  unlet query

  return s:post('http://pastebin.com/api/api_login.php', data)
endfunction

" what to do with the return value - should be a url
" TODO check it's not an error and act appropriately
function! s:finished(url)
  if g:pastebin_browser_command == ''
    echo a:url
    return
  endif

  let cmd = substitute(g:pastebin_browser_command, '%URL%', a:url, 'g')
  if cmd =~ '^!'
    silent! exec cmd
  elseif cmd =~ '^:[A-Z]'
    exec cmd
  else
    call system(cmd)
  endif
endfunction

" Post the passed data to the url
function! s:post(url, data)
  let file = tempname()
  call writefile([a:data], file)
  let quote = &shellxquote == '"' ?  "'" : '"'
  let res = system('curl -s -d @'.quote.file.quote.' '.a:url)
  call delete(file)
  return res
endfunction

command! -nargs=? -range=% PasteBin :call PasteBin(<line1>, <line2>)

" Section: Plugin completion
let g:loaded_pastebin=2
