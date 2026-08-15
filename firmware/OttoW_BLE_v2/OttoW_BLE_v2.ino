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
#include <EEPROM.h>

#ifdef ARDUINO_ARCH_ESP32
#include <ESP32Servo.h>
#include "driver/gpio.h"
#else
#include <Servo.h>
#endif

#define RIGHTSERVO 2
#define LEFTSERVO 3
#define BLE_TX 11
#define BLE_RX 12
#define BUZZER 10
#ifdef ARDUINO_ARCH_ESP32
#define LINE_SENSOR_RIGHT 5
#define LINE_SENSOR_LEFT 6
#define TRIG 0
#define ECHO 1
#else
#define LINE_SENSOR_RIGHT A0
#define LINE_SENSOR_LEFT A1
#define TRIG 8
#define ECHO 9
#endif

#define BUTTON_OBSTACLE 20
#define BUTTON_LINE 21

#define EEPROM_WHEEL_TRIM_LEFT 10
#define EEPROM_WHEEL_TRIM_RIGHT 11
#define EEPROM_WHEEL_MAGIC 12
#define EEPROM_WHEEL_MAGIC_VAL 0x57

// Self-contained sound note definitions (copied from Otto DIY Library)
#define note_E5  659.26
#define note_B5  987.77
#define note_C6  1046.50
#define note_E6  1318.51
#define note_G6  1567.98
#define note_A6  1760.00
#define note_D7  2349.32

void _tone(float noteFrequency, long noteDuration, int silentDuration) {
  if (silentDuration == 0) { silentDuration = 1; }
  tone(BUZZER, (unsigned int)noteFrequency, noteDuration);
  delay(noteDuration);
  noTone(BUZZER);
  delay(silentDuration);
}

void doubleBeep() {
  _tone(1500, 35, 30);
  _tone(1500, 35, 10);
}

void bendTones(float initFrequency, float finalFrequency, float prop, long noteDuration, int silentDuration) {
  if (silentDuration == 0) { silentDuration = 1; }
  if (initFrequency < finalFrequency) {
    for (float i = initFrequency; i < finalFrequency; i = i * prop) {
      _tone(i, noteDuration, silentDuration);
    }
  } else {
    for (float i = initFrequency; i > finalFrequency; i = i / prop) {
      _tone(i, noteDuration, silentDuration);
    }
  }
}

void sing(int songName) {
  switch (songName) {
    case 1: // S_connection
      _tone(note_E5, 50, 30);
      _tone(note_E6, 55, 25);
      _tone(note_A6, 60, 10);
      break;
    case 2: // S_disconnection
      _tone(note_E5, 50, 30);
      _tone(note_A6, 55, 25);
      _tone(note_E6, 50, 10);
      break;
    case 3: // S_buttonPushed
      bendTones(note_E6, note_G6, 1.03, 20, 2);
      delay(30);
      bendTones(note_E6, note_D7, 1.04, 10, 2);
      break;
    case 4: // S_mode1
      bendTones(note_E6, note_A6, 1.02, 30, 10);
      break;
    case 5: // S_mode2
      bendTones(note_G6, note_D7, 1.03, 30, 10);
      break;
    case 6: // S_surprise
      bendTones(800, 2150, 1.02, 10, 1);
      bendTones(2149, 800, 1.03, 7, 1);
      break;
    case 7: // S_OhOoh
      bendTones(880, 2000, 1.04, 8, 3);
      delay(200);
      for (float i = 880; i < 2000; i = i * 1.04) {
        _tone(note_B5, 5, 10);
      }
      break;
    case 8: // S_OhOoh2
      bendTones(1880, 3000, 1.03, 8, 3);
      delay(200);
      for (float i = 1880; i < 3000; i = i * 1.03) {
        _tone(note_C6, 10, 10);
      }
      break;
    case 9: // S_cuddly
      bendTones(700, 900, 1.03, 16, 4);
      bendTones(899, 650, 1.01, 18, 7);
      break;
    case 10: // S_sleeping
      bendTones(100, 500, 1.04, 10, 10);
      delay(500);
      bendTones(400, 100, 1.04, 10, 1);
      break;
    case 12: // S_happy
      bendTones(1500, 2500, 1.05, 20, 8);
      bendTones(2499, 1500, 1.05, 25, 8);
      break;
    case 13: // S_superHappy
      bendTones(2000, 6000, 1.05, 8, 3);
      delay(50);
      bendTones(5999, 2000, 1.05, 13, 2);
      break;
    case 14: // S_sad
      bendTones(880, 669, 1.02, 20, 200);
      break;
    case 15: // S_confused
      bendTones(1000, 1700, 1.03, 8, 2);
      bendTones(1699, 500, 1.04, 8, 3);
      bendTones(1000, 1700, 1.05, 9, 10);
      break;
    case 17: // S_fart1
      bendTones(1600, 3000, 1.02, 2, 15);
      break;
    case 18: // S_fart2
      bendTones(2000, 6000, 1.02, 2, 20);
      break;
    case 19: // S_fart3
      bendTones(1600, 4000, 1.02, 2, 20);
      bendTones(4000, 3000, 1.02, 2, 20);
      break;
  }
}



