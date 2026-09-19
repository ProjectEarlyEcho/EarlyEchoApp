#include <ESP_I2S.h>
#include <WebSocketsServer.h>
#include <WiFi.h>
#include <freertos/stream_buffer.h>

#include "arduino_secrets.h"

constexpr uint8_t PIN_BCLK = 4;
constexpr uint8_t PIN_LRC = 5;
constexpr uint8_t PIN_DOUT = 6;
constexpr uint16_t WEBSOCKET_PORT = 81;

// Gemini Live audio output is raw little-endian PCM16, mono, at 24 kHz.
constexpr uint32_t SAMPLE_RATE = 24000;
constexpr size_t BYTES_PER_SAMPLE = sizeof(int16_t);
constexpr size_t BYTES_PER_SECOND = SAMPLE_RATE * BYTES_PER_SAMPLE;
constexpr size_t PRIME_BYTES = (BYTES_PER_SECOND * 4) / 5;  // 800 ms
constexpr size_t STREAM_BUFFER_BYTES = 65536;

I2SClass i2s;
WebSocketsServer ws(WEBSOCKET_PORT);
StreamBufferHandle_t streamBuffer = nullptr;

volatile bool flushRequested = false;
volatile bool endOfTurnRequested = false;
volatile uint32_t acceptedBytes = 0;
volatile uint32_t droppedBytes = 0;
volatile uint32_t underrunCount = 0;
volatile uint32_t flushCount = 0;
volatile uint32_t shortWriteCount = 0;

void writeI2sFully(const int16_t* samples, size_t byteCount) {
  const uint8_t* bytes = reinterpret_cast<const uint8_t*>(samples);
  size_t offset = 0;
  uint8_t zeroWriteRetries = 0;
  while (offset < byteCount) {
    const size_t written = i2s.write(bytes + offset, byteCount - offset);
    if (written == 0) {
      ++shortWriteCount;
      if (++zeroWriteRetries >= 4) return;
      vTaskDelay(1);
      continue;
    }
    if (written < byteCount - offset) ++shortWriteCount;
    zeroWriteRetries = 0;
    offset += written;
  }
}

void onWebSocketEvent(uint8_t client, WStype_t type, uint8_t* payload,
                      size_t length) {
  if (type == WStype_BIN) {
    // A PCM16 frame must always contain complete two-byte samples.
    length &= ~static_cast<size_t>(1);
    if (length == 0 || streamBuffer == nullptr) return;

    const size_t sent = xStreamBufferSend(streamBuffer, payload, length, 0);
    acceptedBytes += sent;
    droppedBytes += length - sent;
    return;
  }

  if (type == WStype_TEXT && length == 5 &&
      memcmp(payload, "flush", 5) == 0) {
    flushRequested = true;
    ++flushCount;
    return;
  }

  if (type == WStype_TEXT && length == 3 &&
      memcmp(payload, "end", 3) == 0) {
    endOfTurnRequested = true;
    return;
  }

  if (type == WStype_DISCONNECTED) {
    flushRequested = true;
    Serial.printf("WebSocket client %u disconnected\n", client);
  } else if (type == WStype_CONNECTED) {
    Serial.printf("WebSocket client %u connected\n", client);
  }
}

void audioTask(void*) {
  // Static storage keeps the 3.8 kB of audio blocks off the FreeRTOS task
  // stack, avoiding stack corruption on a 4 kB task.
  static int16_t mono[480];            // 20 ms at 24 kHz
  static int16_t stereo[960];          // explicit [left, right] frames
  static int16_t silence[480] = {0};  // 10 ms of stereo silence
  bool primed = false;

  for (;;) {
    if (flushRequested) {
      while (xStreamBufferReceive(streamBuffer, mono, sizeof(mono), 0) > 0) {
      }
      primed = false;
      endOfTurnRequested = false;
      flushRequested = false;
    }

    const size_t available = xStreamBufferBytesAvailable(streamBuffer);
    if (!primed &&
        (available >= PRIME_BYTES ||
         (endOfTurnRequested && available > 0))) {
      primed = true;
    }

    if (!primed) {
      if (endOfTurnRequested && available == 0) endOfTurnRequested = false;
      writeI2sFully(silence, sizeof(silence));
      continue;
    }

    if (endOfTurnRequested && available == 0) {
      primed = false;
      endOfTurnRequested = false;
      writeI2sFully(silence, sizeof(silence));
      continue;
    }

    size_t received = xStreamBufferReceive(
        streamBuffer, mono, sizeof(mono), pdMS_TO_TICKS(30));
    received &= ~static_cast<size_t>(1);
    if (received == 0) {
      ++underrunCount;
      // Stay primed during an active turn. Returning to the startup threshold
      // here strands short late packets and creates repeated audible gaps.
      writeI2sFully(silence, sizeof(silence));
      continue;
    }

    const size_t samples = received / sizeof(int16_t);
    for (size_t index = 0; index < samples; ++index) {
      stereo[index * 2] = mono[index];
      stereo[index * 2 + 1] = mono[index];
    }
    const size_t outputBytes = samples * 2 * sizeof(int16_t);
    writeI2sFully(stereo, outputBytes);
  }
}

void setup() {
  Serial.begin(115200);
  Serial.println("Starting ESP32-S3 Gemini audio speaker");

  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);
  WiFi.begin(SECRET_WIFI_SSID, SECRET_WIFI_PASS);
  while (WiFi.status() != WL_CONNECTED) {
    delay(200);
  }
  Serial.print("WebSocket URL: ws://");
  Serial.print(WiFi.localIP());
  Serial.printf(":%u\n", WEBSOCKET_PORT);

  i2s.setPins(PIN_BCLK, PIN_LRC, PIN_DOUT);
  if (!i2s.begin(I2S_MODE_STD, SAMPLE_RATE, I2S_DATA_BIT_WIDTH_16BIT,
                 I2S_SLOT_MODE_STEREO)) {
    Serial.println("I2S initialization failed");
    while (true) delay(1000);
  }

  streamBuffer = xStreamBufferCreate(STREAM_BUFFER_BYTES, 1);
  if (streamBuffer == nullptr) {
    Serial.println("Audio stream-buffer allocation failed");
    while (true) delay(1000);
  }

  xTaskCreatePinnedToCore(audioTask, "audio", 4096, nullptr, 3, nullptr, 1);
  ws.begin();
  ws.onEvent(onWebSocketEvent);
}

void loop() {
  ws.loop();

  static uint32_t lastReportMs = 0;
  if (millis() - lastReportMs >= 1000) {
    lastReportMs = millis();
    const uint32_t accepted = acceptedBytes;
    const uint32_t dropped = droppedBytes;
    acceptedBytes = 0;
    droppedBytes = 0;
    Serial.printf(
        "accepted=%lu B/s buffered=%u dropped=%lu underruns=%lu "
        "flushes=%lu shortWrites=%lu\n",
        static_cast<unsigned long>(accepted),
        static_cast<unsigned>(xStreamBufferBytesAvailable(streamBuffer)),
        static_cast<unsigned long>(dropped),
        static_cast<unsigned long>(underrunCount),
        static_cast<unsigned long>(flushCount),
        static_cast<unsigned long>(shortWriteCount));
  }

  delay(1);
}
