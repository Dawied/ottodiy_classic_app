/*  
*                        
*    ______________      ____                                _____    _  _     _
*   |   __     __  |    / __ \ _________ _________   ____   |  __ \  | | \\   //  
*   |  |__|   |__| |   | |  | |___   ___ ___   ___  / __ \  | |  | | | |  \\ //  
*   |_    _________|   | |  | |   | |       | |    | |  | | | |  | | | |   | |
*   | \__/         |   | |__| |   | |       | |    | |__| | | |__| | | |   | |
*   |              |    \____/    |_|       |_|     \____/  |_____/  |_|   |_|
*   |_    _________|
*     \__/            
*
*    This Sketch was created to control Otto Wheels with the Offical Web Bluetooth Controller for Otto DIY Robots.
*    For any question about this script you can contact us at education@ottodiy.com
*    By: Iván R. Artiles
*    v2 By: David Pront
*/

#include <NimBLEDevice.h>
#if !defined(ARDUINO_ARCH_ESP32)
#include <SoftwareSerial.h>
#endif

#ifdef ARDUINO_ARCH_ESP32
#include <ESP32Servo.h>
#else
#include <Servo.h>
#endif

#define RIGHTSERVO 2
#define LEFTSERVO 3
#define TRIG 8
#define ECHO 9
#define BLE_TX 11
#define BLE_RX 12
#include <Otto.h>
#define BUZZER 13
Otto Ottobot;

#if not defined(ARDUINO_ARCH_ESP32)  // disable LineFollower ... Esp32 only has one analog ... maybe fix to use with digital line sensors
int line_sensor_right = A0;
int line_sensor_left = A1;
#endif

int speed_right_forward = 30;
int speed_right_backward = 150;
int speed_left_forward = 150;
int speed_left_backward = 30;
int speed_stop = 90;
int right_threeshold = 35;
int left_threeshold = 35;
int ultrasound_threeshold = 15;
int rightValue, leftValue = 0;
String command = "";
int current_speed_index = 2;


class BTInterface {
public:
  virtual void begin(const char* name) = 0;
  virtual bool available() = 0;
  virtual String readLine() = 0;
  virtual void write(const String& msg) = 0;
};

#if !defined(ARDUINO_ARCH_ESP32)

#include <SoftwareSerial.h>

class BT_HC05 : public BTInterface {
  SoftwareSerial serial;

public:
  BT_HC05(uint8_t rx, uint8_t tx)
    : serial(rx, tx) {}

  void begin(const char* name) override {
    serial.begin(9600);
  }

  bool available() override {
    return serial.available();
  }

  String readLine() override {
    return serial.readStringUntil('\n');
  }

  void write(const String& msg) override {
    serial.println(msg);
  }
};

#endif

#if !defined(ARDUINO_ARCH_ESP32)

class BT_HM10 : public BTInterface {
  SoftwareSerial serial;

public:
  BT_HM10(uint8_t rx, uint8_t tx)
    : serial(rx, tx) {}

  void begin(const char* name) override {
    serial.begin(9600);
  }

  bool available() override {
    return serial.available();
  }

  String readLine() override {
    return serial.readStringUntil('\n');
  }

  void write(const String& msg) override {
    serial.println(msg);
  }
};

#endif

#if defined(ARDUINO_ARCH_ESP32) && !defined(CONFIG_IDF_TARGET_ESP32C3)

#include "BluetoothSerial.h"

class BT_ESP32Classic : public BTInterface {
  BluetoothSerial bt;

public:
  void begin(const char* name) override {
    bt.begin(name);
  }

  bool available() override {
    return bt.available();
  }

  String readLine() override {
    return bt.readStringUntil('\n');
  }

  void write(const String& msg) override {
    bt.println(msg);
  }
};

#endif

#if defined(ARDUINO_ARCH_ESP32)

#include <NimBLEDevice.h>

static String bleBuffer = "";
static bool bleReady = false;

