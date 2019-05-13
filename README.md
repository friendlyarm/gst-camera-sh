# gst-camera.sh
The script "gst-camera.sh" is use to test camera's functions for FriendlyELEC RK3399 boards. You can run it in a commandline to test picture taking and video recording.

## Currently supported boards 
* RK3399  
NanoPC T4  
NanoPi M4  
NanoPi NEO4
  
## Supported cameras
* MIPI camera  
MCAM400 (ov4689): https://www.friendlyarm.com/index.php?route=product/product&product_id=247  
CAM1320 (ov13850): https://www.friendlyarm.com/index.php?route=product/product&product_id=228&search=CAM1320&description=true&category_id=0&sub_category=true
* USB camera  
Logitech C920 pro  


Install update
------------
## Installation 
***Note: FriendlyCore-20190511+/FriendlyDesktop-20190511+ required.  
Please download the latest FriendlyCore/FriendlyDesktop Image file from the following URL: http://download.friendlyarm.com/nanopct4***  

```
cd /tmp/
git clone https://github.com/friendlyarm/gst-camera-sh.git
sudo cp gst-camera-sh/gst-camera.sh `which gst-camera.sh`
```

Usage
------------
http://wiki.friendlyarm.com/wiki/index.php/NanoPC-T4#Work_with_MIPI_Camera_OV13850_and_MIPI_WDR_Camera_OV4689_Under_Linux_2
