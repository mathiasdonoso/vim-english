vim9script

var jobs: dict<dict<any>> = {}
var job_id_counter: number = 0
var spinner_tick: number = 0
const spinner_frames: list<string> = [' .', ' ..', ' ...']

if empty(prop_type_get('ImproveEnglishSpinner'))
    prop_type_add('ImproveEnglishSpinner', {highlight: 'ImproveEnglishSpinner'})
endif

def OutCb(jid: number, ch: channel, data: string)
    if has_key(jobs, string(jid))
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
    var cur_prop = prop_find({type: state.anchor_start_type, lnum: 1, bufnr: state.bufnr})
    if empty(cur_prop)
        return
    endif
    var cur_line = cur_prop.lnum
    echo 'Improving English' .. frame
    prop_remove({type: 'ImproveEnglishSpinner', bufnr: state.bufnr, all: true})
    prop_add(cur_line, 0, {
        type:       'ImproveEnglishSpinner',
        text:       frame,
        text_align: 'after',
        bufnr:      state.bufnr,
    })
    redraw
enddef

def TimeoutHandler(jid: number, timer_id: number)
    if !has_key(jobs, string(jid))
        return
    endif
    var state = jobs[string(jid)]
    remove(jobs, string(jid))
    timer_stop(state.timer_id)
    job_stop(state.job)
    prop_remove({type: 'ImproveEnglishSpinner', bufnr: state.bufnr, all: true})
    prop_remove({type: state.pending_type, bufnr: state.bufnr, all: true})
    prop_type_delete(state.pending_type)
    prop_type_delete(state.anchor_start_type)
    prop_type_delete(state.anchor_end_type)
    echo ''
    echoerr 'ImproveEnglish: timed out'
enddef

def ExitCb(jid: number, j: job, status: number)
    if !has_key(jobs, string(jid))
        return
    endif
    var state = jobs[string(jid)]
    remove(jobs, string(jid))
    timer_stop(state.timer_id)
    timer_stop(state.timeout_id)
    prop_remove({type: 'ImproveEnglishSpinner', bufnr: state.bufnr, all: true})
    prop_remove({type: state.pending_type, bufnr: state.bufnr, all: true})
    prop_type_delete(state.pending_type)
    echo ''
    if status != 0 || empty(state.output)
        prop_type_delete(state.anchor_start_type)
        prop_type_delete(state.anchor_end_type)
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
        prop_type_delete(state.anchor_start_type)
        prop_type_delete(state.anchor_end_type)
        return
    endif
    var start_prop = prop_find({type: state.anchor_start_type, lnum: 1, bufnr: state.bufnr})
    var end_prop   = prop_find({type: state.anchor_end_type,   lnum: 1, bufnr: state.bufnr})
    prop_type_delete(state.anchor_start_type)
    prop_type_delete(state.anchor_end_type)
    if empty(start_prop) || empty(end_prop)
        echoerr 'ImproveEnglish: selected text was deleted, result discarded'
        return
    endif
    var new_line1 = start_prop.lnum
    var new_line2 = end_prop.lnum
    if getbufline(state.bufnr, new_line1, new_line2) != state.original_lines
        echoerr 'ImproveEnglish: selected text was modified, result discarded'
        return
    endif
    var result = join(state.output, "\n")
    var trimmed = substitute(result, '\n\+$', '', '')
    if trimmed == 'ERROR:NO_TEXT'
        echohl WarningMsg
        echo 'ImproveEnglish: backend received no text'
        echohl None
        return
    endif
    var new_lines = split(trimmed, "\n", 1)
    deletebufline(state.bufnr, new_line1, new_line2)
    appendbufline(state.bufnr, new_line1 - 1, new_lines)
    echo 'English improved'
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
    prompt ..= ' If you receive no text to improve, output exactly: ERROR:NO_TEXT'
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

    var buf = bufnr('%')

    job_id_counter += 1
    var jid = job_id_counter

    var start_type   = 'ImproveEnglishAnchorStart_' .. jid
    var end_type     = 'ImproveEnglishAnchorEnd_' .. jid
    var pending_type = 'ImproveEnglishPending_' .. jid
    prop_type_add(start_type, {})
    prop_type_add(end_type, {})
    prop_type_add(pending_type, {highlight: 'ImproveEnglishPending'})
    prop_add(line1, 1, {type: start_type, bufnr: buf})
    prop_add(line2, 1, {type: end_type,   bufnr: buf})
    prop_add(line1, 1, {
        type:     pending_type,
        end_lnum: line2,
        end_col:  len(getline(line2)) + 1,
        bufnr:    buf,
    })

    var job = job_start(cmd, {
        in_io:   'pipe',
        out_io:  'pipe',
        err_io:  'pipe',
        out_cb:  (ch, data) => OutCb(jid, ch, data),
        err_cb:  (ch, data) => ErrCb(jid, ch, data),
        exit_cb: (j, status) => ExitCb(jid, j, status),
    })

    if job_status(job) == 'fail'
        prop_remove({type: pending_type, bufnr: buf, all: true})
        prop_type_delete(pending_type)
        prop_type_delete(start_type)
        prop_type_delete(end_type)
        echoerr 'ImproveEnglish: failed to start backend'
        return
    endif

    var timeout_ms = get(g:, 'english_timeout', 30000)

    jobs[string(jid)] = {bufnr: buf, line1: line1, line2: line2,
                         pending_type: pending_type, output: [], err_lines: [],
                         original_lines: lines, job: job, timer_id: 0, timeout_id: 0,
                         anchor_start_type: start_type, anchor_end_type: end_type}
    ch_sendraw(job_getchannel(job), text)
    ch_close_in(job_getchannel(job))

    var tid = timer_start(400, (t) => SpinnerTick(jid, t), {repeat: -1})
    jobs[string(jid)].timer_id = tid

    var xid = timer_start(timeout_ms, (t) => TimeoutHandler(jid, t))
    jobs[string(jid)].timeout_id = xid

    echo 'Improving English .'
    prop_add(line1, 0, {type: 'ImproveEnglishSpinner', text: ' .', text_align: 'after'})
    redraw
enddef
