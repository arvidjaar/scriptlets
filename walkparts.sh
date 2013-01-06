#!/bin/sh

dev="$1"
epstart=0
pstart=0
sector=


function fail() {
    printf "%s\n" "$@" 1>&2
    [ -n "$sector" ] && rm -f "$sector"
    exit 1
}

function dump_part_table () {
	local mbr="$1"

	echo "Flag CHS/Start Type CHS/End    LBA/Start      LBA/Cnt"
	hexdump -v -s 446 -n 64 -e '1/1 "  %02x    " 3/1 "%02x" 1/1 "   %02x  " 3/1 "%02x" 2/4 " %12u" "\n"' "$mbr"
	echo
}

function check_for_extended_partition() {
    local mbr="$1" ptype psize

    for i in 0 1 2 3; do
	ptype=$(hexdump -v -s $[450+i*16] -n 1 -e '"%02x"' "$mbr")
	pstart=$(hexdump -v -s $[454+i*16] -n 4 -e '"%u"' "$mbr")
	psize=$(hexdump -v -s $[458+i*16] -n 4 -e '"%u"' "$mbr")
	if [ \( "$ptype" = 05 -o "$ptype" = 0f \) -a \
	     -n "$pstart" -a -n "$psize" ]; then
	    if [ $epstart -eq 0 ]; then
		epstart=$pstart
	    else
		: $[pstart=epstart+pstart]
	    fi
	    return 0
	fi
    done

    return 1
}

[ -b "$dev" ] || fail "Not a block device"

sector=$(mktemp -q) || fail "Failed to create temprary directory"

dd if="$dev" of="$sector" count=1 2> /dev/null || fail "Failed to read MBR"

magic=$(hexdump -v -s 510 -n 2 -e '"%04x"' "$sector")
[ "$magic" == aa55 ] || fail "Not a valid MBR: $magic"

echo "MBR dump"
dump_part_table "$sector"

while check_for_extended_partition "$sector"; do
    dd if="$dev" of="$sector" count=1 skip="$pstart" 2> /dev/null || fail "Failed to read EBR at offset $pstart"
    
    echo "EBR at offset $pstart"
    dump_part_table "$sector"
done

[ -n "$sector" ] && rm -f "$sector"
