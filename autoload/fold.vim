fu! fold#text() abort "{{{1
    let line = getline(v:foldstart)
    " get the desired level of indentation for the title
    if &ft is# 'markdown' || get(b:, 'title_like_in_markdown', 0)
        let level = fold#md#heading_depth(v:foldstart)
        let indent = repeat(' ', (level-1)*3)
    else
        let indent = line =~# '{{'.'{\d\+\s*$'
                 \ ?     repeat(' ', (v:foldlevel-1)*3)
                 \ :     matchstr(getline(v:foldstart), '^\s*')
    endif

    " get a possible comment leader
    let cml = '\V'.matchstr(get(split(&l:cms, '%s'), 0, ''), '\S*').'\v'
    "           │
    "           └ the comment leader could contain special characters,
    "             like % in a tex file

    " remove general noise
    let title = substitute(line, '\v^\s*%('.cml.')\@?\s?|\s*%('.cml.')?\s*\{\{\{%(\d+)?\s*$', '', 'g')
    "                                             └─┤
    "                                               └ for commented code

    " remove filetype specific noise
    let title = &ft is# 'markdown' || get(b:, 'title_like_in_markdown', 0)
            \ ?     substitute(getline(v:foldstart), '^[-=#]\+\s*', '', '')
            \ : &ft is# 'sh' || &ft is# 'zsh'
            \ ?     substitute(title, '\v^.*\zs\(\)\s*%(\{|\()', '', '')
            \ : &ft is# 'vim'
            \ ?     substitute(title, '\v^\s*fu%[nction]! %(.*%(#|s:))?(.{-})\(.*\).*', '\1', '')
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

