#include <Arduino.h>

constexpr uint8_t HALL_PIN = 34;      // Yellow wire here

constexpr unsigned long BASELINE_WINDOW_MS = 2000;  // auto-calibrate for first 2s
constexpr unsigned long OUTPUT_INTERVAL_MS = 300;   // slower output rate after calibration
constexpr int DEADZONE = 300;                        // +/- around baseline counts as "nothing"

constexpr uint8_t HISTORY_SIZE = 10;

enum State { NOTHING, NORTH, SOUTH };

int baseline = 0;
State history[HISTORY_SIZE];
uint8_t historyIndex = 0;
uint8_t historyCount = 0;

void setup() {
  Serial.begin(115200);
  analogReadResolution(12);

  Serial.println("Calibrating baseline, keep sensor clear...");

  long sum = 0;
  int samples = 0;
  unsigned long start = millis();

  while (millis() - start < BASELINE_WINDOW_MS) {
    sum += analogRead(HALL_PIN);
    samples++;
    delay(20);
  }

  baseline = sum / samples;
  Serial.printf("Baseline set: %d (from %d samples)\n", baseline, samples);
}

State classify(int value) {
  if (value > baseline + DEADZONE) return NORTH;
  if (value < baseline - DEADZONE) return SOUTH;
  return NOTHING;
}

State mostCommon() {
  int counts[3] = {0, 0, 0}; // NOTHING, NORTH, SOUTH
  for (uint8_t i = 0; i < historyCount; i++) {
    counts[history[i]]++;
  }
  uint8_t best = 0;
  for (uint8_t i = 1; i < 3; i++) {
    if (counts[i] > counts[best]) best = i;
  }
  return (State)best;
}

void loop() {
  int value = analogRead(HALL_PIN);
  State state = classify(value);

  history[historyIndex] = state;
  historyIndex = (historyIndex + 1) % HISTORY_SIZE;
  if (historyCount < HISTORY_SIZE) historyCount++;

  State result = mostCommon();

  const char* label = (result == NORTH) ? "NORTH" : (result == SOUTH) ? "SOUTH" : "NOTHING";
  Serial.printf("%s (raw=%d)\n", label, value);

  delay(OUTPUT_INTERVAL_MS);
}
