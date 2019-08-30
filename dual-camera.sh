#!/bin/bash

# Copyright (C) Guangzhou FriendlyARM Computer Tech. Co., Ltd.
# (http://www.friendlyarm.com)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, you can access it online at
# http://www.gnu.org/licenses/gpl-2.0.html.

#
# Supported cameras
# ----------------------------------------------------------
# MCAM400 (ov4689):  https://www.friendlyarm.com/index.php?route=product/product&path=78&product_id=247
# CAM1320 (ov13850):  https://www.friendlyarm.com/index.php?route=product/product&path=78&product_id=228
# Logitech C920 pro webcam
#

preview_mode="width=640,height=480,framerate=30/1"
vsnk="glimagesink"

if [ -f /usr/bin/lxsession ]; then
	export DISPLAY=:0.0
else
	echo "only support FriendlyDesktop."
	exit 1
fi

#----------------------------------------------------------
# selfpath
declare -a PreviewDevs=()
# mainpath
declare -a PictureDevs=()
# camera type
declare -a CameraTypes=()

# isp1
if [ -d /sys/class/video4linux/v4l-subdev2/device/video4linux/video1 -o \
        -d /sys/class/video4linux/v4l-subdev5/device/video4linux/video1 ]; then
        PreviewDevs+=("/dev/video1")
        PictureDevs+=("/dev/video0")
	CameraTypes+=("mipi")
fi

# isp2
if [ -d /sys/class/video4linux/v4l-subdev2/device/video4linux/video5 -o \
        -d /sys/class/video4linux/v4l-subdev5/device/video4linux/video5 ]; then
        PreviewDevs+=("/dev/video5")
        PictureDevs+=("/dev/video4")
	CameraTypes+=("mipi")
fi

# usb camera 1
if [ -f /sys/class/video4linux/video10/name ]; then
	# only test Logitech C920 pro
        if [ "$( grep -i "webcam" /sys/class/video4linux/video10/name )" ]; then
		PreviewDevs+=("/dev/video10")
		PictureDevs+=("/dev/video10")
		CameraTypes+=("usb")
        fi
fi

# usb camera 2
if [ -f /sys/class/video4linux/video12/name ]; then
        # only test Logitech C920 pro
        if [ "$( grep -i "webcam" /sys/class/video4linux/video12/name )" ]; then
                PreviewDevs+=("/dev/video12")
                PictureDevs+=("/dev/video12")
                CameraTypes+=("usb")
        fi
fi

killall gst-launch-1.0 2>&1 > /dev/null
sleep 1

for icam in 0 1
do
	[ -c "${PreviewDevs[$icam]}" ] || break

	echo "Start MIPI CSI Camera Preview ${PreviewDevs[$icam]} ..."

        rkargs="device=${PreviewDevs[$icam]}"
	if [ ${CameraTypes[$icam]} = "mipi" ]; then
        	CMD="gst-launch-1.0 rkisp ${rkargs} io-mode=4 \
                	! video/x-raw,format=NV12,${preview_mode} \
                	! ${vsnk}"
	else
		CMD="gst-launch-1.0 v4l2src ${rkargs} io-mode=4 \
                        ! videoconvert ! video/x-raw,format=NV12,${preview_mode} \
                        ! ${vsnk}"
	fi

        echo "===================================================="
        echo "=== GStreamer 1.1 command:"
        echo "=== $(echo $CMD | sed -e 's/\r//g')"
        echo "===================================================="

	if [ $vsnk = "kmssink" -o "$(id -un)" = "pi" ]; then
                eval "${CMD}"&
        else
                su pi -c "${CMD}"&
        fi

        sleep 2
done

