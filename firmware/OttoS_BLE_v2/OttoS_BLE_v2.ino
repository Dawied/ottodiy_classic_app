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

#include <EEPROM.h>

#ifdef ARDUINO_ARCH_ESP32
  #include <ESP32Servo.h>
#else
  #include <Servo.h>
#endif

// Directions
#ifndef FORWARD
#define FORWARD 1
#define BACKWARD -1
#define LEFT 1
#define RIGHT -1
#endif

// Gestures
#define OttoHappy 1
#define OttoSuperHappy 2
#define OttoSad 3
#define OttoVictory 4
#define OttoSleeping 5
#define OttoConfused 6
#define OttoFail 7
#define OttoFart 8
#define OttoLove 9
#define OttoFretful 10
#define OttoMagic 11
#define OttoWave 12

// Sounds
#define S_connection 0
#define S_disconnection 1
#define S_buttonPushed 2
#define S_mode1 3
#define S_mode2 4
#define S_mode3 5
#define S_surprise 6
#define S_OhOoh 7
#define S_OhOoh2 8
#define S_cuddly 9
#define S_sleeping 10
#define S_happy 11
#define S_superHappy 12
#define S_happy_short 13
#define S_sad 14
#define S_confused 15
#define S_fart 16

// Musical Notes
#define note_C4 262
#define note_D4 294
#define note_E4 330
#define note_F4 349
#define note_G4 392
#define note_A4 440
#define note_B4 494
#define note_C5 523
#define note_D5 587
#define note_E5 659
#define note_F5 698
#define note_G5 784
#define note_A5 880
#define note_B5 988
#define note_C6 1047
#define note_D6 1175
#define note_E6 1319
#define note_F6 1397
#define note_G6 1568
#define note_A6 1760
#define note_B6 1976

class Oscillator {
private:
  Servo _servo;
  int _position;
  int _target;
  int _origin;
  int _previous;
  int _diff;
  int _inc;
  double _period;
  double _amplitude;
  double _phase;
  double _offset;
  double _trim;
  double _number_cycles;
  double _time_previous;
  double _time_current;
  bool _stop;
  bool _is_attached;

public:
  Oscillator() {
    _position = 90;
    _target = 90;
    _origin = 90;
    _previous = 90;
    _diff = 0;
    _inc = 0;
    _period = 2000;
    _amplitude = 45;
    _phase = 0;
    _offset = 0;
    _trim = 0;
    _number_cycles = 0;
    _time_previous = 0;
    _time_current = 0;
    _stop = true;
    _is_attached = false;
  }

  void attach(int pin) {
    if (!_is_attached) {
      _servo.attach(pin);
      _is_attached = true;
    }
  }

  void detach() {
    if (_is_attached) {
      _servo.detach();
      _is_attached = false;
    }
  }

  void SetPeriod(int period) { _period = period; }
  void SetAmplitude(int amplitude) { _amplitude = amplitude; }
  void SetPhase(int phase) { _phase = phase; }
  void SetOffset(int offset) { _offset = offset; }
  void SetTrim(int trim) { _trim = trim; }

  void SetPosition(int position) {
    _position = position;
    if (_is_attached) {
      _servo.write(_position + _trim);
    }
  }

  int getPosition() { return _position; }
  int getTrim() { return _trim; }

  void refresh() {
    if (!_stop) {
      _time_current = millis();
      if (_time_current - _time_previous >= _inc) {
        _time_previous = _time_current;
        _position = _origin + _amplitude * sin(2 * PI * (_time_current / _period) + _phase * PI / 180) + _offset;
        if (_is_attached) {
          _servo.write(_position + _trim);
        }
      }
    }
  }

  void stop() { _stop = true; }
  void start() { _stop = false; _time_previous = millis(); }
  void reset() { _time_previous = millis(); }
};

class Otto {
private:
  Oscillator osc[4];
  int servo_pins[4];
  int servo_trim[4];
  int pinBuzzer;
  unsigned long final_time;
  unsigned long partial_time;
  float increment[4];