int speed_right_forward = 30;
int speed_right_backward = 150;
int speed_left_forward = 150;
int speed_left_backward = 30;
int speed_stop = 90;
int right_threeshold = 35;
int left_threeshold = 35;
int ultrasound_threeshold = 15;
int avoidance_sound = 0;
int line_steer = 100;
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
    serial.print("AT+NAME");
    serial.println(name);
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

    adv->addServiceUUID("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");

    NimBLEAdvertisementData scanResponseData;
    scanResponseData.setName(name);
    adv->setScanResponseData(scanResponseData);

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

  bluetooth->begin("OttoWheels");
}

Servo servo_right;
Servo servo_left;

int trim_left = 0;
int trim_right = 0;

void writeServoLeft(int speed) {
  int val;
  if (speed > speed_stop) {
    val = speed + trim_left;
  } else if (speed < speed_stop) {
    val = speed - trim_left;
  } else {
    val = speed_stop;
  }
  servo_left.write(constrain(val, 0, 180));
}

void writeServoRight(int speed) {
  int val;
  if (speed > speed_stop) {
    val = speed + trim_right;
  } else if (speed < speed_stop) {
    val = speed - trim_right;
  } else {
    val = speed_stop;
  }
  servo_right.write(constrain(val, 0, 180));
}

void sendCalibrationData() {
  String msg = "WHEEL_CALIB:" + String(trim_left) + "," + String(trim_right);
  bluetooth->write(msg);
  Serial.println(msg);
}

void loadCalibration() {
#ifdef ARDUINO_ARCH_ESP32
  EEPROM.begin(64);
#endif
  if (EEPROM.read(EEPROM_WHEEL_MAGIC) == EEPROM_WHEEL_MAGIC_VAL) {
    trim_left = (int8_t)EEPROM.read(EEPROM_WHEEL_TRIM_LEFT);
    trim_right = (int8_t)EEPROM.read(EEPROM_WHEEL_TRIM_RIGHT);
  } else {
    trim_left = 0;
    trim_right = 0;
  }
}

void saveCalibration() {
#ifdef ARDUINO_ARCH_ESP32
  EEPROM.begin(64);
#endif
  EEPROM.write(EEPROM_WHEEL_TRIM_LEFT, (uint8_t)trim_left);
  EEPROM.write(EEPROM_WHEEL_TRIM_RIGHT, (uint8_t)trim_right);
  EEPROM.write(EEPROM_WHEEL_MAGIC, EEPROM_WHEEL_MAGIC_VAL);
#ifdef ARDUINO_ARCH_ESP32
  EEPROM.commit();
#endif
  sendCalibrationData();
  doubleBeep();
}

void clearCalibration() {
  trim_left = 0;
  trim_right = 0;
#ifdef ARDUINO_ARCH_ESP32
  EEPROM.begin(64);
#endif
  EEPROM.write(EEPROM_WHEEL_TRIM_LEFT, 0);
  EEPROM.write(EEPROM_WHEEL_TRIM_RIGHT, 0);
  EEPROM.write(EEPROM_WHEEL_MAGIC, 0xFF);
#ifdef ARDUINO_ARCH_ESP32
  EEPROM.commit();
#endif
  sendCalibrationData();
  doubleBeep();
}

long ultrasound_distance() {
  long duration, distance;
  digitalWrite(TRIG, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG, LOW);
  duration = pulseIn(ECHO, HIGH, 30000);
  distance = duration / 58;
  return distance;
}

