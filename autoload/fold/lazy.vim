" FAQ{{{
" What's the purpose of this script?{{{
"
" Editing text in insert mode in a markdown buffer can sometimes be slow.
"
" MWE:
"
"     $ vim -Nu <(cat <<'EOF'
"         setl fdm=expr fde=Heading_depth(v:lnum)>0?'>1':'='
"         fu Heading_depth(lnum)
"             let nextline = getline(a:lnum+1)
"             let level = getline(a:lnum)->matchstr('^#\{1,6}')->strlen()
"             if !level
"                 if nextline =~# '^=\+\s*$'
"                     return '>1'
"                 elseif nextline =~# '^-\+\s*$'
"                     return '>2'
"                 endif
"             endif
"             return level
"         endfu
"         ino <expr> <c-k><c-k> repeat('<del>', 300)
"     EOF
"     ) +"%d | put='text' | norm! yy300pG300Ax" /tmp/md.md
"
" Vim takes several seconds to start.
" Now, press `I C-k C-k` to delete the rest of the line.
" Again, it takes several seconds.
"
" It seems the issue is `markdown#fold#foldexpr#heading_depth()` which, for some
" reason, is called more than 180,000 times!
"
" I think  that every time  a character is inserted  or removed while  in insert
" mode, Vim has to  recompute the folding level of each line  above when using a
" foldexpr.
" That would  explain why  the issue  gets worse  as the  number of  lines above
" increases, and why it gets worse  as the number of inserted/removed characters
" increases.
"
" ---
"
" The main culprit is the value `'='` returned from `Heading_depth()`.
" If you replace it with `1`, the slowness disappears.
"}}}
"   Why can't I just use `>1` and `1` to fix this issue?{{{
"
" We don't want to use `1` in `markdown#fold#foldexpr#stacked()`; see the comments there.
"
" Besides, for a given buffer, we may be using:
"
"    - a different foldexpr which also uses a costly value (e.g. `'='`, `'a123'`, `'s123'`)
"    - a different folding method which can still be slow (e.g. `syntax`)
"}}}
"     Ok, so how does `vim-fold` fix it?{{{
"
" It lets Vim create folds according to the value of `'fdm'` (e.g. `foldexpr` or
" `syntax`), then  it resets  the latter  to manual, which  is much  less costly
" because  it doesn't  ask Vim  to recompute  anything every  time you  edit the
" buffer.
"
" From `:h fold-methods`:
"
"    > Switching to  the "manual" method  doesn't remove the existing  folds.  This
"    > can be  used to first  define the folds  automatically and then  change them
"    > manually.
"
" ---
"
" You can observe the positive effect from `vim-fold` like this:
"
"     $ vim -Nu <(cat <<'EOF'
"         filetype on
"         set rtp^=~/.vim/plugged/vim-fold rtp^=~/.vim/plugged/vim-markdown
"         setl fdm=expr fde=Heading_depth(v:lnum)>0?'>1':'='
"         fu Heading_depth(lnum)
"             let level = getline(a:lnum)->matchstr('^#\{1,6}')->strlen()
"             if !level
"                 if getline(a:lnum+1) =~ '^=\+\s*$'
"                     let level = 1
"                 endif
"             endif
"             return level
"         endfu
"         ino <expr> <c-k><c-k> repeat('<del>', 300)
"     EOF
"     ) +"%d | put='text' | norm! yy300pG300Ax" /tmp/md.md
"
" Vim should  start up immediately, and  removing 300 characters with  `C-k C-k`
" should also be instantaneous.
"}}}

" When won't the foldmethod be reset from a costly value to 'manual'?{{{
"
" When an autocmd installed after the ones from `vim-fold` resets `'fdm'`.
" As an example, add this to `~/.vim/after/plugin/markdown.vim`:
"
"     au FileType markdown setl fdm=expr
"
" And disable the `BufWinEnter` autocmd in your markdown filetype plugin.
" Finally, run:
"
"     $ vim
"     :e /tmp/md.md
"
" The foldmethod is set to 'expr'.
"
" See: https://github.com/Konfekt/FastFold/commit/e14d31902fea2ee8fde22c99921ba946d18f692c
"}}}
"   How to fix this possible issue?{{{
"
" Delay the vim-fold autocmds until `VimEnter`.
"
" However, another issue will arise:
"
"     $ vim /tmp/md.md
"
" In that case, the foldmethod is still 'expr', even after delaying the autocmds.
"
" Solution: on `VimEnter` invoke `fold#lazy#compute()` in *all* windows
" (*in addition to installing the autocmds*):
"
"     let winids = getwininfo()->map({_, v -> v.winid})
"     call map(winids, {_, v -> win_execute(v, 'call fold#lazy#compute("force")')})
"
" See:
" https://github.com/Konfekt/FastFold/issues/30
" https://github.com/Konfekt/FastFold/blob/bd88eed0c22a298a49f52a14a673bc1aad8c0a1b/plugin/fastfold.vim#L184
"}}}
"     Why don't you try to fix it?{{{
"
" I can't imagine a realistic scenario where this issue would affect us.
" I think  it would require an  autocmd listening to `FileType`;  we would never
" install such an autocmd to set the foldmethod.
" We will always  use proper ftplugins, which are sourced  *before* the autocmds
" of third-party plugins are fired.
"}}}

