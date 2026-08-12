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
*    This Sketch was created to control Otto Starter with the Offical Web Bluetooth Controller for Otto DIY Robots.
*    For any question about this script you can contact us at education@ottodiy.com
*    By: Iván R. Artiles
*    v2 By: David Pront
*/

#include <Otto.h>
#include <EEPROM.h>

#define LEFTLEG 2
#define RIGHTLEG 3
#define LEFTFOOT 4
#define RIGHTFOOT 5
#define TRIG 8
#define ECHO 9
#define BLE_TX 11
#define BLE_RX 12
#define BUZZER 13

class BTInterface {
public:
  virtual void begin(const char* name) = 0;
  virtual bool available() = 0;
  virtual String readLine() = 0;
  virtual void write(const String& msg) = 0;
};

#if !defined(ARDUINO_ARCH_ESP32)

#include <SoftwareSerial.h>

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
  static BT_HM10 bt(BLE_TX, BLE_RX);
  bluetooth = &bt;
#endif

  bluetooth->begin("OttoClassic");
}

int move_speed[] = {3000, 2000, 1000, 750, 500, 250};
int n = 2;
int ultrasound_threeshold = 15;
int avoidance_sound = 0;
String command = "";

int v;
int ch;
int i;
int positions[] = {90, 90, 90, 90};
int8_t trims[4] = {0,0,0,0};
unsigned long sync_time = 0;

bool calibration = false;
  
Otto Ottobot;

long ultrasound_distance() {
   long duration, distance;
   digitalWrite(TRIG,LOW);
   delayMicroseconds(2);
   digitalWrite(TRIG, HIGH);
   delayMicroseconds(10);
   digitalWrite(TRIG, LOW);
   duration = pulseIn(ECHO, HIGH);
   distance = duration/58;
   return distance;
}

void setup() {
  Serial.begin(9600);
  Ottobot.init(LEFTLEG, RIGHTLEG, LEFTFOOT, RIGHTFOOT, true, BUZZER);

  /// ddp v2 - read eeprom for calibrations
  trims[0] = EEPROM.read(0); if (trims[0] > 128) trims[0] -= 256;
  trims[1] = EEPROM.read(1); if (trims[1] > 128) trims[1] -= 256;
  trims[2] = EEPROM.read(2); if (trims[2] > 128) trims[2] -= 256;
  trims[3] = EEPROM.read(3); if (trims[3] > 128) trims[3] -= 256;

  pinMode(TRIG, OUTPUT); 
  pinMode(ECHO, INPUT);

  setupBluetooth();
  
  forceHome();
  v = 0;
}

void loop() {
  checkBluetooth();//if something is coming at us
  if (command == "forward") {
    Forward();
  }
  else if (command == "backward") {
    Backward();
  }
  else if (command == "right") {
    Right();
  }
  else if (command == "left") {
    Left();
  }
  else if (command == "avoidance") {
    Avoidance();
  }
  else if (command == "force") {
    UseForce();
  }
}

void checkBluetooth() {
  if (!bluetooth->available()) return;

  String cmd = bluetooth->readLine();
  cmd.trim();

  char charBuffer[40];
  cmd.toCharArray(charBuffer, 40);

  Serial.print("Received: ");
  Serial.println(charBuffer);
  
  int numberOfBytesReceived = strlen(charBuffer);
  if (numberOfBytesReceived > 0) {
    n = charBuffer[numberOfBytesReceived-1]-'0';
    
    if (strstr(charBuffer, "forward") == &charBuffer[0]) {
      command = "forward";
    }   
    else if (strstr(charBuffer, "backward") == &charBuffer[0]) {
      command = "backward";
    }
    else if (strstr(charBuffer, "right") == &charBuffer[0]) {
      command = "right";
    }
    else if (strstr(charBuffer, "left") == &charBuffer[0]) {
      command = "left";
    }
    else if (strstr(charBuffer, "stop") == &charBuffer[0]) {
      command = "stop";
      Stop();
    }
    else if (strstr(charBuffer, "ultrasound") == &charBuffer[0]) {
      Stop();
      bluetooth->write(String(ultrasound_distance()));
    }
    else if (strstr(charBuffer, "avoidance_dist") == &charBuffer[0] || strstr(charBuffer, "avoid_dist") == &charBuffer[0]) {
      char *p = charBuffer;
      while (*p && (*p < '0' || *p > '9')) p++;
      if (*p) {
        int dist = atoi(p);
        if (dist >= 5 && dist <= 100) {
          ultrasound_threeshold = dist;
          Serial.print("Updated avoidance threshold: ");
          Serial.println(ultrasound_threeshold);
        }
      }
    }
    else if (strstr(charBuffer, "avoidance_sound") == &charBuffer[0] || strstr(charBuffer, "avoid_sound") == &charBuffer[0]) {
      char *p = charBuffer;
      while (*p && (*p < '0' || *p > '9')) p++;
      if (*p) {
        avoidance_sound = atoi(p);
        Serial.print("Updated avoidance sound: ");
        Serial.println(avoidance_sound);
      }
    }
    else if (strstr(charBuffer, "avoidance") == &charBuffer[0]) {
      command = "avoidance";
    }
    else if (strstr(charBuffer, "force") == &charBuffer[0]) {
      command = "force";
    }
    else if (strstr(charBuffer, "happy") == &charBuffer[0]) {
      command = "";
      Ottobot.playGesture(OttoSuperHappy);
    }
    else if (strstr(charBuffer, "victory") == &charBuffer[0]) {
      command = "";
      Ottobot.playGesture(OttoVictory);
    }
    else if (strstr(charBuffer, "sad") == &charBuffer[0]) {
      command = "";
      Ottobot.playGesture(OttoSad);
    }
    else if (strstr(charBuffer, "sleeping") == &charBuffer[0]) {
      command = "";
      Ottobot.playGesture(OttoSleeping);
    }
    else if (strstr(charBuffer, "confused") == &charBuffer[0]) {
      command = "";
      Ottobot.playGesture(OttoConfused);
    }
    else if (strstr(charBuffer, "fail") == &charBuffer[0]) {
      command = "";
      Ottobot.playGesture(OttoFail);
    }
    else if (strstr(charBuffer, "fart") == &charBuffer[0]) {
      command = "";
      Ottobot.playGesture(OttoFart);
    }
    else if (strstr(charBuffer, "love") == &charBuffer[0]) {
      command = "";
      Ottobot.playGesture(OttoLove);
    }
    else if (strstr(charBuffer, "fretful") == &charBuffer[0]) {
      command = "";
      Ottobot.playGesture(OttoFretful);
    }
    else if (strstr(charBuffer, "magic") == &charBuffer[0]) {
      command = "";
      Ottobot.playGesture(OttoMagic);
    }
    else if (strstr(charBuffer, "C") == &charBuffer[0]) {
      
      if (calibration == false) {
        Ottobot._moveServos(10, positions);
        calibration = true;
        delay(50);
      } 
      command = "calibration";
      Calibration(charBuffer);
    }
    else if (strstr(charBuffer, "walk_test") == &charBuffer[0]) {
      command = "";
      Ottobot.walk(3, 1000, FORWARD);
    }
    else if (strstr(charBuffer, "sing") == &charBuffer[0]) {
      command = "";
      char *p = charBuffer + 4;
      while (*p && (*p < '0' || *p > '9')) {
        p++;
      }
      int songName = atoi(p);
      Ottobot.sing(songName);
    }
    else if (strstr(charBuffer, "save_calibration") == &charBuffer[0]) {
      command = "";
      readChar('s');
    }
  }
}

