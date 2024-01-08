buttons.json: buttons.jq
	cat buttons.jq |\
	sed -e '/^[ 	]*#/d' -e 's/"/\\"/g' |\
	tr -d ' 	\012' |\
        sed 's/$$/,/'	>buttons.json
