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
mode="width=1280,height=720,framerate=30/1"
vsnk="kmssink"
action="preview"
output="IMG_MIPI.jpg"
verbose="no"

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
	echo -e "  -m, --mode width=WIDTH,height=HEIGHT,framerate=FPS/1\n\tset camera resolution and framerate"
	echo -e "  -a, --action <preview|photo|video>\n\tpreview, take photo or record video"
	echo -e "  -o, --output <filename>\n\toutput file name"
	echo -e "  -v, --verbose\n\tshow full command"
	echo -e "  -x\n\tuse rkximagesink as video render(sink)"
	echo -e "  -k\n\tuse kmssink as video render(sink)"
	exit 1
}

parse_args()
{
	TEMP=`getopt -o "i:m:a:o:v:xkh" --long "index:,mode:,action:,output:,verbose:,help" -n "$SELF" -- "$@"`
	if [ $? != 0 ] ; then exit 1; fi
	eval set -- "$TEMP"

	while true; do
		case "$1" in
			-i|--index ) icam=$2; shift 2;;
			-m|--mode ) mode=$2; shift 2;;
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
	rkargs_picture="device=${picture_dev} sensor-id=1"
else
	preview_dev="/dev/video4"
	picture_dev="/dev/video6"
	rkargs="device=${preview_dev} sensor-id=5"
	rkargs_picture="device=${picture_dev} sensor-id=5"
fi

if [ ! -d /sys/class/video4linux/v4l-subdev${icam} ]; then
	echo "Error: Camera ${icam} not found"
	exit -1
fi

sname=$(cut -d" " -f1 /sys/class/video4linux/v4l-subdev${icam}/name)
iqf="/etc/cam_iq/${sname}.xml"

if [ -c ${preview_dev} ]; then
	echo "Start MIPI CSI Camera Preview [${preview_dev}] ..."
else
	echo "Error: ${preview_dev}: No such device"
	exit -1
fi

#----------------------------------------------------------
export DISPLAY=:0.0

GSTC="gst-launch-1.0 rkisp ${rkargs} io-mode=4 path-iqf=${iqf} \
        ! video/x-raw,format=NV12,${mode} \
        ! ${vsnk}"

if [ "x$action" == "xphoto" ]; then
    GSTC="gst-launch-1.0 rkisp num-buffers=1 ${rkargs_picture} io-mode=4 path-iqf=${iqf} \
        ! video/x-raw,format=NV12,${mode} \
        ! jpegenc ! filesink location=${output}"
fi

if [ "x$action" == "xvideo" ]; then
    GSTC="gst-launch-1.0 rkisp num-buffers=512 ${rkargs} io-mode=4 path-iqf=${iqf} \
        ! video/x-raw,format=NV12,${mode} \
	! tee name=t t. ! queue ! ${vsnk} t. \
	! queue ! mpph264enc ! queue ! h264parse ! mpegtsmux \
        ! filesink location=${output}"
fi

if [ "x${verbose}" == "xyes" ]; then
	echo "===================================================="
	echo "GStreamer 1.1 command:"
	echo ${GSTC}
	echo "===================================================="
fi

if [ $vsnk = "kmssink" -o "$(id -un)" = "pi" ]; then
	eval "${GSTC}"
else
	su pi -c "${GSTC}"
fi
