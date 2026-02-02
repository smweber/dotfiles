# Defined in /var/folders/g3/clwzdfnj3x500hlx1xvkc94w0000gn/T//fish.VgrGqI/fzkill.fish @ line 2
function fzkill --description 'Kill processes with fzf'
  set -l __kp__pid (ps -ef | sed 1d | eval "fzf $FZF_DEFAULT_OPTS -m --header='[kill:process]'" | awk '{print $2}')
  set -l __kp__kc $argv[1]

  if test "x$__kp__pid" != "x"
    if test "x$argv[1]" != "x"
      echo $__kp__pid | xargs kill $argv[1]
    else
      echo $__kp__pid | xargs kill -9
    end
  end
end