void setup() {
  Serial.begin(9600);
  setupBluetooth();
  pinMode(BUZZER, OUTPUT);
  pinMode(TRIG, OUTPUT);
  pinMode(ECHO, INPUT);
  pinMode(LINE_SENSOR_RIGHT, INPUT);
  pinMode(LINE_SENSOR_LEFT, INPUT);
  pinMode(BUTTON_OBSTACLE, INPUT_PULLUP);
  pinMode(BUTTON_LINE, INPUT_PULLUP);

#ifdef ARDUINO_ARCH_ESP32
  ESP32PWM::allocateTimer(0);
  ESP32PWM::allocateTimer(1);
  ESP32PWM::allocateTimer(2);
  ESP32PWM::allocateTimer(3);

  // Set the 50Hz frequency required by standard servos
  servo_right.setPeriodHertz(50);
  servo_left.setPeriodHertz(50);

  gpio_set_drive_capability((gpio_num_t)BUZZER, GPIO_DRIVE_CAP_3);
#endif

  attachServos();
  loadCalibration();
  writeServoRight(speed_stop);
  writeServoLeft(speed_stop);
}

bool lastObstacleState = HIGH;
bool obstacleState = HIGH;
unsigned long lastObstacleDebounceTime = 0;

bool lastLineState = HIGH;
bool lineState = HIGH;
unsigned long lastLineDebounceTime = 0;
const unsigned long debounceDelay = 50;

void checkButtons() {
  bool readingObstacle = digitalRead(BUTTON_OBSTACLE);
  if (readingObstacle != lastObstacleState) {
    lastObstacleDebounceTime = millis();
    lastObstacleState = readingObstacle;
  }
  if ((millis() - lastObstacleDebounceTime) > debounceDelay) {
    if (readingObstacle != obstacleState) {
      obstacleState = readingObstacle;
      if (obstacleState == LOW) {
        doubleBeep(); // Short double beep feedback
        if (command == "avoidance") {
          command = "";
          Stop();
        } else {
          command = "avoidance";
        }
      }
    }
  }

  bool readingLine = digitalRead(BUTTON_LINE);
  if (readingLine != lastLineState) {
    lastLineDebounceTime = millis();
    lastLineState = readingLine;
  }
  if ((millis() - lastLineDebounceTime) > debounceDelay) {
    if (readingLine != lineState) {
      lineState = readingLine;
      if (lineState == LOW) {
        doubleBeep(); // Short double beep feedback
        if (command == "linefollower") {
          command = "";
          Stop();
        } else {
          command = "linefollower";
        }
      }
    }
  }
}

