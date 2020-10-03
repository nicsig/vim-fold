import InTerminalBuffer from 'lg.vim'

fu fold#adhoc#main() abort "{{{1
    if !(&ft == '' || &ft is# 'markdown' && search('^health#', 'n'))
        return
    endif
    let b:title_like_in_markdown = 1
    if s:InTerminalBuffer()
        setl fdm=expr
        setl fde=getline(v:lnum)=~#'^٪'?'>1':'='
        setl fdt=fold#fdt#get()
        return
    endif
    runtime! ftplugin/markdown.vim
    " usually, we set fold options via an autocmd listening to `BufWinEnter`
    do <nomodeline> BufWinEnter
endfu

