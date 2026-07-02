# devvm completions — all logic lives in `devvm __complete` (see bin/devvm).
# Forward the tokens typed so far (dropping the leading `devvm`) and let the
# script decide the candidates. `-f` disables file completion: subcommands and
# `exec CMD` run inside the guest, so host paths are never meaningful.
complete -c devvm -f -a '(devvm __complete (commandline -opc)[2..-1])'
