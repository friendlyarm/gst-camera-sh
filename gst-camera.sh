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

icam=0
vsnk=
action="preview"
output=
verbose="yes"

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
	echo -e "  -g\n\tuse glimagesink as video render(sink)"
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
			-g ) vsnk="glimagesink"; shift 1;;
			-h|--help ) usage; exit 1 ;;
			-- ) shift; break ;;
			*  ) echo "invalid option $1"; usage; return 1 ;;
		esac
	done

	if [ -z "$output" ]; then
		if [ $action = "photo" ]; then
			output="Image_MIPI.jpg"
		elif [ $action = "video" ]; then
			output="Video_MIPI.ts"
		fi
	fi
}



isp_default_vsnk=
usbcamera_default_vsnk=
if [ -f /usr/bin/lxsession ]; then
	export DISPLAY=:0.0
	# for FriendlyDesktop
	isp_default_vsnk="rkximagesink"
	usbcamera_default_vsnk="glimagesink"
else
	# for FriendlyCore
	isp_default_vsnk="kmssink"
	usbcamera_default_vsnk="kmssink"
fi


#----------------------------------------------------------
SELF=$0
parse_args $@

# selfpath
declare -a PreviewDevs=()
# mainpath
declare -a PictureDevs=()
# camera type
declare -a CameraTypes=()
# sink
declare -a Sinks=()

# preivew format
declare -a PreviewModes=()
# photo format
declare -a PictureModes=()
# video recoard format
declare -a VideoModes=()

# isp1
if [ -d /sys/devices/platform/ff910000.rkisp1/video4linux/v4l-subdev2 ]; then
    PreviewDevs+=("/dev/video1")
    PictureDevs+=("/dev/video0")
	CameraTypes+=("mipi")
	# use did not specify sink
	if [ -z "${vsnk}" ]; then
		Sinks+=(${isp_default_vsnk})
	else
		Sinks+=(${vsnk})
	fi
	PreviewModes+=("width=1280,height=720,framerate=30/1")
	PictureModes+=("width=1920,height=1080,framerate=10/1")
	VideoModes+=("width=1280,height=720,framerate=30/1")
fi

# isp2
if [ -d /sys/devices/platform/ff920000.rkisp1/video4linux/v4l-subdev1 -o \
     -d /sys/devices/platform/ff920000.rkisp1/video4linux/v4l-subdev5 ]; then
    PreviewDevs+=("/dev/video6")
    PictureDevs+=("/dev/video5")
	CameraTypes+=("mipi")
	# use did not specify sink
	if [ -z "${vsnk}" ]; then
		Sinks+=(${isp_default_vsnk})
	else
		Sinks+=(${vsnk})
	fi
	PreviewModes+=("width=1280,height=720,framerate=30/1")
	PictureModes+=("width=1920,height=1080,framerate=10/1")
	VideoModes+=("width=1280,height=720,framerate=30/1")
fi

# usb camera
if [ -f /sys/class/video4linux/video10/name ]; then
	# only test Logitech C920 pro
        if [ "$( grep -i "webcam" /sys/class/video4linux/video10/name )" ]; then
		PreviewDevs+=("/dev/video10")
		PictureDevs+=("/dev/video10")
		CameraTypes+=("usb")
        fi
	# use did not specify sink
	if [ -z "${vsnk}" ]; then
		Sinks+=(${usbcamera_default_vsnk})
	else
		Sinks+=(${vsnk})
	fi
	PreviewModes+=("width=640,height=480,framerate=30/1")
	PictureModes+=("width=640,height=480,framerate=30/1")
	VideoModes+=("width=640,height=480,framerate=30/1")
fi

rkargs="device=${PreviewDevs[$icam]}"
rkargs_mainpath="device=${PictureDevs[$icam]}"

#----------------------------------------------------------
killall gst-launch-1.0 2>&1 > /dev/null
sleep 1