  void _tone(float noteFrequency, long noteDuration, int silentDuration = 0) {
    if (pinBuzzer >= 0) {
      if (noteFrequency > 0) {
        tone(pinBuzzer, (unsigned int)noteFrequency, noteDuration);
      }
      delay(noteDuration);
      if (silentDuration > 0) {
        delay(silentDuration);
      }
    }
  }

public:
  Otto() {
    pinBuzzer = -1;
    for (int i = 0; i < 4; i++) {
      servo_trim[i] = 0;
      servo_pins[i] = -1;
    }
  }

  void init(int YL, int YR, int RL, int RR, bool load_calibration, int NoiseSensor, int Buzzer, int USTrigger, int USEcho) {
    servo_pins[0] = YL;
    servo_pins[1] = YR;
    servo_pins[2] = RL;
    servo_pins[3] = RR;
    pinBuzzer = Buzzer;

    if (pinBuzzer >= 0) {
      pinMode(pinBuzzer, OUTPUT);
    }

    attachServos();

    if (load_calibration) {
      for (int i = 0; i < 4; i++) {
        int8_t val = EEPROM.read(i);
        if (val > 128) val -= 256;
        servo_trim[i] = val;
      }
    }

    for (int i = 0; i < 4; i++) {
      osc[i].SetTrim(servo_trim[i]);
    }
    home();
  }

  void init(int YL, int YR, int RL, int RR, bool load_calibration = true, int Buzzer = -1) {
    init(YL, YR, RL, RR, load_calibration, -1, Buzzer, -1, -1);
  }

  void attachServos() {
    for (int i = 0; i < 4; i++) {
      if (servo_pins[i] >= 0) {
        osc[i].attach(servo_pins[i]);
      }
    }
  }

  void detachServos() {
    for (int i = 0; i < 4; i++) {
      osc[i].detach();
    }
  }

  void setTrims(int YL, int YR, int RL, int RR) {
    servo_trim[0] = YL;
    servo_trim[1] = YR;
    servo_trim[2] = RL;
    servo_trim[3] = RR;
    for (int i = 0; i < 4; i++) {
      osc[i].SetTrim(servo_trim[i]);
    }
  }

  void _moveServos(int time, int servo_target[]) {
    attachServos();
    if (time < 10) time = 10;
    for (int i = 0; i < 4; i++) {
      increment[i] = ((float)servo_target[i] - osc[i].getPosition()) / (time / 10.0);
    }
    final_time = millis() + time;
    while (millis() < final_time) {
      partial_time = millis() + 10;
      for (int i = 0; i < 4; i++) {
        osc[i].SetPosition(osc[i].getPosition() + increment[i]);
      }
      while (millis() < partial_time) {
        // Wait 10ms step
      }
    }
    for (int i = 0; i < 4; i++) {
      osc[i].SetPosition(servo_target[i]);
    }
  }

  void home() {
    int homes[4] = {90, 90, 90, 90};
    _moveServos(500, homes);
  }

  void oscillateServos(int A[4], int O[4], int T, double phase_diff[4], float cycle = 1) {
    for (int i = 0; i < 4; i++) {
      osc[i].SetAmplitude(A[i]);
      osc[i].SetOffset(O[i]);
      osc[i].SetPeriod(T);
      osc[i].SetPhase(phase_diff[i]);
      osc[i].start();
    }

    final_time = millis() + T * cycle;
    while (millis() < final_time) {
      for (int i = 0; i < 4; i++) {
        osc[i].refresh();
      }
    }
  }

  void walk(float steps = 1, int T = 1000, int dir = FORWARD) {
    int A[4] = {30, 30, 20, 20};
    int O[4] = {0, 0, 0, 0};
    double phase_diff[4] = {0, 0, 90 * dir, 90 * dir};
    for (int i = 0; i < steps; i++) {
      oscillateServos(A, O, T, phase_diff, 1);
    }
  }