" Why could it be useful to disable the lazyfold feature in small files?{{{
"
" https://github.com/Konfekt/FastFold/pull/55
"}}}
"   How could I do it?{{{
"
" Initialize some constant:
"
"     const s:MIN_LINES = 30
"
" Write this function:
"
"     fu s:is_small() abort
"         return line('$') <= s:MIN_LINES
"     endfu
"
" And update `s:should_skip()` to include it:
"
"     return s:is_small() || !s:is_costly() || !empty(&bt) || !&l:ma
"            ^----------^
"}}}
"   Which pitfalls should I be aware of?{{{
"
" `s:MIN_LINES` adds complexity; not in terms of number of lines of code, but in
" terms of logic; it increases the number of code paths.
"
" Suppose the script contains a bug which  can be reproduced when some options A
" and B are both on, or both off.
" But during your tests, you can't reproduce with A and B off, because you use a
" small file.
" You'll come to the conclusion that the bug  is only triggered when A and B are
" on; you may find a solution, but you won't have fixed the bug in all cases.
"
" Also, you may sometimes reproduce the issue, but not always, because you don't
" know or  have forgotten about the  fact that the  number of lines in  the file
" matters.
"
" More generally, the more  code paths, the harder it is to  debug and reason on
" issues.
"
" ---
"
" If you choose a too big value, you may experience lag too frequently.
"
" Whatever value you use for `s:MIN_LINES`, make this experiment:
"
"                                       replace with the new number you want to use (minus 3)
"                                       v-v  v-v
"     $ vim +"%d | put='text' | norm! yy123pG123Ax" /tmp/md.md
"     " make sure that 'fdm' is 'expr'
"     " press:  I C-k C-k
"
" Check how much time it takes for Vim to remove all the characters.
" Choose a value for which the time is acceptable.
"
" 30 seems like a  good fit, because it's a round number, and  it's close to the
" current maximum number of lines we can display in a window (`&lines`).
" It makes sense to consider a file which  fits on a single screen as small; but
" not anything above.
"}}}

" When won't the folds be recomputed?{{{
"
" When  you  modify  a buffer  to  add  new  folded  text, the  folds  won't  be
" recomputed until  you save  the buffer  or use  a custom  fold-related command
" (e.g. `SPC SPC`, `]Z`), provided that the latter has been customized to invoke
" `#compute()`.
"
" If you  use a  fold-related command, but  don't save, the  folds will  only be
" recomputed in the current window; they won't be recomputed in inactive windows
" displaying the current buffer.
" If  this is  an  issue,  then you  should  refactor  your custom  fold-related
" commands so that they invoke `#compute_windows()`.
"
" I don't see the  necessity to do it right now;  `#compute()` seems good enough
" until we save.
"}}}
" How to make Vim recompute folds in another script?{{{
"
" Call `#compute()` if you want to recompute folds only in the current window.
" If you call it from an autocmd, pass it an optional argument (e.g. 'force').
" This will force Vim to recompute folds  no matter what, even if it has already
" been done recently.
"}}}
" I want to test how our "lazyfold" feature behaves when the foldmethod is set to syntax.  What should I do?{{{
"
"     $ git clone https://github.com/BurntSushi/ripgrep && cd *(/oc[1])
"     $ vim --cmd 'let g:rust_fold=2' build.rs
"}}}
"}}}

