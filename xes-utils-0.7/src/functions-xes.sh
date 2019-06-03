# Copyright 2008 Extreme Engineering Solutions, Inc.
#
# Set of shell functions shared by X-ES scripts
#
# Author: Nate Case <ncase@xes-inc.com>

# Note: Test changes in both bash *AND* busybox ash

SYS_GPIO=/sys/class/gpio

### Generic Functions ###

# Return the current board name
xes_board_name () {
	local board
	if [ -f /proc/device-tree/model ]; then
		# OpenFirmware systems
		board=`cat /proc/device-tree/model | sed 's/.*,//'`
	elif [ -f /sys/class/dmi/id/product_name ]; then
		# x86 DMI product name
		board=`cat /sys/class/dmi/id/product_name`
	elif [ -f /usr/sbin/dmidecode ]; then
		# x86 DMI product name (pre sysfs interface)
		board=`dmidecode -s system-product-name`
	else
		board=`cat /proc/cpuinfo | grep -E "^machine" |
		      awk '{print $3}'`
	fi

	# Fix case of board name (e.g., XPort1000)
	local board_first=`echo ${board} | cut -c1-2 | tr 'a-z' 'A-Z'`
	local board_last=`echo ${board} | cut -c3- | tr 'A-Z' 'a-z'`
	echo ${board_first}${board_last}
}

# Convert numeric value to integer ('0x' prefix for hex, '0' for octal, etc.)
to_int () {
	local i
	let i=${1}
	return ${i}
}

# Convert an integer to binary representation
int_to_binstr () {
	# Pad to at least 8 bits
	printf "%08d" `echo "obase=2; ${1}" | bc`
}

# Convert binary to decimal
bin_to_dec () {
	local bin=`echo $1 | sed 's/\(.\)/\1 /g'`
	local binr
	local x
	# reverse input
	for x in $bin; do
		binr="$x $binr"
	done

	local val=0
	local mult=1
	for x in $binr; do
		if [ "$x" = "1" ]; then
			val=$((val+mult))
		fi
		mult=$((mult*2))
	done

	echo ${val}
}

