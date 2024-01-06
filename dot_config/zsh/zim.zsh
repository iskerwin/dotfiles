# Use degit instead of git as the default tool to install and update modules.
# zstyle ':zim:zmodule' use 'degit'

#To set where the directory used by Zim will be located.
ZIM_HOME=${ZDOTDIR:-${HOME}}/.zim

# Download zimfw plugin manager if missing.
if [[ ! -e ${ZIM_HOME}/zimfw.zsh ]]; then
  if (( ${+commands[curl]} )); then
    curl -fsSL --create-dirs -o ${ZIM_HOME}/zimfw.zsh \
        https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh
  else
    mkdir -p ${ZIM_HOME} && wget -nv -O ${ZIM_HOME}/zimfw.zsh \
        https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh
  fi
fi

export PLUG_DIR=$HOME/.zim
if [[ ! -d $PLUG_DIR ]]; then
	curl -fsSL https://raw.githubusercontent.com/zimfw/install/master/install.zsh | zsh
	rm ~/.zimrc
	ln -s ~/.config/zsh/zimrc ~/.zimrc
fi