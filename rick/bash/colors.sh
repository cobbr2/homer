#!/usr/bin/env bash
# Usage: source scripts/colors.sh
#   echo $(yellow Warning: $(red error) occurred)
#
# Each function joins its arguments with single spaces and wraps the result
# in the corresponding ANSI color. Nested color calls are handled by replacing
# inner reset codes with the outer color so the outer color is restored after
# nested spans, rather than falling back to the terminal default.
#
# For PS1, export _COLORIZE_PS1=1 while building the prompt string so escapes are
# wrapped in \[...\] (bash treats them as zero-width). Nested $(green $(red …))
# still works; unset _COLORIZE_PS1 when done. Sequences from tput(1) or OSC
# title bytes are not SGR — use ps1_nonprinting / ps1_title_* for those.

_colorize() {
    local code="$1"; shift
    local ESC=$'\033'
    local reset color
    if [[ -n "${_COLORIZE_PS1:-}" ]]; then
        reset="\[${ESC}[0m\]"
        color="\[${ESC}[${code}m\]"
    else
        reset="${ESC}[0m"
        color="${ESC}[${code}m"
    fi
    local text="$*"
    text="${text//$reset/$color}"
    printf '%s%s%s' "$color" "$text" "$reset"
}

red()    { _colorize 31 "$@"; }
green()  { _colorize 32 "$@"; }
yellow() { _colorize 33 "$@"; }
blue()   { _colorize 34 "$@"; }
bold()   { _colorize  1 "$@"; }
plain()  { _colorize  0 "$@"; }

# Wrap output that is not SGR (e.g. tput setab) for PS1 width accounting.
ps1_nonprinting() {
  printf '\[%s\]' "$1"
}

# OSC 0: set window + icon title (see xterm ctlseqs)
ps1_title_start() { printf '\[\033]0;'; }
ps1_title_end()   { printf '\007\]'; }
