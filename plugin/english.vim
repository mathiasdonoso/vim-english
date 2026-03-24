vim9script

if !exists('g:english_prompt')
    g:english_prompt = 'Improve the English grammar, clarity, and style of the following text. Preserve the original meaning and structure. Output ONLY the improved text with no preamble, explanations, or comments.'
endif

if !exists('g:english_backend')
    g:english_backend = 'claude'
endif

if !exists('g:english_model')
    g:english_model = 'claude-haiku-4-5-20251001'
endif

highlight default ImproveEnglishPending cterm=italic ctermfg=darkgrey gui=italic guifg=#888888

command -range=% ImproveEnglish call english#ImproveEnglish(<line1>, <line2>)

xnoremap <leader>ie :<C-u>'<,'>ImproveEnglish<CR>
