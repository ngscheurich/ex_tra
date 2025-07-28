" Elixir Transform for Vim
" Minimal plugin to run Elixir transforms on visually selected text using the `extra` binary.
" Place this file in ~/.vim/plugin/ or source it manually.

" Path to the extra binary (edit as needed)
let g:elixir_transform_extra_bin = '~/.vim/plugin/elixir-transform/extra'

function! ElixirTransformEscape(str) abort
  " Escape backslashes, double quotes, and #{
  let s = substitute(a:str, '\\', '\\\\', 'g')
  let s = substitute(s, '"', '\\"', 'g')
  let s = substitute(s, '#{', '\\#{', 'g')
  return s
endfunction

function! ElixirTransform() range abort
  " Get visually selected text
  let l:start = getpos("'<")[1]
  let l:end   = getpos("'>")[1]
  let l:lines = getline(l:start, l:end)
  let l:selected = join(l:lines, "\n")

  if empty(l:selected)
    echoerr "No text selected!"
    return
  endif

  " List available transforms
  let l:cmd = g:elixir_transform_extra_bin . ' list_transforms'
  let l:raw_transforms = system(l:cmd)
  if v:shell_error
    echoerr "Error running 'extra list_transforms'"
    return
  endif
  let l:transforms = split(trim(l:raw_transforms), ',\s*')

  if empty(l:transforms)
    echoerr "No transforms found!"
    return
  endif

  " Prompt user to select transform
  let l:choice = inputlist(['Elixir Transform:'] + l:transforms)
  if l:choice < 1 || l:choice > len(l:transforms)
    echoerr "No command selected!"
    return
  endif
  let l:function_name = l:transforms[l:choice - 1]

  " Escape selected text
  let l:escaped = ElixirTransformEscape(l:selected)

  " Run the transform
  let l:transform_cmd = printf('%s %s "%s"', g:elixir_transform_extra_bin, l:function_name, l:escaped)
  let l:result = system(l:transform_cmd)
  if v:shell_error
    echoerr "Error executing transform: " . l:result
    return
  endif

  " Replace selection with result
  " Save and restore cursor position
  let l:view = winsaveview()
  call setline(l:start, split(l:result, "\n"))
  if l:end > l:start
    call deletebufline(bufnr('%'), l:start + 1, l:end)
  endif
  call winrestview(l:view)
endfunction

" Visual mode mapping (adjust <leader>tt as desired)
xnoremap <silent> <leader>tt :<C-u>call ElixirTransform()<CR>
