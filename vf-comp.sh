# Add this in your Xshrc
# 	source /path/to/vf.sh
#
# With ZSH, this script assume that compinit has been loaded!
#
# 	autoload -U compinit
# 	compinit

export VF_HOME=$(dirname $0)
OPTIONS=($(ruby $VF_HOME/vf.rb -C))

vf() {
	eval $(ruby $VF_HOME/vf.rb $@)
}

# -- ZSH ----------------------------------------------------------------------

__zsh_make_comp_list()
{
	compadd $OPTIONS
	_files
}

__zsh_complete()
{
	compdef __zsh_make_comp_list vf
}

# -- BASH ---------------------------------------------------------------------

__bash_make_comp_list()
{	
	COMPREPLY=( $(compgen -W "${OPTIONS[*]}") )
	return 0
}

__bash_complete()
{
	complete -df -F __bash_make_comp_list vf
}

# -- MAIN ---------------------------------------------------------------------

export SHELL=$(ps -p $$ | tail -1 | awk '{print $NF}' | sed -e 's/-//g')

if [ "X$SHELL" = "Xzsh" ]; then
	__zsh_complete
fi

if [ "X$SHELL" = "Xbash" ]; then
	__bash_complete
fi
