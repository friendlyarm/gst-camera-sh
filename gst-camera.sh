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

# ----------------------------------------------------------
# base setup

icam=0
preview_mode="width=1280,height=720,framerate=30/1"
picture_mode="width=1280,height=720,framerate=10/1"
video_mode="width=1920,height=1080,framerate=30/1"
vsnk="kmssink"
action="preview"
output="IMG_MIPI.jpg"
verbose="no"

sname=$(cut -d" " -f1 /sys/class/video4linux/v4l-subdev${icam}/name)
iqf="/etc/cam_iq/${sname}.xml"
if [ x"$sname" = x"rk-ov13850" ]; then
	picture_mode="width=2112,height=1568,framerate=10/1"
elif [ x"$sname" = x"rk-ov4689" ]; then
	picture_mode="width=2668,height=1520,framerate=10/1"
fi

if [ -f /usr/bin/lxsession ]; then
	# for FriendlyDesktop
	vsnk="rkximagesink"
fi

#----------------------------------------------------------
usage()
{
	echo "Usage: $0 [ARGS]"
	echo
	echo "Options:"
	echo -e "  -h, --help\n\tshow this help message and exit"
	echo -e "  -i, --index <0|1>\n\tcamera index,  0 or 1"
	echo -e "  -a, --action <preview|photo|video>\n\tpreview, take photo or record video"
	echo -e "  -o, --output <filename>\n\toutput file name"
	echo -e "  -v, --verbose\n\tshow full command"
	echo -e "  -x\n\tuse rkximagesink as video render(sink)"
	echo -e "  -k\n\tuse kmssink as video render(sink)"
	exit 1
}

parse_args()
{
	TEMP=`getopt -o "i:a:o:v:xkh" --long "index:,action:,output:,verbose:,help" -n "$SELF" -- "$@"`
	if [ $? != 0 ] ; then exit 1; fi
	eval set -- "$TEMP"

	while true; do
		case "$1" in
			-i|--index ) icam=$2; shift 2;;
			-a|--action) action=$2; shift 2;;
			-o|--output) output=$2; shift 2;;
			-v|--verbose) verbose=$2; shift 2;;
			-x ) vsnk="rkximagesink"; shift 1;;
			-k ) vsnk="kmssink"; shift 1;;
			-h|--help ) usage; exit 1 ;;
			-- ) shift; break ;;
			*  ) echo "invalid option $1"; usage; return 1 ;;
		esac
	done
}

#----------------------------------------------------------
SELF=$0
parse_args $@

if [ $icam -eq 0 ]; then
	preview_dev="/dev/video0"
	picture_dev="/dev/video2"
	rkargs="device=${preview_dev} sensor-id=1"
	rkargs_mainpath="device=${picture_dev} sensor-id=1"
else
	preview_dev="/dev/video4"
	picture_dev="/dev/video6"
	rkargs="device=${preview_dev} sensor-id=5"
	rkargs_mainpath="device=${picture_dev} sensor-id=5"
fi

if [ ! -d /sys/class/video4linux/v4l-subdev${icam} ]; then
	echo "Error: Camera ${icam} not found"
	exit -1
fi

if [ -c ${preview_dev} ]; then
	echo "Start MIPI CSI Camera Preview [${preview_dev}] ..."
else
	echo "Error: ${preview_dev}: No such device"
	exit -1
fi

#----------------------------------------------------------
export DISPLAY=:0.0

killall gst-launch-1.0 2>&1 > /dev/null
sleep 1

function start_preview() {
	local CMD="gst-launch-1.0 rkisp ${rkargs} io-mode=4 path-iqf=${iqf} \
		! video/x-raw,format=NV12,${preview_mode} \
		! ${vsnk}"
	if [ "x${verbose}" == "xyes" ]; then
                echo "===================================================="
                echo "=== GStreamer 1.1 command:"
                echo "=== $(echo $CMD | sed -e 's/\r//g')"
                echo "===================================================="
        fi
	if [ $vsnk = "kmssink" -o "$(id -un)" = "pi" ]; then
                eval "${CMD}"&
        else
                su pi -c "${CMD}"&
        fi
	sleep 2
}

function take_photo() {
	local CMD="gst-launch-1.0 rkisp num-buffers=20 ${rkargs_mainpath} io-mode=1 path-iqf=${iqf} \
        	! video/x-raw,format=NV12,${picture_mode} \
        	! jpegenc ! multifilesink location=\"/tmp/isp-frame%d.jpg\""
        if [ "x${verbose}" == "xyes" ]; then
                echo "===================================================="
                echo "=== GStreamer 1.1 command:"
                echo "=== $(echo $CMD | sed -e 's/\r//g')"
                echo "===================================================="
        fi
	echo "{{{{{{ start take photo"
        if [ $vsnk = "kmssink" -o "$(id -un)" = "pi" ]; then
                eval "${CMD}"
        else
                su pi -c "${CMD}"
        fi
	echo "}}}}}} end take photo"
	if [ -f /tmp/isp-frame19.jpg ]; then
		cp /tmp/isp-frame19.jpg ${output}
	fi
}

function start_video_recording() {
	local CMD="gst-launch-1.0 rkisp num-buffers=512 ${rkargs_mainpath} io-mode=1 path-iqf=${iqf} \
        	! video/x-raw,format=NV12,${video_mode} \
        	! mpph264enc ! queue ! h264parse ! mpegtsmux \
        	! filesink location=${output}"
        if [ "x${verbose}" == "xyes" ]; then
                echo "===================================================="
                echo "=== GStreamer 1.1 command:"
                echo "=== $(echo $CMD | sed -e 's/\r//g')"
                echo "===================================================="
        fi
	echo "{{{{{{ start video recording"
        if [ $vsnk = "kmssink" -o "$(id -un)" = "pi" ]; then
                eval "${CMD}"
        else
                su pi -c "${CMD}"
        fi
	echo "}}}}}} end video recording"
}


if [ "x$action" == "xphoto" ]; then
    # start_preview
    take_photo
elif [ "x$action" == "xvideo" ]; then
    # start_preview
    start_video_recording
else
    start_preview
fi

