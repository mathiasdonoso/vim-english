# vim-english

For non-native English speakers who write a lot of code comments, commit messages, and documentation — without leaving the editor.

Select any text in Vim and have it corrected and improved in place by an AI.

## Motivation

Because sometimes you want to write code on your own. Keeping your programming skills sharp means resisting the urge to offload every problem to an AI — and that is a deliberate choice worth protecting. But when English is not your first language, writing clear comments and docs gets in the way. This plugin helps with just that.

## Requirements

- Vim 9.0+
- [Claude Code CLI](https://github.com/anthropics/claude-code) installed and authenticated (`claude` in `$PATH`)

## Installation

```sh
git clone https://github.com/mathiasdonoso/vim-english \
  ~/.vim/pack/plugins/start/vim-english
```

## Demo

![vim-english demo](assets/demo.gif)

## Usage

Visually select the text you want to improve, then press `<leader>ie`.

```
v{motion}  →  <leader>ie
V{motion}  →  <leader>ie
```

Or use the ex command directly with a range:

```vim
'<,'>ImproveEnglish
```

The selected lines are replaced in-place with the improved version.

## Supported Backends and Models

### Backends

| Backend | Value | CLI |
|---|---|---|
| Claude Code | `'claude'` | [`claude`](https://github.com/anthropics/claude-code) |

Support for other AI CLIs (e.g. `aichat`, `llm`, `ollama`) may be added in the future — contributions are very welcome!

### Models (Claude)

Any Claude model can be used via `g:english_model`. Recommended options:

| Model ID | Notes |
|---|---|
| `claude-haiku-4-5-20251001` | Default — fast and cost-efficient, great for grammar fixes |
| `claude-sonnet-4-6` | More capable, better for nuanced rewrites |
| `claude-opus-4-6` | Most capable, slower and more expensive |

## Configuration

Set these variables in your `vimrc` before the plugin loads:

| Variable | Default | Description |
|---|---|---|
| `g:english_backend` | `'claude'` | CLI backend to use |
| `g:english_model` | `'claude-haiku-4-5-20251001'` | Model passed to the CLI |
| `g:english_prompt` | *(English improvement prompt)* | System prompt sent to the model |

Example:

```vim
" Use a more capable model
let g:english_model = 'claude-sonnet-4-6'

" Custom prompt — fix grammar only, keep the tone
let g:english_prompt = 'Fix grammar and spelling only. Do not change the tone or structure. Output only the corrected text.'
```
