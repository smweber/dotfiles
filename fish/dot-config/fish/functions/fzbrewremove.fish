# From https://github.com/SidOfc/dotfiles

function fzbrewremove --description "Remove brew plugins with fzf"
  set -l inst (brew leaves | eval "fzf $FZF_DEFAULT_OPTS -m --header='[brew:update]'")

  if not test (count $inst) = 0
    for prog in $inst
      brew uninstall "$prog"
    end
  end
end
