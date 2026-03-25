vim9script

var jobs: dict<dict<any>> = {}
var job_id_counter: number = 0

def OutCb(jid: number, ch: channel, data: string)
    if has_key(jobs, string(jid)) && data != ''
        add(jobs[string(jid)].output, data)
    endif
enddef

def ErrCb(jid: number, ch: channel, data: string)
    if has_key(jobs, string(jid)) && jobs[string(jid)].err == ''
        jobs[string(jid)].err = data
    endif
enddef

def ExitCb(jid: number, j: job, status: number)
    if !has_key(jobs, string(jid))
        return
    endif
    var state = jobs[string(jid)]
    remove(jobs, string(jid))
    matchdelete(state.match_id)
    if status != 0 || empty(state.output)
        var msg = 'ImproveEnglish failed'
        if state.err != '' && len(state.err) <= 80
            msg ..= ': ' .. state.err
        endif
        echoerr msg
        return
    endif
    if !bufexists(state.bufnr)
        return
    endif
    var result = join(state.output, "\n")
    var trimmed = substitute(result, '\n\+$', '', '')
    var new_lines = split(trimmed, "\n")
    deletebufline(state.bufnr, state.line1, state.line2)
    appendbufline(state.bufnr, state.line1 - 1, new_lines)
enddef

export def ImproveEnglish(line1: number, line2: number)
    var lines = getline(line1, line2)
    var text = join(lines, "\n")

    if trim(text) == ''
        echoerr 'ImproveEnglish: selection is empty'
        return
    endif

    var prompt = get(g:, 'english_prompt', '')
    var backend = get(g:, 'english_backend', 'claude')

    if backend != 'claude'
        echoerr 'ImproveEnglish: unknown backend "' .. backend .. '"'
        return
    endif

    var model = get(g:, 'english_model', '')
    var cmd: list<string> = ['claude', '-p', prompt, '--output-format', 'text']
    if model != ''
        cmd->add('--model')
        cmd->add(model)
    endif

    var pending_pat = '\%>' .. (line1 - 1) .. 'l.\+\%<' .. (line2 + 1) .. 'l'
    var match_id = matchadd('ImproveEnglishPending', pending_pat)
    var buf = bufnr('%')

    job_id_counter += 1
    var jid = job_id_counter

    var job = job_start(cmd, {
        in_io:   'pipe',
        out_io:  'pipe',
        err_io:  'pipe',
        out_cb:  (ch, data) => OutCb(jid, ch, data),
        err_cb:  (ch, data) => ErrCb(jid, ch, data),
        exit_cb: (j, status) => ExitCb(jid, j, status),
    })

    if job_status(job) == 'fail'
        matchdelete(match_id)
        echoerr 'ImproveEnglish: failed to start backend'
        return
    endif

    jobs[string(jid)] = {bufnr: buf, line1: line1, line2: line2, match_id: match_id, output: [], err: ''}
    ch_sendraw(job_getchannel(job), text)
    ch_close_in(job_getchannel(job))
    echo 'Improving English...'
enddef
