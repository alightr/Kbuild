#!/bin/bash
#
# Facility for conditional evaluation of compiler flags based on availability,
# version, and compiler.
#
# Environment variables:
# 1. KBUILD_CC
#    Compiler to use. (required)
# 2. KBUILD_IF_CCFLAGS
#    Flags to use for testing. Cannot contain conditional expressions.
# 3. KBUILD_DRYRUN
#    Evaluate flags and print final command without executing iff =y
# 4. KBUILD_DIR
#    Directory containing Kbuild. (required)
#
# Supported expressions:
#
# 1. (@test <if-true>[ <if-false>])
#    Test if compiler supports <if-true>, emitting <if-true>, otherwise,
#    <if-false> iff present or empty string.
# 2. (@version <lt gt eq ne ge le> <version> <if-true>[ <if-false>])
#    Test if compiler version is less than ('lt'), greater than ('gt'),
#    equal to ('eq'), not equal to ('ne'), greater than or equal to ('ge'),
#    less than or equal to ('le') <version>.
# 3. (@name <eq ne> <name> <if-true>[ <if-false>])
#    Test if compiler name equals ('eq') or does not equal ('ne') <name>.
# 4. (@warn <base-option>)
#    Shorthand for '(@test -W<base-option>)'
# 5. (@nowarn <base-option>)
#    Shorthand for '(@test -Wno-<base-option>)'
#
# <if-true> and <if-false> may be expressions or flags. In instances where
# <if-false> is just a flag, *no* test is performed, f.e.,
#
#	(@test -foo -bar) != (@test -foo (@test -bar))
#
# The first test only tests if '-foo' is supported, evaluating to '-bar'
# unconditionally if false. The second tests both, if neither option is
# supported, evaluating to empty string.
#
# The order of flags is *always* maintained.
#

source "$KBUILD_DIR/cond.sh"

cc=$KBUILD_CC
declare -a "if_flags=($KBUILD_IF_CCFLAGS)"

version_major=$(echo __GNUC__ | $cc -E -x c - | tail -n 1)
version_minor=$(echo __GNUC_MINOR__ | $cc -E -x c - | tail -n 1)
version_patch=$(echo __GNUC_PATCHLEVEL__ | $cc -E -x c - | tail -n 1)
version=$(printf "%02d%02d%02d" $version_major $version_minor $version_patch)

name=$($cc -v 2>&1 | grep -q "clang version" && echo clang || echo gcc)

do_test () {
	local flag1="$1"
	if [[ "$flag1" != "" ]]; then
		local tmpobj=$(mktemp)
		$cc -Werror ${if_flags[@]} "$flag1" -c -x c /dev/null \
			-o "$tmpobj" > /dev/null 2>&1
		local res=$?
		rm -rf "$tmpobj"
		if [[ $res -eq 0 ]]; then
			echo "$flag1"
			return
		fi
	fi
	echo "$2"
}

do_version () {
	local cmp="$1"
	local opr="$2"
	case "$cmp" in
	  "lt")
		[[ $version -lt $opr ]]
	  ;;
	  "gt")
		[[ $version -gt $opr ]]
	  ;;
	  "eq")
		[[ $version -eq $opr ]]
	  ;;
	  "ne")
		[[ $version -ne $opr ]]
	  ;;
	  "ge")
		[[ $version -ge $opr ]]
	  ;;
	  "le")
		[[ $version -le $opr ]]
	  ;;
	  *)
		error "Invalid operator for version expression: $cmp"
	  ;;
	esac
	if [[ $? -eq 0 ]]; then
		echo "$3"
	else
		echo "$4"
	fi
}

do_name () {
	local cmp="$1"
	local opr="$2"
	case "$cmp" in
	  "eq")
		[[ "$name" == "$opr" ]]
	  ;;
	  "ne")
		[[ "$name" != "$opr" ]]
	  ;;
	  *)
		error "Invalid operator for name expression: $cmp"
	  ;;
	esac
	if [[ $? -eq 0 ]]; then
		echo "$3"
	else
		echo "$4"
	fi
}

do_warn () {
	local flag="-W$1"
	do_test "$flag"
}

do_nowarn () {
	local flag="-Wno-$1"
	do_test "$flag"
}

flags=$(parse_flags "${@}")
if [[ $? -ne 0 ]]; then
	exit 1
fi

run_cmd $cc ${flags[@]}