" Interface{{{1
fu fold#lazy#compute_windows() abort "{{{2
    " compute folds in each window displaying the current buffer; not just the current window
    let curbuf = bufnr('%')
    let winids = getwininfo()
        \ ->filter({_, v -> v.bufnr == curbuf})
        \ ->map({_, v -> v.winid})
    " When I save a new fold, it stays open in the current window (✔), but not in an inactive one (✘)!{{{
    "
    " Replace the next line with this block:
    "
    "     let curlnum = line('.')
    "     let was_visible = foldclosed('.') == -1
    "     call copy(winids)->map({_, v -> win_execute(v, 'call fold#lazy#compute("force")')})
    "     call map(winids, {_, v -> win_execute(v,
    "         \ 'exe ' .. was_visible .. ' && foldclosed(' .. curlnum .. ') != -1 ? "norm! ' .. curlnum .. 'Gzv" : ""')})
    "
    " The issue is due to the fact  that the current line in inactive windows is
    " not synchronized with the current line in the active window.
    "
    " ---
    "
    " I don't  try to fix this  "issue" because it  adds too much code  for what
    " seems to be  an edge case.
    "
    " Note that the previous block could  change the current line of an inactive
    " window; you may want to preserve it.
    "
    " Besides, whether  it's an  issue is  debatable.  I mean  the fold  did not
    " exist in  an inactive window, so  when Vim closes it  automatically there,
    " you can't  say that its state  has not been  preserved; it did not  have a
    " state to begin with.
    "}}}
    call copy(winids)->map({_, v -> win_execute(v, 'call fold#lazy#compute("force")')})
endfu