  void turn(float steps = 1, int T = 1000, int dir = LEFT) {
    int A[4] = {30, 30, 20, 20};
    int O[4] = {0, 0, 0, 0};
    double phase_diff[4] = {0, 0, 90 * dir, -90 * dir};
    for (int i = 0; i < steps; i++) {
      oscillateServos(A, O, T, phase_diff, 1);
    }
  }

  void bend(int steps = 1, int T = 1400, int dir = LEFT) {
    int bend1[4] = {90, 90, 62, 35};
    int bend2[4] = {90, 90, 62, 105};
    int homes[4] = {90, 90, 90, 90};
    for (int i = 0; i < steps; i++) {
      if (dir == LEFT) {
        _moveServos(T / 2, bend1);
        _moveServos(T / 2, homes);
      } else {
        _moveServos(T / 2, bend2);
        _moveServos(T / 2, homes);
      }
    }
  }

  void shakeLeg(int steps = 1, int T = 2000, int dir = LEFT) {
    int shake1[4] = {90, 90, 58, 35};
    int shake2[4] = {90, 90, 58, 120};
    int homes[4] = {90, 90, 90, 90};
    for (int i = 0; i < steps; i++) {
      if (dir == LEFT) {
        _moveServos(T / 4, shake1);
        _moveServos(T / 4, shake2);
        _moveServos(T / 4, shake1);
        _moveServos(T / 4, homes);
      } else {
        _moveServos(T / 4, shake2);
        _moveServos(T / 4, shake1);
        _moveServos(T / 4, shake2);
        _moveServos(T / 4, homes);
      }
    }
  }

  void crusaito(float steps = 1, int T = 1000, int h = 25, int dir = FORWARD) {
    int A[4] = {25, 25, h, h};
    int O[4] = {0, 0, 0, 0};
    double phase_diff[4] = {90, 90, 90 * dir, 90 * dir};
    for (int i = 0; i < steps; i++) {
      oscillateServos(A, O, T, phase_diff, 1);
    }
  }

  void moonwalker(float steps = 1, int T = 1000, int h = 25, int dir = LEFT) {
    int A[4] = {0, 0, h, h};
    int O[4] = {0, 0, 0, 0};
    double phase_diff[4] = {0, 0, 90 * dir, 90 * dir};
    for (int i = 0; i < steps; i++) {
      oscillateServos(A, O, T, phase_diff, 1);
    }
  }

  void flapping(float steps = 1, int T = 1000, int h = 25, int dir = FORWARD) {
    int A[4] = {12, 12, h, h};
    int O[4] = {0, 0, 0, 0};
    double phase_diff[4] = {-90 * dir, 90 * dir, -90 * dir, 90 * dir};
    for (int i = 0; i < steps; i++) {
      oscillateServos(A, O, T, phase_diff, 1);
    }
  }

  void swing(float steps = 1, int T = 1000, int h = 25) {
    int A[4] = {25, 25, 0, 0};
    int O[4] = {0, 0, 0, 0};
    double phase_diff[4] = {0, 0, 0, 0};
    for (int i = 0; i < steps; i++) {
      oscillateServos(A, O, T, phase_diff, 1);
    }
  }

  void tiptoeWaist(float steps = 1, int T = 1000, int h = 25) {
    int A[4] = {25, 25, h, h};
    int O[4] = {0, 0, 0, 0};
    double phase_diff[4] = {0, 0, 90, -90};
    for (int i = 0; i < steps; i++) {
      oscillateServos(A, O, T, phase_diff, 1);
    }
  }

  void jitter(float steps = 1, int T = 500, int h = 25) {
    int A[4] = {h, h, 0, 0};
    int O[4] = {0, 0, 0, 0};
    double phase_diff[4] = {0, 0, 0, 0};
    for (int i = 0; i < steps; i++) {
      oscillateServos(A, O, T, phase_diff, 1);
    }
  }

  void updown(float steps = 1, int T = 1000, int h = 25) {
    int A[4] = {0, 0, h, h};
    int O[4] = {0, 0, 0, 0};
    double phase_diff[4] = {0, 0, -90, 90};
    for (int i = 0; i < steps; i++) {
      oscillateServos(A, O, T, phase_diff, 1);
    }
  }