void loop() {
  checkBluetooth();
  checkSerial();
  checkButtons();

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
  if (strncmp(buffer, "forward", 7) == 0 || strncmp(buffer, "backward", 8) == 0 ||
      strncmp(buffer, "right", 5) == 0 || strncmp(buffer, "left", 4) == 0) {
    if (len > 0 && isDigit(buffer[len - 1])) {
      current_speed_index = buffer[len - 1] - '0';
    }
  }

  if (buffer[0] == 'J') {
    command = "";
    GetCoords(cmd);
  }

  static bool is_moving = false;

  if (strncmp(buffer, "forward", 7) == 0) {
    is_moving = true;
    Forward();
  } else if (strncmp(buffer, "backward", 8) == 0) {
    is_moving = true;
    Backward();
  } else if (strncmp(buffer, "right", 5) == 0) {
    is_moving = true;
    Right();
  } else if (strncmp(buffer, "left", 4) == 0) {
    is_moving = true;
    Left();
  } else if (strncmp(buffer, "stop", 4) == 0) {
    is_moving = false;
    command = "";
    Stop();
  } else if (strncmp(buffer, "avoidance_dist", 14) == 0 || strncmp(buffer, "avoid_dist", 10) == 0) {
    char *p = buffer;
    while (*p && (*p < '0' || *p > '9')) p++;
    if (*p) {
      int dist = atoi(p);
      if (dist >= 5 && dist <= 100) {
        ultrasound_threeshold = dist;
        Serial.print("Updated avoidance threshold: ");
        Serial.println(ultrasound_threeshold);
      }
    }
  } else if (strncmp(buffer, "avoidance_sound", 15) == 0 || strncmp(buffer, "avoid_sound", 11) == 0) {
    char *p = buffer;
    while (*p && (*p < '0' || *p > '9')) p++;
    if (*p) {
      avoidance_sound = atoi(p);
      Serial.print("Updated avoidance sound: ");
      Serial.println(avoidance_sound);
    }
  } else if (strncmp(buffer, "line_steer", 10) == 0) {
    char *p = buffer;
    while (*p && (*p < '0' || *p > '9')) p++;
    if (*p) {
      line_steer = atoi(p);
      if (line_steer < 0) line_steer = 0;
      if (line_steer > 100) line_steer = 100;
      Serial.print("Updated line steer sharpness: ");
      Serial.println(line_steer);
    }
  } else if (strncmp(buffer, "avoidance", 9) == 0) command = "avoidance";
  else if (strncmp(buffer, "line_follower", 13) == 0) command = "linefollower";
  else if (strncmp(buffer, "ultrasound", 10) == 0) {
    if (command == "avoidance" || command == "linefollower") {
      command = "";
      is_moving = false;
      Stop();
    }
    long dist = ultrasound_distance();
    Serial.print("Ultrasound distance: ");
    Serial.println(dist);
    bluetooth->write(String(dist));
  } else if (strncmp(buffer, "linesensor", 10) == 0 || strncmp(buffer, "line_status", 11) == 0) {
#if defined(ARDUINO_ARCH_ESP32)
    int rVal = digitalRead(LINE_SENSOR_RIGHT);
    int lVal = digitalRead(LINE_SENSOR_LEFT);
#else
    int rAnalog = analogRead(LINE_SENSOR_RIGHT);
    int lAnalog = analogRead(LINE_SENSOR_LEFT);
    int rVal = (rAnalog > right_threeshold) ? 1 : 0;
    int lVal = (lAnalog > left_threeshold) ? 1 : 0;
#endif
    String res = "LINE:" + String(lVal) + "," + String(rVal);
    Serial.print("Line status: ");
    Serial.println(res);
    bluetooth->write(res);
  } else if (strncmp(buffer, "sing", 4) == 0) {
    command = "";
    char *p = buffer + 4;
    while (*p && (*p < '0' || *p > '9')) {
      p++;
    }
    int songName = atoi(p);
    sing(songName);
  } else if (strncmp(buffer, "wheel_calib_save", 16) == 0 || strncmp(buffer, "save_wheel_calib", 16) == 0) {
    saveCalibration();
    Serial.println("Wheel calibration saved to EEPROM");
  } else if (strncmp(buffer, "wheel_calib_read", 16) == 0 || strncmp(buffer, "get_wheel_calib", 15) == 0) {
    sendCalibrationData();
  } else if (strncmp(buffer, "wheel_calib_clear", 17) == 0 || strncmp(buffer, "clear_wheel_calib", 17) == 0) {
    clearCalibration();
    Serial.println("Wheel calibration cleared from EEPROM");
  } else if (strncmp(buffer, "wheel_test", 10) == 0) {
    command = "";
    is_moving = true;
    Forward();
    delay(3000);
    is_moving = false;
    Stop();
  } else if (strncmp(buffer, "wheel_calib", 11) == 0) {
    char *p = strchr(buffer, ':');
    if (!p) p = strchr(buffer, ' ');
    if (p) {
      p++;
      trim_left = atoi(p);
      char *p2 = strchr(p, ',');
      if (!p2) p2 = strchr(p, ' ');
      if (p2) {
        trim_right = atoi(p2 + 1);
      }
    }
    if (is_moving) {
      Forward();
    }
    Serial.print("Updated wheel trims -> Left: ");
    Serial.print(trim_left);
    Serial.print(", Right: ");
    Serial.println(trim_right);
  }
}

void attachServos() {
#ifdef ARDUINO_ARCH_ESP32
  if (!servo_right.attached()) servo_right.attach(RIGHTSERVO, 1000, 2000);
  if (!servo_left.attached()) servo_left.attach(LEFTSERVO, 1000, 2000);
#else
  if (!servo_right.attached()) servo_right.attach(RIGHTSERVO);
  if (!servo_left.attached()) servo_left.attach(LEFTSERVO);
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
    
    writeServoLeft(left_base + steer);
    writeServoRight(right_base + steer);
  }
}

void Forward() {
  attachServos();
  double factor = 0.4 + (current_speed_index / 5.0) * 0.6;
  int left_speed = speed_stop + (speed_left_forward - speed_stop) * factor;
  int right_speed = speed_stop + (speed_right_forward - speed_stop) * factor;
  writeServoLeft(left_speed);
  writeServoRight(right_speed);
}