fu fold#lazy#compute(...) abort "{{{2
    " Why not just inspecting `&l:diff`?{{{
    "
    " It would cause this issue:
    "
    "     $ vimdiff /tmp/md1.md /tmp/md2.md
    "     :tabnew
    "     :e /tmp/md2.md
    "     :echo &l:fdm
    "     expr~
    "     " it should be 'manual'
    "
    " That's because the window in the new  tab page has copied the local values
    " of some options from a diffed window (including `'diff'` which is set).
    "}}}
    if &l:fdm is# 'diff' | return | endif
    " If the file is to be skipped, make sure `b:last_fdm` does not exist.{{{
    "
    " Its existence has a meaning for our  code; I suspect that keeping it while
    " the file is to be skipped could lead to subtle bugs.
    "}}}
    if s:should_skip() | unlet! b:last_fdm b:lazyfold_changedtick | return | endif

    " To improve performance, bail out if folds have been recomputed recently.
    " What's this optional argument?{{{
    "
    " Its value doesn't matter, only its existence.
    " But by convention, use the string 'force'.
    " When it exists, it means that we want folds to be recomputed no matter what.
    "}}}
    "   Ok, and why do you bail out only when it does not exist?{{{
    "
    " When  we call  `#compute()`  from  a custom  mapping,  we  don't pass  the
    " optional argument, to  let the function know that it  should not recompute
    " folds if it has already been done recently.
    " Otherwise, if the mapping is pressed  repeatedly very fast, there would be
    " too much lag in a big file.
    "
    " When  we call  `#compute()`  from  an autocmd,  we  do  pass the  optional
    " argument, because  in that case  we want them  to be recomputed  no matter
    " what (even if they have been recomputed recently).
    "}}}
    "     and only when the buffer has changed?{{{
    "
    " If the buffer has not changed, there's no reason to recompute the folds.
    "
    " In fact, bailing out can improve the performance in some cases.
    " Suppose we are in a big folded file.
    " There's no reason to recompute all the folds every time we press `SPC SPC`
    " to toggle a fold.
    " Same thing for any custom  mapping which invokes this function; especially
    " if we press it frequently (e.g. `] SPC` followed by a smashed `.`, or `]Z`
    " followed by a smashed `;`/`,`).
    "}}}
    "     why don't you bail out if the buffer is not modified?{{{
    "
    " Suppose you delete a fold, then undo.
    " The buffer is still unmodified, but the folding information has been lost.
    " For Vim, this text you've restored is not folded.
    " We probably expect Vim to recompute the fold when we press `SPC SPC` inside.
    "}}}
    if !a:0 && b:changedtick == get(b:, 'lazyfold_changedtick')
        return
    endif
    let b:lazyfold_changedtick = b:changedtick

    " temporarily restore the original costly foldmethod
    if exists('b:last_fdm') && &l:fdm is# 'manual'
        " Don't close a new fold automatically.{{{
        "
        " When saving a  modified buffer containing a new fold,  the latter could be
        " closed automatically; we don't want that.
        "
        " MWE:
        "
        "     $ vim -Nu NONE -S <(cat <<'EOF'
        "         setl fml=0 fdm=manual fde=getline(v:lnum)=~#'^#'?'>1':'='
        "         au BufWritePost * setl fdm=expr | eval foldlevel(1) | setl fdm=manual
        "         %d|sil pu=repeat(['x'], 5)|1
        "     EOF
        "     ) /tmp/md.md
        "
        "     " press:  O # Esc :w  (the fold is closed automatically)
        "     " press:  O # Esc :w  (the fold is closed automatically if 'fml' is 0)
        "
        " I think that for the issue to be reproduced, you need to:
        "
        "    - set `'fdl'` to 0 (it is by default)
        "    - modify the buffer so that the expr method detects a *new* fold
        "    - switch from manual to expr
        "}}}
        let was_visible = foldclosed('.') == -1
        let &l:fdm = b:last_fdm
        " Wait.  Aren't the folds recomputed only when the dummy assignment is executed?{{{
        "
        " Any folding-related function causes folds to be recomputed.
        " So the  evaluation of the next  `foldclosed()` causes the folds  to be
        " recomputed  immediately (to  be  accurate, they  are recomputed  right
        " before computing the fold level of the current line).
        "}}}
        if was_visible && foldclosed('.') != -1
            " Do *not* move `norm! zv` in `#compute_windows()`.{{{
            "
            " The latter is only invoked on certain events:
            "
            "     FileType
            "     BufWritePost
            "     BufWinEnter
            "
            " This is not frequent enough.
            "
            " E.g.  we manually  call  `#compute()` from  `s:jump()` (called  by
            " `fold#motion#rhs()`).
            " If you moved `:norm! zv`  in `#compute_windows()`, it would not be
            " executed when we  press `]z`, which would prevent  the latter from
            " moving the cursor to the end of a *new* open fold.
            "
            " It would work only after pressing it twice.
            " Indeed,  the first  time,  the fold  would be  closed  as soon  as
            " vim-fold executes:
            "
            "     let &l:fdm = b:last_fdm
            "
            " Btw, the reason why the fold seems to stay open is because `#go()`
            " runs `:norm! zv`  at the end; but it *is*  temporarily closed, and
            " it  *is* closed  right  before  `]z` is  pressed  by `#go()`  (via
            " `:norm`) for the first time in a new fold.
            "}}}
            " `:norm! zv` may be executed in an inactive window.{{{
            "
            " Which is ok.
            " It happens when `FileType` or `BufWritePost` are fired.
            "
            " `:norm! zv` is helpful when the buffer is reloaded (e.g. with `:e`).
            " When that happens:
            "
            "    - all the folds are deleted in all the windows displaying the buffer
            "
            "    - folds are recreated when  the foldmethod is temporarily reset
            "      to its original costly  value (e.g. 'expr'), and `foldclosed('.')`
            "      is evaluated
            "
            "    - the new folds are closed (if `'foldlevel'` is 0)
            "
            " If `norm! zv` was not executed in an inactive window, we would not
            " see the  contents of its  current fold  when we reload  the buffer
            " from another window.  I prefer to see it.
            "}}}
            norm! zv
        endif
    endif

    " and now get back to 'manual'
    let b:last_fdm = &l:fdm
    " Why this dummy assignment?{{{
    "
    " To make sure Vim recomputes folds, before we reset the foldmethod to manual.
    " Without, there is a risk that no fold would be created:
    "
    "     $ vim -Nu NONE -S <(cat <<'EOF'
    "         setl fml=0 fdm=manual fde=getline(v:lnum)=~#'^#'?'>1':'='
    "         %d|pu=repeat(['x'], 5)|1
    "     EOF
    "     ) /tmp/file
    "     " insert:  #
    "     " run:  setl fdm=expr | setl fdm=manual
    "     " no fold is created;
    "     " but a fold would have been created if you had run:
    "
    "         :setl fdm=expr | let _ = foldlevel(1) | setl fdm=manual
    "
    "      or
    "
    "         :setl fdm=expr | exe '1windo "' | setl fdm=manual
    "
    "      or
    "
    "         :setl fdm=expr
    "         :setl manual
    "
    " ---
    "
    " I don't know why/how it works, but the original FastFold plugin implicitly
    " relies on  a side effect  of `:windo`  for folds  to be  recomputed before
    " resetting the foldmethod to manual.
    "}}}
    "   Why not `:norm! zx`?{{{
    "
    " It does not preserve manually opened/closed folds.
    " Note that `winsaveview()` does not save fold information.
    "}}}
    let _ = foldlevel(1)
    setl fdm=manual
endfu

fu fold#lazy#handle_diff() abort "{{{2
    let enter_diff_mode = v:option_new == 1 && v:option_old == 0
    let leave_diff_mode = v:option_new == 0 && v:option_old == 1

    if enter_diff_mode && exists('b:last_fdm')
        let b:prediff_fdm = b:last_fdm
    elseif leave_diff_mode && exists('b:prediff_fdm')
        let &l:fdm = b:prediff_fdm
        let _ = foldlevel(1)
        unlet! b:prediff_fdm
    endif
endfu
"}}}1
" Utilities {{{1
fu s:should_skip() abort "{{{2
    return !s:is_costly() || !empty(&bt) || !&l:ma
endfu

fu s:is_costly() abort "{{{2
    let pat = '^\%(expr\|indent\|syntax\)$'
    return (exists('b:last_fdm') && b:last_fdm =~# pat) || &l:fdm =~# pat
endfu

