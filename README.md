# Otto DIY Classic App

A replacement flutter app for the Otto DIY Arduino based project https://www.ottodiy.com/
Mainly build to make it more responsive than the original web based app.

## Features

- Connects to Otto DIY Classic robot
- Send commands to Otto DIY Classic robot
- Receives telemetry data from Otto DIY Classic robot
- Sends calibration commands to Otto DIY Classic robot
- Visualizes Otto DIY Classic robot's ultrasound sensor data
- Sings the songs included in Otto DIY Sounds.h

## Arduino

Although this will work with the original OttoS_BLE sketch, some of the features only work with the supplied new firmware OttoS_BLE_v2.ino that is located in the firmware folder.

Open OttoS_BLE_v2.ino in the Arduino IDE, install the OttoDIY library via the library manager and upload it to your microcontroller.

## Example page

You can see an example of the running app here: https://dawied.github.io/ottodiy_classic_app/