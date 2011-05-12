# Add this in your Xshrc
# 	source /path/to/vf.sh

export VF_HOME=$(dirname $0)

vf() 
{
	eval $(ruby $VF_HOME/vf.rb $@)
}
