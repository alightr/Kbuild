# !/bin/bash
#
# Helper script for conditional flag evaluation.
# See cc.sh for examples.
#

#
# Print $@ and exit with 1
#
error () {
	echo "$@" >&2
	exit 1
}

#
# Parse and execute $1 expression.
#
parse_expr () {
	local expr="$1"
	if [[ ! "$expr" =~ ^\(\@.*\) ]]; then
		echo "$expr"
	else
		expr=${expr:2:-1}
		expr=${expr//\(\@/\$(do_}
		expr="do_$expr"
		eval $expr
	fi
}

#
# Parse $@ flags and return parsed flags.
#
parse_flags () {
	local flag=
	local flags=()
	for expr in "${@}"; do
		flag=$(parse_expr "$expr")
		if [[ $? -ne 0 ]]; then
			exit 1
		fi
		flags+=("$flag")
	done
	echo "${flags[@]}"
}

#
# Run command or print depending on $KBUILD_DRYRUN
#
run_cmd () {
	if [[ "$KBUILD_DRYRUN" == "y" ]]; then
		echo "${@}"
	else
		${@}
	fi
}
