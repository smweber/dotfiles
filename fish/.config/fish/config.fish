fish_vi_key_bindings
set -g theme_display_vi yes
set -g theme_nerd_fonts yes

# For Shopify "dev"
if test -f /opt/dev/dev.fish
   source /opt/dev/dev.fish
end

eval (direnv hook fish)