void Forward() {
  Ottobot.walk(1, move_speed[n], FORWARD);
}

void Backward() {
  Ottobot.walk(1, move_speed[n], BACKWARD);
}

void Right() {
  Ottobot.walk(1, move_speed[n], RIGHT);
}

void Left() {
  Ottobot.walk(1, move_speed[n], LEFT);
}

void Stop() {
  forceHome();
  //Ottobot.home();
}

void Avoidance() {
  long dist = ultrasound_distance();
  if (dist > 0 && dist <= ultrasound_threeshold) {
    if (avoidance_sound > 0) {
      Ottobot.sing(avoidance_sound);
    } else {
      Ottobot.playGesture(OttoConfused);
    }
    for (int count=0 ; count<2 ; count++) {
      Ottobot.walk(1, move_speed[n], -1); // BACKWARD
    }
    for (int count=0 ; count<4 ; count++) {
      Ottobot.turn(1, move_speed[n], 1); // LEFT
    }
  } else {
    Ottobot.walk(1, move_speed[n], 1); // FORWARD
  }
}

void UseForce() {
  if (ultrasound_distance() <= ultrasound_threeshold) {
      Ottobot.walk(1,move_speed[n],-1); // BACKWARD
    }
    if ((ultrasound_distance() > 10) && ( ultrasound_distance() < 15)) {
      forceHome();
    }
    if ((ultrasound_distance() > 15) && ( ultrasound_distance() < 30)) {
      Ottobot.walk(1,move_speed[n],1); // FORWARD
    }
    if (ultrasound_distance() > 30) {
      forceHome();
    }  
}

void Settings(String ts_ultrasound) {
  ultrasound_threeshold = ts_ultrasound.toInt();
}

void Calibration(String c) {
  if (sync_time < millis()) {
      sync_time = millis() + 50;
      for (int k = 1; k < c.length(); k++) {
        readChar((c[k]));
      }
  } 
}

void readChar(char ch) {
  switch (ch) {
  case '0'...'9':
    v = (v * 10 + ch) - 48;
    break;
   case 'a':
    trims[0] = v-90;
    setTrims();
    v = 0;
    break;
   case 'b':
    trims[1] = v-90;
    setTrims();
    v = 0;
    break;
   case 'c':
    trims[2] = v-90;
    setTrims();
    v = 0;
    break;
   case 'd':
    trims[3] = v-90;
    setTrims();
    v = 0;
    break;
   case 's':
    for (i=0 ; i<=3 ; i=i+1) {
      EEPROM.write(i,trims[i]);
    }
    delay(500);
    Ottobot.sing(S_superHappy);
    Ottobot.crusaito(1, 1000, 25, -1);
    Ottobot.crusaito(1, 1000, 25, 1);
    Ottobot.sing(S_happy_short);
    break;
  }
}

// void setTrims() {
//   Ottobot.setTrims(trims[0],trims[1],trims[2],trims[3]);
//   Ottobot._moveServos(10, positions); 
// }

///
/// ddp v2 setTrims
///
void setTrims() {
  Ottobot.setTrims(trims[0],trims[1],trims[2],trims[3]);
  Ottobot._moveServos(500, positions); 
  Ottobot.detachServos();
}

/// 
/// ddp v2 forceHome
///
void forceHome() {
  int dummyPos[4] = {90, 90, 90, 90};
  
  // Force library out of rest state 
  Ottobot._moveServos(10, dummyPos);

  // Move home  
  Ottobot.home();
}
