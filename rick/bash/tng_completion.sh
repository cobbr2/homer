# bash completion for tng                                  -*- shell-script -*-
# Update using `tng completion > <this file>`

__tng_debug()
{
    if [[ -n ${BASH_COMP_DEBUG_FILE:-} ]]; then
        echo "$*" >> "${BASH_COMP_DEBUG_FILE}"
    fi
}

# Homebrew on Macs have version 1.3 of bash-completion which doesn't include
# _init_completion. This is a very minimal version of that function.
__tng_init_completion()
{
    COMPREPLY=()
    _get_comp_words_by_ref "$@" cur prev words cword
}

__tng_index_of_word()
{
    local w word=$1
    shift
    index=0
    for w in "$@"; do
        [[ $w = "$word" ]] && return
        index=$((index+1))
    done
    index=-1
}

__tng_contains_word()
{
    local w word=$1; shift
    for w in "$@"; do
        [[ $w = "$word" ]] && return
    done
    return 1
}

__tng_handle_go_custom_completion()
{
    __tng_debug "${FUNCNAME[0]}: cur is ${cur}, words[*] is ${words[*]}, #words[@] is ${#words[@]}"

    local shellCompDirectiveError=1
    local shellCompDirectiveNoSpace=2
    local shellCompDirectiveNoFileComp=4
    local shellCompDirectiveFilterFileExt=8
    local shellCompDirectiveFilterDirs=16

    local out requestComp lastParam lastChar comp directive args

    # Prepare the command to request completions for the program.
    # Calling ${words[0]} instead of directly tng allows handling aliases
    args=("${words[@]:1}")
    # Disable ActiveHelp which is not supported for bash completion v1
    requestComp="TNG_ACTIVE_HELP=0 ${words[0]} __completeNoDesc ${args[*]}"

    lastParam=${words[$((${#words[@]}-1))]}
    lastChar=${lastParam:$((${#lastParam}-1)):1}
    __tng_debug "${FUNCNAME[0]}: lastParam ${lastParam}, lastChar ${lastChar}"

    if [ -z "${cur}" ] && [ "${lastChar}" != "=" ]; then
        # If the last parameter is complete (there is a space following it)
        # We add an extra empty parameter so we can indicate this to the go method.
        __tng_debug "${FUNCNAME[0]}: Adding extra empty parameter"
        requestComp="${requestComp} \"\""
    fi

    __tng_debug "${FUNCNAME[0]}: calling ${requestComp}"
    # Use eval to handle any environment variables and such
    out=$(eval "${requestComp}" 2>/dev/null)

    # Extract the directive integer at the very end of the output following a colon (:)
    directive=${out##*:}
    # Remove the directive
    out=${out%:*}
    if [ "${directive}" = "${out}" ]; then
        # There is not directive specified
        directive=0
    fi
    __tng_debug "${FUNCNAME[0]}: the completion directive is: ${directive}"
    __tng_debug "${FUNCNAME[0]}: the completions are: ${out}"

    if [ $((directive & shellCompDirectiveError)) -ne 0 ]; then
        # Error code.  No completion.
        __tng_debug "${FUNCNAME[0]}: received error from custom completion go code"
        return
    else
        if [ $((directive & shellCompDirectiveNoSpace)) -ne 0 ]; then
            if [[ $(type -t compopt) = "builtin" ]]; then
                __tng_debug "${FUNCNAME[0]}: activating no space"
                compopt -o nospace
            fi
        fi
        if [ $((directive & shellCompDirectiveNoFileComp)) -ne 0 ]; then
            if [[ $(type -t compopt) = "builtin" ]]; then
                __tng_debug "${FUNCNAME[0]}: activating no file completion"
                compopt +o default
            fi
        fi
    fi

    if [ $((directive & shellCompDirectiveFilterFileExt)) -ne 0 ]; then
        # File extension filtering
        local fullFilter filter filteringCmd
        # Do not use quotes around the $out variable or else newline
        # characters will be kept.
        for filter in ${out}; do
            fullFilter+="$filter|"
        done

        filteringCmd="_filedir $fullFilter"
        __tng_debug "File filtering command: $filteringCmd"
        $filteringCmd
    elif [ $((directive & shellCompDirectiveFilterDirs)) -ne 0 ]; then
        # File completion for directories only
        local subdir
        # Use printf to strip any trailing newline
        subdir=$(printf "%s" "${out}")
        if [ -n "$subdir" ]; then
            __tng_debug "Listing directories in $subdir"
            __tng_handle_subdirs_in_dir_flag "$subdir"
        else
            __tng_debug "Listing directories in ."
            _filedir -d
        fi
    else
        while IFS='' read -r comp; do
            COMPREPLY+=("$comp")
        done < <(compgen -W "${out}" -- "$cur")
    fi
}

__tng_handle_reply()
{
    __tng_debug "${FUNCNAME[0]}"
    local comp
    case $cur in
        -*)
            if [[ $(type -t compopt) = "builtin" ]]; then
                compopt -o nospace
            fi
            local allflags
            if [ ${#must_have_one_flag[@]} -ne 0 ]; then
                allflags=("${must_have_one_flag[@]}")
            else
                allflags=("${flags[*]} ${two_word_flags[*]}")
            fi
            while IFS='' read -r comp; do
                COMPREPLY+=("$comp")
            done < <(compgen -W "${allflags[*]}" -- "$cur")
            if [[ $(type -t compopt) = "builtin" ]]; then
                [[ "${COMPREPLY[0]}" == *= ]] || compopt +o nospace
            fi

            # complete after --flag=abc
            if [[ $cur == *=* ]]; then
                if [[ $(type -t compopt) = "builtin" ]]; then
                    compopt +o nospace
                fi

                local index flag
                flag="${cur%=*}"
                __tng_index_of_word "${flag}" "${flags_with_completion[@]}"
                COMPREPLY=()
                if [[ ${index} -ge 0 ]]; then
                    PREFIX=""
                    cur="${cur#*=}"
                    ${flags_completion[${index}]}
                    if [ -n "${ZSH_VERSION:-}" ]; then
                        # zsh completion needs --flag= prefix
                        eval "COMPREPLY=( \"\${COMPREPLY[@]/#/${flag}=}\" )"
                    fi
                fi
            fi

            if [[ -z "${flag_parsing_disabled}" ]]; then
                # If flag parsing is enabled, we have completed the flags and can return.
                # If flag parsing is disabled, we may not know all (or any) of the flags, so we fallthrough
                # to possibly call handle_go_custom_completion.
                return 0;
            fi
            ;;
    esac

    # check if we are handling a flag with special work handling
    local index
    __tng_index_of_word "${prev}" "${flags_with_completion[@]}"
    if [[ ${index} -ge 0 ]]; then
        ${flags_completion[${index}]}
        return
    fi

    # we are parsing a flag and don't have a special handler, no completion
    if [[ ${cur} != "${words[cword]}" ]]; then
        return
    fi

    local completions
    completions=("${commands[@]}")
    if [[ ${#must_have_one_noun[@]} -ne 0 ]]; then
        completions+=("${must_have_one_noun[@]}")
    elif [[ -n "${has_completion_function}" ]]; then
        # if a go completion function is provided, defer to that function
        __tng_handle_go_custom_completion
    fi
    if [[ ${#must_have_one_flag[@]} -ne 0 ]]; then
        completions+=("${must_have_one_flag[@]}")
    fi
    while IFS='' read -r comp; do
        COMPREPLY+=("$comp")
    done < <(compgen -W "${completions[*]}" -- "$cur")

    if [[ ${#COMPREPLY[@]} -eq 0 && ${#noun_aliases[@]} -gt 0 && ${#must_have_one_noun[@]} -ne 0 ]]; then
        while IFS='' read -r comp; do
            COMPREPLY+=("$comp")
        done < <(compgen -W "${noun_aliases[*]}" -- "$cur")
    fi

    if [[ ${#COMPREPLY[@]} -eq 0 ]]; then
        if declare -F __tng_custom_func >/dev/null; then
            # try command name qualified custom func
            __tng_custom_func
        else
            # otherwise fall back to unqualified for compatibility
            declare -F __custom_func >/dev/null && __custom_func
        fi
    fi

    # available in bash-completion >= 2, not always present on macOS
    if declare -F __ltrim_colon_completions >/dev/null; then
        __ltrim_colon_completions "$cur"
    fi

    # If there is only 1 completion and it is a flag with an = it will be completed
    # but we don't want a space after the =
    if [[ "${#COMPREPLY[@]}" -eq "1" ]] && [[ $(type -t compopt) = "builtin" ]] && [[ "${COMPREPLY[0]}" == --*= ]]; then
       compopt -o nospace
    fi
}

# The arguments should be in the form "ext1|ext2|extn"
__tng_handle_filename_extension_flag()
{
    local ext="$1"
    _filedir "@(${ext})"
}

__tng_handle_subdirs_in_dir_flag()
{
    local dir="$1"
    pushd "${dir}" >/dev/null 2>&1 && _filedir -d && popd >/dev/null 2>&1 || return
}

__tng_handle_flag()
{
    __tng_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    # if a command required a flag, and we found it, unset must_have_one_flag()
    local flagname=${words[c]}
    local flagvalue=""
    # if the word contained an =
    if [[ ${words[c]} == *"="* ]]; then
        flagvalue=${flagname#*=} # take in as flagvalue after the =
        flagname=${flagname%=*} # strip everything after the =
        flagname="${flagname}=" # but put the = back
    fi
    __tng_debug "${FUNCNAME[0]}: looking for ${flagname}"
    if __tng_contains_word "${flagname}" "${must_have_one_flag[@]}"; then
        must_have_one_flag=()
    fi

    # if you set a flag which only applies to this command, don't show subcommands
    if __tng_contains_word "${flagname}" "${local_nonpersistent_flags[@]}"; then
      commands=()
    fi

    # keep flag value with flagname as flaghash
    # flaghash variable is an associative array which is only supported in bash > 3.
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        if [ -n "${flagvalue}" ] ; then
            flaghash[${flagname}]=${flagvalue}
        elif [ -n "${words[ $((c+1)) ]}" ] ; then
            flaghash[${flagname}]=${words[ $((c+1)) ]}
        else
            flaghash[${flagname}]="true" # pad "true" for bool flag
        fi
    fi

    # skip the argument to a two word flag
    if [[ ${words[c]} != *"="* ]] && __tng_contains_word "${words[c]}" "${two_word_flags[@]}"; then
        __tng_debug "${FUNCNAME[0]}: found a flag ${words[c]}, skip the next argument"
        c=$((c+1))
        # if we are looking for a flags value, don't show commands
        if [[ $c -eq $cword ]]; then
            commands=()
        fi
    fi

    c=$((c+1))

}

__tng_handle_noun()
{
    __tng_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    if __tng_contains_word "${words[c]}" "${must_have_one_noun[@]}"; then
        must_have_one_noun=()
    elif __tng_contains_word "${words[c]}" "${noun_aliases[@]}"; then
        must_have_one_noun=()
    fi

    nouns+=("${words[c]}")
    c=$((c+1))
}

__tng_handle_command()
{
    __tng_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    local next_command
    if [[ -n ${last_command} ]]; then
        next_command="_${last_command}_${words[c]//:/__}"
    else
        if [[ $c -eq 0 ]]; then
            next_command="_tng_root_command"
        else
            next_command="_${words[c]//:/__}"
        fi
    fi
    c=$((c+1))
    __tng_debug "${FUNCNAME[0]}: looking for ${next_command}"
    declare -F "$next_command" >/dev/null && $next_command
}

__tng_handle_word()
{
    if [[ $c -ge $cword ]]; then
        __tng_handle_reply
        return
    fi
    __tng_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"
    if [[ "${words[c]}" == -* ]]; then
        __tng_handle_flag
    elif __tng_contains_word "${words[c]}" "${commands[@]}"; then
        __tng_handle_command
    elif [[ $c -eq 0 ]]; then
        __tng_handle_command
    elif __tng_contains_word "${words[c]}" "${command_aliases[@]}"; then
        # aliashash variable is an associative array which is only supported in bash > 3.
        if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
            words[c]=${aliashash[${words[c]}]}
            __tng_handle_command
        else
            __tng_handle_noun
        fi
    else
        __tng_handle_noun
    fi
    __tng_handle_word
}

_tng_auth_aws_assume-role()
{
    last_command="tng_auth_aws_assume-role"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--force-sts")
    local_nonpersistent_flags+=("--force-sts")
    flags+=("--no-cache")
    flags+=("-N")
    local_nonpersistent_flags+=("--no-cache")
    local_nonpersistent_flags+=("-N")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_auth_aws_exec-role()
{
    last_command="tng_auth_aws_exec-role"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--force-sts")
    local_nonpersistent_flags+=("--force-sts")
    flags+=("--no-cache")
    flags+=("-N")
    local_nonpersistent_flags+=("--no-cache")
    local_nonpersistent_flags+=("-N")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    local_nonpersistent_flags+=("-r")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_auth_aws_list-roles()
{
    last_command="tng_auth_aws_list-roles"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--refresh")
    local_nonpersistent_flags+=("--refresh")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_auth_aws()
{
    last_command="tng_auth_aws"

    command_aliases=()

    commands=()
    commands+=("assume-role")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("ar")
        aliashash["ar"]="assume-role"
        command_aliases+=("assume")
        aliashash["assume"]="assume-role"
        command_aliases+=("login")
        aliashash["login"]="assume-role"
    fi
    commands+=("exec-role")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("exec")
        aliashash["exec"]="exec-role"
        command_aliases+=("shell")
        aliashash["shell"]="exec-role"
    fi
    commands+=("list-roles")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("list")
        aliashash["list"]="list-roles"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_auth()
{
    last_command="tng_auth"

    command_aliases=()

    commands=()
    commands+=("aws")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_breakglass_check-access()
{
    last_command="tng_breakglass_check-access"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_breakglass_request()
{
    last_command="tng_breakglass_request"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--dry-run")
    local_nonpersistent_flags+=("--dry-run")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tng_breakglass_status()
{
    last_command="tng_breakglass_status"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--dry-run")
    local_nonpersistent_flags+=("--dry-run")
    flags+=("--timezone=")
    two_word_flags+=("--timezone")
    local_nonpersistent_flags+=("--timezone")
    local_nonpersistent_flags+=("--timezone=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_breakglass()
{
    last_command="tng_breakglass"

    command_aliases=()

    commands=()
    commands+=("check-access")
    commands+=("request")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("run")
        aliashash["run"]="request"
        command_aliases+=("start")
        aliashash["start"]="request"
    fi
    commands+=("status")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_codegen_clean()
{
    last_command="tng_codegen_clean"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_codegen_inputs()
{
    last_command="tng_codegen_inputs"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    local_nonpersistent_flags+=("--all")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_codegen_outputs()
{
    last_command="tng_codegen_outputs"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_codegen_run()
{
    last_command="tng_codegen_run"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--auto-update")
    flags+=("-a")
    local_nonpersistent_flags+=("--auto-update")
    local_nonpersistent_flags+=("-a")
    flags+=("--disable-generator=")
    two_word_flags+=("--disable-generator")
    two_word_flags+=("-d")
    local_nonpersistent_flags+=("--disable-generator")
    local_nonpersistent_flags+=("--disable-generator=")
    local_nonpersistent_flags+=("-d")
    flags+=("--generator=")
    two_word_flags+=("--generator")
    two_word_flags+=("-g")
    local_nonpersistent_flags+=("--generator")
    local_nonpersistent_flags+=("--generator=")
    local_nonpersistent_flags+=("-g")
    flags+=("--needed")
    flags+=("-n")
    local_nonpersistent_flags+=("--needed")
    local_nonpersistent_flags+=("-n")
    flags+=("--update")
    flags+=("-u")
    local_nonpersistent_flags+=("--update")
    local_nonpersistent_flags+=("-u")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_codegen_update()
{
    last_command="tng_codegen_update"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--disable-generator=")
    two_word_flags+=("--disable-generator")
    two_word_flags+=("-d")
    local_nonpersistent_flags+=("--disable-generator")
    local_nonpersistent_flags+=("--disable-generator=")
    local_nonpersistent_flags+=("-d")
    flags+=("--generator=")
    two_word_flags+=("--generator")
    two_word_flags+=("-g")
    local_nonpersistent_flags+=("--generator")
    local_nonpersistent_flags+=("--generator=")
    local_nonpersistent_flags+=("-g")
    flags+=("--mockery.migrate")
    local_nonpersistent_flags+=("--mockery.migrate")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_codegen()
{
    last_command="tng_codegen"

    command_aliases=()

    commands=()
    commands+=("clean")
    commands+=("inputs")
    commands+=("outputs")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("sentinels")
        aliashash["sentinels"]="outputs"
    fi
    commands+=("run")
    commands+=("update")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("init")
        aliashash["init"]="update"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_completion()
{
    last_command="tng_completion"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--help")
    flags+=("-h")
    local_nonpersistent_flags+=("--help")
    local_nonpersistent_flags+=("-h")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    must_have_one_noun+=("bash")
    must_have_one_noun+=("fish")
    must_have_one_noun+=("powershell")
    must_have_one_noun+=("zsh")
    noun_aliases=()
}

_tng_compute_kill()
{
    last_command="tng_compute_kill"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_compute_list()
{
    last_command="tng_compute_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--age=")
    two_word_flags+=("--age")
    two_word_flags+=("-a")
    flags+=("--status=")
    two_word_flags+=("--status")
    two_word_flags+=("-s")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_compute_logs()
{
    last_command="tng_compute_logs"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--follow")
    flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_compute_status()
{
    last_command="tng_compute_status"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_compute_submit()
{
    last_command="tng_compute_submit"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_compute()
{
    last_command="tng_compute"

    command_aliases=()

    commands=()
    commands+=("kill")
    commands+=("list")
    commands+=("logs")
    commands+=("status")
    commands+=("submit")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_config_cd_disable()
{
    last_command="tng_config_cd_disable"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_config_cd_enable()
{
    last_command="tng_config_cd_enable"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_config_cd_status()
{
    last_command="tng_config_cd_status"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_config_cd()
{
    last_command="tng_config_cd"

    command_aliases=()

    commands=()
    commands+=("disable")
    commands+=("enable")
    commands+=("status")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_config_dir()
{
    last_command="tng_config_dir"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_config_dump()
{
    last_command="tng_config_dump"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_config_rev-dir()
{
    last_command="tng_config_rev-dir"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_config_validate()
{
    last_command="tng_config_validate"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--descriptor=")
    two_word_flags+=("--descriptor")
    two_word_flags+=("-d")
    local_nonpersistent_flags+=("--descriptor")
    local_nonpersistent_flags+=("--descriptor=")
    local_nonpersistent_flags+=("-d")
    flags+=("--repository=")
    two_word_flags+=("--repository")
    local_nonpersistent_flags+=("--repository")
    local_nonpersistent_flags+=("--repository=")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--skip-remote")
    local_nonpersistent_flags+=("--skip-remote")
    flags+=("--type=")
    two_word_flags+=("--type")
    two_word_flags+=("-t")
    local_nonpersistent_flags+=("--type")
    local_nonpersistent_flags+=("--type=")
    local_nonpersistent_flags+=("-t")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_config()
{
    last_command="tng_config"

    command_aliases=()

    commands=()
    commands+=("cd")
    commands+=("dir")
    commands+=("dump")
    commands+=("rev-dir")
    commands+=("validate")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_cronjob_start()
{
    last_command="tng_cronjob_start"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--descriptor=")
    two_word_flags+=("--descriptor")
    two_word_flags+=("-d")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tng_cronjob()
{
    last_command="tng_cronjob"

    command_aliases=()

    commands=()
    commands+=("start")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("run")
        aliashash["run"]="start"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--descriptor=")
    two_word_flags+=("--descriptor")
    two_word_flags+=("-d")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_deploy_block_add()
{
    last_command="tng_deploy_block_add"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_deploy_block_remove()
{
    last_command="tng_deploy_block_remove"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--confirm")
    flags+=("-y")
    local_nonpersistent_flags+=("--confirm")
    local_nonpersistent_flags+=("-y")
    flags+=("--reason=")
    two_word_flags+=("--reason")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--reason")
    local_nonpersistent_flags+=("--reason=")
    local_nonpersistent_flags+=("-r")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_deploy_block_status()
{
    last_command="tng_deploy_block_status"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_deploy_block()
{
    last_command="tng_deploy_block"

    command_aliases=()

    commands=()
    commands+=("add")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("create")
        aliashash["create"]="add"
        command_aliases+=("set")
        aliashash["set"]="add"
    fi
    commands+=("remove")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("delete")
        aliashash["delete"]="remove"
    fi
    commands+=("status")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_deploy_cancel()
{
    last_command="tng_deploy_cancel"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_deploy_commits()
{
    last_command="tng_deploy_commits"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--limit=")
    two_word_flags+=("--limit")
    two_word_flags+=("-l")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tng_deploy_gates_dump()
{
    last_command="tng_deploy_gates_dump"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tng_deploy_gates_eval()
{
    last_command="tng_deploy_gates_eval"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--descriptor=")
    two_word_flags+=("--descriptor")
    two_word_flags+=("-d")
    local_nonpersistent_flags+=("--descriptor")
    local_nonpersistent_flags+=("--descriptor=")
    local_nonpersistent_flags+=("-d")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_deploy_gates()
{
    last_command="tng_deploy_gates"

    command_aliases=()

    commands=()
    commands+=("dump")
    commands+=("eval")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_deploy_history()
{
    last_command="tng_deploy_history"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--limit=")
    two_word_flags+=("--limit")
    two_word_flags+=("-l")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--timezone=")
    two_word_flags+=("--timezone")
    local_nonpersistent_flags+=("--timezone")
    local_nonpersistent_flags+=("--timezone=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tng_deploy_infra_apply()
{
    last_command="tng_deploy_infra_apply"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--allow-delete")
    flags+=("--auto-approve")
    flags+=("-a")
    flags+=("--block-duration=")
    two_word_flags+=("--block-duration")
    flags+=("--deployed-by=")
    two_word_flags+=("--deployed-by")
    flags+=("--deployment-reason=")
    two_word_flags+=("--deployment-reason")
    flags+=("--disable-gates-reason=")
    two_word_flags+=("--disable-gates-reason")
    flags+=("--disable-tests-reason=")
    two_word_flags+=("--disable-tests-reason")
    local_nonpersistent_flags+=("--disable-tests-reason")
    local_nonpersistent_flags+=("--disable-tests-reason=")
    flags+=("--dry-run")
    local_nonpersistent_flags+=("--dry-run")
    flags+=("--follow")
    flags+=("-f")
    flags+=("--force-region")
    flags+=("--local-descriptors")
    flags+=("--no-block")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--apply")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tng_deploy_infra_history()
{
    last_command="tng_deploy_infra_history"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--limit=")
    two_word_flags+=("--limit")
    two_word_flags+=("-l")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--allow-delete")
    flags+=("--apply")
    flags+=("--auto-approve")
    flags+=("-a")
    flags+=("--block-duration=")
    two_word_flags+=("--block-duration")
    flags+=("--deployed-by=")
    two_word_flags+=("--deployed-by")
    flags+=("--deployment-reason=")
    two_word_flags+=("--deployment-reason")
    flags+=("--disable-gates-reason=")
    two_word_flags+=("--disable-gates-reason")
    flags+=("--follow")
    flags+=("-f")
    flags+=("--force-region")
    flags+=("--local-descriptors")
    flags+=("--no-block")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tng_deploy_infra_plan()
{
    last_command="tng_deploy_infra_plan"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--auto-approve")
    flags+=("-a")
    flags+=("--block-duration=")
    two_word_flags+=("--block-duration")
    flags+=("--deployed-by=")
    two_word_flags+=("--deployed-by")
    flags+=("--deployment-reason=")
    two_word_flags+=("--deployment-reason")
    flags+=("--disable-gates-reason=")
    two_word_flags+=("--disable-gates-reason")
    flags+=("--disable-tests-reason=")
    two_word_flags+=("--disable-tests-reason")
    local_nonpersistent_flags+=("--disable-tests-reason")
    local_nonpersistent_flags+=("--disable-tests-reason=")
    flags+=("--dry-run")
    local_nonpersistent_flags+=("--dry-run")
    flags+=("--follow")
    flags+=("-f")
    flags+=("--force-region")
    flags+=("--local-descriptors")
    flags+=("--no-block")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--allow-delete")
    flags+=("--apply")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tng_deploy_infra()
{
    last_command="tng_deploy_infra"

    command_aliases=()

    commands=()
    commands+=("apply")
    commands+=("history")
    commands+=("plan")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--allow-delete")
    flags+=("--apply")
    flags+=("--auto-approve")
    flags+=("-a")
    flags+=("--block-duration=")
    two_word_flags+=("--block-duration")
    flags+=("--deployed-by=")
    two_word_flags+=("--deployed-by")
    flags+=("--deployment-reason=")
    two_word_flags+=("--deployment-reason")
    flags+=("--disable-gates-reason=")
    two_word_flags+=("--disable-gates-reason")
    flags+=("--disable-tests-reason=")
    two_word_flags+=("--disable-tests-reason")
    local_nonpersistent_flags+=("--disable-tests-reason")
    local_nonpersistent_flags+=("--disable-tests-reason=")
    flags+=("--dry-run")
    local_nonpersistent_flags+=("--dry-run")
    flags+=("--follow")
    flags+=("-f")
    flags+=("--force-region")
    flags+=("--local-descriptors")
    flags+=("--no-block")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tng_deploy_list()
{
    last_command="tng_deploy_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--timezone=")
    two_word_flags+=("--timezone")
    local_nonpersistent_flags+=("--timezone")
    local_nonpersistent_flags+=("--timezone=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tng_deploy_logs()
{
    last_command="tng_deploy_logs"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--follow")
    flags+=("-f")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tng_deploy_needed()
{
    last_command="tng_deploy_needed"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_deploy_service()
{
    last_command="tng_deploy_service"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--auto-approve")
    flags+=("-a")
    flags+=("--block-duration=")
    two_word_flags+=("--block-duration")
    flags+=("--deployed-by=")
    two_word_flags+=("--deployed-by")
    flags+=("--deployment-reason=")
    two_word_flags+=("--deployment-reason")
    flags+=("--disable-gates-reason=")
    two_word_flags+=("--disable-gates-reason")
    flags+=("--disable-tests-reason=")
    two_word_flags+=("--disable-tests-reason")
    local_nonpersistent_flags+=("--disable-tests-reason")
    local_nonpersistent_flags+=("--disable-tests-reason=")
    flags+=("--dry-run")
    local_nonpersistent_flags+=("--dry-run")
    flags+=("--follow")
    flags+=("-f")
    flags+=("--force-region")
    flags+=("--local-descriptors")
    flags+=("--no-block")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tng_deploy_showdiff()
{
    last_command="tng_deploy_showdiff"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tng_deploy_status()
{
    last_command="tng_deploy_status"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--timezone=")
    two_word_flags+=("--timezone")
    local_nonpersistent_flags+=("--timezone")
    local_nonpersistent_flags+=("--timezone=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tng_deploy_test()
{
    last_command="tng_deploy_test"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--branch=")
    two_word_flags+=("--branch")
    local_nonpersistent_flags+=("--branch")
    local_nonpersistent_flags+=("--branch=")
    flags+=("--follow")
    flags+=("-f")
    local_nonpersistent_flags+=("--follow")
    local_nonpersistent_flags+=("-f")
    flags+=("--local-descriptors")
    local_nonpersistent_flags+=("--local-descriptors")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_deploy()
{
    last_command="tng_deploy"

    command_aliases=()

    commands=()
    commands+=("block")
    commands+=("cancel")
    commands+=("commits")
    commands+=("gates")
    commands+=("history")
    commands+=("infra")
    commands+=("list")
    commands+=("logs")
    commands+=("needed")
    commands+=("service")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("run")
        aliashash["run"]="service"
    fi
    commands+=("showdiff")
    commands+=("status")
    commands+=("test")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_browse()
{
    last_command="tng_dev_browse"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    flags+=("-a")
    local_nonpersistent_flags+=("--all")
    local_nonpersistent_flags+=("-a")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tng_dev_database_postgres_browse()
{
    last_command="tng_dev_database_postgres_browse"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_database_postgres_dump-list()
{
    last_command="tng_dev_database_postgres_dump-list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_database_postgres_dump-status()
{
    last_command="tng_dev_database_postgres_dump-status"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_database_postgres_load-from-uat()
{
    last_command="tng_dev_database_postgres_load-from-uat"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--fresh")
    local_nonpersistent_flags+=("--fresh")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_database_postgres_psql()
{
    last_command="tng_dev_database_postgres_psql"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_database_postgres_reset()
{
    last_command="tng_dev_database_postgres_reset"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_database_postgres_stop()
{
    last_command="tng_dev_database_postgres_stop"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_database_postgres_unmet()
{
    last_command="tng_dev_database_postgres_unmet"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_database_postgres_up()
{
    last_command="tng_dev_database_postgres_up"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--force")
    local_nonpersistent_flags+=("--force")
    flags+=("--skip-dependencies")
    local_nonpersistent_flags+=("--skip-dependencies")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_database_postgres()
{
    last_command="tng_dev_database_postgres"

    command_aliases=()

    commands=()
    commands+=("browse")
    commands+=("dump-list")
    commands+=("dump-status")
    commands+=("load-from-uat")
    commands+=("psql")
    commands+=("reset")
    commands+=("stop")
    commands+=("unmet")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("check")
        aliashash["check"]="unmet"
    fi
    commands+=("up")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_database_sql-migrations_unmet()
{
    last_command="tng_dev_database_sql-migrations_unmet"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_database_sql-migrations_up()
{
    last_command="tng_dev_database_sql-migrations_up"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--force")
    local_nonpersistent_flags+=("--force")
    flags+=("--skip-dependencies")
    local_nonpersistent_flags+=("--skip-dependencies")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_database_sql-migrations()
{
    last_command="tng_dev_database_sql-migrations"

    command_aliases=()

    commands=()
    commands+=("unmet")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("check")
        aliashash["check"]="unmet"
    fi
    commands+=("up")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_database()
{
    last_command="tng_dev_database"

    command_aliases=()

    commands=()
    commands+=("postgres")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("pg")
        aliashash["pg"]="postgres"
        command_aliases+=("postgres-k8s")
        aliashash["postgres-k8s"]="postgres"
    fi
    commands+=("sql-migrations")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_debug()
{
    last_command="tng_dev_debug"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--debuggable")
    local_nonpersistent_flags+=("--debuggable")
    flags+=("--liberate-ports")
    local_nonpersistent_flags+=("--liberate-ports")
    flags+=("--skip=")
    two_word_flags+=("--skip")
    flags_with_completion+=("--skip")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--skip")
    local_nonpersistent_flags+=("--skip=")
    flags+=("--watch")
    flags+=("-w")
    local_nonpersistent_flags+=("--watch")
    local_nonpersistent_flags+=("-w")
    flags+=("--watch-debounce=")
    two_word_flags+=("--watch-debounce")
    local_nonpersistent_flags+=("--watch-debounce")
    local_nonpersistent_flags+=("--watch-debounce=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tng_dev_down()
{
    last_command="tng_dev_down"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_kafka_console()
{
    last_command="tng_dev_kafka_console"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_kafka_kafka_browse()
{
    last_command="tng_dev_kafka_kafka_browse"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_kafka_kafka_reset()
{
    last_command="tng_dev_kafka_kafka_reset"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_kafka_kafka_stop()
{
    last_command="tng_dev_kafka_kafka_stop"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_kafka_kafka_unmet()
{
    last_command="tng_dev_kafka_kafka_unmet"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_kafka_kafka_up()
{
    last_command="tng_dev_kafka_kafka_up"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--force")
    local_nonpersistent_flags+=("--force")
    flags+=("--skip-dependencies")
    local_nonpersistent_flags+=("--skip-dependencies")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_kafka_kafka()
{
    last_command="tng_dev_kafka_kafka"

    command_aliases=()

    commands=()
    commands+=("browse")
    commands+=("reset")
    commands+=("stop")
    commands+=("unmet")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("check")
        aliashash["check"]="unmet"
    fi
    commands+=("up")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_kafka_kafka-topics-registered_unmet()
{
    last_command="tng_dev_kafka_kafka-topics-registered_unmet"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_kafka_kafka-topics-registered_up()
{
    last_command="tng_dev_kafka_kafka-topics-registered_up"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--force")
    local_nonpersistent_flags+=("--force")
    flags+=("--skip-dependencies")
    local_nonpersistent_flags+=("--skip-dependencies")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_kafka_kafka-topics-registered()
{
    last_command="tng_dev_kafka_kafka-topics-registered"

    command_aliases=()

    commands=()
    commands+=("unmet")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("check")
        aliashash["check"]="unmet"
    fi
    commands+=("up")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_kafka()
{
    last_command="tng_dev_kafka"

    command_aliases=()

    commands=()
    commands+=("console")
    commands+=("kafka")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("kafka-k8s")
        aliashash["kafka-k8s"]="kafka"
    fi
    commands+=("kafka-topics-registered")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_llm_configure()
{
    last_command="tng_dev_llm_configure"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_llm_debug()
{
    last_command="tng_dev_llm_debug"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_llm_disable()
{
    last_command="tng_dev_llm_disable"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_llm_enable()
{
    last_command="tng_dev_llm_enable"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_llm_info()
{
    last_command="tng_dev_llm_info"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_llm_logs()
{
    last_command="tng_dev_llm_logs"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--follow")
    flags+=("-f")
    local_nonpersistent_flags+=("--follow")
    local_nonpersistent_flags+=("-f")
    flags+=("--stdout")
    local_nonpersistent_flags+=("--stdout")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_llm_reset()
{
    last_command="tng_dev_llm_reset"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--confirm")
    flags+=("-y")
    local_nonpersistent_flags+=("--confirm")
    local_nonpersistent_flags+=("-y")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_llm_restart()
{
    last_command="tng_dev_llm_restart"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_llm_start()
{
    last_command="tng_dev_llm_start"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_llm_stop()
{
    last_command="tng_dev_llm_stop"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_llm()
{
    last_command="tng_dev_llm"

    command_aliases=()

    commands=()
    commands+=("configure")
    commands+=("debug")
    commands+=("disable")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("d")
        aliashash["d"]="disable"
    fi
    commands+=("enable")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("e")
        aliashash["e"]="enable"
    fi
    commands+=("info")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("status")
        aliashash["status"]="info"
    fi
    commands+=("logs")
    commands+=("reset")
    commands+=("restart")
    commands+=("start")
    commands+=("stop")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_proxy_restart()
{
    last_command="tng_dev_proxy_restart"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_proxy_start()
{
    last_command="tng_dev_proxy_start"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_proxy_stop()
{
    last_command="tng_dev_proxy_stop"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_proxy()
{
    last_command="tng_dev_proxy"

    command_aliases=()

    commands=()
    commands+=("restart")
    commands+=("start")
    commands+=("stop")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_rancher_configure()
{
    last_command="tng_dev_rancher_configure"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_rancher()
{
    last_command="tng_dev_rancher"

    command_aliases=()

    commands=()
    commands+=("configure")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_recompose()
{
    last_command="tng_dev_recompose"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_require-docker-compose()
{
    last_command="tng_dev_require-docker-compose"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--files=")
    two_word_flags+=("--files")
    local_nonpersistent_flags+=("--files")
    local_nonpersistent_flags+=("--files=")
    flags+=("--repo=")
    two_word_flags+=("--repo")
    local_nonpersistent_flags+=("--repo")
    local_nonpersistent_flags+=("--repo=")
    flags+=("--services=")
    two_word_flags+=("--services")
    local_nonpersistent_flags+=("--services")
    local_nonpersistent_flags+=("--services=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_flag+=("--repo=")
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_require-repo-up-to-date()
{
    last_command="tng_dev_require-repo-up-to-date"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--ref=")
    two_word_flags+=("--ref")
    local_nonpersistent_flags+=("--ref")
    local_nonpersistent_flags+=("--ref=")
    flags+=("--repo=")
    two_word_flags+=("--repo")
    local_nonpersistent_flags+=("--repo")
    local_nonpersistent_flags+=("--repo=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_flag+=("--ref=")
    must_have_one_flag+=("--repo=")
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_requirements()
{
    last_command="tng_dev_requirements"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_reset()
{
    last_command="tng_dev_reset"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_reset-k8s()
{
    last_command="tng_dev_reset-k8s"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--confirm")
    flags+=("-y")
    local_nonpersistent_flags+=("--confirm")
    local_nonpersistent_flags+=("-y")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_run()
{
    last_command="tng_dev_run"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--debuggable")
    local_nonpersistent_flags+=("--debuggable")
    flags+=("--liberate-ports")
    local_nonpersistent_flags+=("--liberate-ports")
    flags+=("--skip=")
    two_word_flags+=("--skip")
    flags_with_completion+=("--skip")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--skip")
    local_nonpersistent_flags+=("--skip=")
    flags+=("--watch")
    flags+=("-w")
    local_nonpersistent_flags+=("--watch")
    local_nonpersistent_flags+=("-w")
    flags+=("--watch-debounce=")
    two_word_flags+=("--watch-debounce")
    local_nonpersistent_flags+=("--watch-debounce")
    local_nonpersistent_flags+=("--watch-debounce=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tng_dev_spec_show()
{
    last_command="tng_dev_spec_show"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_spec_update()
{
    last_command="tng_dev_spec_update"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_spec()
{
    last_command="tng_dev_spec"

    command_aliases=()

    commands=()
    commands+=("show")
    commands+=("update")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_status()
{
    last_command="tng_dev_status"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--dependencies")
    local_nonpersistent_flags+=("--dependencies")
    flags+=("--details")
    local_nonpersistent_flags+=("--details")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_temporal_temporal_browse()
{
    last_command="tng_dev_temporal_temporal_browse"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_temporal_temporal_reset()
{
    last_command="tng_dev_temporal_temporal_reset"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_temporal_temporal_stop()
{
    last_command="tng_dev_temporal_temporal_stop"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_temporal_temporal_unmet()
{
    last_command="tng_dev_temporal_temporal_unmet"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_temporal_temporal_up()
{
    last_command="tng_dev_temporal_temporal_up"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--force")
    local_nonpersistent_flags+=("--force")
    flags+=("--skip-dependencies")
    local_nonpersistent_flags+=("--skip-dependencies")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_temporal_temporal()
{
    last_command="tng_dev_temporal_temporal"

    command_aliases=()

    commands=()
    commands+=("browse")
    commands+=("reset")
    commands+=("stop")
    commands+=("unmet")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("check")
        aliashash["check"]="unmet"
    fi
    commands+=("up")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_temporal_temporal-configured_unmet()
{
    last_command="tng_dev_temporal_temporal-configured_unmet"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_temporal_temporal-configured_up()
{
    last_command="tng_dev_temporal_temporal-configured_up"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--force")
    local_nonpersistent_flags+=("--force")
    flags+=("--skip-dependencies")
    local_nonpersistent_flags+=("--skip-dependencies")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_temporal_temporal-configured()
{
    last_command="tng_dev_temporal_temporal-configured"

    command_aliases=()

    commands=()
    commands+=("unmet")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("check")
        aliashash["check"]="unmet"
    fi
    commands+=("up")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_temporal()
{
    last_command="tng_dev_temporal"

    command_aliases=()

    commands=()
    commands+=("temporal")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("temporal-k8s")
        aliashash["temporal-k8s"]="temporal"
    fi
    commands+=("temporal-configured")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("temporal-k8s-configured")
        aliashash["temporal-k8s-configured"]="temporal-configured"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_test_add()
{
    last_command="tng_dev_test_add"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--acceptance")
    flags+=("-a")
    local_nonpersistent_flags+=("--acceptance")
    local_nonpersistent_flags+=("-a")
    flags+=("--comment=")
    two_word_flags+=("--comment")
    local_nonpersistent_flags+=("--comment")
    local_nonpersistent_flags+=("--comment=")
    flags+=("--description=")
    two_word_flags+=("--description")
    local_nonpersistent_flags+=("--description")
    local_nonpersistent_flags+=("--description=")
    flags+=("--env=")
    two_word_flags+=("--env")
    two_word_flags+=("-e")
    local_nonpersistent_flags+=("--env")
    local_nonpersistent_flags+=("--env=")
    local_nonpersistent_flags+=("-e")
    flags+=("--integration")
    flags+=("-i")
    local_nonpersistent_flags+=("--integration")
    local_nonpersistent_flags+=("-i")
    flags+=("--labels=")
    two_word_flags+=("--labels")
    local_nonpersistent_flags+=("--labels")
    local_nonpersistent_flags+=("--labels=")
    flags+=("--parameters.app=")
    two_word_flags+=("--parameters.app")
    local_nonpersistent_flags+=("--parameters.app")
    local_nonpersistent_flags+=("--parameters.app=")
    flags+=("--paths=")
    two_word_flags+=("--paths")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--paths")
    local_nonpersistent_flags+=("--paths=")
    local_nonpersistent_flags+=("-p")
    flags+=("--private")
    local_nonpersistent_flags+=("--private")
    flags+=("--regex=")
    two_word_flags+=("--regex")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--regex")
    local_nonpersistent_flags+=("--regex=")
    local_nonpersistent_flags+=("-r")
    flags+=("--service=")
    two_word_flags+=("--service")
    two_word_flags+=("-s")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--tags=")
    two_word_flags+=("--tags")
    two_word_flags+=("-t")
    local_nonpersistent_flags+=("--tags")
    local_nonpersistent_flags+=("--tags=")
    local_nonpersistent_flags+=("-t")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_test_list()
{
    last_command="tng_dev_test_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_test_remove()
{
    last_command="tng_dev_test_remove"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev_test()
{
    last_command="tng_dev_test"

    command_aliases=()

    commands=()
    commands+=("add")
    commands+=("list")
    commands+=("remove")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--acceptance")
    flags+=("-a")
    local_nonpersistent_flags+=("--acceptance")
    local_nonpersistent_flags+=("-a")
    flags+=("--env=")
    two_word_flags+=("--env")
    two_word_flags+=("-e")
    local_nonpersistent_flags+=("--env")
    local_nonpersistent_flags+=("--env=")
    local_nonpersistent_flags+=("-e")
    flags+=("--exclude=")
    two_word_flags+=("--exclude")
    flags_with_completion+=("--exclude")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--exclude")
    local_nonpersistent_flags+=("--exclude=")
    flags+=("--include=")
    two_word_flags+=("--include")
    flags_with_completion+=("--include")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--include")
    local_nonpersistent_flags+=("--include=")
    flags+=("--integration")
    flags+=("-i")
    local_nonpersistent_flags+=("--integration")
    local_nonpersistent_flags+=("-i")
    flags+=("--no-cache")
    flags+=("-C")
    local_nonpersistent_flags+=("--no-cache")
    local_nonpersistent_flags+=("-C")
    flags+=("--parameters.app=")
    two_word_flags+=("--parameters.app")
    local_nonpersistent_flags+=("--parameters.app")
    local_nonpersistent_flags+=("--parameters.app=")
    flags+=("--paths=")
    two_word_flags+=("--paths")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--paths")
    local_nonpersistent_flags+=("--paths=")
    local_nonpersistent_flags+=("-p")
    flags+=("--regex=")
    two_word_flags+=("--regex")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--regex")
    local_nonpersistent_flags+=("--regex=")
    local_nonpersistent_flags+=("-r")
    flags+=("--save-private=")
    two_word_flags+=("--save-private")
    local_nonpersistent_flags+=("--save-private")
    local_nonpersistent_flags+=("--save-private=")
    flags+=("--save-shared=")
    two_word_flags+=("--save-shared")
    local_nonpersistent_flags+=("--save-shared")
    local_nonpersistent_flags+=("--save-shared=")
    flags+=("--selector=")
    two_word_flags+=("--selector")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--selector")
    local_nonpersistent_flags+=("--selector=")
    local_nonpersistent_flags+=("-l")
    flags+=("--service=")
    two_word_flags+=("--service")
    two_word_flags+=("-s")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--tags=")
    two_word_flags+=("--tags")
    two_word_flags+=("-t")
    local_nonpersistent_flags+=("--tags")
    local_nonpersistent_flags+=("--tags=")
    local_nonpersistent_flags+=("-t")
    flags+=("--verbose")
    flags+=("-v")
    local_nonpersistent_flags+=("--verbose")
    local_nonpersistent_flags+=("-v")
    flags+=("--watch")
    flags+=("-w")
    local_nonpersistent_flags+=("--watch")
    local_nonpersistent_flags+=("-w")
    flags+=("--watch-debounce=")
    two_word_flags+=("--watch-debounce")
    local_nonpersistent_flags+=("--watch-debounce")
    local_nonpersistent_flags+=("--watch-debounce=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tng_dev_up()
{
    last_command="tng_dev_up"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--skip=")
    two_word_flags+=("--skip")
    flags_with_completion+=("--skip")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--skip")
    local_nonpersistent_flags+=("--skip=")
    flags+=("--watch")
    flags+=("-w")
    local_nonpersistent_flags+=("--watch")
    local_nonpersistent_flags+=("-w")
    flags+=("--watch-debounce=")
    two_word_flags+=("--watch-debounce")
    local_nonpersistent_flags+=("--watch-debounce")
    local_nonpersistent_flags+=("--watch-debounce=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dev()
{
    last_command="tng_dev"

    command_aliases=()

    commands=()
    commands+=("browse")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("console")
        aliashash["console"]="browse"
    fi
    commands+=("database")
    commands+=("debug")
    commands+=("down")
    commands+=("kafka")
    commands+=("llm")
    commands+=("proxy")
    commands+=("rancher")
    commands+=("recompose")
    commands+=("require-docker-compose")
    commands+=("require-repo-up-to-date")
    commands+=("requirements")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("req")
        aliashash["req"]="requirements"
        command_aliases+=("reqs")
        aliashash["reqs"]="requirements"
    fi
    commands+=("reset")
    commands+=("reset-k8s")
    commands+=("run")
    commands+=("spec")
    commands+=("status")
    commands+=("temporal")
    commands+=("test")
    commands+=("up")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_dump-help()
{
    last_command="tng_dump-help"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_flags_sync-user()
{
    last_command="tng_flags_sync-user"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    local_nonpersistent_flags+=("--config")
    local_nonpersistent_flags+=("--config=")
    flags+=("--dry-run")
    local_nonpersistent_flags+=("--dry-run")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_flags()
{
    last_command="tng_flags"

    command_aliases=()

    commands=()
    commands+=("sync-user")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_git_worktree-operation()
{
    last_command="tng_git_worktree-operation"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--base=")
    two_word_flags+=("--base")
    local_nonpersistent_flags+=("--base")
    local_nonpersistent_flags+=("--base=")
    flags+=("--no-commit")
    local_nonpersistent_flags+=("--no-commit")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tng_git()
{
    last_command="tng_git"

    command_aliases=()

    commands=()
    commands+=("worktree-operation")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_graphql_dev_auth()
{
    last_command="tng_graphql_dev_auth"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--auth-client-id=")
    two_word_flags+=("--auth-client-id")
    local_nonpersistent_flags+=("--auth-client-id")
    local_nonpersistent_flags+=("--auth-client-id=")
    flags+=("--auth-client-secret=")
    two_word_flags+=("--auth-client-secret")
    local_nonpersistent_flags+=("--auth-client-secret")
    local_nonpersistent_flags+=("--auth-client-secret=")
    flags+=("--auth-url=")
    two_word_flags+=("--auth-url")
    local_nonpersistent_flags+=("--auth-url")
    local_nonpersistent_flags+=("--auth-url=")
    flags+=("--jwt=")
    two_word_flags+=("--jwt")
    local_nonpersistent_flags+=("--jwt")
    local_nonpersistent_flags+=("--jwt=")
    flags+=("--ruby-token=")
    two_word_flags+=("--ruby-token")
    local_nonpersistent_flags+=("--ruby-token")
    local_nonpersistent_flags+=("--ruby-token=")
    flags+=("--service=")
    two_word_flags+=("--service")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    flags+=("--docker-compose-file=")
    two_word_flags+=("--docker-compose-file")
    flags+=("--in-docker-compose=")
    two_word_flags+=("--in-docker-compose")
    flags+=("--insecure-skip-verify")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_check-client-operations_list()
{
    last_command="tng_check-client-operations_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--descriptor-path=")
    two_word_flags+=("--descriptor-path")
    local_nonpersistent_flags+=("--descriptor-path")
    local_nonpersistent_flags+=("--descriptor-path=")
    flags+=("--operations=")
    two_word_flags+=("--operations")
    local_nonpersistent_flags+=("--operations")
    local_nonpersistent_flags+=("--operations=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_graphql_check_operations()
{
    last_command="tng_graphql_check_operations"

    command_aliases=()

    commands=()
    commands+=("list")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--apollo-key=")
    two_word_flags+=("--apollo-key")
    local_nonpersistent_flags+=("--apollo-key")
    local_nonpersistent_flags+=("--apollo-key=")
    flags+=("--descriptor-path=")
    two_word_flags+=("--descriptor-path")
    local_nonpersistent_flags+=("--descriptor-path")
    local_nonpersistent_flags+=("--descriptor-path=")
    flags+=("--git-branch=")
    two_word_flags+=("--git-branch")
    local_nonpersistent_flags+=("--git-branch")
    local_nonpersistent_flags+=("--git-branch=")
    flags+=("--git-commit=")
    two_word_flags+=("--git-commit")
    local_nonpersistent_flags+=("--git-commit")
    local_nonpersistent_flags+=("--git-commit=")
    flags+=("--git-remote-url=")
    two_word_flags+=("--git-remote-url")
    local_nonpersistent_flags+=("--git-remote-url")
    local_nonpersistent_flags+=("--git-remote-url=")
    flags+=("--git-user=")
    two_word_flags+=("--git-user")
    local_nonpersistent_flags+=("--git-user")
    local_nonpersistent_flags+=("--git-user=")
    flags+=("--graph-alias=")
    two_word_flags+=("--graph-alias")
    two_word_flags+=("-g")
    local_nonpersistent_flags+=("--graph-alias")
    local_nonpersistent_flags+=("--graph-alias=")
    local_nonpersistent_flags+=("-g")
    flags+=("--graph-id=")
    two_word_flags+=("--graph-id")
    local_nonpersistent_flags+=("--graph-id")
    local_nonpersistent_flags+=("--graph-id=")
    flags+=("--operations=")
    two_word_flags+=("--operations")
    local_nonpersistent_flags+=("--operations")
    local_nonpersistent_flags+=("--operations=")
    flags+=("--variant=")
    two_word_flags+=("--variant")
    local_nonpersistent_flags+=("--variant")
    local_nonpersistent_flags+=("--variant=")
    flags+=("--docker-compose-file=")
    two_word_flags+=("--docker-compose-file")
    flags+=("--in-docker-compose=")
    two_word_flags+=("--in-docker-compose")
    flags+=("--insecure-skip-verify")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_graphql_check_subgraph()
{
    last_command="tng_graphql_check_subgraph"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--apollo-key=")
    two_word_flags+=("--apollo-key")
    local_nonpersistent_flags+=("--apollo-key")
    local_nonpersistent_flags+=("--apollo-key=")
    flags+=("--auth-client-id=")
    two_word_flags+=("--auth-client-id")
    local_nonpersistent_flags+=("--auth-client-id")
    local_nonpersistent_flags+=("--auth-client-id=")
    flags+=("--auth-client-secret=")
    two_word_flags+=("--auth-client-secret")
    local_nonpersistent_flags+=("--auth-client-secret")
    local_nonpersistent_flags+=("--auth-client-secret=")
    flags+=("--auth-url=")
    two_word_flags+=("--auth-url")
    local_nonpersistent_flags+=("--auth-url")
    local_nonpersistent_flags+=("--auth-url=")
    flags+=("--check-pql=")
    two_word_flags+=("--check-pql")
    local_nonpersistent_flags+=("--check-pql")
    local_nonpersistent_flags+=("--check-pql=")
    flags+=("--endpoint=")
    two_word_flags+=("--endpoint")
    local_nonpersistent_flags+=("--endpoint")
    local_nonpersistent_flags+=("--endpoint=")
    flags+=("--git-branch=")
    two_word_flags+=("--git-branch")
    local_nonpersistent_flags+=("--git-branch")
    local_nonpersistent_flags+=("--git-branch=")
    flags+=("--git-commit=")
    two_word_flags+=("--git-commit")
    local_nonpersistent_flags+=("--git-commit")
    local_nonpersistent_flags+=("--git-commit=")
    flags+=("--git-remote-url=")
    two_word_flags+=("--git-remote-url")
    local_nonpersistent_flags+=("--git-remote-url")
    local_nonpersistent_flags+=("--git-remote-url=")
    flags+=("--git-user=")
    two_word_flags+=("--git-user")
    local_nonpersistent_flags+=("--git-user")
    local_nonpersistent_flags+=("--git-user=")
    flags+=("--graph-alias=")
    two_word_flags+=("--graph-alias")
    two_word_flags+=("-g")
    local_nonpersistent_flags+=("--graph-alias")
    local_nonpersistent_flags+=("--graph-alias=")
    local_nonpersistent_flags+=("-g")
    flags+=("--graph-id=")
    two_word_flags+=("--graph-id")
    local_nonpersistent_flags+=("--graph-id")
    local_nonpersistent_flags+=("--graph-id=")
    flags+=("--jwt=")
    two_word_flags+=("--jwt")
    local_nonpersistent_flags+=("--jwt")
    local_nonpersistent_flags+=("--jwt=")
    flags+=("--ruby-token=")
    two_word_flags+=("--ruby-token")
    local_nonpersistent_flags+=("--ruby-token")
    local_nonpersistent_flags+=("--ruby-token=")
    flags+=("--sdl-file-glob=")
    two_word_flags+=("--sdl-file-glob")
    local_nonpersistent_flags+=("--sdl-file-glob")
    local_nonpersistent_flags+=("--sdl-file-glob=")
    flags+=("--sdl-file-path=")
    two_word_flags+=("--sdl-file-path")
    local_nonpersistent_flags+=("--sdl-file-path")
    local_nonpersistent_flags+=("--sdl-file-path=")
    flags+=("--service=")
    two_word_flags+=("--service")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    flags+=("--variant=")
    two_word_flags+=("--variant")
    local_nonpersistent_flags+=("--variant")
    local_nonpersistent_flags+=("--variant=")
    flags+=("--docker-compose-file=")
    two_word_flags+=("--docker-compose-file")
    flags+=("--in-docker-compose=")
    two_word_flags+=("--in-docker-compose")
    flags+=("--insecure-skip-verify")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_graphql_check()
{
    last_command="tng_graphql_check"

    command_aliases=()

    commands=()
    commands+=("operations")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("op")
        aliashash["op"]="operations"
        command_aliases+=("operation")
        aliashash["operation"]="operations"
    fi
    commands+=("subgraph")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("graph")
        aliashash["graph"]="subgraph"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--docker-compose-file=")
    two_word_flags+=("--docker-compose-file")
    flags+=("--in-docker-compose=")
    two_word_flags+=("--in-docker-compose")
    flags+=("--insecure-skip-verify")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_graphql_config_init()
{
    last_command="tng_graphql_config_init"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--docker-compose-file=")
    two_word_flags+=("--docker-compose-file")
    flags+=("--in-docker-compose=")
    two_word_flags+=("--in-docker-compose")
    flags+=("--insecure-skip-verify")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_graphql_config()
{
    last_command="tng_graphql_config"

    command_aliases=()

    commands=()
    commands+=("init")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--docker-compose-file=")
    two_word_flags+=("--docker-compose-file")
    flags+=("--in-docker-compose=")
    two_word_flags+=("--in-docker-compose")
    flags+=("--insecure-skip-verify")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_graphql_dashboard()
{
    last_command="tng_graphql_dashboard"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--client=")
    two_word_flags+=("--client")
    local_nonpersistent_flags+=("--client")
    local_nonpersistent_flags+=("--client=")
    flags+=("--env=")
    two_word_flags+=("--env")
    local_nonpersistent_flags+=("--env")
    local_nonpersistent_flags+=("--env=")
    flags+=("--from=")
    two_word_flags+=("--from")
    local_nonpersistent_flags+=("--from")
    local_nonpersistent_flags+=("--from=")
    flags+=("--server=")
    two_word_flags+=("--server")
    local_nonpersistent_flags+=("--server")
    local_nonpersistent_flags+=("--server=")
    flags+=("--to=")
    two_word_flags+=("--to")
    local_nonpersistent_flags+=("--to")
    local_nonpersistent_flags+=("--to=")
    flags+=("--docker-compose-file=")
    two_word_flags+=("--docker-compose-file")
    flags+=("--in-docker-compose=")
    two_word_flags+=("--in-docker-compose")
    flags+=("--insecure-skip-verify")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_graphql_dev_auth()
{
    last_command="tng_graphql_dev_auth"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--auth-client-id=")
    two_word_flags+=("--auth-client-id")
    local_nonpersistent_flags+=("--auth-client-id")
    local_nonpersistent_flags+=("--auth-client-id=")
    flags+=("--auth-client-secret=")
    two_word_flags+=("--auth-client-secret")
    local_nonpersistent_flags+=("--auth-client-secret")
    local_nonpersistent_flags+=("--auth-client-secret=")
    flags+=("--auth-url=")
    two_word_flags+=("--auth-url")
    local_nonpersistent_flags+=("--auth-url")
    local_nonpersistent_flags+=("--auth-url=")
    flags+=("--jwt=")
    two_word_flags+=("--jwt")
    local_nonpersistent_flags+=("--jwt")
    local_nonpersistent_flags+=("--jwt=")
    flags+=("--ruby-token=")
    two_word_flags+=("--ruby-token")
    local_nonpersistent_flags+=("--ruby-token")
    local_nonpersistent_flags+=("--ruby-token=")
    flags+=("--service=")
    two_word_flags+=("--service")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    flags+=("--docker-compose-file=")
    two_word_flags+=("--docker-compose-file")
    flags+=("--in-docker-compose=")
    two_word_flags+=("--in-docker-compose")
    flags+=("--insecure-skip-verify")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_graphql_dev_config_path()
{
    last_command="tng_graphql_dev_config_path"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--docker-compose-file=")
    two_word_flags+=("--docker-compose-file")
    flags+=("--in-docker-compose=")
    two_word_flags+=("--in-docker-compose")
    flags+=("--insecure-skip-verify")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_graphql_dev_config_show()
{
    last_command="tng_graphql_dev_config_show"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--docker-compose-file=")
    two_word_flags+=("--docker-compose-file")
    flags+=("--in-docker-compose=")
    two_word_flags+=("--in-docker-compose")
    flags+=("--insecure-skip-verify")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_graphql_dev_config()
{
    last_command="tng_graphql_dev_config"

    command_aliases=()

    commands=()
    commands+=("path")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("location")
        aliashash["location"]="path"
    fi
    commands+=("show")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--docker-compose-file=")
    two_word_flags+=("--docker-compose-file")
    flags+=("--in-docker-compose=")
    two_word_flags+=("--in-docker-compose")
    flags+=("--insecure-skip-verify")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_graphql_dev_explorer()
{
    last_command="tng_graphql_dev_explorer"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--docker-compose-file=")
    two_word_flags+=("--docker-compose-file")
    flags+=("--in-docker-compose=")
    two_word_flags+=("--in-docker-compose")
    flags+=("--insecure-skip-verify")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_graphql_dev_info()
{
    last_command="tng_graphql_dev_info"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--apollo-key=")
    two_word_flags+=("--apollo-key")
    local_nonpersistent_flags+=("--apollo-key")
    local_nonpersistent_flags+=("--apollo-key=")
    flags+=("--graph-alias=")
    two_word_flags+=("--graph-alias")
    two_word_flags+=("-g")
    local_nonpersistent_flags+=("--graph-alias")
    local_nonpersistent_flags+=("--graph-alias=")
    local_nonpersistent_flags+=("-g")
    flags+=("--graph-id=")
    two_word_flags+=("--graph-id")
    local_nonpersistent_flags+=("--graph-id")
    local_nonpersistent_flags+=("--graph-id=")
    flags+=("--variant=")
    two_word_flags+=("--variant")
    local_nonpersistent_flags+=("--variant")
    local_nonpersistent_flags+=("--variant=")
    flags+=("--docker-compose-file=")
    two_word_flags+=("--docker-compose-file")
    flags+=("--in-docker-compose=")
    two_word_flags+=("--in-docker-compose")
    flags+=("--insecure-skip-verify")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_graphql_dev_reset()
{
    last_command="tng_graphql_dev_reset"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--apollo-key=")
    two_word_flags+=("--apollo-key")
    local_nonpersistent_flags+=("--apollo-key")
    local_nonpersistent_flags+=("--apollo-key=")
    flags+=("--auth-client-id=")
    two_word_flags+=("--auth-client-id")
    local_nonpersistent_flags+=("--auth-client-id")
    local_nonpersistent_flags+=("--auth-client-id=")
    flags+=("--auth-client-secret=")
    two_word_flags+=("--auth-client-secret")
    local_nonpersistent_flags+=("--auth-client-secret")
    local_nonpersistent_flags+=("--auth-client-secret=")
    flags+=("--auth-url=")
    two_word_flags+=("--auth-url")
    local_nonpersistent_flags+=("--auth-url")
    local_nonpersistent_flags+=("--auth-url=")
    flags+=("--confirm")
    flags+=("-y")
    local_nonpersistent_flags+=("--confirm")
    local_nonpersistent_flags+=("-y")
    flags+=("--graph-alias=")
    two_word_flags+=("--graph-alias")
    two_word_flags+=("-g")
    local_nonpersistent_flags+=("--graph-alias")
    local_nonpersistent_flags+=("--graph-alias=")
    local_nonpersistent_flags+=("-g")
    flags+=("--graph-id=")
    two_word_flags+=("--graph-id")
    local_nonpersistent_flags+=("--graph-id")
    local_nonpersistent_flags+=("--graph-id=")
    flags+=("--jwt=")
    two_word_flags+=("--jwt")
    local_nonpersistent_flags+=("--jwt")
    local_nonpersistent_flags+=("--jwt=")
    flags+=("--ruby-token=")
    two_word_flags+=("--ruby-token")
    local_nonpersistent_flags+=("--ruby-token")
    local_nonpersistent_flags+=("--ruby-token=")
    flags+=("--variant=")
    two_word_flags+=("--variant")
    local_nonpersistent_flags+=("--variant")
    local_nonpersistent_flags+=("--variant=")
    flags+=("--docker-compose-file=")
    two_word_flags+=("--docker-compose-file")
    flags+=("--in-docker-compose=")
    two_word_flags+=("--in-docker-compose")
    flags+=("--insecure-skip-verify")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_graphql_dev_route()
{
    last_command="tng_graphql_dev_route"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--apollo-key=")
    two_word_flags+=("--apollo-key")
    local_nonpersistent_flags+=("--apollo-key")
    local_nonpersistent_flags+=("--apollo-key=")
    flags+=("--auth-client-id=")
    two_word_flags+=("--auth-client-id")
    local_nonpersistent_flags+=("--auth-client-id")
    local_nonpersistent_flags+=("--auth-client-id=")
    flags+=("--auth-client-secret=")
    two_word_flags+=("--auth-client-secret")
    local_nonpersistent_flags+=("--auth-client-secret")
    local_nonpersistent_flags+=("--auth-client-secret=")
    flags+=("--auth-url=")
    two_word_flags+=("--auth-url")
    local_nonpersistent_flags+=("--auth-url")
    local_nonpersistent_flags+=("--auth-url=")
    flags+=("--graph-alias=")
    two_word_flags+=("--graph-alias")
    two_word_flags+=("-g")
    local_nonpersistent_flags+=("--graph-alias")
    local_nonpersistent_flags+=("--graph-alias=")
    local_nonpersistent_flags+=("-g")
    flags+=("--graph-id=")
    two_word_flags+=("--graph-id")
    local_nonpersistent_flags+=("--graph-id")
    local_nonpersistent_flags+=("--graph-id=")
    flags+=("--jwt=")
    two_word_flags+=("--jwt")
    local_nonpersistent_flags+=("--jwt")
    local_nonpersistent_flags+=("--jwt=")
    flags+=("--port=")
    two_word_flags+=("--port")
    local_nonpersistent_flags+=("--port")
    local_nonpersistent_flags+=("--port=")
    flags+=("--ruby-token=")
    two_word_flags+=("--ruby-token")
    local_nonpersistent_flags+=("--ruby-token")
    local_nonpersistent_flags+=("--ruby-token=")
    flags+=("--service=")
    two_word_flags+=("--service")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    flags+=("--variant=")
    two_word_flags+=("--variant")
    local_nonpersistent_flags+=("--variant")
    local_nonpersistent_flags+=("--variant=")
    flags+=("--docker-compose-file=")
    two_word_flags+=("--docker-compose-file")
    flags+=("--in-docker-compose=")
    two_word_flags+=("--in-docker-compose")
    flags+=("--insecure-skip-verify")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_graphql_dev_start()
{
    last_command="tng_graphql_dev_start"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--apollo-key=")
    two_word_flags+=("--apollo-key")
    local_nonpersistent_flags+=("--apollo-key")
    local_nonpersistent_flags+=("--apollo-key=")
    flags+=("--auth-client-id=")
    two_word_flags+=("--auth-client-id")
    local_nonpersistent_flags+=("--auth-client-id")
    local_nonpersistent_flags+=("--auth-client-id=")
    flags+=("--auth-client-secret=")
    two_word_flags+=("--auth-client-secret")
    local_nonpersistent_flags+=("--auth-client-secret")
    local_nonpersistent_flags+=("--auth-client-secret=")
    flags+=("--auth-url=")
    two_word_flags+=("--auth-url")
    local_nonpersistent_flags+=("--auth-url")
    local_nonpersistent_flags+=("--auth-url=")
    flags+=("--graph-alias=")
    two_word_flags+=("--graph-alias")
    two_word_flags+=("-g")
    local_nonpersistent_flags+=("--graph-alias")
    local_nonpersistent_flags+=("--graph-alias=")
    local_nonpersistent_flags+=("-g")
    flags+=("--graph-id=")
    two_word_flags+=("--graph-id")
    local_nonpersistent_flags+=("--graph-id")
    local_nonpersistent_flags+=("--graph-id=")
    flags+=("--jwt=")
    two_word_flags+=("--jwt")
    local_nonpersistent_flags+=("--jwt")
    local_nonpersistent_flags+=("--jwt=")
    flags+=("--ruby-token=")
    two_word_flags+=("--ruby-token")
    local_nonpersistent_flags+=("--ruby-token")
    local_nonpersistent_flags+=("--ruby-token=")
    flags+=("--variant=")
    two_word_flags+=("--variant")
    local_nonpersistent_flags+=("--variant")
    local_nonpersistent_flags+=("--variant=")
    flags+=("--docker-compose-file=")
    two_word_flags+=("--docker-compose-file")
    flags+=("--in-docker-compose=")
    two_word_flags+=("--in-docker-compose")
    flags+=("--insecure-skip-verify")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_graphql_dev_stop()
{
    last_command="tng_graphql_dev_stop"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--docker-compose-file=")
    two_word_flags+=("--docker-compose-file")
    flags+=("--in-docker-compose=")
    two_word_flags+=("--in-docker-compose")
    flags+=("--insecure-skip-verify")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_graphql_dev_update()
{
    last_command="tng_graphql_dev_update"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--apollo-key=")
    two_word_flags+=("--apollo-key")
    local_nonpersistent_flags+=("--apollo-key")
    local_nonpersistent_flags+=("--apollo-key=")
    flags+=("--auth-client-id=")
    two_word_flags+=("--auth-client-id")
    local_nonpersistent_flags+=("--auth-client-id")
    local_nonpersistent_flags+=("--auth-client-id=")
    flags+=("--auth-client-secret=")
    two_word_flags+=("--auth-client-secret")
    local_nonpersistent_flags+=("--auth-client-secret")
    local_nonpersistent_flags+=("--auth-client-secret=")
    flags+=("--auth-url=")
    two_word_flags+=("--auth-url")
    local_nonpersistent_flags+=("--auth-url")
    local_nonpersistent_flags+=("--auth-url=")
    flags+=("--graph-alias=")
    two_word_flags+=("--graph-alias")
    two_word_flags+=("-g")
    local_nonpersistent_flags+=("--graph-alias")
    local_nonpersistent_flags+=("--graph-alias=")
    local_nonpersistent_flags+=("-g")
    flags+=("--graph-id=")
    two_word_flags+=("--graph-id")
    local_nonpersistent_flags+=("--graph-id")
    local_nonpersistent_flags+=("--graph-id=")
    flags+=("--jwt=")
    two_word_flags+=("--jwt")
    local_nonpersistent_flags+=("--jwt")
    local_nonpersistent_flags+=("--jwt=")
    flags+=("--ruby-token=")
    two_word_flags+=("--ruby-token")
    local_nonpersistent_flags+=("--ruby-token")
    local_nonpersistent_flags+=("--ruby-token=")
    flags+=("--variant=")
    two_word_flags+=("--variant")
    local_nonpersistent_flags+=("--variant")
    local_nonpersistent_flags+=("--variant=")
    flags+=("--docker-compose-file=")
    two_word_flags+=("--docker-compose-file")
    flags+=("--in-docker-compose=")
    two_word_flags+=("--in-docker-compose")
    flags+=("--insecure-skip-verify")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_graphql_dev()
{
    last_command="tng_graphql_dev"

    command_aliases=()

    commands=()
    commands+=("auth")
    commands+=("config")
    commands+=("explorer")
    commands+=("info")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("status")
        aliashash["status"]="info"
    fi
    commands+=("reset")
    commands+=("route")
    commands+=("start")
    commands+=("stop")
    commands+=("update")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--docker-compose-file=")
    two_word_flags+=("--docker-compose-file")
    flags+=("--in-docker-compose=")
    two_word_flags+=("--in-docker-compose")
    flags+=("--insecure-skip-verify")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_graphql_fetch()
{
    last_command="tng_graphql_fetch"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--auth-client-id=")
    two_word_flags+=("--auth-client-id")
    local_nonpersistent_flags+=("--auth-client-id")
    local_nonpersistent_flags+=("--auth-client-id=")
    flags+=("--auth-client-secret=")
    two_word_flags+=("--auth-client-secret")
    local_nonpersistent_flags+=("--auth-client-secret")
    local_nonpersistent_flags+=("--auth-client-secret=")
    flags+=("--auth-url=")
    two_word_flags+=("--auth-url")
    local_nonpersistent_flags+=("--auth-url")
    local_nonpersistent_flags+=("--auth-url=")
    flags+=("--endpoint=")
    two_word_flags+=("--endpoint")
    local_nonpersistent_flags+=("--endpoint")
    local_nonpersistent_flags+=("--endpoint=")
    flags+=("--jwt=")
    two_word_flags+=("--jwt")
    local_nonpersistent_flags+=("--jwt")
    local_nonpersistent_flags+=("--jwt=")
    flags+=("--ruby-token=")
    two_word_flags+=("--ruby-token")
    local_nonpersistent_flags+=("--ruby-token")
    local_nonpersistent_flags+=("--ruby-token=")
    flags+=("--sdl-file-glob=")
    two_word_flags+=("--sdl-file-glob")
    local_nonpersistent_flags+=("--sdl-file-glob")
    local_nonpersistent_flags+=("--sdl-file-glob=")
    flags+=("--sdl-file-path=")
    two_word_flags+=("--sdl-file-path")
    local_nonpersistent_flags+=("--sdl-file-path")
    local_nonpersistent_flags+=("--sdl-file-path=")
    flags+=("--service=")
    two_word_flags+=("--service")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    flags+=("--docker-compose-file=")
    two_word_flags+=("--docker-compose-file")
    flags+=("--in-docker-compose=")
    two_word_flags+=("--in-docker-compose")
    flags+=("--insecure-skip-verify")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_graphql_publish_operations()
{
    last_command="tng_graphql_publish_operations"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--apollo-key=")
    two_word_flags+=("--apollo-key")
    local_nonpersistent_flags+=("--apollo-key")
    local_nonpersistent_flags+=("--apollo-key=")
    flags+=("--descriptor-path=")
    two_word_flags+=("--descriptor-path")
    local_nonpersistent_flags+=("--descriptor-path")
    local_nonpersistent_flags+=("--descriptor-path=")
    flags+=("--git-branch=")
    two_word_flags+=("--git-branch")
    local_nonpersistent_flags+=("--git-branch")
    local_nonpersistent_flags+=("--git-branch=")
    flags+=("--git-commit=")
    two_word_flags+=("--git-commit")
    local_nonpersistent_flags+=("--git-commit")
    local_nonpersistent_flags+=("--git-commit=")
    flags+=("--git-remote-url=")
    two_word_flags+=("--git-remote-url")
    local_nonpersistent_flags+=("--git-remote-url")
    local_nonpersistent_flags+=("--git-remote-url=")
    flags+=("--git-user=")
    two_word_flags+=("--git-user")
    local_nonpersistent_flags+=("--git-user")
    local_nonpersistent_flags+=("--git-user=")
    flags+=("--graph-alias=")
    two_word_flags+=("--graph-alias")
    two_word_flags+=("-g")
    local_nonpersistent_flags+=("--graph-alias")
    local_nonpersistent_flags+=("--graph-alias=")
    local_nonpersistent_flags+=("-g")
    flags+=("--graph-id=")
    two_word_flags+=("--graph-id")
    local_nonpersistent_flags+=("--graph-id")
    local_nonpersistent_flags+=("--graph-id=")
    flags+=("--manifest-path=")
    two_word_flags+=("--manifest-path")
    local_nonpersistent_flags+=("--manifest-path")
    local_nonpersistent_flags+=("--manifest-path=")
    flags+=("--operations=")
    two_word_flags+=("--operations")
    local_nonpersistent_flags+=("--operations")
    local_nonpersistent_flags+=("--operations=")
    flags+=("--variant=")
    two_word_flags+=("--variant")
    local_nonpersistent_flags+=("--variant")
    local_nonpersistent_flags+=("--variant=")
    flags+=("--docker-compose-file=")
    two_word_flags+=("--docker-compose-file")
    flags+=("--in-docker-compose=")
    two_word_flags+=("--in-docker-compose")
    flags+=("--insecure-skip-verify")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_graphql_publish_subgraph()
{
    last_command="tng_graphql_publish_subgraph"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--apollo-key=")
    two_word_flags+=("--apollo-key")
    local_nonpersistent_flags+=("--apollo-key")
    local_nonpersistent_flags+=("--apollo-key=")
    flags+=("--auth-client-id=")
    two_word_flags+=("--auth-client-id")
    local_nonpersistent_flags+=("--auth-client-id")
    local_nonpersistent_flags+=("--auth-client-id=")
    flags+=("--auth-client-secret=")
    two_word_flags+=("--auth-client-secret")
    local_nonpersistent_flags+=("--auth-client-secret")
    local_nonpersistent_flags+=("--auth-client-secret=")
    flags+=("--auth-url=")
    two_word_flags+=("--auth-url")
    local_nonpersistent_flags+=("--auth-url")
    local_nonpersistent_flags+=("--auth-url=")
    flags+=("--endpoint=")
    two_word_flags+=("--endpoint")
    local_nonpersistent_flags+=("--endpoint")
    local_nonpersistent_flags+=("--endpoint=")
    flags+=("--git-branch=")
    two_word_flags+=("--git-branch")
    local_nonpersistent_flags+=("--git-branch")
    local_nonpersistent_flags+=("--git-branch=")
    flags+=("--git-commit=")
    two_word_flags+=("--git-commit")
    local_nonpersistent_flags+=("--git-commit")
    local_nonpersistent_flags+=("--git-commit=")
    flags+=("--git-remote-url=")
    two_word_flags+=("--git-remote-url")
    local_nonpersistent_flags+=("--git-remote-url")
    local_nonpersistent_flags+=("--git-remote-url=")
    flags+=("--git-user=")
    two_word_flags+=("--git-user")
    local_nonpersistent_flags+=("--git-user")
    local_nonpersistent_flags+=("--git-user=")
    flags+=("--graph-alias=")
    two_word_flags+=("--graph-alias")
    two_word_flags+=("-g")
    local_nonpersistent_flags+=("--graph-alias")
    local_nonpersistent_flags+=("--graph-alias=")
    local_nonpersistent_flags+=("-g")
    flags+=("--graph-id=")
    two_word_flags+=("--graph-id")
    local_nonpersistent_flags+=("--graph-id")
    local_nonpersistent_flags+=("--graph-id=")
    flags+=("--jwt=")
    two_word_flags+=("--jwt")
    local_nonpersistent_flags+=("--jwt")
    local_nonpersistent_flags+=("--jwt=")
    flags+=("--launchdarkly-sdk-key=")
    two_word_flags+=("--launchdarkly-sdk-key")
    local_nonpersistent_flags+=("--launchdarkly-sdk-key")
    local_nonpersistent_flags+=("--launchdarkly-sdk-key=")
    flags+=("--ruby-token=")
    two_word_flags+=("--ruby-token")
    local_nonpersistent_flags+=("--ruby-token")
    local_nonpersistent_flags+=("--ruby-token=")
    flags+=("--sdl-file-glob=")
    two_word_flags+=("--sdl-file-glob")
    local_nonpersistent_flags+=("--sdl-file-glob")
    local_nonpersistent_flags+=("--sdl-file-glob=")
    flags+=("--sdl-file-path=")
    two_word_flags+=("--sdl-file-path")
    local_nonpersistent_flags+=("--sdl-file-path")
    local_nonpersistent_flags+=("--sdl-file-path=")
    flags+=("--service=")
    two_word_flags+=("--service")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    flags+=("--variant=")
    two_word_flags+=("--variant")
    local_nonpersistent_flags+=("--variant")
    local_nonpersistent_flags+=("--variant=")
    flags+=("--docker-compose-file=")
    two_word_flags+=("--docker-compose-file")
    flags+=("--in-docker-compose=")
    two_word_flags+=("--in-docker-compose")
    flags+=("--insecure-skip-verify")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_graphql_publish()
{
    last_command="tng_graphql_publish"

    command_aliases=()

    commands=()
    commands+=("operations")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("op")
        aliashash["op"]="operations"
        command_aliases+=("operation")
        aliashash["operation"]="operations"
    fi
    commands+=("subgraph")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--docker-compose-file=")
    two_word_flags+=("--docker-compose-file")
    flags+=("--in-docker-compose=")
    two_word_flags+=("--in-docker-compose")
    flags+=("--insecure-skip-verify")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_graphql_supergraph_fetch()
{
    last_command="tng_graphql_supergraph_fetch"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--apollo-key=")
    two_word_flags+=("--apollo-key")
    local_nonpersistent_flags+=("--apollo-key")
    local_nonpersistent_flags+=("--apollo-key=")
    flags+=("--graph-alias=")
    two_word_flags+=("--graph-alias")
    two_word_flags+=("-g")
    local_nonpersistent_flags+=("--graph-alias")
    local_nonpersistent_flags+=("--graph-alias=")
    local_nonpersistent_flags+=("-g")
    flags+=("--graph-id=")
    two_word_flags+=("--graph-id")
    local_nonpersistent_flags+=("--graph-id")
    local_nonpersistent_flags+=("--graph-id=")
    flags+=("--variant=")
    two_word_flags+=("--variant")
    local_nonpersistent_flags+=("--variant")
    local_nonpersistent_flags+=("--variant=")
    flags+=("--docker-compose-file=")
    two_word_flags+=("--docker-compose-file")
    flags+=("--in-docker-compose=")
    two_word_flags+=("--in-docker-compose")
    flags+=("--insecure-skip-verify")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_graphql_supergraph()
{
    last_command="tng_graphql_supergraph"

    command_aliases=()

    commands=()
    commands+=("fetch")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--docker-compose-file=")
    two_word_flags+=("--docker-compose-file")
    flags+=("--in-docker-compose=")
    two_word_flags+=("--in-docker-compose")
    flags+=("--insecure-skip-verify")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_graphql_web()
{
    last_command="tng_graphql_web"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--dev")
    local_nonpersistent_flags+=("--dev")
    flags+=("--docker-compose-file=")
    two_word_flags+=("--docker-compose-file")
    flags+=("--in-docker-compose=")
    two_word_flags+=("--in-docker-compose")
    flags+=("--insecure-skip-verify")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_graphql()
{
    last_command="tng_graphql"

    command_aliases=()

    commands=()
    commands+=("auth")
    commands+=("check")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("validate")
        aliashash["validate"]="check"
    fi
    commands+=("config")
    commands+=("dashboard")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("dash")
        aliashash["dash"]="dashboard"
    fi
    commands+=("dev")
    commands+=("fetch")
    commands+=("publish")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("push")
        aliashash["push"]="publish"
    fi
    commands+=("supergraph")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("sg")
        aliashash["sg"]="supergraph"
    fi
    commands+=("web")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--docker-compose-file=")
    two_word_flags+=("--docker-compose-file")
    flags+=("--in-docker-compose=")
    two_word_flags+=("--in-docker-compose")
    flags+=("--insecure-skip-verify")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_help()
{
    last_command="tng_help"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tng_incident_hotfix_create()
{
    last_command="tng_incident_hotfix_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_incident_hotfix_deploy()
{
    last_command="tng_incident_hotfix_deploy"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_incident_hotfix()
{
    last_command="tng_incident_hotfix"

    command_aliases=()

    commands=()
    commands+=("create")
    commands+=("deploy")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_incident_report()
{
    last_command="tng_incident_report"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--no-discover-links")
    flags+=("-D")
    local_nonpersistent_flags+=("--no-discover-links")
    local_nonpersistent_flags+=("-D")
    flags+=("--no-use-links")
    flags+=("-L")
    local_nonpersistent_flags+=("--no-use-links")
    local_nonpersistent_flags+=("-L")
    flags+=("--test")
    flags+=("-t")
    local_nonpersistent_flags+=("--test")
    local_nonpersistent_flags+=("-t")
    flags+=("--trial")
    local_nonpersistent_flags+=("--trial")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_incident_start()
{
    last_command="tng_incident_start"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--env=")
    two_word_flags+=("--env")
    local_nonpersistent_flags+=("--env")
    local_nonpersistent_flags+=("--env=")
    flags+=("--test")
    flags+=("-t")
    local_nonpersistent_flags+=("--test")
    local_nonpersistent_flags+=("-t")
    flags+=("--trial")
    local_nonpersistent_flags+=("--trial")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_incident()
{
    last_command="tng_incident"

    command_aliases=()

    commands=()
    commands+=("hotfix")
    commands+=("report")
    commands+=("start")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("create")
        aliashash["create"]="start"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_jira_backfill()
{
    last_command="tng_jira_backfill"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--confirm")
    flags+=("-y")
    local_nonpersistent_flags+=("--confirm")
    local_nonpersistent_flags+=("-y")
    flags+=("--default-branch=")
    two_word_flags+=("--default-branch")
    local_nonpersistent_flags+=("--default-branch")
    local_nonpersistent_flags+=("--default-branch=")
    flags+=("--draft-pr")
    flags+=("-d")
    local_nonpersistent_flags+=("--draft-pr")
    local_nonpersistent_flags+=("-d")
    flags+=("--no-pr")
    local_nonpersistent_flags+=("--no-pr")
    flags+=("--project-key=")
    two_word_flags+=("--project-key")
    local_nonpersistent_flags+=("--project-key")
    local_nonpersistent_flags+=("--project-key=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_jira_start()
{
    last_command="tng_jira_start"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_jira()
{
    last_command="tng_jira"

    command_aliases=()

    commands=()
    commands+=("backfill")
    commands+=("start")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_kafka_config_init()
{
    last_command="tng_kafka_config_init"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--descriptor=")
    two_word_flags+=("--descriptor")
    two_word_flags+=("-d")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_kafka_config()
{
    last_command="tng_kafka_config"

    command_aliases=()

    commands=()
    commands+=("init")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--descriptor=")
    two_word_flags+=("--descriptor")
    two_word_flags+=("-d")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_kafka_consumer_failover()
{
    last_command="tng_kafka_consumer_failover"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--consumer=")
    two_word_flags+=("--consumer")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--consumer")
    local_nonpersistent_flags+=("--consumer=")
    local_nonpersistent_flags+=("-c")
    flags+=("--destination-region=")
    two_word_flags+=("--destination-region")
    local_nonpersistent_flags+=("--destination-region")
    local_nonpersistent_flags+=("--destination-region=")
    flags+=("--dry-run")
    local_nonpersistent_flags+=("--dry-run")
    flags+=("--failover-topic=")
    two_word_flags+=("--failover-topic")
    two_word_flags+=("-t")
    local_nonpersistent_flags+=("--failover-topic")
    local_nonpersistent_flags+=("--failover-topic=")
    local_nonpersistent_flags+=("-t")
    flags+=("--origin-region=")
    two_word_flags+=("--origin-region")
    local_nonpersistent_flags+=("--origin-region")
    local_nonpersistent_flags+=("--origin-region=")
    flags+=("--reason=")
    two_word_flags+=("--reason")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--reason")
    local_nonpersistent_flags+=("--reason=")
    local_nonpersistent_flags+=("-r")
    flags+=("--auto-approve")
    flags+=("-a")
    flags+=("--descriptor=")
    two_word_flags+=("--descriptor")
    two_word_flags+=("-d")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_kafka_consumer_list()
{
    last_command="tng_kafka_consumer_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--auto-approve")
    flags+=("-a")
    flags+=("--descriptor=")
    two_word_flags+=("--descriptor")
    two_word_flags+=("-d")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_kafka_consumer_pause()
{
    last_command="tng_kafka_consumer_pause"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--consumer=")
    two_word_flags+=("--consumer")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--consumer")
    local_nonpersistent_flags+=("--consumer=")
    local_nonpersistent_flags+=("-c")
    flags+=("--dry-run")
    local_nonpersistent_flags+=("--dry-run")
    flags+=("--reason=")
    two_word_flags+=("--reason")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--reason")
    local_nonpersistent_flags+=("--reason=")
    local_nonpersistent_flags+=("-r")
    flags+=("--topic=")
    two_word_flags+=("--topic")
    two_word_flags+=("-t")
    local_nonpersistent_flags+=("--topic")
    local_nonpersistent_flags+=("--topic=")
    local_nonpersistent_flags+=("-t")
    flags+=("--auto-approve")
    flags+=("-a")
    flags+=("--descriptor=")
    two_word_flags+=("--descriptor")
    two_word_flags+=("-d")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_kafka_consumer_redirect()
{
    last_command="tng_kafka_consumer_redirect"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--consumer=")
    two_word_flags+=("--consumer")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--consumer")
    local_nonpersistent_flags+=("--consumer=")
    local_nonpersistent_flags+=("-c")
    flags+=("--dry-run")
    local_nonpersistent_flags+=("--dry-run")
    flags+=("--reason=")
    two_word_flags+=("--reason")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--reason")
    local_nonpersistent_flags+=("--reason=")
    local_nonpersistent_flags+=("-r")
    flags+=("--topic=")
    two_word_flags+=("--topic")
    two_word_flags+=("-t")
    local_nonpersistent_flags+=("--topic")
    local_nonpersistent_flags+=("--topic=")
    local_nonpersistent_flags+=("-t")
    flags+=("--auto-approve")
    flags+=("-a")
    flags+=("--descriptor=")
    two_word_flags+=("--descriptor")
    two_word_flags+=("-d")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_kafka_consumer_reject()
{
    last_command="tng_kafka_consumer_reject"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--consumer=")
    two_word_flags+=("--consumer")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--consumer")
    local_nonpersistent_flags+=("--consumer=")
    local_nonpersistent_flags+=("-c")
    flags+=("--dry-run")
    local_nonpersistent_flags+=("--dry-run")
    flags+=("--reason=")
    two_word_flags+=("--reason")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--reason")
    local_nonpersistent_flags+=("--reason=")
    local_nonpersistent_flags+=("-r")
    flags+=("--topic=")
    two_word_flags+=("--topic")
    two_word_flags+=("-t")
    local_nonpersistent_flags+=("--topic")
    local_nonpersistent_flags+=("--topic=")
    local_nonpersistent_flags+=("-t")
    flags+=("--auto-approve")
    flags+=("-a")
    flags+=("--descriptor=")
    two_word_flags+=("--descriptor")
    two_word_flags+=("-d")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_kafka_consumer_set-offsets()
{
    last_command="tng_kafka_consumer_set-offsets"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--consumer=")
    two_word_flags+=("--consumer")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--consumer")
    local_nonpersistent_flags+=("--consumer=")
    local_nonpersistent_flags+=("-c")
    flags+=("--dry-run")
    local_nonpersistent_flags+=("--dry-run")
    flags+=("--reason=")
    two_word_flags+=("--reason")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--reason")
    local_nonpersistent_flags+=("--reason=")
    local_nonpersistent_flags+=("-r")
    flags+=("--topic=")
    two_word_flags+=("--topic")
    two_word_flags+=("-t")
    local_nonpersistent_flags+=("--topic")
    local_nonpersistent_flags+=("--topic=")
    local_nonpersistent_flags+=("-t")
    flags+=("--auto-approve")
    flags+=("-a")
    flags+=("--descriptor=")
    two_word_flags+=("--descriptor")
    two_word_flags+=("-d")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_kafka_consumer_status()
{
    last_command="tng_kafka_consumer_status"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--consumer=")
    two_word_flags+=("--consumer")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--consumer")
    local_nonpersistent_flags+=("--consumer=")
    local_nonpersistent_flags+=("-c")
    flags+=("--dry-run")
    local_nonpersistent_flags+=("--dry-run")
    flags+=("--limit=")
    two_word_flags+=("--limit")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--limit")
    local_nonpersistent_flags+=("--limit=")
    local_nonpersistent_flags+=("-l")
    flags+=("--reason=")
    two_word_flags+=("--reason")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--reason")
    local_nonpersistent_flags+=("--reason=")
    local_nonpersistent_flags+=("-r")
    flags+=("--topic=")
    two_word_flags+=("--topic")
    two_word_flags+=("-t")
    local_nonpersistent_flags+=("--topic")
    local_nonpersistent_flags+=("--topic=")
    local_nonpersistent_flags+=("-t")
    flags+=("--auto-approve")
    flags+=("-a")
    flags+=("--descriptor=")
    two_word_flags+=("--descriptor")
    two_word_flags+=("-d")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_kafka_consumer_unpause()
{
    last_command="tng_kafka_consumer_unpause"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--consumer=")
    two_word_flags+=("--consumer")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--consumer")
    local_nonpersistent_flags+=("--consumer=")
    local_nonpersistent_flags+=("-c")
    flags+=("--dry-run")
    local_nonpersistent_flags+=("--dry-run")
    flags+=("--reason=")
    two_word_flags+=("--reason")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--reason")
    local_nonpersistent_flags+=("--reason=")
    local_nonpersistent_flags+=("-r")
    flags+=("--topic=")
    two_word_flags+=("--topic")
    two_word_flags+=("-t")
    local_nonpersistent_flags+=("--topic")
    local_nonpersistent_flags+=("--topic=")
    local_nonpersistent_flags+=("-t")
    flags+=("--auto-approve")
    flags+=("-a")
    flags+=("--descriptor=")
    two_word_flags+=("--descriptor")
    two_word_flags+=("-d")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_kafka_consumer()
{
    last_command="tng_kafka_consumer"

    command_aliases=()

    commands=()
    commands+=("failover")
    commands+=("list")
    commands+=("pause")
    commands+=("redirect")
    commands+=("reject")
    commands+=("set-offsets")
    commands+=("status")
    commands+=("unpause")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--auto-approve")
    flags+=("-a")
    flags+=("--descriptor=")
    two_word_flags+=("--descriptor")
    two_word_flags+=("-d")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_kafka_dev_console()
{
    last_command="tng_kafka_dev_console"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--descriptor=")
    two_word_flags+=("--descriptor")
    two_word_flags+=("-d")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_kafka_dev_info()
{
    last_command="tng_kafka_dev_info"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--descriptor=")
    two_word_flags+=("--descriptor")
    two_word_flags+=("-d")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_kafka_dev_register()
{
    last_command="tng_kafka_dev_register"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--descriptor=")
    two_word_flags+=("--descriptor")
    two_word_flags+=("-d")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_kafka_dev_reset()
{
    last_command="tng_kafka_dev_reset"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--confirm")
    flags+=("-y")
    local_nonpersistent_flags+=("--confirm")
    local_nonpersistent_flags+=("-y")
    flags+=("--descriptor=")
    two_word_flags+=("--descriptor")
    two_word_flags+=("-d")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_kafka_dev_start()
{
    last_command="tng_kafka_dev_start"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--descriptor=")
    two_word_flags+=("--descriptor")
    two_word_flags+=("-d")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_kafka_dev_stop()
{
    last_command="tng_kafka_dev_stop"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--descriptor=")
    two_word_flags+=("--descriptor")
    two_word_flags+=("-d")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_kafka_dev()
{
    last_command="tng_kafka_dev"

    command_aliases=()

    commands=()
    commands+=("console")
    commands+=("info")
    commands+=("register")
    commands+=("reset")
    commands+=("start")
    commands+=("stop")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--descriptor=")
    two_word_flags+=("--descriptor")
    two_word_flags+=("-d")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_kafka_schemas_register()
{
    last_command="tng_kafka_schemas_register"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--descriptor=")
    two_word_flags+=("--descriptor")
    two_word_flags+=("-d")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_kafka_schemas()
{
    last_command="tng_kafka_schemas"

    command_aliases=()

    commands=()
    commands+=("register")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--descriptor=")
    two_word_flags+=("--descriptor")
    two_word_flags+=("-d")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_kafka()
{
    last_command="tng_kafka"

    command_aliases=()

    commands=()
    commands+=("config")
    commands+=("consumer")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("consumers")
        aliashash["consumers"]="consumer"
    fi
    commands+=("dev")
    commands+=("schemas")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--descriptor=")
    two_word_flags+=("--descriptor")
    two_word_flags+=("-d")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_observability_apply()
{
    last_command="tng_observability_apply"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--descriptor-dir=")
    two_word_flags+=("--descriptor-dir")
    local_nonpersistent_flags+=("--descriptor-dir")
    local_nonpersistent_flags+=("--descriptor-dir=")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace=")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--descriptor=")
    two_word_flags+=("--descriptor")
    two_word_flags+=("-d")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_observability_delete()
{
    last_command="tng_observability_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--delete-pd-services")
    local_nonpersistent_flags+=("--delete-pd-services")
    flags+=("--descriptor-dir=")
    two_word_flags+=("--descriptor-dir")
    local_nonpersistent_flags+=("--descriptor-dir")
    local_nonpersistent_flags+=("--descriptor-dir=")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace=")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--descriptor=")
    two_word_flags+=("--descriptor")
    two_word_flags+=("-d")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_observability_dev_console()
{
    last_command="tng_observability_dev_console"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--descriptor=")
    two_word_flags+=("--descriptor")
    two_word_flags+=("-d")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_observability_dev_reset()
{
    last_command="tng_observability_dev_reset"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--confirm")
    flags+=("-y")
    local_nonpersistent_flags+=("--confirm")
    local_nonpersistent_flags+=("-y")
    flags+=("--descriptor=")
    two_word_flags+=("--descriptor")
    two_word_flags+=("-d")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_observability_dev_start()
{
    last_command="tng_observability_dev_start"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--descriptor=")
    two_word_flags+=("--descriptor")
    two_word_flags+=("-d")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_observability_dev_stop()
{
    last_command="tng_observability_dev_stop"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--descriptor=")
    two_word_flags+=("--descriptor")
    two_word_flags+=("-d")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_observability_dev()
{
    last_command="tng_observability_dev"

    command_aliases=()

    commands=()
    commands+=("console")
    commands+=("reset")
    commands+=("start")
    commands+=("stop")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--descriptor=")
    two_word_flags+=("--descriptor")
    two_word_flags+=("-d")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_observability()
{
    last_command="tng_observability"

    command_aliases=()

    commands=()
    commands+=("apply")
    commands+=("delete")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("del")
        aliashash["del"]="delete"
    fi
    commands+=("dev")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--descriptor=")
    two_word_flags+=("--descriptor")
    two_word_flags+=("-d")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_opslevel_check()
{
    last_command="tng_opslevel_check"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--check-all-services")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_opslevel()
{
    last_command="tng_opslevel"

    command_aliases=()

    commands=()
    commands+=("check")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--check-all-services")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_parameters_add()
{
    last_command="tng_parameters_add"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--selector=")
    two_word_flags+=("--selector")
    local_nonpersistent_flags+=("--selector")
    local_nonpersistent_flags+=("--selector=")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--fs=")
    two_word_flags+=("--fs")
    flags_with_completion+=("--fs")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_parameters_adjust_regionality()
{
    last_command="tng_parameters_adjust_regionality"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--region=")
    two_word_flags+=("--region")
    flags_with_completion+=("--region")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--fs=")
    two_word_flags+=("--fs")
    flags_with_completion+=("--fs")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_parameters_adjust()
{
    last_command="tng_parameters_adjust"

    command_aliases=()

    commands=()
    commands+=("regionality")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--fs=")
    two_word_flags+=("--fs")
    flags_with_completion+=("--fs")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_parameters_dump()
{
    last_command="tng_parameters_dump"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--app=")
    two_word_flags+=("--app")
    flags_with_completion+=("--app")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-a")
    flags_with_completion+=("-a")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--app")
    local_nonpersistent_flags+=("--app=")
    local_nonpersistent_flags+=("-a")
    flags+=("--compute-job=")
    two_word_flags+=("--compute-job")
    local_nonpersistent_flags+=("--compute-job")
    local_nonpersistent_flags+=("--compute-job=")
    flags+=("--decrypt")
    flags+=("-d")
    local_nonpersistent_flags+=("--decrypt")
    local_nonpersistent_flags+=("-d")
    flags+=("--dev")
    local_nonpersistent_flags+=("--dev")
    flags+=("--region=")
    two_word_flags+=("--region")
    flags_with_completion+=("--region")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    flags+=("--role=")
    two_word_flags+=("--role")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--role")
    local_nonpersistent_flags+=("--role=")
    local_nonpersistent_flags+=("-r")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--fs=")
    two_word_flags+=("--fs")
    flags_with_completion+=("--fs")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_parameters_edit()
{
    last_command="tng_parameters_edit"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--dev")
    local_nonpersistent_flags+=("--dev")
    flags+=("--region=")
    two_word_flags+=("--region")
    flags_with_completion+=("--region")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    flags+=("--schema=")
    two_word_flags+=("--schema")
    local_nonpersistent_flags+=("--schema")
    local_nonpersistent_flags+=("--schema=")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--fs=")
    two_word_flags+=("--fs")
    flags_with_completion+=("--fs")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_parameters_env()
{
    last_command="tng_parameters_env"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--app=")
    two_word_flags+=("--app")
    flags_with_completion+=("--app")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-a")
    flags_with_completion+=("-a")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--app")
    local_nonpersistent_flags+=("--app=")
    local_nonpersistent_flags+=("-a")
    flags+=("--compute-job=")
    two_word_flags+=("--compute-job")
    local_nonpersistent_flags+=("--compute-job")
    local_nonpersistent_flags+=("--compute-job=")
    flags+=("--dev")
    local_nonpersistent_flags+=("--dev")
    flags+=("--region=")
    two_word_flags+=("--region")
    flags_with_completion+=("--region")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    flags+=("--role=")
    two_word_flags+=("--role")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--role")
    local_nonpersistent_flags+=("--role=")
    local_nonpersistent_flags+=("-r")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--skip-validation")
    local_nonpersistent_flags+=("--skip-validation")
    flags+=("--fs=")
    two_word_flags+=("--fs")
    flags_with_completion+=("--fs")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_parameters_exec()
{
    last_command="tng_parameters_exec"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--app=")
    two_word_flags+=("--app")
    flags_with_completion+=("--app")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-a")
    flags_with_completion+=("-a")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--app")
    local_nonpersistent_flags+=("--app=")
    local_nonpersistent_flags+=("-a")
    flags+=("--compute-job=")
    two_word_flags+=("--compute-job")
    local_nonpersistent_flags+=("--compute-job")
    local_nonpersistent_flags+=("--compute-job=")
    flags+=("--dev")
    local_nonpersistent_flags+=("--dev")
    flags+=("--region=")
    two_word_flags+=("--region")
    flags_with_completion+=("--region")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    flags+=("--role=")
    two_word_flags+=("--role")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--role")
    local_nonpersistent_flags+=("--role=")
    local_nonpersistent_flags+=("-r")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--skip-validation")
    local_nonpersistent_flags+=("--skip-validation")
    flags+=("--fs=")
    two_word_flags+=("--fs")
    flags_with_completion+=("--fs")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_parameters_get()
{
    last_command="tng_parameters_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--app=")
    two_word_flags+=("--app")
    flags_with_completion+=("--app")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-a")
    flags_with_completion+=("-a")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--app")
    local_nonpersistent_flags+=("--app=")
    local_nonpersistent_flags+=("-a")
    flags+=("--dev")
    local_nonpersistent_flags+=("--dev")
    flags+=("--region=")
    two_word_flags+=("--region")
    flags_with_completion+=("--region")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    flags+=("--role=")
    two_word_flags+=("--role")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--role")
    local_nonpersistent_flags+=("--role=")
    local_nonpersistent_flags+=("-r")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--skip-validation")
    local_nonpersistent_flags+=("--skip-validation")
    flags+=("--fs=")
    two_word_flags+=("--fs")
    flags_with_completion+=("--fs")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_parameters_history()
{
    last_command="tng_parameters_history"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--columns=")
    two_word_flags+=("--columns")
    local_nonpersistent_flags+=("--columns")
    local_nonpersistent_flags+=("--columns=")
    flags+=("--decrypt")
    flags+=("-d")
    local_nonpersistent_flags+=("--decrypt")
    local_nonpersistent_flags+=("-d")
    flags+=("--limit=")
    two_word_flags+=("--limit")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--limit")
    local_nonpersistent_flags+=("--limit=")
    local_nonpersistent_flags+=("-l")
    flags+=("--parameter=")
    two_word_flags+=("--parameter")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--parameter")
    local_nonpersistent_flags+=("--parameter=")
    local_nonpersistent_flags+=("-p")
    flags+=("--region=")
    two_word_flags+=("--region")
    flags_with_completion+=("--region")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--timezone=")
    two_word_flags+=("--timezone")
    local_nonpersistent_flags+=("--timezone")
    local_nonpersistent_flags+=("--timezone=")
    flags+=("--fs=")
    two_word_flags+=("--fs")
    flags_with_completion+=("--fs")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_parameters_list()
{
    last_command="tng_parameters_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--columns=")
    two_word_flags+=("--columns")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--columns")
    local_nonpersistent_flags+=("--columns=")
    local_nonpersistent_flags+=("-c")
    flags+=("--decrypt")
    flags+=("-d")
    local_nonpersistent_flags+=("--decrypt")
    local_nonpersistent_flags+=("-d")
    flags+=("--preset=")
    two_word_flags+=("--preset")
    local_nonpersistent_flags+=("--preset")
    local_nonpersistent_flags+=("--preset=")
    flags+=("--print-columns")
    local_nonpersistent_flags+=("--print-columns")
    flags+=("--selector=")
    two_word_flags+=("--selector")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--selector")
    local_nonpersistent_flags+=("--selector=")
    local_nonpersistent_flags+=("-l")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--skip-validation")
    local_nonpersistent_flags+=("--skip-validation")
    flags+=("--timezone=")
    two_word_flags+=("--timezone")
    local_nonpersistent_flags+=("--timezone")
    local_nonpersistent_flags+=("--timezone=")
    flags+=("--fs=")
    two_word_flags+=("--fs")
    flags_with_completion+=("--fs")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_parameters_schema()
{
    last_command="tng_parameters_schema"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--fs=")
    two_word_flags+=("--fs")
    flags_with_completion+=("--fs")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_parameters_set()
{
    last_command="tng_parameters_set"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--confirm")
    flags+=("-y")
    local_nonpersistent_flags+=("--confirm")
    local_nonpersistent_flags+=("-y")
    flags+=("--dev")
    local_nonpersistent_flags+=("--dev")
    flags+=("--diff-only")
    local_nonpersistent_flags+=("--diff-only")
    flags+=("--from-env=")
    two_word_flags+=("--from-env")
    local_nonpersistent_flags+=("--from-env")
    local_nonpersistent_flags+=("--from-env=")
    flags+=("--from-file=")
    two_word_flags+=("--from-file")
    local_nonpersistent_flags+=("--from-file")
    local_nonpersistent_flags+=("--from-file=")
    flags+=("--region=")
    two_word_flags+=("--region")
    flags_with_completion+=("--region")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--ttl=")
    two_word_flags+=("--ttl")
    local_nonpersistent_flags+=("--ttl")
    local_nonpersistent_flags+=("--ttl=")
    flags+=("--fs=")
    two_word_flags+=("--fs")
    flags_with_completion+=("--fs")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tng_parameters_set-missing()
{
    last_command="tng_parameters_set-missing"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--fs=")
    two_word_flags+=("--fs")
    flags_with_completion+=("--fs")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_parameters_tidy()
{
    last_command="tng_parameters_tidy"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--confirm")
    flags+=("-y")
    local_nonpersistent_flags+=("--confirm")
    local_nonpersistent_flags+=("-y")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--fs=")
    two_word_flags+=("--fs")
    flags_with_completion+=("--fs")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_parameters_unset()
{
    last_command="tng_parameters_unset"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--dev")
    local_nonpersistent_flags+=("--dev")
    flags+=("--region=")
    two_word_flags+=("--region")
    flags_with_completion+=("--region")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--fs=")
    two_word_flags+=("--fs")
    flags_with_completion+=("--fs")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_parameters_validate()
{
    last_command="tng_parameters_validate"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--columns=")
    two_word_flags+=("--columns")
    local_nonpersistent_flags+=("--columns")
    local_nonpersistent_flags+=("--columns=")
    flags+=("--region=")
    two_word_flags+=("--region")
    flags_with_completion+=("--region")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--region")
    local_nonpersistent_flags+=("--region=")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--skip-validation")
    local_nonpersistent_flags+=("--skip-validation")
    flags+=("--fs=")
    two_word_flags+=("--fs")
    flags_with_completion+=("--fs")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_parameters()
{
    last_command="tng_parameters"

    command_aliases=()

    commands=()
    commands+=("add")
    commands+=("adjust")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("alter")
        aliashash["alter"]="adjust"
    fi
    commands+=("dump")
    commands+=("edit")
    commands+=("env")
    commands+=("exec")
    commands+=("get")
    commands+=("history")
    commands+=("list")
    commands+=("schema")
    commands+=("set")
    commands+=("set-missing")
    commands+=("tidy")
    commands+=("unset")
    commands+=("validate")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--fs=")
    two_word_flags+=("--fs")
    flags_with_completion+=("--fs")
    flags_completion+=("__tng_handle_go_custom_completion")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_repo_github_configure()
{
    last_command="tng_repo_github_configure"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--description=")
    two_word_flags+=("--description")
    two_word_flags+=("-d")
    local_nonpersistent_flags+=("--description")
    local_nonpersistent_flags+=("--description=")
    local_nonpersistent_flags+=("-d")
    flags+=("--primary-team=")
    two_word_flags+=("--primary-team")
    two_word_flags+=("-t")
    local_nonpersistent_flags+=("--primary-team")
    local_nonpersistent_flags+=("--primary-team=")
    local_nonpersistent_flags+=("-t")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_repo_github()
{
    last_command="tng_repo_github"

    command_aliases=()

    commands=()
    commands+=("configure")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_repo_init()
{
    last_command="tng_repo_init"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_repo_new_go()
{
    last_command="tng_repo_new_go"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_repo_new()
{
    last_command="tng_repo_new"

    command_aliases=()

    commands=()
    commands+=("go")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_repo_template_adr()
{
    last_command="tng_repo_template_adr"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--title=")
    two_word_flags+=("--title")
    local_nonpersistent_flags+=("--title")
    local_nonpersistent_flags+=("--title=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_repo_template()
{
    last_command="tng_repo_template"

    command_aliases=()

    commands=()
    commands+=("adr")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_repo_update_check()
{
    last_command="tng_repo_update_check"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_repo_update_run()
{
    last_command="tng_repo_update_run"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_repo_update()
{
    last_command="tng_repo_update"

    command_aliases=()

    commands=()
    commands+=("check")
    commands+=("run")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_repo()
{
    last_command="tng_repo"

    command_aliases=()

    commands=()
    commands+=("github")
    commands+=("init")
    commands+=("new")
    commands+=("template")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("t")
        aliashash["t"]="template"
    fi
    commands+=("update")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("u")
        aliashash["u"]="update"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_run_mcp()
{
    last_command="tng_run_mcp"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_run()
{
    last_command="tng_run"

    command_aliases=()

    commands=()
    commands+=("mcp")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_service_clone()
{
    last_command="tng_service_clone"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tng_service_debug()
{
    last_command="tng_service_debug"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--cpu=")
    two_word_flags+=("--cpu")
    local_nonpersistent_flags+=("--cpu")
    local_nonpersistent_flags+=("--cpu=")
    flags+=("--duration=")
    two_word_flags+=("--duration")
    two_word_flags+=("-d")
    flags+=("--interactive")
    flags+=("-i")
    flags+=("--memory=")
    two_word_flags+=("--memory")
    local_nonpersistent_flags+=("--memory")
    local_nonpersistent_flags+=("--memory=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tng_service_failover()
{
    last_command="tng_service_failover"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--app=")
    two_word_flags+=("--app")
    flags_with_completion+=("--app")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--app")
    local_nonpersistent_flags+=("--app=")
    flags+=("--destination-region=")
    two_word_flags+=("--destination-region")
    local_nonpersistent_flags+=("--destination-region")
    local_nonpersistent_flags+=("--destination-region=")
    flags+=("--origin-region=")
    two_word_flags+=("--origin-region")
    local_nonpersistent_flags+=("--origin-region")
    local_nonpersistent_flags+=("--origin-region=")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    flags+=("--type=")
    two_word_flags+=("--type")
    flags_with_completion+=("--type")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--type")
    local_nonpersistent_flags+=("--type=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_service_list()
{
    last_command="tng_service_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--app=")
    two_word_flags+=("--app")
    flags_with_completion+=("--app")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--app")
    local_nonpersistent_flags+=("--app=")
    flags+=("--include-undeployed")
    local_nonpersistent_flags+=("--include-undeployed")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    flags+=("--type=")
    two_word_flags+=("--type")
    flags_with_completion+=("--type")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--type")
    local_nonpersistent_flags+=("--type=")
    flags+=("--with=")
    two_word_flags+=("--with")
    local_nonpersistent_flags+=("--with")
    local_nonpersistent_flags+=("--with=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_service_logs()
{
    last_command="tng_service_logs"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--container=")
    two_word_flags+=("--container")
    two_word_flags+=("-c")
    flags+=("--follow")
    flags+=("-f")
    flags+=("--previous")
    flags+=("-p")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tng_service_restart()
{
    last_command="tng_service_restart"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--app=")
    two_word_flags+=("--app")
    flags_with_completion+=("--app")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--app")
    local_nonpersistent_flags+=("--app=")
    flags+=("--dry-run")
    local_nonpersistent_flags+=("--dry-run")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    flags+=("--type=")
    two_word_flags+=("--type")
    flags_with_completion+=("--type")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--type")
    local_nonpersistent_flags+=("--type=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tng_service_status()
{
    last_command="tng_service_status"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--app=")
    two_word_flags+=("--app")
    flags_with_completion+=("--app")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--app")
    local_nonpersistent_flags+=("--app=")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    flags+=("--type=")
    two_word_flags+=("--type")
    flags_with_completion+=("--type")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--type")
    local_nonpersistent_flags+=("--type=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_tng_service_weblogs()
{
    last_command="tng_service_weblogs"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--app=")
    two_word_flags+=("--app")
    flags_with_completion+=("--app")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-a")
    flags_with_completion+=("-a")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--app")
    local_nonpersistent_flags+=("--app=")
    local_nonpersistent_flags+=("-a")
    flags+=("--env=")
    two_word_flags+=("--env")
    local_nonpersistent_flags+=("--env")
    local_nonpersistent_flags+=("--env=")
    flags+=("--from=")
    two_word_flags+=("--from")
    local_nonpersistent_flags+=("--from")
    local_nonpersistent_flags+=("--from=")
    flags+=("--keyword=")
    two_word_flags+=("--keyword")
    two_word_flags+=("-k")
    local_nonpersistent_flags+=("--keyword")
    local_nonpersistent_flags+=("--keyword=")
    local_nonpersistent_flags+=("-k")
    flags+=("--level=")
    two_word_flags+=("--level")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--level")
    local_nonpersistent_flags+=("--level=")
    local_nonpersistent_flags+=("-l")
    flags+=("--query=")
    two_word_flags+=("--query")
    two_word_flags+=("-q")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--to=")
    two_word_flags+=("--to")
    local_nonpersistent_flags+=("--to")
    local_nonpersistent_flags+=("--to=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_service()
{
    last_command="tng_service"

    command_aliases=()

    commands=()
    commands+=("clone")
    commands+=("debug")
    commands+=("failover")
    commands+=("list")
    commands+=("logs")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("log")
        aliashash["log"]="logs"
    fi
    commands+=("restart")
    commands+=("status")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("events")
        aliashash["events"]="status"
    fi
    commands+=("weblogs")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_status()
{
    last_command="tng_status"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_temporal_config_apply()
{
    last_command="tng_temporal_config_apply"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--descriptor=")
    two_word_flags+=("--descriptor")
    local_nonpersistent_flags+=("--descriptor")
    local_nonpersistent_flags+=("--descriptor=")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_temporal_config_init()
{
    last_command="tng_temporal_config_init"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_temporal_config()
{
    last_command="tng_temporal_config"

    command_aliases=()

    commands=()
    commands+=("apply")
    commands+=("init")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_temporal_dev_info()
{
    last_command="tng_temporal_dev_info"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_temporal_dev_reset()
{
    last_command="tng_temporal_dev_reset"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_temporal_dev_start()
{
    last_command="tng_temporal_dev_start"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_temporal_dev_stop()
{
    last_command="tng_temporal_dev_stop"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_temporal_dev()
{
    last_command="tng_temporal_dev"

    command_aliases=()

    commands=()
    commands+=("info")
    commands+=("reset")
    commands+=("start")
    commands+=("stop")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_temporal_endpoint()
{
    last_command="tng_temporal_endpoint"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_temporal_new_workflow()
{
    last_command="tng_temporal_new_workflow"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--codegen-config=")
    two_word_flags+=("--codegen-config")
    local_nonpersistent_flags+=("--codegen-config")
    local_nonpersistent_flags+=("--codegen-config=")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--workflow-name=")
    two_word_flags+=("--workflow-name")
    local_nonpersistent_flags+=("--workflow-name")
    local_nonpersistent_flags+=("--workflow-name=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_temporal_new()
{
    last_command="tng_temporal_new"

    command_aliases=()

    commands=()
    commands+=("workflow")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_temporal()
{
    last_command="tng_temporal"

    command_aliases=()

    commands=()
    commands+=("config")
    commands+=("dev")
    commands+=("endpoint")
    commands+=("new")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_terraform_provider_authzilla()
{
    last_command="tng_terraform_provider_authzilla"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_terraform_provider_install()
{
    last_command="tng_terraform_provider_install"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_terraform_provider()
{
    last_command="tng_terraform_provider"

    command_aliases=()

    commands=()
    commands+=("authzilla")
    commands+=("install")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_terraform()
{
    last_command="tng_terraform"

    command_aliases=()

    commands=()
    commands+=("provider")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_tool_docker()
{
    last_command="tng_tool_docker"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flag_parsing_disabled=1
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_tool_docker-compose()
{
    last_command="tng_tool_docker-compose"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flag_parsing_disabled=1
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_tool_rancher-helm()
{
    last_command="tng_tool_rancher-helm"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flag_parsing_disabled=1
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_tool_rancher-kubectl()
{
    last_command="tng_tool_rancher-kubectl"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flag_parsing_disabled=1
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_tool()
{
    last_command="tng_tool"

    command_aliases=()

    commands=()
    commands+=("docker")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("d")
        aliashash["d"]="docker"
    fi
    commands+=("docker-compose")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("dc")
        aliashash["dc"]="docker-compose"
    fi
    commands+=("rancher-helm")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("rh")
        aliashash["rh"]="rancher-helm"
    fi
    commands+=("rancher-kubectl")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("rk")
        aliashash["rk"]="rancher-kubectl"
    fi

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_visualize()
{
    last_command="tng_visualize"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--dump")
    local_nonpersistent_flags+=("--dump")
    flags+=("--out=")
    two_word_flags+=("--out")
    local_nonpersistent_flags+=("--out")
    local_nonpersistent_flags+=("--out=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_wordsmith_generate-key()
{
    last_command="tng_wordsmith_generate-key"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--max-budget=")
    two_word_flags+=("--max-budget")
    local_nonpersistent_flags+=("--max-budget")
    local_nonpersistent_flags+=("--max-budget=")
    flags+=("--models=")
    two_word_flags+=("--models")
    local_nonpersistent_flags+=("--models")
    local_nonpersistent_flags+=("--models=")
    flags+=("--service=")
    two_word_flags+=("--service")
    flags_with_completion+=("--service")
    flags_completion+=("__tng_handle_go_custom_completion")
    two_word_flags+=("-s")
    flags_with_completion+=("-s")
    flags_completion+=("__tng_handle_go_custom_completion")
    local_nonpersistent_flags+=("--service")
    local_nonpersistent_flags+=("--service=")
    local_nonpersistent_flags+=("-s")
    flags+=("--ttl=")
    two_word_flags+=("--ttl")
    local_nonpersistent_flags+=("--ttl")
    local_nonpersistent_flags+=("--ttl=")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_wordsmith()
{
    last_command="tng_wordsmith"

    command_aliases=()

    commands=()
    commands+=("generate-key")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_tng_root_command()
{
    last_command="tng"

    command_aliases=()

    commands=()
    commands+=("auth")
    commands+=("breakglass")
    commands+=("codegen")
    commands+=("completion")
    commands+=("compute")
    commands+=("config")
    commands+=("cronjob")
    commands+=("deploy")
    commands+=("dev")
    commands+=("dump-help")
    commands+=("flags")
    commands+=("git")
    commands+=("graphql")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("apollo")
        aliashash["apollo"]="graphql"
        command_aliases+=("gql")
        aliashash["gql"]="graphql"
    fi
    commands+=("help")
    commands+=("incident")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("inc")
        aliashash["inc"]="incident"
    fi
    commands+=("jira")
    commands+=("kafka")
    commands+=("observability")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("o11y")
        aliashash["o11y"]="observability"
        command_aliases+=("obs")
        aliashash["obs"]="observability"
    fi
    commands+=("opslevel")
    commands+=("parameters")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("param")
        aliashash["param"]="parameters"
        command_aliases+=("parameter")
        aliashash["parameter"]="parameters"
        command_aliases+=("params")
        aliashash["params"]="parameters"
        command_aliases+=("secret")
        aliashash["secret"]="parameters"
        command_aliases+=("secrets")
        aliashash["secrets"]="parameters"
    fi
    commands+=("repo")
    commands+=("run")
    commands+=("service")
    commands+=("status")
    commands+=("temporal")
    commands+=("terraform")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("tf")
        aliashash["tf"]="terraform"
    fi
    commands+=("tool")
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        command_aliases+=("tools")
        aliashash["tools"]="tool"
    fi
    commands+=("visualize")
    commands+=("wordsmith")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    flags+=("--server=")
    two_word_flags+=("--server")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

__start_tng()
{
    local cur prev words cword split
    declare -A flaghash 2>/dev/null || :
    declare -A aliashash 2>/dev/null || :
    if declare -F _init_completion >/dev/null 2>&1; then
        _init_completion -s || return
    else
        __tng_init_completion -n "=" || return
    fi

    local c=0
    local flag_parsing_disabled=
    local flags=()
    local two_word_flags=()
    local local_nonpersistent_flags=()
    local flags_with_completion=()
    local flags_completion=()
    local commands=("tng")
    local command_aliases=()
    local must_have_one_flag=()
    local must_have_one_noun=()
    local has_completion_function=""
    local last_command=""
    local nouns=()
    local noun_aliases=()

    __tng_handle_word
}

if [[ $(type -t compopt) = "builtin" ]]; then
    complete -o default -F __start_tng tng
else
    complete -o default -o nospace -F __start_tng tng
fi

# ex: ts=4 sw=4 et filetype=sh
