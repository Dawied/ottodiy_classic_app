# Otto DIY Classic App

A replacement flutter app for the official Otto DIY app. Mainly to make it more responsive for mobile devices.

## Features

- Connects to Otto DIY Classic robot
- Send commands to Otto DIY Classic robot
- Receives telemetry data from Otto DIY Classic robot
- Sends calibration commands to Otto DIY Classic robot
- Visualizes Otto DIY Classic robot's ultrasound sensor data
- Sings the songs included in Otto DIY Sounds.h

## Arduino

Though this will work with the old OttoS_BLE sketch, some of the features only work with the supplied new firmware OttoS_BLE_v2.ino that is located in the firmware folder.

Open OttoS_BLE_v2.ino in the Arduino IDE, install the OttoDIY library via the library manager and upload it to your microcontroller.
