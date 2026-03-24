vim9script

export def ImproveEnglish(line1: number, line2: number)
    var lines = getline(line1, line2)
    var text = join(lines, "\n")

    if trim(text) == ''
        echoerr 'ImproveEnglish: selection is empty'
        return
    endif

    var prompt = get(g:, 'english_prompt', '')
    var backend = get(g:, 'english_backend', 'claude')
    var result: string

    if backend == 'claude'
        var model = get(g:, 'english_model', '')
        var cmd = 'claude -p ' .. shellescape(prompt) .. ' --output-format text'
        if model != ''
            cmd ..= ' --model ' .. shellescape(model)
        endif
        echo 'Improving English...'
        result = system(cmd, text)
    else
        echoerr 'ImproveEnglish: unknown backend "' .. backend .. '"'
        return
    endif

    if v:shell_error != 0 || result == ''
        echoerr 'ImproveEnglish failed'
        return
    endif

    var trimmed = substitute(result, '\n\+$', '', '')
    var new_lines = split(trimmed, "\n")

    deletebufline('%', line1, line2)
    append(line1 - 1, new_lines)
enddef
