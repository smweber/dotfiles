fish_vi_key_bindings
set -g theme_display_vi yes
#set -g theme_nerd_fonts yes

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
