syntax clear
syntax region nbtString start=/"/ skip=/\\./ end=/"/ oneline
syntax region nbtString start=/'/ skip=/\\./ end=/'/ oneline
syntax match nbtKey /[A-Za-z_][A-Za-z0-9_+.-]*\ze\s*:/
syntax match nbtArrayType /\[[BIL];/
syntax match nbtNumber /[-+]\?\%(\d\+\.\?\d*\|\.\d\+\)\%([eE][-+]\?\d\+\)\?[bBsSlLfFdD]\?\>/
syntax keyword nbtBoolean true false
syntax match nbtPunct /[{}\[\],:]/
highlight default link nbtString String
highlight default link nbtKey Identifier
highlight default link nbtArrayType Type
highlight default link nbtNumber Number
highlight default link nbtBoolean Boolean
highlight default link nbtPunct Delimiter
let b:current_syntax = "nbt"
