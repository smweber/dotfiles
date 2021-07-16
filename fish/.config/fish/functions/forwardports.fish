# Defined in /var/folders/g3/clwzdfnj3x500hlx1xvkc94w0000gn/T//fish.dRSufV/forwardports.fish @ line 2
function forwardports --description 'Use ssh to tunnel localhost ports to a remote machine'

    set -l ssh_control_socket "/tmp/ssh-fish-forwardports"
    set -l ssh_command (which ssh)

    argparse h/help c/clear -- $argv
    or return

    if set -q _flag_help
        echo "forwardports [-h|--help] [-c|--clear] [HOST] [PORTS]"
        return 0
    end

    # List currently exposed ports
    if set -q CURRENTLY_FORWARDED_PORTS
        echo "Currently forwarded ports: $CURRENTLY_FORWARDED_PORTS"
    else if test (count $argv) -eq 0
        echo "No currently exposed ports"
    end
    if set -q CURRENTLY_FORWARDED_PORTS_HOST
        echo "Remote host: $CURRENTLY_FORWARDED_PORTS_HOST"
        $ssh_command -S $ssh_control_socket -O check $CURRENTLY_FORWARDED_PORTS_HOST 
    end

    if set -q _flag_clear
        if set -q CURRENTLY_FORWARDED_PORTS_HOST
            echo
            echo "Stopping ssh for host: $CURRENTLY_FORWARDED_PORTS_HOST"
            $ssh_command -S $ssh_control_socket -O exit $CURRENTLY_FORWARDED_PORTS_HOST 
            set -e CURRENTLY_FORWARDED_PORTS
            set -e CURRENTLY_FORWARDED_PORTS_HOST
            return 0
        else
            echo
            echo "ssh not currently running probably"
            return -1
        end
    end

    if set -q CURRENTLY_FORWARDED_PORTS && test (count $argv) -gt 1
        echo "Can't forward more ports while ports are already forwarded"
        return -1
    end

    if test (count $argv) -gt 1
        set -l remote_host $argv[1]
        set -l ports
        for port in $argv[2..-1]
            set -a ports "-L $port:localhost:$port"
        end

        $ssh_command -S $ssh_control_socket -o ExitOnForwardFailure=yes -N -f -M $ports $remote_host

        set -gx CURRENTLY_FORWARDED_PORTS_HOST $remote_host
        for port in $argv[2..-1]
            set -gx CURRENTLY_FORWARDED_PORTS $CURRENTLY_FORWARDED_PORTS $port
        end
    end
end
