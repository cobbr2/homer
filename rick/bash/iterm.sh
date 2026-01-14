find_iterm_tty() {
    local tty_to_find="$1"

    # Strip off /dev/ prefix if provided
    tty_to_find=${tty_to_find#/dev/}

    # Create a temporary file to store the result
    local tmp_file=$(mktemp)

    # Run the AppleScript in the background so it can maintain focus
    osascript > "$tmp_file" <<EOF &
    tell application "iTerm2"
        activate

        set foundWindow to false
        set foundTab to false
        set foundSession to false

        repeat with aWindow in windows
            repeat with aTab in tabs of aWindow
                repeat with aSession in sessions of aTab
                    -- Create a temporary file for this session
                    set tmpName to do shell script "mktemp"

                    -- Run tty command in background without disrupting the session
                    write aSession text "tty > " & quoted form of tmpName & " &"

                    -- Give it a moment to execute
                    delay 0.2

                    -- Check the result
                    try
                        set sessionTty to do shell script "cat " & quoted form of tmpName
                        do shell script "rm " & quoted form of tmpName

                        if sessionTty contains "$tty_to_find" then
                            -- Found it! Store references
                            set foundWindow to aWindow
                            set foundTab to aTab
                            set foundSession to aSession
                        end if
                    on error
                        do shell script "rm -f " & quoted form of tmpName
                    end try
                end repeat
            end repeat
        end repeat

        -- Now select the found session if we found one
        if foundWindow is not false then
            -- First select the window
            tell foundWindow
                select
                set index to 1
            end tell

            -- Then select the tab
            tell foundTab of foundWindow
                select
            end tell

            -- Finally select the session
            tell foundSession of foundTab of foundWindow
                select
            end tell

            -- Keep the window focused
            activate

            -- Flash the terminal for visibility (optional)
            try
                repeat 3 times
                    tell foundSession
                        set backgroundColor to {65535, 0, 0}
                    end tell
                    delay 0.2
                    tell foundSession
                        set backgroundColor to {0, 0, 0}
                    end tell
                    delay 0.2
                end repeat
            end try

            return "Found and selected TTY $tty_to_find"
        else
            return "Could not find terminal with TTY $tty_to_find"
        end if
    end tell
EOF

    # Give the script a moment to run
    sleep 1

    # Display the result
    if [ -f "$tmp_file" ]; then
        cat "$tmp_file"
        rm "$tmp_file"
    fi
}
