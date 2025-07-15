#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <Arduino.h>
#include <math.h> // fmod, fmax, fmin ve sin için gerekli

// ----- KARAKTERİSTİK UUID'LERİ (FLUTTER İLE AYNI OLMALI) -----
#define DEVICE_NAME "ESP32_Graph_Tester"
#define SERVICE_UUID           "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define TIMESERIES_CHAR_UUID_1 "c1d2e3f4-a5b6-c7d8-e9f0-a1b2c3d4e5f6" // Grafik 1 için mevcut UUID
#define TIMESERIES_CHAR_UUID_2 "e6a7b8c9-d0e1-f2a3-b4c5-d6e7f8a9b0c1" // Grafik 2 için YENİ UUID

// YENİ UUID'LERİ BURAYA EKLE
#define TIMESERIES_CHAR_UUID_3 "b2f6d0f4-5f80-4a11-b0e5-7b5e43a9f5d3" // Grafik 3 için YENİ UUID
#define TIMESERIES_CHAR_UUID_4 "5e1a7b8c-2d1f-4e0c-9a3d-6c8f4b0e9a72" // Grafik 4 için YENİ UUID

// Karakteristik nesneleri
BLECharacteristic *pTimeSeriesCharacteristic1; // Grafik 1
BLECharacteristic *pTimeSeriesCharacteristic2; // Grafik 2
BLECharacteristic *pTimeSeriesCharacteristic3; // Grafik 3 için YENİ
BLECharacteristic *pTimeSeriesCharacteristic4; // Grafik 4 için YENİ

bool deviceConnected = false;
unsigned long lastDataSendTime = 0;
const int dataSendInterval = 100; // Flutter'daki _dataPointIntervalMs ile aynı olmalı (10ms)

// Grafiğin zamanlamasını başlatmak için bağlantı anını kaydeden değişken
unsigned long graphStartTimeMillis = 0;

// Grafik 1 için parametreler (Mevcut tester sinyali)
const float minValue1 = 1.0;
const float maxValue1 = 5.0;
const float riseTime1 = 4.0;
const float fallTime1 = 4.0;
const float totalCycleTime1 = riseTime1 + fallTime1;

// Grafik 2 için parametreler (Mevcut farklı tester sinyali)
const float minValue2 = 1.0; // Farklı bir min değer
const float maxValue2 = 5.0; // Farklı bir max değer
const float riseTime2 = 4.0; // Daha hızlı yükselme
const float fallTime2 = 4.0; // Daha yavaş düşme
const float totalCycleTime2 = riseTime2 + fallTime2;

// YENİ: Grafik 3 için parametreler (Sinüs dalgası)
const float minValue3 = 1.0; // Farklı bir min değer
const float maxValue3 = 5.0; // Farklı bir max değer
const float riseTime3 = 4.0; // Daha hızlı yükselme
const float fallTime3 = 4.0; // Daha yavaş düşme
const float totalCycleTime3 = riseTime3 + fallTime3;

// YENİ: Grafik 4 için parametreler (Kare dalga)
const float minValue4 = 1.0; // Farklı bir min değer
const float maxValue4 = 5.0; // Farklı bir max değer
const float riseTime4 = 4.0; // Daha hızlı yükselme
const float fallTime4 = 4.0; // Daha yavaş düşme
const float totalCycleTime4 = riseTime4 + fallTime4;

// Sunucu bağlantı callback'i
class ServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
        deviceConnected = true;
        // Cihaz bağlandığında grafiğin mutlak zamanını başlat
        graphStartTimeMillis = millis();
        Serial.println("Cihaz baglandi. Veri akisi basliyor...");
    }
    void onDisconnect(BLEServer* pServer) {
        deviceConnected = false;
        Serial.println("Cihaz baglantisi koptu.");
        BLEDevice::startAdvertising(); // Yeniden reklam yayınlamaya başla
    }
};