  void ascendingWeek(float steps = 1, int T = 1000, int h = 25) {
    int A[4] = {h, h, h, h};
    int O[4] = {0, 0, 0, 0};
    double phase_diff[4] = {0, 0, 90, 90};
    for (int i = 0; i < steps; i++) {
      oscillateServos(A, O, T, phase_diff, 1);
    }
  }

  void sing(int songName) {
    switch (songName) {
      case S_connection:
        _tone(note_E5, 80, 30);
        _tone(note_A5, 80, 30);
        _tone(note_E6, 80, 30);
        break;
      case S_disconnection:
        _tone(note_E6, 80, 30);
        _tone(note_A5, 80, 30);
        _tone(note_E5, 80, 30);
        break;
      case S_buttonPushed:
        _tone(note_C6, 50, 20);
        _tone(note_D6, 50, 20);
        break;
      case S_mode1:
        _tone(note_E6, 50, 30);
        _tone(note_G6, 50, 30);
        break;
      case S_mode2:
        _tone(note_G6, 50, 30);
        _tone(note_E6, 50, 30);
        break;
      case S_mode3:
        _tone(note_E6, 50, 30);
        _tone(note_E6, 50, 30);
        break;
      case S_surprise:
        _tone(note_C6, 100, 10);
        _tone(note_G6, 200, 10);
        break;
      case S_OhOoh:
      case S_OhOoh2:
        _tone(note_C6, 200, 50);
        _tone(note_G5, 400, 50);
        break;
      case S_cuddly:
        _tone(note_A5, 100, 20);
        _tone(note_C6, 100, 20);
        _tone(note_E6, 200, 20);
        break;
      case S_sleeping:
        _tone(note_E5, 300, 100);
        _tone(note_C5, 400, 100);
        break;
      case S_happy:
      case S_superHappy:
        _tone(note_E5, 80, 20);
        _tone(note_G5, 80, 20);
        _tone(note_C6, 120, 20);
        break;
      case S_happy_short:
        _tone(note_C6, 60, 10);
        _tone(note_G6, 60, 10);
        break;
      case S_sad:
        _tone(note_G5, 200, 50);
        _tone(note_E5, 400, 50);
        break;
      case S_confused:
        _tone(note_D5, 100, 30);
        _tone(note_E5, 100, 30);
        _tone(note_D5, 100, 30);
        break;
      case S_fart:
        _tone(note_C4, 150, 10);
        _tone(note_C4 / 2, 250, 10);
        break;
      default:
        break;
    }
  }

  void playGesture(int gesture) {
    switch (gesture) {
      case OttoHappy:
        sing(S_happy);
        home();
        break;
      case OttoSuperHappy:
        sing(S_superHappy);
        bend(2, 800, LEFT);
        home();
        break;
      case OttoSad:
        sing(S_sad);
        bend(1, 1400, RIGHT);
        home();
        break;
      case OttoVictory:
        sing(S_mode1);
        shakeLeg(1, 1500, LEFT);
        home();
        break;
      case OttoSleeping:
        sing(S_sleeping);
        bend(1, 2000, LEFT);
        home();
        break;
      case OttoConfused:
        sing(S_confused);
        bend(1, 1000, LEFT);
        home();
        break;
      case OttoFail:
        sing(S_sad);
        bend(1, 1500, LEFT);
        home();
        break;
      case OttoFart:
        sing(S_fart);
        shakeLeg(1, 1000, RIGHT);
        home();
        break;
      case OttoLove:
        sing(S_cuddly);
        bend(1, 1200, LEFT);
        home();
        break;
      case OttoFretful:
        sing(S_confused);
        shakeLeg(1, 800, LEFT);
        home();
        break;
      case OttoMagic:
        sing(S_surprise);
        bend(2, 1000, RIGHT);
        home();
        break;
      case OttoWave:
        shakeLeg(2, 1000, LEFT);
        home();
        break;
      default:
        break;
    }
  }
};

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
