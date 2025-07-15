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

// Karakteristik nesneleri
BLECharacteristic *pTimeSeriesCharacteristic1; // Grafik 1
BLECharacteristic *pTimeSeriesCharacteristic2; // Grafik 2

bool deviceConnected = false;
unsigned long lastDataSendTime = 0;
const int dataSendInterval = 10; // Flutter'daki _dataPointIntervalMs ile aynı olmalı (10ms)

// Grafiğin zamanlamasını başlatmak için bağlantı anını kaydeden değişken
unsigned long graphStartTimeMillis = 0; 

// Grafik 1 için parametreler (Mevcut tester sinyali)
const float minValue1 = 1.0;
const float maxValue1 = 5.0;
const float riseTime1 = 4.0;
const float fallTime1 = 4.0;
const float totalCycleTime1 = riseTime1 + fallTime1;

// Grafik 2 için parametreler (Yeni sinyal - daha farklı bir tester sinyali yapalım)
const float minValue2 = 0.5; // Farklı bir min değer
const float maxValue2 = 4.5; // Farklı bir max değer
const float riseTime2 = 2.0; // Daha hızlı yükselme
const float fallTime2 = 6.0; // Daha yavaş düşme
const float totalCycleTime2 = riseTime2 + fallTime2;


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

    // Grafik 1 Karakteristiği
    pTimeSeriesCharacteristic1 = pService->createCharacteristic(
        TIMESERIES_CHAR_UUID_1, 
        BLECharacteristic::PROPERTY_NOTIFY // Sadece bildirim özelliği yeterli
    );
    pTimeSeriesCharacteristic1->addDescriptor(new BLE2902()); // Notifikasyonlar için descriptor

    // Grafik 2 Karakteristiği
    pTimeSeriesCharacteristic2 = pService->createCharacteristic(
        TIMESERIES_CHAR_UUID_2, 
        BLECharacteristic::PROPERTY_NOTIFY
    );
    pTimeSeriesCharacteristic2->addDescriptor(new BLE2902());

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

            // --- Grafik 2 için değer hesaplama (Yeni, farklı bir sinyal) ---
            float timeInCycle2 = fmod(elapsedTotalTime, totalCycleTime2); 
            float currentValue2;
            
            if (timeInCycle2 < riseTime2) {
                // Yükselen faz
                // Başlangıç değeri + (fazdaki geçen süre / fazın toplam süresi) * (maks-min değer farkı)
                currentValue2 = minValue2 + (timeInCycle2 / riseTime2) * (maxValue2 - minValue2);
            } else {
                // Azalan faz
                float timeInFallingPhase2 = timeInCycle2 - riseTime2; 
                // Maks değer - (fazdaki geçen süre / fazın toplam süresi) * (maks-min değer farkı)
                currentValue2 = maxValue2 - (timeInFallingPhase2 / fallTime2) * (maxValue2 - minValue2);
            }
            currentValue2 = fmax(minValue2, fmin(maxValue2, currentValue2));
            pTimeSeriesCharacteristic2->setValue((uint8_t*)&currentValue2, sizeof(currentValue2));
            pTimeSeriesCharacteristic2->notify();

            Serial.printf("Zaman: %.3f s, Deger1: %.2f, Deger2: %.2f\n", elapsedTotalTime, currentValue1, currentValue2);
        }
    }
}
