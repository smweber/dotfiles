# Defined in /var/folders/94/4qrs_nv54mqdfy9pv8sjpgh40000gn/T//fish.uU62u9/exposeports.fish @ line 2
function exposeports --description 'Use socat to expose localhost ports to local network'
    argparse h/help c/clear -- $argv
    or return

    if set -q _flag_help
        echo "exposeports [-h|--help] [-c|--clear] [PORTS]"
        return 0
    end

    # List currently exposed ports
    if set -q CURRENT_EXPOSED_PORTS
        echo "Currently exposed ports: $CURRENT_EXPOSED_PORTS"
    else if test (count $argv) -eq 0
        echo "No currently exposed ports"
    end
    if set -q CURRENT_EXPOSED_PORTS_PIDS
        echo "(socat PIDs: $CURRENT_EXPOSED_PORTS_PIDS)"
    end

    if set -q _flag_clear
        set -e CURRENT_EXPOSED_PORTS
        if set -q CURRENT_EXPOSED_PORTS_PIDS
            echo
            echo "Killing socat with PIDs: $CURRENT_EXPOSED_PORTS_PIDS"
            for pid in $CURRENT_EXPOSED_PORTS_PIDS
                kill $pid
            end
            set -e CURRENT_EXPOSED_PORTS_PIDS
            return 0
        else
            echo
            echo "No ports cleared: no socat PIDs in CURRENT_EXPOSED_PORTS_PIDS"
            return -1
        end
    end

    if set -q CURRENT_EXPOSED_PORTS && test (count $argv) -gt 0
        echo "Can't expose more ports while ports are already exposed"
        return -1
    end
        
    for port in $argv
        set -l socat_command (which socat) tcp-listen:$port,reuseaddr,fork tcp:localhost:$port
        $socat_command &
        set -gx CURRENT_EXPOSED_PORTS_PIDS $CURRENT_EXPOSED_PORTS_PIDS $last_pid
        set -gx CURRENT_EXPOSED_PORTS $CURRENT_EXPOSED_PORTS $port
        echo "$socat_command (PID: $last_pid)"
    end
end
