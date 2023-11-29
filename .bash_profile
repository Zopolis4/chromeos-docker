echo "This is the .bash_profile"
#Without this, env.d files do not get sourced.
if [ -f ~/.bashrc ]; then . ~/.bashrc; fi
cd /usr/local/lib/crew/packages
crew update
if [ -n "$LOCALRC" ]; then echo "LOCALRC found!"; . "$LOCALRC"; fi
