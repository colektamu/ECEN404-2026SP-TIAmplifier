#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>

// See the following for generating UUIDs:
// https://www.uuidgenerator.net/
/*
UUIDs are used for server, service, and characteristic tracking and connection across multiple devices using BLE. 
The UUIDs below were used to declare characteristics, both for the final project and for BLE testing
*/
#define SERVICE_UUID         "94fa7d4e-136a-43d2-9f08-c8f296530110"
#define CHARACTERISTIC_RECEIVE0 "df170f02-3641-4594-806d-c113a27ce6cb"
#define CHARACTERISTIC_RECEIVE1 "cda5747e-5862-4196-be75-6d5c2b9fa72d"
#define CHARACTERISTIC_UUID1 "762c4a12-fbae-4904-872a-56373c871e69"
#define CHARACTERISTIC_UUID2 "c74e219d-d204-4e2d-87e5-4c9a7636438b"
#define CHARACTERISTIC_UUID3 "27af974a-50c8-4d4c-bd25-d9f872e59dff"
#define CHARACTERISTIC_UUID4 "a8b3ec2f-2c93-46d9-a71b-2e5d7448693b"
#define CHARACTERISTIC_UUID5 "bfd96262-5124-46c8-b412-c316098f26bd"
#define CHARACTERISTIC_UUID6 "d285491d-331f-4f17-95a3-103b2a072304"


/*The variables below were used for verification and testing through a BLE scanner app*/
//The pointer below was used for initial testing, to verify the code used to translate BLE signals to data changes and SPI sends
BLECharacteristic *LastChangedPort = nullptr;                //*_UUID5
//The pointer array used below was used to organize Volume and EQ control and verifying their states, organizing it as an array that is easily translatable to input data
BLECharacteristic *PortStates[4];                         //*_UUID1 -> //*_UUID4
//The pointer below was used for verification of signal translation, so that the input matches the output value
BLECharacteristic *SPI_Received = nullptr;                   //*_UUID6
                                                          //*_Recieved* is used for DataIn and write interfacing

//Sets up SPI protocol
#include <SPI.h>

// Define ALternate Pins to use non-standard GPIO pins for SPI bus
#define SPI_MISO  15      //Used to test SPI output, unneeded for implementation
#define SPI_MOSI  11      //Databus for SPI send
#define SPI_SCLK  10       //Clock used for SPI send
#define SPI_SS1   18      //Enable pin 1 (volume)
#define SPI_SS2   19      //Enable pin 2 (bass)
#define SPI_SS3   20      //Enable pin 3 (mid)
#define SPI_SS4   21      //Enable pin 4 (treble)

//Defines SPI groupings
#if !defined(CONFIG_IDF_TARGET_ESP32)
#define VSPI FSPI
#endif

//Sets clock rate for SPI protocol
static const int spiClk = 1;

//These global variables were used to interpret input through the mobile app
uint8_t port = 0x00;
uint8_t data = 0x00;

/*
array of SPI groupings, each index correlates to a different digital pot
spi_r[0] = Volume
spi_r[1] = BassEQ
spi_r[2] = MidEQ
spi_r[3] = TrebleEQ
*/
SPIClass* spi_r[4];

//Byte used for testing received SPI signal (MISO)
uint8_t received = 0x00;

/*
The potentiometers used in implementation were organized on a linear scale, requiring a logarithmic signal control for expected results. Instead of requiring
a direct computation for every update, a simple logarithmic conversion array was used
*/
int log_conv[31] = {0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 
                    21, 24, 27, 31, 36, 42, 49, 56, 62, 70, 80, 
                    90, 101, 114, 128, 143, 161, 180, 203, 227, 255};

/*
The Following array was used for translation from an integer value to a boolean array for the SPI send. As the potentiometers
use a 16 bit command, the array was set to 16 bits. The first byte of this remains 0 regardless.
*/
bool ar_out[16] = {0,0,0,0,0,0,0,0,
                   0,0,0,0,0,0,0,0};


