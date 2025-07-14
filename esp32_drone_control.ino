#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>  
#include <Arduino.h>
#include <math.h> // fmod, fmax ve fmin için gerekli

// ----- KARAKTERİSTİK UUID'LERİ (FLUTTER İLE AYNI) -----
#define DEVICE_NAME "ESP32_Graph_Tester"
#define SERVICE_UUID           "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define TIMESERIES_CHAR_UUID   "c1d2e3f4-a5b6-c7d8-e9f0-a1b2c3d4e5f6"

// Karakteristik nesnesi
BLECharacteristic *pTimeSeriesCharacteristic;

bool deviceConnected = false;
unsigned long lastDataSendTime = 0;
const int dataSendInterval = 10; // Flutter'daki _dataPointIntervalMs ile aynı olmalı (10ms)

// Grafiğin zamanlamasını başlatmak için bağlantı anını kaydeden değişken
unsigned long graphStartTimeMillis = 0; 


const float minValue = 1.0;
const float maxValue = 5.0; // Y ekseninin zirvesi hala 5.0
const float riseTime = 4.0; // 1.0'dan 5.0'a çıkış süresi (4 birim * 1 saniye/birim)
const float fallTime = 4.0; // 5.0'dan 1.0'a iniş süresi (4 birim * 1 saniye/birim)
const float totalCycleTime = riseTime + fallTime; // Toplam döngü süresi: 4 + 4 = 8 saniye

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

    pTimeSeriesCharacteristic = pService->createCharacteristic(
        TIMESERIES_CHAR_UUID, 
        BLECharacteristic::PROPERTY_NOTIFY // Sadece bildirim özelliği yeterli
    );
    pTimeSeriesCharacteristic->addDescriptor(new BLE2902()); // Notifikasyonlar için descriptor

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

            // Döngü içindeki zamanı hesapla (0'dan totalCycleTime'a kadar)
            float timeInCycle = fmod(elapsedTotalTime, totalCycleTime); 

            float currentValue;
            
            if (timeInCycle < riseTime) {
                // Yükselen faz (0'dan 4 saniyeye kadar: 1.0 -> 5.0)
                // Her saniyede 1 birim artar
                currentValue = minValue + timeInCycle; 
            } else {
                // Azalan faz (4'ten 8 saniyeye kadar: 5.0 -> 1.0)
                // Bu fazın başlangıcından bu yana geçen süre
                float timeInFallingPhase = timeInCycle - riseTime; 
                // Her saniyede 1 birim azalır
                currentValue = maxValue - timeInFallingPhase; 
            }
            
            // Değerlerin istenen aralıkta kaldığından emin ol
            currentValue = fmax(minValue, fmin(maxValue, currentValue));

            pTimeSeriesCharacteristic->setValue((uint8_t*)&currentValue, sizeof(currentValue));
            pTimeSeriesCharacteristic->notify();

            Serial.printf("Zaman: %.3f s (Döngü: %.3f s), Gonderilen deger: %.2f\n", elapsedTotalTime, timeInCycle, currentValue);
        }
    }
    // delay(10); // Bu delay, yukarıdaki dataSendInterval mantığını bozacağı için hala kaldırılmış durumda.
}
