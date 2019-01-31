#!/bin/bash
#
# Facility for conditional evaluation of ld flags based on availability.
#
# Environment variables:
# 1. KBUILD_LD
#    Linker to use. (required)
# 2. KBUILD_CC
#    Compiler to use. (required)
# 3. KBUILD_IF_LDFLAGS
#    Flags to use for testing. Cannot contain conditional expressions.
# 4. KBUILD_DRYRUN
#    Evaluate flags and print final command without executing iff =y
# 5. KBUILD_DIR
#    Directory containing Kbuild. (required)
# 6. KBUILD_USE_CC_LINK
#    Use $(KBUILD_CC) instead of $(KBUILD_LD) for linking. (required)
#
# Only (@test ...) is supported, see cc.sh for explanation.
#

source "$KBUILD_DIR/cond.sh"
ld=$KBUILD_LD
cc=$KBUILD_CC
declare -a "if_flags=($KBUILD_IF_LDFLAGS)"

if [[ "$KBUILD_USE_CC_LINK" == "y" ]]; then
	ld=$cc
fi

#
# Fix ldflags for linking through $(cc), stolen from linux/scripts/gcc-ld
#
fixup_ld_flags () {
	if [[ "$KBUILD_USE_CC_LINK" != "y" ]]; then
		echo ${@}
		return
	fi

	local flags=()
	while [[ "$1" != "" ]]; do
		local flag=
		case "$1" in
		  --save-temps|-static|-m32|-m64|-r|-[Wg]*|-[ov]|-[Ofd]*)
		  ;&
		  -nostdlib|-[l]*)
			flag="$1"
		  ;;
		  -no-pie)
			flag="-fno-pie"
		  ;;
		  -no-PIE)
			flag="-fno-PIE"
		  ;;
		  -[RTFGhIezcbyYu]*|--script|--defsym|-init|-Map)
		  ;&
		  --oformat|-rpath|-rpath-link|--sort-section|--section-start)
		  ;&
		  -Tbss|-Tdata|-Ttext|--version-script|--dynamic-list)
		  ;&
		  --version-exports-symbol|--wrap|-m)
			flag="$1"
			shift
			flag="-Wl,$flag,$1"
		  ;;
		  -[m]*)
			flag="$1"
		  ;;
		  -*)
			flag="-Wl,$1"
		  ;;
		  *)
			flag="$1"
		  ;;
		esac
		flags+=("$flag")
		shift
	done
	echo ${flags[@]}
	return
}

do_test () {
	local flag1="$1"
	if [[ "$flag1" != "" ]]; then
		local tmpflg=$(fixup_ld_flags ${if_flags[@]} "$flag1")
		local tmpobj=$(mktemp)
		local tmpsrc=$(mktemp)
		echo "int main(void) { return 0; }" > "$tmpsrc"
		$cc -c -x c "$tmpsrc" -o "$tmpobj"
		$ld ${tmpflg[@]} "$tmpobj" -o /dev/null > /dev/null 2>&1
		local res=$?
		rm -rf "$tmpobj"
		rm -rf "$tmpsrc"
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
flags=$(fixup_ld_flags ${flags[@]})
run_cmd $ld ${flags[@]}