/*
The following function was used for integer to boolean array translation. The first 8 bits will always be 0, so after an initial reset, only indices 8-15 will be changed.
The array is reset to 0x0000 every update to avoid unwanted values potentially causing MCU burnout
*/
void ByteArray(uint8_t datain){
  for (int i = 0; i < 16; i++){
    ar_out[i] = false;
  }

  if (datain >= 128) {ar_out[8] = 1;}
  if (datain >= 64) {ar_out[9] = 1;}
  if (datain >= 32) {ar_out[10] = 1;}
  if (datain >= 16) {ar_out[11] = 1;}
  if (datain >= 8) {ar_out[12] = 1;}
  if (datain >= 4) {ar_out[13] = 1;}
  if (datain >= 2) {ar_out[14] = 1;}
  if (datain >= 1) {ar_out[15] = 1;}

}

//Function used for the actual SPI send
//*spi should be the specific index of spi_r correlating to the correct pot
//data should be processed and on a 256 scale (uint8_t)
void spi_bash(SPIClass *spi, bool dataout[]){
  digitalWrite(SPI_SCLK, LOW);
  digitalWrite(spi->pinSS(), LOW);

  for (int i = 0; i < 16; i++){
    delayMicroseconds(1);

    if (ar_out[i] == 0) {digitalWrite(SPI_MOSI, LOW);}
    else {digitalWrite(SPI_MOSI, HIGH);}
    delayMicroseconds(1);
    
    digitalWrite(SPI_SCLK, HIGH);
    delayMicroseconds(2);

    digitalWrite(SPI_SCLK, LOW);
  }

  delayMicroseconds(1);
  digitalWrite(spi->pinSS(), HIGH);
  delayMicroseconds(1);
  digitalWrite(SPI_MOSI, LOW);

}

//The following was declared globally to allow for callback functions regarding it.
BLEServer *pServer = nullptr;

/*
The following callback function is used for connection updates without reboots. Without restarting advertising, the system will not allow for other connections
once it has been connected to, even if the initial connected device was disconnected.
*/
class ServerAdvertControl : public BLEServerCallbacks {
  void onDisconnect(BLEServer* pServer) {
    delay(500);
    BLEDevice::startAdvertising();
  }
};

/*Callback class used for variable updating
Only used on the writable characteristic, the "onWrite" function specifically calls both the data processing and SPI send functions
This function is called any time *Datain is updated remotely
This function is works as an automatic updater any time a state is changed
*/
class DataInCallback : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    String value = pCharacteristic->getValue();
    
    if (value.length() >= 2) {
      port = static_cast<uint8_t>(value[0]);
      data = static_cast<uint8_t>(value[1]);

      
      uint8_t processed_state = log_conv[data];
      //ByteTranslation(port, data);


      LastChangedPort->setValue(&port, 1);
      PortStates[port % 4]->setValue(&processed_state, 1);

      //spiCommand(spi_r[port % 4], pro= cessed_state);
      ByteArray(processed_state);
      if((port%4) == 2) {
        for (int i = 8; i < 16; i++){
          ar_out[i] = !ar_out[i];
        }
      }
      spi_bash(spi_r[port % 4], ar_out);
    }

    //SPI_Received->setValue(received);
    Serial.println(port);
    Serial.println(data);

  }
};


