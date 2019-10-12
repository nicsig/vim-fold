fu fold#fdt#get() abort "{{{1
    let line = getline(v:foldstart)
    " get the desired level of indentation for the title
    if &ft is# 'markdown' || get(b:, 'title_like_in_markdown', 0)
        let level = fold#md#fde#heading_depth(v:foldstart)
        let indent = repeat(' ', (level-1)*3)
    else
        let indent = line =~# '{'.'{{\d\+\s*$'
                 \ ?     repeat(' ', (v:foldlevel-1)*3)
                 \ :     matchstr(getline(v:foldstart), '^\s*')
    endif

    " If you don't care about html and css, you could probably simplify the code
    " of this function, and get rid of `cml_right`.
    let cml_left = '\V'.matchstr(get(split(&l:cms, '%s'), 0, ''), '\S*').'\m'
    let cml_right = '\V'.matchstr(get(split(&l:cms, '%s', 1), 1, ''), '\S*').'\m'

    " remove comment leader
    " Why 2 spaces in the bracket expression?{{{
    "
    " The first is a space, the other is a no-break space.
    " We sometimes use the latter when we want the title to be indented compared
    " to the title of the previous fold (outside markdown).
    " This  can be  useful to  prevent  the title  from being  highlighted as  a
    " codeblock.
    "}}}
    let pat = '^\s*'.cml_left.'[  \t]\='
    " remove fold markers
    if cml_right is# '\V\m'
        let pat ..= '\|\s*\%('.cml_left.'\)\=\s*{'.'{{\d*\s*$'
    else
        let pat ..= '\|\s*'.cml_right.'\s*'.cml_left.'\s*{'.'{{\d*\s*'.cml_right.'\s*$'
    endif

    let title = substitute(line, pat, '', 'g')

    " remove filetype specific noise
    let title = &ft is# 'markdown' || get(b:, 'title_like_in_markdown', 0)
            \ ?     substitute(getline(v:foldstart), '^[-=#]\+\s*', '', '')
            \ : &ft is# 'sh' || &ft is# 'zsh'
            \ ?     substitute(title, '^.*\zs()\s*\%({\|(\)', '', '')
            \ : &ft is# 'vim'
            \ ?     substitute(title, '^\s*fu\%[nction]!\= \%(.*\%(#\|s:\)\)\=\(.\{-}\)(.*).*', '\1', '')
            \ : &ft is# 'python'
            \ ?     substitute(title, '^def\s\+\|(.\{-})\%(^def\s\+.*\)\@<=:', '', 'g')
            \ :     title

    if get(b:, 'foldtitle_full', 0)
        let foldsize  = (v:foldend - v:foldstart)
        let linecount = '['.foldsize.']'.repeat(' ', 4 - strchars(foldsize))
        return indent . (foldsize > 1 ? linecount : '') . title
    else
        return indent.title
    endif
endfu

