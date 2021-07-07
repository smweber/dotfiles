function tnl
  set TUNNEL "ssh -N "
  echo Port forwarding for ports:
  for i in ${@:2}
  do
    echo " - $i"
    set TUNNEL "$TUNNEL -L 127.0.0.1:$i:localhost:$i"
  done
  set TUNNEL "$TUNNEL $1"
  $TUNNEL &
  set PID $!
  alias tnlkill="kill $PID && unalias tnlkill"
end