/*
The following is used for initial setup and one time functionality. All relevant code is in this function, due to the limitations of the software used for coding.
*/
void setup() {
  //SPI setup
  spi_r[0] = new SPIClass(VSPI); //Declares SPI class
  spi_r[0]->begin(SPI_SCLK, SPI_MISO, SPI_MOSI, SPI_SS1); //Assigns the SPI pins
  spi_r[1] = new SPIClass(VSPI);
  spi_r[1]->begin(SPI_SCLK, SPI_MISO, SPI_MOSI, SPI_SS2); //All assigned SPI pins overlap except for the SPI_SS*
  spi_r[2] = new SPIClass(VSPI);                          //SPI_SS* correspond to the unique enable pins of each bus
  spi_r[2]->begin(SPI_SCLK, SPI_MISO, SPI_MOSI, SPI_SS3); //This allows the databus and clock to be shared across devices
  spi_r[3] = new SPIClass(VSPI);                          //As the data is only written to a pot when its corresponding EN pin (SPI_SS*)
  spi_r[3]->begin(SPI_SCLK, SPI_MISO, SPI_MOSI, SPI_SS4); //Is set to LOW

  //Initializes pins used for SPI transfer
  pinMode(SPI_SCLK, OUTPUT);
  pinMode(SPI_MISO, INPUT);
  pinMode(SPI_MOSI, OUTPUT);

  digitalWrite(SPI_SCLK, LOW);
  digitalWrite(SPI_MOSI, LOW);
  
  //Iterable loop to simplify the addition or removal of signals
  //Also improves performance
  for (int i = 0; i < 4; i++) {
    pinMode(spi_r[i]->pinSS(), OUTPUT);
    digitalWrite(spi_r[i]->pinSS(), HIGH);
  }

  //Serial Setup
  Serial.begin(115200);

  //Bluetooth Low Energy Setup
  BLEDevice::init("TIAmpEsp");                                  //Server Initialization
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerAdvertControl());

  BLEService *pService = pServer->createService(SERVICE_UUID);  //Creates a Service in the Server under which the Characteristics are organized

  BLECharacteristic *DataIn =
    pService->createCharacteristic(CHARACTERISTIC_RECEIVE0, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE);

  DataIn->setCallbacks(new DataInCallback());                      //Initializes Callback, activating the "onWrite" function call
                                                                //This causes the program to update correlating SPI busses any time DataIn is changed
  DataIn->setValue(0x00);                                     //Initializes the value as 0x0000 for any initial reads

  LastChangedPort =                                             //This Characteristic Saves the last Changed Port, allowing for a short history
    pService->createCharacteristic(CHARACTERISTIC_UUID5, BLECharacteristic::PROPERTY_READ); //Mostly used for Proof of Concept and Debugging

  LastChangedPort->setValue(0x00);                              //Initializes the value for any initial reads

  //Pot State Characteristics
  PortStates[0] =                                               //Volume Pot State
    pService->createCharacteristic(CHARACTERISTIC_UUID1, BLECharacteristic::PROPERTY_READ);

  PortStates[1] =                                               //Bass EQ Pot State
    pService->createCharacteristic(CHARACTERISTIC_UUID2, BLECharacteristic::PROPERTY_READ);

  PortStates[2] =                                               //Mid EQ Pot State
    pService->createCharacteristic(CHARACTERISTIC_UUID3, BLECharacteristic::PROPERTY_READ);

  PortStates[3] =                                               //Treble EQ Pot State
    pService->createCharacteristic(CHARACTERISTIC_UUID4, BLECharacteristic::PROPERTY_READ);

  for (int i = 0; i < 4; i++) {                                 //Initialize all Pot States to 0 for initial read
    PortStates[i]->setValue(0x00);
  }

  //Characteristic for remote SPI Debugging
  /*
  For Proper behavior, connect the MISO and MOSI pins on the ESP. Doing so causes the ESP to read its own output as a Slave input
  This received data will be updated to SPI_Received, to verify integrity of all SPI sends
  */
  SPI_Received =   
    pService->createCharacteristic(CHARACTERISTIC_UUID6, BLECharacteristic::PROPERTY_READ);

  SPI_Received->setValue(0x00);

  //Activates the Service holding all declared Characteristics
  pService->start();

  //Advertises the Server for all incoming BLE connections
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);

  BLEDevice::startAdvertising();

}

void loop() {
  delay(2000); //All code runs through Setup. Permanent delay to keep from causing any errors or corruptions
}