void setup() {
    Serial.begin(115200);
    Serial.println("Basit Grafik Veri Gonderici Baslatiliyor...");

    BLEDevice::init(DEVICE_NAME);
    BLEServer *pServer = BLEDevice::createServer();
    pServer->setCallbacks(new ServerCallbacks());
    BLEService *pService = pServer->createService(SERVICE_UUID);

    // Grafik 1 Karakteristiği (Mevcut)
    pTimeSeriesCharacteristic1 = pService->createCharacteristic(
        TIMESERIES_CHAR_UUID_1,
        BLECharacteristic::PROPERTY_NOTIFY
    );
    pTimeSeriesCharacteristic1->addDescriptor(new BLE2902());

    // Grafik 2 Karakteristiği (Mevcut)
    pTimeSeriesCharacteristic2 = pService->createCharacteristic(
        TIMESERIES_CHAR_UUID_2,
        BLECharacteristic::PROPERTY_NOTIFY
    );
    pTimeSeriesCharacteristic2->addDescriptor(new BLE2902());

    // YENİ: Grafik 3 Karakteristiği (Sinüs dalgası için)
    pTimeSeriesCharacteristic3 = pService->createCharacteristic(
        TIMESERIES_CHAR_UUID_3,
        BLECharacteristic::PROPERTY_NOTIFY
    );
    pTimeSeriesCharacteristic3->addDescriptor(new BLE2902());

    // YENİ: Grafik 4 Karakteristiği (Kare dalga için)
    pTimeSeriesCharacteristic4 = pService->createCharacteristic(
        TIMESERIES_CHAR_UUID_4,
        BLECharacteristic::PROPERTY_NOTIFY
    );
    pTimeSeriesCharacteristic4->addDescriptor(new BLE2902());

    pService->start();
    BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->start();

    Serial.println("Cihaz reklam yayini yapiyor. Baglanti bekleniyor...");
}

void loop() {
    if (deviceConnected) {
        unsigned long currentTime = millis();

        if (currentTime - lastDataSendTime >= dataSendInterval) {
            lastDataSendTime = currentTime;

            // Bağlantı başlangıcından bu yana geçen süreyi hesapla (saniye cinsinden)
            float elapsedTotalTime = (float)(currentTime - graphStartTimeMillis) / 1000.0f;

            // --- Grafik 1 için değer hesaplama (Mevcut mantık) ---
            float timeInCycle1 = fmod(elapsedTotalTime, totalCycleTime1);
            float currentValue1;

            if (timeInCycle1 < riseTime1) {
                currentValue1 = minValue1 + timeInCycle1;
            } else {
                float timeInFallingPhase1 = timeInCycle1 - riseTime1;
                currentValue1 = maxValue1 - timeInFallingPhase1;
            }
            currentValue1 = fmax(minValue1, fmin(maxValue1, currentValue1));
            pTimeSeriesCharacteristic1->setValue((uint8_t*)&currentValue1, sizeof(currentValue1));
            pTimeSeriesCharacteristic1->notify();

            // --- Grafik 2 için değer hesaplama (Mevcut, farklı bir sinyal) ---
            float timeInCycle2 = fmod(elapsedTotalTime, totalCycleTime2);
            float currentValue2;

            if (timeInCycle2 < riseTime2) {
                currentValue2 = minValue2 + (timeInCycle2 / riseTime2) * (maxValue2 - minValue2);
            } else {
                float timeInFallingPhase2 = timeInCycle2 - riseTime2;
                currentValue2 = maxValue2 - (timeInFallingPhase2 / fallTime2) * (maxValue2 - minValue2);
            }
            currentValue2 = fmax(minValue2, fmin(maxValue2, currentValue2));
            pTimeSeriesCharacteristic2->setValue((uint8_t*)&currentValue2, sizeof(currentValue2));
            pTimeSeriesCharacteristic2->notify();

            // YENİ: Grafik 3 için değer hesaplama (Sinüs dalgası)
            float timeInCycle3 = fmod(elapsedTotalTime, totalCycleTime3);
            float currentValue3;

            if (timeInCycle3 < riseTime3) {
                currentValue1 = minValue3 + timeInCycle3;
            } else {
                float timeInFallingPhase3 = timeInCycle3 - riseTime3;
                currentValue3 = maxValue3 - timeInFallingPhase3;
            }
            currentValue3 = fmax(minValue3, fmin(maxValue3, currentValue3));
            pTimeSeriesCharacteristic3->setValue((uint8_t*)&currentValue3, sizeof(currentValue3));
            pTimeSeriesCharacteristic3->notify();

            // YENİ: Grafik 4 için değer hesaplama (Kare dalga)
          float timeInCycle4 = fmod(elapsedTotalTime, totalCycleTime4);
            float currentValue4;

            if (timeInCycle4 < riseTime4) {
                currentValue4 = minValue4 + timeInCycle4;
            } else {
                float timeInFallingPhase4 = timeInCycle4 - riseTime4;
                currentValue4 = maxValue4 - timeInFallingPhase4;
            }
            currentValue4 = fmax(minValue4, fmin(maxValue4, currentValue4));
            pTimeSeriesCharacteristic4->setValue((uint8_t*)&currentValue4, sizeof(currentValue4));
            pTimeSeriesCharacteristic4->notify();


            Serial.printf("Zaman: %.3f s, Deger1: %.2f, Deger2: %.2f, Deger3: %.2f, Deger4: %.2f\n",
                          elapsedTotalTime, currentValue1, currentValue2, currentValue3, currentValue4);
        }
    }
    
}
