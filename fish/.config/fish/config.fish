fish_vi_key_bindings
set -g theme_display_vi yes
#set -g theme_nerd_fonts yes

# ---- JJ stuff ----
# (probably not needed after fish v4.1)
# Based on fish_jj_prompt and https://gist.github.com/hroi/d0dc0e95221af858ee129fd66251897e
function fish_jj_prompt
    # If jj isn't installed, there's nothing we can do
    # Return 1 so the calling prompt can deal with it
    if not command -sq jj
        return 1
    end
    set -l info "$(
        jj log 2>/dev/null --no-graph --ignore-working-copy --color=always --revisions @ \
            --template '
                surround(
                    "(",
                    ")",
                    separate(
                        " ",
                        bookmarks.join(", "),
                        coalesce(
                            surround(
                                "\"",
                                "\"",
                                if(
                                    description.first_line().substr(0, 16).starts_with(description.first_line()),
                                    description.first_line().substr(0, 16),
                                    description.first_line().substr(0, 15) ++ "…"
                                )
                            ),
                            label(if(empty, "empty"), description_placeholder)
                        ),
                        change_id.shortest(),
                        commit_id.shortest(),
                        if(conflict, label("conflict", "×")),
                        if(divergent, label("divergent", "??")),
                        if(hidden, label("hidden prefix", "(hidden)")),
                        if(immutable, label("node immutable", "◆")),
                        coalesce(
                            if(
                                empty,
                                coalesce(
                                    if(
                                        parents.len() > 1,
                                        label("empty", "(merged)"),
                                    ),
                                    label("empty", "(empty)"),
                                ),
                            ),
                            label("description placeholder", "*")
                        ),
                    )
                )
            '
    )"
    or return 1
    if test -n "$info"
        printf ' %s' $info
    end
end

function fish_vcs_prompt --description "Print all vcs prompts"
    # If a prompt succeeded, we assume that it's printed the correct info.
    # This is so we don't try svn if git already worked.
    fish_jj_prompt $argv
    or fish_git_prompt $argv
    or fish_hg_prompt $argv
    or fish_fossil_prompt $argv
    # The svn prompt is disabled by default because it's quite slow on common svn repositories.
    # To enable it uncomment it.
    # You can also only use it in specific directories by checking $PWD.
    # or fish_svn_prompt
end
# ---- End JJ stuff ----

function parse_export_file
    set file $argv[1]
    egrep "^export " $file | while read e
        set var (echo $e | sed -E "s/^export ([A-Z_]+)=(.*)\$/\1/")
        set value (echo $e | sed -E "s/^export ([A-Z_]+)=(.*)\$/\2/")

        # remove surrounding quotes if existing
        set value (echo $value | sed -E "s/^\"(.*)\"\$/\1/")

        # If the value contains a colon, we'll need to replace them
        if test (echo $value | string match "*:*")
            # replace ":" by spaces. this is how PATH looks for Fish
            set value (echo $value | sed -E "s/:/ /g")

            # use eval because we need to expand the value
            eval set -xg $var $value

            continue
        end

        # evaluate variables. we can use eval because we most likely just used "$var"
        set value (eval echo $value)

        set -xg $var $value
    end
end

parse_export_file ~/.profile
parse_export_file ~/.local_profile

eval (direnv hook fish)
fzf --fish | source

# SSH Agent on Ubuntu
if test -z (pgrep ssh-agent | string collect)
    eval (ssh-agent -c)
    set -Ux SSH_AUTH_SOCK $SSH_AUTH_SOCK
    set -Ux SSH_AGENT_PID $SSH_AGENT_PID
end

mise activate fish | source