function start_preview() {
	local CMD=
	if [ ${CameraTypes[$icam]} = "mipi" ]; then
        	CMD="gst-launch-1.0 rkisp ${rkargs} io-mode=4 \
                	! video/x-raw,format=NV12,${PreviewModes[$icam]} \
                	! ${Sinks[$icam]}"
	else
		CMD="gst-launch-1.0 v4l2src ${rkargs} io-mode=4 \
                        ! videoconvert ! video/x-raw,format=NV12,${PreviewModes[$icam]} \
                        ! ${Sinks[$icam]}"
	fi

	if [ "x${verbose}" == "xyes" ]; then
                echo "===================================================="
                echo "=== GStreamer 1.1 command:"
                echo "=== $(echo $CMD | sed -e 's/\r//g')"
                echo "===================================================="
        fi
	if [ ${Sinks[$icam]} = "kmssink" -o "$(id -un)" = "pi" ]; then
                eval "${CMD}"&
        else
                su pi -c "${CMD}"&
        fi
	sleep 2
}

function take_photo() {
	local CMD=
	if [ ${CameraTypes[$icam]} = "mipi" ]; then
        	CMD="gst-launch-1.0 rkisp num-buffers=20 ${rkargs_mainpath} io-mode=1 \
        	! video/x-raw,format=NV12,${PictureModes[$icam]} \
        	! jpegenc ! multifilesink location=\"/tmp/isp-frame%d.jpg\""
	else
		# usb camera only support io-mode=4
		CMD="gst-launch-1.0 v4l2src num-buffers=1 ${rkargs_mainpath} io-mode=4 \
        	! videoconvert ! video/x-raw,format=NV12,${PictureModes[$icam]} \
        	! jpegenc ! filesink location=\"/tmp/usb-frame.jpg\""
	fi

        if [ "x${verbose}" == "xyes" ]; then
                echo "===================================================="
                echo "=== GStreamer 1.1 command:"
                echo "=== $(echo $CMD | sed -e 's/\r//g')"
                echo "===================================================="
        fi
	echo "{{{{{{ start take photo"
        if [ ${Sinks[$icam]} = "kmssink" -o "$(id -un)" = "pi" ]; then
                eval "${CMD}"
        else
                su pi -c "${CMD}"
        fi
	echo "}}}}}} end take photo"
	if [ ${CameraTypes[$icam]} = "mipi" ]; then
		if [ -f /tmp/isp-frame19.jpg ]; then
			cp /tmp/isp-frame19.jpg ${output}
		fi
	else
		if [ -f /tmp/usb-frame.jpg ]; then
			cp /tmp/usb-frame.jpg ${output}
		fi
	fi
}

function start_video_recording() {
	local CMD=

	if [ ${CameraTypes[$icam]} = "mipi" ]; then
        	CMD="gst-launch-1.0 rkisp num-buffers=512 ${rkargs_mainpath} io-mode=1 \
        	! video/x-raw,format=NV12,${VideoModes[$icam]} \
        	! mpph264enc ! queue ! h264parse ! mpegtsmux \
        	! filesink location=/tmp/camera-record.ts"
	else
		# usb camera only support io-mode=4
		CMD="gst-launch-1.0 v4l2src num-buffers=512 ${rkargs_mainpath} io-mode=4 \
        	! videoconvert ! video/x-raw,format=NV12,${VideoModes[$icam]} \
        	! mpph264enc ! queue ! h264parse ! mpegtsmux \
        	! filesink location=/tmp/camera-record.ts"
	fi

        if [ "x${verbose}" == "xyes" ]; then
                echo "===================================================="
                echo "=== GStreamer 1.1 command:"
                echo "=== $(echo $CMD | sed -e 's/\r//g')"
                echo "===================================================="
        fi
	echo "{{{{{{ start video recording"
        if [ ${Sinks[$icam]} = "kmssink" -o "$(id -un)" = "pi" ]; then
                eval "${CMD}"
        else
                su pi -c "${CMD}"
        fi
	if [ -f /tmp/camera-record.ts ]; then
		cp /tmp/camera-record.ts ${output}
	fi
	echo "}}}}}} end video recording"
}


if [ "x$action" == "xphoto" ]; then
    take_photo
elif [ "x$action" == "xvideo" ]; then
    start_video_recording
else
    start_preview
fi