# Display each bit of a given binary value, one line per bit
# Valid bit values are 0, 1, and n (undefined/unused)
dump_binary () {
	local bindata=$1
	local index=$2
	local bit

	if [ -z "$index" ]; then
		# Add a space between all characters for loop below
		local bits=`echo ${bindata} | sed 's/\([01n]\)/\1 /g'`

		# Calculate the number of bits to display
		local i=$((${#bindata}-1))

		for bit in ${bits} ; do
			if [ "${bit}" = "n" ]; then
				printf "reserved\n"
			else
				printf "${bit}\n"
			fi
			i=$((i-1))
		done
	else
		# remember bits are LSB->MSB
		bit=${bindata:$((${#bindata}-$index-1)):1}
		if [ "${bit}" = "n" ]; then
			printf "reserved\n"
		else
			printf "${bit}\n"
		fi
	fi
}

### GPIO functions ###

# Access pca955x GPIO chips using 'i2cget' tool.  Note that
# after 2.6.27 is released, there will be an official gpiolib sysfs
# interface that we should use instead along with the pca955x GPIO
# kernel driver.  In the meantime, we'll do it using the userspace i2c
# device interface.
pca955x_gpio_get () {
	local bus=$1
	local chip=$2
	i2cget -y ${bus} ${chip} 0x00 b
}

# Read value for specific pin number 0-7
pca955x_gpio_get_pin () {
	local bus=$1
	local chip=$2
	local pin=$3
	local hexbyte=`i2cget -y ${bus} ${chip} 0x00 b`
	to_int ${hexbyte}
	local binstr=`int_to_binstr $?`
	local bits=`echo ${binstr} | sed 's/\([01]\)/\1 /g'`
	echo ${bits} | awk "{print \$$((8-pin))}"
}

pca955x_gpio_set () {
	local bus=$1
	local chip=$2
	local val=$3
	local mask=$4
	# Set polarity to normal
	i2cset -y ${bus} ${chip} 0x02 0x00 b ${mask}
	# Configure as output
	i2cset -y ${bus} ${chip} 0x03 0x00 b ${mask}
	# Set output value
	i2cset -y ${bus} ${chip} 0x01 ${val} b ${mask}
}

sys_num_gpio () {
	cat $SYS_GPIO/gpiochip${1}/ngpio
}

# Returns 0 if gpio is already exported, 1 otherwise.
# Assumes: There is a /sys gpio interface
# $1: gpio pin to check
sys_exported_gpio () {
	[ -e $SYS_GPIO/gpio$1 ] && return 0
	return 1
}

# Exports a gpio pin using /sys gpio interface
# Assumes: There is a /sys gpio interface
# $1: gpio pin to export
sys_export_gpio () {
	echo $1 > $SYS_GPIO/export 2> /dev/null
}

# Unexports a gpio pin using /sys gpio interface
# Assumes: The pin has been exported
# $1: gpio pin to export
sys_unexport_gpio () {
	echo $1 > $SYS_GPIO/unexport 2> /dev/null
}

# Sets a gpio pin direction
# Assumes: we have exported the pins
# $1: gpio pin to set direction
# $2: the name of the direction (in or out)
sys_set_direction_gpio () {
	# Not all gpio pins can have their direction set
	if [ -e $SYS_GPIO/gpio$1/direction ]; then
		if [ "$2" != "`cat $SYS_GPIO/gpio$1/direction`" ]; then
			echo $2 > $SYS_GPIO/gpio$1/direction 2> /dev/null
		fi
	fi
}

# Gets a gpio pin direction
# Assumes: we have exported the pins
# $1: gpio pin to get direction
sys_get_direction_gpio () {
	local direction="$SYS_GPIO/gpio$1/direction"
	# Not all gpio pins can have their direction set
	if [ -e $direction ]; then
		echo "`cat $direction`"
	else
		echo "N/A"
	fi
}

# Read the value of a gpio pin
# Assumes: we have exported the pin
# $1: the gpio pin to read
sys_read_gpio () {
	if [ "`cat $SYS_GPIO/gpio$1/value`" != "0" ]; then
		echo "1"
	else
		echo "0"
	fi
}

# Write a specific value to a gpio pin
# Assumes: we have root permissions and we have exported the pin
# $1: the gpio pin to write
# $2: the binary value to be writen
sys_write_gpio () {
	echo $2 > $SYS_GPIO/gpio$1/value 2> /dev/null
}

# Uses /sys gpio interface to get the value of a gpio chip
# Assumes: There is a /sys gpio interface
# $1: the base number of a gpio chip on the board
sys_gpio_get () {
	local CHIP=$1
	local LAST=$(($1 + `sys_num_gpio $CHIP` - 1))
	local BINVAL
	local DECVAL
	local i

	for i in `seq $CHIP $LAST`; do
		# Make sure gpio pin was exported before reading it
		if sys_export_gpio $i; then
			BINVAL="`sys_read_gpio $i`$BINVAL"
			sys_unexport_gpio $i
		else
			BINVAL="n$BINVAL"
		fi
	done

	echo $BINVAL
}

# Uses /sys gpio interface to set the value of a bit on a gpio chip
# Assumes: There is a /sys gpio interface
# $1: the address of a gpio chip on the board
# $2: the value to set the bit
sys_gpio_set () {
	local ADDR=$1
	local BITVAL=$2

	# Make sure the gpio pin is actually exported prior to writing it
	if ! sys_exported_gpio "$ADDR"; then
		sys_export_gpio $ADDR
		sys_write_gpio $ADDR $BITVAL
		sys_unexport_gpio $ADDR
	else
		echo "ERROR: Can't set gpio$ADDR, pin is reserved"
	fi
}

# Display the direction of each pin of a given chip, one line per pin.
# Valid direction values are in and out.
sys_gpio_dir_get () {
	local ADDR=$1

	if ! sys_exported_gpio "$ADDR"; then
		sys_export_gpio "$ADDR"
		sys_get_direction_gpio "$ADDR"
		sys_unexport_gpio "$ADDR"
	else
		sys_get_direction_gpio "$ADDR"
	fi
}

# Uses /sys gpio interface to set the direction of a bit on a gpio chip
# Assumes: There is a /sys gpio interface
# $1: the address of a gpio chip on the board
# $2: the direction to set the bit
sys_gpio_dir_set () {
	local ADDR=$1
	local BITVAL=$2

	# Make sure the gpio pin is actually exported prior to writing it
	if ! sys_exported_gpio "$ADDR"; then
		sys_export_gpio $ADDR
		if ! sys_set_direction_gpio $ADDR $BITVAL; then
			echo "ERROR: Can't set gpio$ADDR"
		fi
		sys_unexport_gpio $ADDR
	else
		echo "ERROR: Can't set gpio$ADDR, pin is reserved"
	fi
}
