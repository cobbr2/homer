#!/usr/bin/env bash
# Usage: source scripts/colors.sh
#   echo $(yellow Warning: $(red error) occurred)
#
# Each function joins its arguments with single spaces and wraps the result
# in the corresponding ANSI color. Nested color calls are handled by replacing
# inner reset codes with the outer color so the outer color is restored after
# nested spans, rather than falling back to the terminal default.

_colorize() {
    local code="$1"; shift
    local ESC=$'\033'
    local reset="${ESC}[0m"
    local color="${ESC}[${code}m"
    local text="$*"
    # Restore outer color after any nested resets
    text="${text//$reset/$color}"
    printf '%s%s%s' "$color" "$text" "$reset"
}

red()    { _colorize 31 "$@"; }
green()  { _colorize 32 "$@"; }
yellow() { _colorize 33 "$@"; }
blue()   { _colorize 34 "$@"; }
bold()   { _colorize  1 "$@"; }
