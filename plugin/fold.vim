if exists('g:loaded_fold')
    finish
endif
let g:loaded_fold = 1

" Why the `[Z` and `]Z` mappings?{{{
"
" By default the cursor is moved to the previous/next fold:
"
"     • no matter its level
"       with `zj` and `zk`
"
"     • on the condition its level is greater than the current one
"       with `[z` and `]z`
"
" I don't like the asymmetry between the 2 pairs of mappings.
" I prefer to use `[z`, `]z` and `[Z`, `]Z`.
"}}}
noremap  <expr><silent><unique>  [Z  fold#motion_rhs('[Z')
noremap  <expr><silent><unique>  ]Z  fold#motion_rhs(']Z')
noremap  <expr><silent><unique>  [z  fold#motion_rhs('[z')
noremap  <expr><silent><unique>  ]z  fold#motion_rhs(']z')
