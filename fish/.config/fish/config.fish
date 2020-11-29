fish_vi_key_bindings
set -g theme_display_vi yes
#set -g theme_nerd_fonts yes

# Parse env variable exports from ~/.profile
egrep "^export " ~/.profile | while read e
    set var (echo $e | sed -E "s/^export ([A-Z_]+)=(.*)\$/\1/")
    set value (echo $e | sed -E "s/^export ([A-Z_]+)=(.*)\$/\2/")
    
    # remove surrounding quotes if existing
    set value (echo $value | sed -E "s/^\"(.*)\"\$/\1/")

    if test $var = "PATH"
        # replace ":" by spaces. this is how PATH looks for Fish
        set value (echo $value | sed -E "s/:/ /g")
    
        # use eval because we need to expand the value
        eval set -xg $var $value

        continue
    end

    # evaluate variables. we can use eval because we most likely just used "$var"
    set value (eval echo $value)

    #echo "set -xg '$var' '$value' (via '$e')"
    set -xg $var $value
end

# For Shopify "dev"
if test -f /opt/dev/dev.fish
   source /opt/dev/dev.fish
end

eval (direnv hook fish)

if test -f "/Users/sweber/.shopify-app-cli/shopify.fish"
  source "/Users/sweber/.shopify-app-cli/shopify.fish"
end
