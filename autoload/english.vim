vim9script

var jobs: dict<dict<any>> = {}
var job_id_counter: number = 0
var spinner_tick: number = 0
const spinner_frames: list<string> = [' .', ' ..', ' ...']

if empty(prop_type_get('ImproveEnglishSpinner'))
    prop_type_add('ImproveEnglishSpinner', {highlight: 'ImproveEnglishSpinner'})
endif

def OutCb(jid: number, ch: channel, data: string)
    if has_key(jobs, string(jid)) && data != ''
        add(jobs[string(jid)].output, data)
    endif
enddef

def ErrCb(jid: number, ch: channel, data: string)
    if has_key(jobs, string(jid)) && data != ''
        add(jobs[string(jid)].err_lines, data)
    endif
enddef

def SpinnerTick(jid: number, timer_id: number)
    if !has_key(jobs, string(jid))
        return
    endif
    spinner_tick = (spinner_tick + 1) % 3
    var frame = spinner_frames[spinner_tick]
    var state = jobs[string(jid)]
    echo 'Improving English' .. frame
    prop_remove({type: 'ImproveEnglishSpinner', bufnr: state.bufnr, all: true}, state.line1, state.line1)
    prop_add(state.line1, 0, {
        type:       'ImproveEnglishSpinner',
        text:       frame,
        text_align: 'after',
        bufnr:      state.bufnr,
    })
    redraw
enddef

def ExitCb(jid: number, j: job, status: number)
    if !has_key(jobs, string(jid))
        return
    endif
    var state = jobs[string(jid)]
    remove(jobs, string(jid))
    timer_stop(state.timer_id)
    prop_remove({type: 'ImproveEnglishSpinner', bufnr: state.bufnr, all: true})
    echo ''
    matchdelete(state.match_id)
    if status != 0 || empty(state.output)
        var msg = 'ImproveEnglish failed'
        var err_detail = ''
        for line in state.err_lines
            if len(line) <= 80
                err_detail = line
                break
            endif
        endfor
        if err_detail != ''
            msg ..= ': ' .. err_detail
        endif
        echoerr msg
        return
    endif
    if !bufexists(state.bufnr)
        return
    endif
    if getbufline(state.bufnr, state.line1, state.line2) != state.original_lines
        echoerr 'ImproveEnglish: buffer changed while job was running, result discarded'
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
    if empty(prompt)
        prompt = 'Improve the English grammar, clarity, and style of the following text. Preserve the original meaning and structure. Output ONLY the improved text with no preamble, explanations, or comments.'
    endif
    var backend = get(g:, 'english_backend', 'claude')

    if backend != 'claude'
        echoerr 'ImproveEnglish: unknown backend "' .. backend .. '"'
        return
    endif

    if !executable(backend)
        echoerr 'ImproveEnglish: backend executable "' .. backend .. '" not found in PATH'
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

    jobs[string(jid)] = {bufnr: buf, line1: line1, line2: line2,
                         match_id: match_id, output: [], err_lines: [],
                         original_lines: lines, timer_id: 0}
    ch_sendraw(job_getchannel(job), text)
    ch_close_in(job_getchannel(job))

    var tid = timer_start(400, (t) => SpinnerTick(jid, t), {repeat: -1})
    jobs[string(jid)].timer_id = tid

    echo 'Improving English .'
    prop_add(line1, 0, {type: 'ImproveEnglishSpinner', text: ' .', text_align: 'after'})
    redraw
enddef
