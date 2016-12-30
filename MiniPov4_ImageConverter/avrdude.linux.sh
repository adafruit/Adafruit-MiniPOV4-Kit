#!/bin/bash

BUS_DEVICE=`lsusb | sed -n -e '/USBtiny/s/Bus \(...\) Device \(...\).*/\1:\2/p'`

avrdude ${@} -P usb:${BUS_DEVICE}
