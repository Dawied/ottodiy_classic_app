# Otto DIY Classic App

A replacement flutter app for the Otto DIY Arduino based project https://www.ottodiy.com/
Mainly built to make it more responsive than the original web-based app.

This app tries to be compatible with the orginal Arduino code but uses alternative Arduino code for new functions. You find the new Arduino code for the classic and wheels version in the firmware folder. The code is also downloadable via the app.

## Features

- Connects to Otto DIY Classic and Wheels robot
- Send commands to Otto DIY Classic robot
- Receives telemetry data from Otto DIY Classic robot
- Sends calibration commands to Otto DIY Classic robot
- Visualizes Otto DIY Classic robot's ultrasound sensor data
- Sings the songs included in Otto DIY Sounds.h

## Arduino

Although this will work with the original OttoS_BLE sketch, some of the features only work with the supplied new firmware OttoS_BLE_v2.ino and OttoW_BLE_v2.ino that are located in the firmware folder.

Open the ino file in the Arduino IDE, install the OttoDIY library via the library manager and upload it to your microcontroller.

## Example page

You can see an example of the running app here: https://dawied.github.io/ottodiy_classic_app/