class BT_ESP32BLE : public BTInterface {
  NimBLECharacteristic* tx;
  NimBLECharacteristic* rx;

public:
  void begin(const char* name) override {
    NimBLEDevice::init(name);
    NimBLEDevice::setDeviceName(name);

    NimBLEServer* server = NimBLEDevice::createServer();
    NimBLEService* service = server->createService(
      "6E400001-B5A3-F393-E0A9-E50E24DCCA9E");

    rx = service->createCharacteristic(
      "6E400002-B5A3-F393-E0A9-E50E24DCCA9E",
      NIMBLE_PROPERTY::WRITE);

    tx = service->createCharacteristic(
      "6E400003-B5A3-F393-E0A9-E50E24DCCA9E",
      NIMBLE_PROPERTY::NOTIFY);

    class RXCallback : public NimBLECharacteristicCallbacks {
      void onWrite(NimBLECharacteristic* pCharacteristic,
                   NimBLEConnInfo& connInfo) {

        std::string v = pCharacteristic->getValue();

        if (!v.empty()) {
          bleBuffer.concat(v.c_str());
        }
      }
    };

    rx->setCallbacks(new RXCallback());

    service->start();

    NimBLEAdvertising* adv = NimBLEDevice::getAdvertising();

    adv->setName(name);  // IMPORTANT
    adv->addServiceUUID("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
    adv->start();
  }

  bool available() override {
    return bleBuffer.indexOf('\n') != -1;
  }

  String readLine() override {
    int idx = bleBuffer.indexOf('\n');
    if (idx == -1) return "";

    String line = bleBuffer.substring(0, idx);
    bleBuffer = bleBuffer.substring(idx + 1);
    return line;
  }

  void write(const String& msg) override {
    tx->setValue(msg.c_str());
    tx->notify();
  }
};

#endif

BTInterface* bluetooth;

void setupBluetooth() {

#if defined(ARDUINO_ARCH_ESP32)

#if defined(CONFIG_IDF_TARGET_ESP32C3)
  static BT_ESP32BLE bt;
#else
  static BT_ESP32Classic bt;
#endif

  bluetooth = &bt;

#else
  static BT_HC05 bt(10, 11);  // or BT_HM10
  bluetooth = &bt;

#endif

  bluetooth->begin("OttoDIY");
}

Servo servo_right;
Servo servo_left;

long ultrasound_distance() {
  long duration, distance;
  digitalWrite(TRIG, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG, LOW);
  duration = pulseIn(ECHO, HIGH);
  distance = duration / 58;
  return distance;
}

void setup() {
  setupBluetooth();

  bluetooth->begin("OttoDIY");

  Serial.begin(9600);
  Ottobot.init(4, 5, 6, 7, true, BUZZER);
  pinMode(TRIG, OUTPUT);
  pinMode(ECHO, INPUT);

#ifdef ARDUINO_ARCH_ESP32
  ESP32PWM::allocateTimer(0);
  ESP32PWM::allocateTimer(1);
  ESP32PWM::allocateTimer(2);
  ESP32PWM::allocateTimer(3);

  // Set the 50Hz frequency required by standard servos
  servo_right.setPeriodHertz(50);
  servo_left.setPeriodHertz(50);
#endif

  attachServos();
  servo_right.write(speed_stop);
  servo_left.write(speed_stop);
}

void loop() {
  checkBluetooth();
  checkSerial();

  if (command == "avoidance") {
    Avoidance();
  } else if (command == "linefollower") {
    LineFollower();
  }
}

void checkSerial() {
  if (Serial.available()) {
    char c = Serial.read();
    if (c == 'w' || c == 'W') {
      Serial.print("Forward");
      command = "";
      Forward();
    } else if (c == 's' || c == 'S') {
      command = "";
      Backward();
    } else if (c == 'a' || c == 'A') {
      command = "";
      Left();
    } else if (c == 'd' || c == 'D') {
      command = "";
      Right();
    } else if (c == ' ' || c == 'x' || c == 'X') {
      command = "";
      Stop();
    }
  }
}

void checkBluetooth() {

  if (!bluetooth->available()) return;

  String cmd = bluetooth->readLine();
  cmd.trim();

  char buffer[40];
  cmd.toCharArray(buffer, 40);

  Serial.println(buffer);

  int len = strlen(buffer);
  if (len > 0 && isDigit(buffer[len - 1])) {
    current_speed_index = buffer[len - 1] - '0';
  }

  if (buffer[0] == 'J') {
    command = "";
    GetCoords(cmd);
  }

  if (strncmp(buffer, "forward", 7) == 0) Forward();
  else if (strncmp(buffer, "backward", 8) == 0) Backward();
  else if (strncmp(buffer, "right", 5) == 0) Right();
  else if (strncmp(buffer, "left", 4) == 0) Left();
  else if (strncmp(buffer, "stop", 4) == 0) {
    command = "";
    Stop();
  } else if (strncmp(buffer, "avoidance", 9) == 0) command = "avoidance";
  else if (strncmp(buffer, "line_follower", 13) == 0) command = "linefollower";
  else if (strncmp(buffer, "sing", 4) == 0) {
    command = "";
    char *p = buffer + 4;
    while (*p && (*p < '0' || *p > '9')) {
      p++;
    }
    int songName = atoi(p);
    Ottobot.sing(songName);
  }
}

void attachServos() {
#ifdef ARDUINO_ARCH_ESP32
  servo_right.attach(RIGHTSERVO, 1000, 2000);
  servo_left.attach(LEFTSERVO, 1000, 2000);
#else
  servo_right.attach(RIGHTSERVO);
  servo_left.attach(LEFTSERVO);
#endif
}

void GetCoords(String str) {
  String x = str.substring(str.lastIndexOf('J') + 1, str.lastIndexOf(','));
  String y = str.substring(str.lastIndexOf(',') + 1, str.lastIndexOf('H'));
  //Serial.println("X:" + x + " Y:" + y);
  joystickRoll(x.toInt(), y.toInt());
}

void joystickRoll(int x, int y) {
  if ((x >= -5) && (x <= 5) && (y >= -5) && (y <= 5)) {
    Stop();
  } else {
    attachServos();
    
    // y goes from -50 (full backward) to 50 (full forward)
    int left_base = map(y, -50, 50, 30, 150);
    int right_base = map(y, -50, 50, 150, 30);
    
    int steer = 0;
    if (y >= 0) {
      // Forward steering: x > 0 increases left speed, decreases right speed
      steer = map(x, -50, 50, -30, 30);
    } else {
      // Backward steering: x > 0 increases left backward speed (decreases servo write value towards 0)
      steer = map(x, -50, 50, 30, -30);
    }
    
    servo_left.write(left_base + steer);
    servo_right.write(right_base + steer);
  }
}

void Forward() {
  attachServos();
  double factor = 0.4 + (current_speed_index / 5.0) * 0.6;
  int left_speed = speed_stop + (speed_left_forward - speed_stop) * factor;
  int right_speed = speed_stop + (speed_right_forward - speed_stop) * factor;
  servo_left.write(left_speed);
  servo_right.write(right_speed);
}

void Backward() {
  attachServos();
  double factor = 0.4 + (current_speed_index / 5.0) * 0.6;
  int left_speed = speed_stop + (speed_left_backward - speed_stop) * factor;
  int right_speed = speed_stop + (speed_right_backward - speed_stop) * factor;
  servo_left.write(left_speed);
  servo_right.write(right_speed);
}

void Right() {
  attachServos();
  double factor = 0.4 + (current_speed_index / 5.0) * 0.6;
  int left_speed = speed_stop + (speed_left_forward - speed_stop) * factor;
  int right_speed = speed_stop + (speed_right_backward - speed_stop) * factor;
  servo_left.write(left_speed);
  servo_right.write(right_speed);
}

void Left() {
  attachServos();
  double factor = 0.4 + (current_speed_index / 5.0) * 0.6;
  int left_speed = speed_stop + (speed_left_backward - speed_stop) * factor;
  int right_speed = speed_stop + (speed_right_forward - speed_stop) * factor;
  servo_left.write(left_speed);
  servo_right.write(right_speed);
}

void Stop() {
  attachServos();
  servo_right.write(speed_stop);
  servo_left.write(speed_stop);
}

void Avoidance() {
  if (ultrasound_distance() < ultrasound_threeshold) {
    Backward();
    delay(500);
    Stop();
    delay(100);
    Right();
    delay(500);
    Stop();
    delay(100);
  }
  Forward();
}

void LineFollower() {
#if not defined(ARDUINO_ARCH_ESP32)  // disable LineFollower ... Esp32 only has one analog ... maybe fix to use digital line sensors
  rightValue = analogRead(line_sensor_right);
  leftValue = analogRead(line_sensor_left);

  if (rightValue > right_threeshold && leftValue > left_threeshold) {
    servo_right.write(speed_right_forward + 10);
    servo_left.write(speed_left_forward - 10);
  } else if (leftValue > left_threeshold) {
    servo_right.write(speed_right_forward - 40);
    servo_left.write(speed_left_forward - 40);
  } else if (rightValue > right_threeshold) {
    servo_right.write(speed_right_forward + 30);
    servo_left.write(speed_left_forward + 30);
  }
#endif
}

void Settings(String speeds) {
  decodeSpeeds(speeds);
}

void decodeSpeeds(String c) {
  int counter = 0;
  String rb = "";
  String rf = "";
  String lf = "";
  String lb = "";
  String ts_r = "";
  String ts_l = "";
  String ts_ultrasound = "";
  for (int i = 1; i < c.length(); i++) {
    if (isDigit(c[i])) {
      if (counter == 0) {
        rf += c[i];
      } else if (counter == 1) {
        rb += c[i];
      } else if (counter == 2) {
        lf += c[i];
      } else if (counter == 3) {
        lb += c[i];
      } else if (counter == 4) {
        ts_r += c[i];
      } else if (counter == 5) {
        ts_l += c[i];
      } else if (counter == 6) {
        ts_ultrasound += c[i];
      }
    } else if (c[i] == '-') {
      counter++;
    }
  }

  speed_right_forward = rf.toInt();
  speed_right_backward = rb.toInt();
  speed_left_forward = lf.toInt();
  speed_left_backward = lb.toInt();
  right_threeshold = ts_r.toInt();
  left_threeshold = ts_l.toInt();
  ultrasound_threeshold = ts_ultrasound.toInt();
}