#!/bin/bash
#
# Facility for conditional evaluation of ar flags based on availability.
#
# Unlike normal ar, all flags should be separated with a space, f.e.,
#
#	ar ars
#
# Should look like,
#
#	./ar.sh a r s
#
# Environment variables:
# 1. KBUILD_AR
#    Archiver to use. (required)
# 2. KBUILD_IF_ARFLAGS
#    Flags to use for testing. Cannot contain conditional expressions.
# 3. KBUILD_DRYRUN
#    Evaluate flags and print final command without executing iff =y
# 4. KBUILD_DIR
#    Directory containing Kbuild. (required)
#
# Only (@test ...) is supported, see cc.sh for explanation.
#

source "$KBUILD_DIR/cond.sh"

ar=$KBUILD_AR
declare -a "if_flags=($KBUILD_IF_ARFLAGS)"

to_args () {
	local pmod=""
	local flags=()
	while [[ "$1" != "" ]]; do
		case "$1" in
		  [dmpqrstx])
		  ;&
		  [abcDfilNoPsSTuUvV])
			pmod="$pmod$1"
		  ;;
		  --*)
		  ;&
		  *)
			flags+=("$1")
		  ;;
		esac
		shift
	done
	flags=("$pmod" "${flags[@]}")
	echo ${flags[@]}
}

do_test () {
	local flag1="$1"
	if [[ "$flag1" != "" ]]; then
		local tmpobj=$(mktemp)
		local flags=("${if_flags[@]}")
		flags+=("$1")
		flags=$(printf "%s" "${flags[@]}")
		$ar $(to_args ${flags[@]}) "$tmpobj" > /dev/null 2>&1
		local res=$?
		rm -rf "$tmpobj"
		if [[ $res -eq 0 ]]; then
			echo "$flag1"
			return
		fi
	fi
	echo "$2"
}

flags=$(parse_flags "${@}")
if [[ $? -ne 0 ]]; then
	exit 1
fi

run_cmd $ar $(to_args ${flags[@]})