void Backward() {
  attachServos();
  double factor = 0.4 + (current_speed_index / 5.0) * 0.6;
  int left_speed = speed_stop + (speed_left_backward - speed_stop) * factor;
  int right_speed = speed_stop + (speed_right_backward - speed_stop) * factor;
  writeServoLeft(left_speed);
  writeServoRight(right_speed);
}

void Right() {
  attachServos();
  double factor = 0.4 + (current_speed_index / 5.0) * 0.6;
  int left_speed = speed_stop + (speed_left_forward - speed_stop) * factor;
  int right_speed = speed_stop + (speed_right_backward - speed_stop) * factor;
  writeServoLeft(left_speed);
  writeServoRight(right_speed);
}

void Left() {
  attachServos();
  double factor = 0.4 + (current_speed_index / 5.0) * 0.6;
  int left_speed = speed_stop + (speed_left_backward - speed_stop) * factor;
  int right_speed = speed_stop + (speed_right_forward - speed_stop) * factor;
  writeServoLeft(left_speed);
  writeServoRight(right_speed);
}

void Stop() {
  attachServos();
  writeServoRight(speed_stop);
  writeServoLeft(speed_stop);
}

void Avoidance() {
  long dist = ultrasound_distance();
  if (dist > 0 && dist < ultrasound_threeshold) {
    if (avoidance_sound > 0) {
      sing(avoidance_sound);
    }
    Backward();
    delay(500);
    Stop();
    delay(100);
    Right();
    delay(500);
    Stop();
    delay(100);
  } else {
    Forward();
  }
}

void DifferentialTurnLeft() {
  attachServos();
  double factor = 0.4 + (current_speed_index / 5.0) * 0.6;
  int right_speed = speed_stop + (speed_right_forward - speed_stop) * factor;

  int left_speed;
  if (line_steer <= 50) {
    double inner_factor = factor * (1.0 - (line_steer / 50.0));
    left_speed = speed_stop + (speed_left_forward - speed_stop) * inner_factor;
  } else {
    double rev_factor = factor * ((line_steer - 50.0) / 50.0);
    left_speed = speed_stop + (speed_left_backward - speed_stop) * rev_factor;
  }

  writeServoLeft(left_speed);
  writeServoRight(right_speed);
}

void DifferentialTurnRight() {
  attachServos();
  double factor = 0.4 + (current_speed_index / 5.0) * 0.6;
  int left_speed = speed_stop + (speed_left_forward - speed_stop) * factor;

  int right_speed;
  if (line_steer <= 50) {
    double inner_factor = factor * (1.0 - (line_steer / 50.0));
    right_speed = speed_stop + (speed_right_forward - speed_stop) * inner_factor;
  } else {
    double rev_factor = factor * ((line_steer - 50.0) / 50.0);
    right_speed = speed_stop + (speed_right_backward - speed_stop) * rev_factor;
  }

  writeServoLeft(left_speed);
  writeServoRight(right_speed);
}

void LineFollower() {
#if defined(ARDUINO_ARCH_ESP32)
  rightValue = digitalRead(LINE_SENSOR_RIGHT);
  leftValue = digitalRead(LINE_SENSOR_LEFT);

  // Digital IR sensors: HIGH (1) when over black line, LOW (0) over white surface
  // Line runs IN BETWEEN sensors: both sensors read LOW (0,0) over white surface when moving forward
  if (leftValue == LOW && rightValue == LOW) {
    Forward();
  } else if (leftValue == HIGH && rightValue == LOW) {
    DifferentialTurnLeft();
  } else if (leftValue == LOW && rightValue == HIGH) {
    DifferentialTurnRight();
  } else if (leftValue == HIGH && rightValue == HIGH) {
    Stop();
  }
#else
  rightValue = analogRead(LINE_SENSOR_RIGHT);
  leftValue = analogRead(LINE_SENSOR_LEFT);

  if (rightValue > right_threeshold && leftValue > left_threeshold) {
    writeServoRight(speed_right_forward + 10);
    writeServoLeft(speed_left_forward - 10);
  } else if (leftValue > left_threeshold) {
    writeServoRight(speed_right_forward - 40);
    writeServoLeft(speed_left_forward - 40);
  } else if (rightValue > right_threeshold) {
    writeServoRight(speed_right_forward + 30);
    writeServoLeft(speed_left_forward + 30);
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