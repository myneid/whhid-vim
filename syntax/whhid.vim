vim9script

if exists('b:current_syntax') | finish | endif

syntax match WhhidHeader   /^ .*/               contained
syntax match WhhidList     /^ ▸ .*/
syntax match WhhidUrgent   /^   !! .*/
syntax match WhhidHigh     /^   !  .*/
syntax match WhhidCard     /^   ·  .*/
syntax match WhhidCardPlain /^      .*/
syntax match WhhidFooter   /^ \[.\].*/

highlight default link WhhidHeader   Title
highlight default link WhhidList     Statement
highlight default link WhhidUrgent   ErrorMsg
highlight default link WhhidHigh     WarningMsg
highlight default link WhhidCard     Normal
highlight default link WhhidCardPlain Normal
highlight default link WhhidFooter   Comment

b:current_syntax = 'whhid'
