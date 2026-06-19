vim9script

if exists('g:loaded_whhid') | finish | endif
g:loaded_whhid = 1

command! WhhidOpen   whhid#Open()
command! WhhidLink   whhid#Link()
command! WhhidUnlink whhid#Unlink()
