# Copyright 2008 Extreme Engineering Solutions, Inc.
#
# Set of shell functions shared by X-ES scripts
#
# Author: Nate Case <ncase@xes-inc.com>

# Note: Test changes in both bash *AND* busybox ash

SYS_GPIO=/sys/class/gpio
XES_BOARD_CONF_DIR=${prefix}/etc/xes/boards

### Generic Functions ###

# Return the current board name
xes_board_name () {
    local board
    if [ -f /proc/device-tree/model ]; then
        # OpenFirmware systems
        board=`sed 's/.*,//' /proc/device-tree/model`
    elif [ -f /sys/class/dmi/id/product_name ]; then
        # x86 DMI product name
        board=`cat /sys/class/dmi/id/product_name`
    elif [ -f /usr/sbin/dmidecode ]; then
        # x86 DMI product name (pre sysfs interface)
        board=`dmidecode -s system-product-name`
    else
        board=`awk '/^machine/ {print $3}' /proc/cpuinfo`
    fi

    # Strip out any unwanted suffixes from board name
    board=`echo ${board} | grep -oE "^[A-Za-z][A-Za-z]*[0-9][0-9]*"`

    # Fix case of board name (e.g., XPort1000)
    local board_first=`echo ${board} | cut -c1-2 | tr 'a-z' 'A-Z'`
    local board_last=`echo ${board} | cut -c3- | tr 'A-Z' 'a-z'`
    echo ${board_first}${board_last}
}

load_board_config () {
    board=`echo $1 | tr 'A-Z' 'a-z'`
    labels_var="$2"
    family=`echo ${board} | sed 's/[0-9][0-9]*//'`
    matches=""
    declare -A fname
    declare -A GPIO_PIN_LABELS

    # Get string like this: "<path/fname>:xpedite7332 <path/fname>:xpedite737"
    # for *.conf files found in the product family
    partials=`ls -1 ${XES_BOARD_CONF_DIR}/${family}*.conf 2>/dev/null | sed 's,\(.*/\)\([^0-9]*\)\([0-9][0-9]*\)\(x*\)\(.*\),\1\2\3\4\5:\2\3,'`

    for x in ${partials} ; do
        partial=${x##*:}    # the "xpedite737" portion
        f=${x%%:*}          # the "/path/to/xpedite737x.conf" portion
        if [[ "${board}" =~ "${partial}" ]] ; then
            matches="${matches} ${partial}"
            fname["${partial}"]="${f}"
        fi
     done

    # Load files in order of most generic to most specific
    matches=`echo ${matches} | sed 's/^ *//g' | sed 's/ /\n/g' | sort`
    if [ -f ${XES_BOARD_CONF_DIR}/global.conf ] ; then
        matches="global ${matches}"
        fname["global"]=${XES_BOARD_CONF_DIR}/global.conf
    fi
    for match in ${matches} ; do
        #echo "DEBUG: Sourcing ${fname[${match}]}"
        source ${fname[${match}]}
    done

    # Copy the labels to an array defined by the caller
    if [ -n "$labels_var" ]; then
      for key in "${!GPIO_PIN_LABELS[@]}"; do
        eval "${labels_var}[$key]=${GPIO_PIN_LABELS[$key]}"
      done
    fi
}

# Convert an integer to binary representation
int_to_bin () {
    # Pad to at least 8 bits
    printf "%08d" `echo "${1} 2 o p" | dc`
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
    local binstr=`int_to_bin $((${hexbyte}))`
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
    if [ -e $SYS_GPIO/gpio$1 ]; then
        return 0
    else
        return 1
    fi
}

# Exports a gpio pin using /sys gpio interface
# Assumes: There is a /sys gpio interface
# $1: gpio pin to export
sys_export_gpio () {
    echo $1 > $SYS_GPIO/export 2> /dev/null
    return $?
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
        cat $direction
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
# $2: the binary value to be written
sys_write_gpio () {
    echo $2 > $SYS_GPIO/gpio$1/value 2> /dev/null
}

# Uses /sys gpio interface to get the value of a gpio chip
# Assumes: There is a /sys gpio interface
# $1: the base number of a gpio chip on the board
sys_gpio_get () {
    local chip=$1
    local last=$(($1 + `sys_num_gpio $chip` - 1))
    local binval
    local i
    for i in `seq $chip $last`; do
        # Make sure the gpio pin is exported before reading it
        if sys_exported_gpio $i; then
            binval="`sys_read_gpio $i`$binval"
        elif sys_export_gpio $i; then
            binval="`sys_read_gpio $i`$binval"
            sys_unexport_gpio $i
        else
            binval="n$binval"
        fi
    done

    echo $binval
}

# Uses /sys gpio interface to set the value of a bit on a gpio chip
# Assumes: There is a /sys gpio interface
# $1: the address of a gpio chip on the board
# $2: the value to set the bit
sys_gpio_set () {
    local addr=$1
    local bitval=$2
    # Make sure the gpio pin is exported before writing to it
    if sys_exported_gpio "$addr"; then
        if ! sys_write_gpio $addr $bitval; then
            echo "ERROR: Can't set gpio$addr"
        fi
    elif sys_export_gpio "$addr"; then
        if ! sys_write_gpio $addr $bitval; then
            echo "ERROR: Can't set gpio$addr"
        fi
        sys_unexport_gpio $addr
    else
        echo "ERROR: Can't set gpio$addr, pin is reserved or doesn't exist"
    fi
}

# Display the direction of each pin of a given chip, one line per pin.
# Valid direction values are in and out.
# $1: the address of a gpio chip on the board
sys_gpio_dir_get () {
    local addr=$1
    # Make sure the gpio pin is exported before reading it
    if sys_exported_gpio "$addr"; then
        sys_get_direction_gpio "$addr"
    elif sys_export_gpio $addr; then
        sys_get_direction_gpio "$addr"
        sys_unexport_gpio "$addr"
    else
        echo "ERROR: Can't get gpio$addr direction, pin is reserved or doesn't exist"
    fi
}

# Uses /sys gpio interface to set the direction of a bit on a gpio chip
# Assumes: There is a /sys gpio interface
# $1: the address of a gpio chip on the board
# $2: the direction to set the bit
sys_gpio_dir_set () {
    local addr=$1
    local bitval=$2
    # Make sure the gpio pin is exported before writing to it
    if sys_exported_gpio "$addr"; then
        if ! sys_set_direction_gpio $addr $bitval; then
            echo "ERROR: Can't set gpio$addr"
        fi
    elif sys_export_gpio $addr; then
        if ! sys_set_direction_gpio $addr $bitval; then
            echo "ERROR: Can't set gpio$addr"
        fi
        sys_unexport_gpio $addr
    else
        echo "ERROR: Can't set gpio$addr, pin is reserved or doesn't exist"
    fi
}
