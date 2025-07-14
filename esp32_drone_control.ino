#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>  
#include <Arduino.h>

// ----- KARAKTERİSTİK UUID'LERİ (FLUTTER İLE AYNI) -----
#define DEVICE_NAME "ESP32_Graph_Tester"
#define SERVICE_UUID           "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define TIMESERIES_CHAR_UUID   "c1d2e3f4-a5b6-c7d8-e9f0-a1b2c3d4e5f6"

// Karakteristik nesnesi
BLECharacteristic *pTimeSeriesCharacteristic;

bool deviceConnected = false;
unsigned long lastDataSendTime = 0;
const int dataSendInterval = 10; // <-- BURAYI DEĞİŞTİRDİK: Veri gönderme sıklığı (ms). Her 500ms'de bir veri.

// Sunucu bağlantı callback'i
class ServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
        deviceConnected = true;
        Serial.println("Cihaz baglandi.");
    }
    void onDisconnect(BLEServer* pServer) {
        deviceConnected = false;
        Serial.println("Cihaz baglantisi koptu.");
        BLEDevice::startAdvertising();
    }
};

void setup() {
    Serial.begin(115200);
    Serial.println("Basit Grafik Veri Gonderici Baslatiliyor...");

    BLEDevice::init(DEVICE_NAME);
    BLEServer *pServer = BLEDevice::createServer();
    pServer->setCallbacks(new ServerCallbacks());
    BLEService *pService = pServer->createService(SERVICE_UUID);

    pTimeSeriesCharacteristic = pService->createCharacteristic(
        TIMESERIES_CHAR_UUID, 
        BLECharacteristic::PROPERTY_NOTIFY
    );
    pTimeSeriesCharacteristic->addDescriptor(new BLE2902());

    pService->start();
    BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->start();

    Serial.println("Cihaz reklam yayini yapiyor. Baglanti bekleniyor...");
    randomSeed(analogRead(0)); // Rastgele sayı üreteci için tohumlama
}


void loop() {
    if (deviceConnected) {
        unsigned long currentTime = millis();

        if (currentTime - lastDataSendTime >= dataSendInterval) {
            lastDataSendTime = currentTime;

            // Rastgele değer üretimi (1.0'dan 5.0'a kadar)
            float currentValue = (float)random(10, 51) / 10.0f; 

            pTimeSeriesCharacteristic->setValue((uint8_t*)&currentValue, sizeof(currentValue));
            pTimeSeriesCharacteristic->notify();

            Serial.printf("Gonderilen deger: %.1f\n", currentValue);
        }
    }
    delay(10); 
}