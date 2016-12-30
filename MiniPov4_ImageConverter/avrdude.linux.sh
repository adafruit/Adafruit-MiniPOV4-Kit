#!/bin/bash

WHICH_AVRDUDE=`which avrdude`
AVRDUDE=${AVRDUDE_BIN:=${WHICH_AVRDUDE}}

if [ -z "${AVRDUDE}" ]; then
    echo "Install avrdude for your distribution or export the path to the binary as AVRDUDE_BIN"
    exit
fi

BUS_DEVICE=`lsusb | sed -n -e '/USBtiny/s/Bus \(...\) Device \(...\).*/\1:\2/p'`

if [ -z "${BUS_DEVICE}" ]; then
    echo "Could not find the USBtiny-Device. Is it plugged in and switched on? Can you access it via the command line?"
    exit
fi

${AVRDUDE} ${@} -P usb:${BUS_DEVICE}
