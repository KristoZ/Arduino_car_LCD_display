/*
* Car_LCD_display.pde
* v0.35
* This version is compatible only with Arduino v0.22
*
*/ 
#include <OneWire.h>
#include <DallasTemperature.h>
#include <LiquidCrystal.h>
#include <Time.h>

// initialize the library with the numbers of the interface pins
LiquidCrystal lcd(12, 11, 5, 4, 3, 2);
// Data wire is plugged into port 2 on the Arduino
#define ONE_WIRE_BUS 8
#define TEMPERATURE_PRECISION 9

#define TIME_MSG_LEN  11   // time sync to PC is HEADER followed by unix time_t as ten ascii digits
#define TIME_HEADER  'T'   // Header tag for serial time sync message
#define TIME_REQUEST  7    // ASCII bell character requests a time sync message 

// Setup a oneWire instance to communicate with any OneWire devices (not just Maxim/Dallas temperature ICs)
OneWire oneWire(ONE_WIRE_BUS);

// Pass our oneWire reference to Dallas Temperature. 
DallasTemperature sensors(&oneWire);

// arrays to hold device addresses
DeviceAddress insideThermometer, outsideThermometer;

// ----Buttons---
const int bPin1 = 10;     // the number of the pushbutton pin
const int bPin2 = 9;

int iMode = 1;

int analogInp = 1;
float vout = 0.0;
float vin = 0.0;
float R1 = 105600.0; //91000.0; /87700.0; /100100.0;
float R2 = 46500.0; //47000.0; /46100.0; /46200.0;
float V5 = 5.04; // 4.92; /5.04;
int value = 0;

const int maxMode = 6;
const int minMode = 1;
int curBtn = 0;
int prevBtn = 0;
int tmpBtn = 0;

const int ledPin = 6;    // LED connected to digital pin 9
const int lightPin = 7;     // the number of the pushbutton pin
int lightState = 0;         // variable for reading the pushbutton status
int fadeValue = 0 ;
//int tempFade = 0;

bool scroll = 0;
int prevMode = 0;
bool go = 0;

unsigned long start, finished, start2, finished2, elapsed, elapsed2, mils;
long result;
float average = 0;

void setup(void)
{
  // start serial port
  Serial.begin(9600);
  Serial.println("Dallas Temperature IC Control Library Demo");
  lcd.begin(8,1);
  // Start up the library
  sensors.begin();

  // locate devices on the bus
  lcd.setCursor(0, 0);
  lcd.print("Starting");
  Serial.print("Locating devices...");
  Serial.print("Found ");
  Serial.print(sensors.getDeviceCount(), DEC);
  Serial.println(" devices.");

  // report parasite power requirements
  Serial.print("Parasite power is: "); 
  if (sensors.isParasitePowerMode()) Serial.println("ON");
  else Serial.println("OFF");

  // assign address manually.  the addresses below will beed to be changed
  // to valid device addresses on your bus.  device address can be retrieved
  // by using either oneWire.search(deviceAddress) or individually via
  // sensors.getAddress(deviceAddress, index)
  //insideThermometer = { 0x28, 0x1D, 0x39, 0x31, 0x2, 0x0, 0x0, 0xF0 };
  //outsideThermometer   = { 0x28, 0x3F, 0x1C, 0x31, 0x2, 0x0, 0x0, 0x2 };

  // search for devices on the bus and assign based on an index.  ideally,
  // you would do this to initially discover addresses on the bus and then 
  // use those addresses and manually assign them (see above) once you know 
  // the devices on your bus (and assuming they don't change).
  // 
  // method 1: by index
  if (!sensors.getAddress(insideThermometer, 0)) Serial.println("Unable to find address for Device 0"); 
  if (!sensors.getAddress(outsideThermometer, 1)) Serial.println("Unable to find address for Device 1"); 

  // method 2: search()
  // search() looks for the next device. Returns 1 if a new address has been
  // returned. A zero might mean that the bus is shorted, there are no devices, 
  // or you have already retrieved all of them.  It might be a good idea to 
  // check the CRC to make sure you didn't get garbage.  The order is 
  // deterministic. You will always get the same devices in the same order
  //
  // Must be called before search()
  //oneWire.reset_search();
  // assigns the first address found to insideThermometer
  //if (!oneWire.search(insideThermometer)) Serial.println("Unable to find address for insideThermometer");
  // assigns the seconds address found to outsideThermometer
  //if (!oneWire.search(outsideThermometer)) Serial.println("Unable to find address for outsideThermometer");

  // show the addresses we found on the bus
  Serial.print("Device 0 Address: ");
  printAddress(insideThermometer);
  Serial.println();

  Serial.print("Device 1 Address: ");
  printAddress(outsideThermometer);
  Serial.println();

  // set the resolution to 9 bit
  sensors.setResolution(insideThermometer, 9);
  sensors.setResolution(outsideThermometer, 9);

  // Serial.print("Device 0 Resolution: ");
  // Serial.print(sensors.getResolution(insideThermometer), DEC); 
  // Serial.println();

  //  Serial.print("Device 1 Resolution: ");
  //  Serial.print(sensors.getResolution(outsideThermometer), DEC); 
  //  Serial.println();


  //--------------------------
  setSyncProvider( requestSync);  //set function to call when sync required
  Serial.println("Waiting for sync message");
  //--------------------------
  setTime(00,00,00,01,01,2011);

  pinMode(analogInp, INPUT);

  // initialize the LED pin as an output:
  pinMode(ledPin, OUTPUT); 
  // initialize the pushbutton pin as an input:
  pinMode(lightPin, INPUT);    

  start = millis();
  start2 = now();
}

// function to print a device address
void printAddress(DeviceAddress deviceAddress)
{
  for (uint8_t i = 0; i < 8; i++)
  {
    // zero pad the address if necessary
    if (deviceAddress[i] < 16) Serial.print("0");
    Serial.print(deviceAddress[i], HEX);
  }
}

// function to print the temperature for a device
void printTemperature(DeviceAddress deviceAddress)
{
  float tempC = sensors.getTempC(deviceAddress);
  Serial.print("Temp C: ");
  Serial.print(tempC);
  //lcd.setCursor(0, 0);
  lcd.print(tempC);
  //Serial.print(" Temp F: ");
  // Serial.print(DallasTemperature::toFahrenheit(tempC));
}

// function to print a device's resolution
void printResolution(DeviceAddress deviceAddress)
{
  Serial.print("Resolution: ");
  Serial.print(sensors.getResolution(deviceAddress));
  Serial.println();    
}

// main function to print information about a device
void printData(DeviceAddress deviceAddress)
{
  Serial.print("Device Address: ");
  printAddress(deviceAddress);
  Serial.print(" ");
  printTemperature(deviceAddress);
  Serial.println();
}


void loop(void) { 
  // call sensors.requestTemperatures() to issue a global temperature 
  // request to all devices on the bus

  // Serial.print("Requesting temperatures...");
  // sensors.requestTemperatures();
  //Serial.println("DONE");

  //--------Time------------------------
  /*  if(Serial.available() ) 
   {
   processSyncMessage();
   }
   if(timeStatus()!= timeNotSet)   
   {
   digitalWrite(13,timeStatus() == timeSet); // on if synced, off if needs refresh  
   digitalClockDisplay();  
   }
   */
  //----------------/Time---------------

  //curBtn = getButton();
  //checkButtons(curBtn);
  //checkButtons();
  //setMode(iMode);
  digitalWrite(13,0);
  go = 1;

  lightState = digitalRead(lightPin);
  if (lightState == HIGH)
    fadeIn(ledPin);
  else
    fadeOut(ledPin);

  switch (iMode) {
  case 1: 
    {
      //do {
      lcd.setCursor(0, 0);
      lcd.print("In: ");
      printData(outsideThermometer);
      sensors.requestTemperatures();
      Serial.println("Case 1 ");
      /* for (int i = 1; i<=10; i++) {
       delay(100);
       curBtn = getButton();
       checkButtons(curBtn);
       }*/
      //  curBtn = getButton();
      //  checkButtons(curBtn);
      //} while (curBtn == 0);
      break;
    }

  case 2: 
    {
      // do {
      lcd.setCursor(0, 0);
      lcd.print("Out:");
      printData(insideThermometer);
      sensors.requestTemperatures();
      /* for (int i = 1; i<=10; i++) {
       delay(100);
       curBtn = getButton();
       checkButtons(curBtn);
       }*/
      Serial.println("Case 2 ");
      //  curBtn = getButton();
      //   checkButtons(curBtn);
      // } while (curBtn == 0);
      if (scroll)
        delay(3000);
      break; 
    }

  case 3: 
    {
      //  do {
      lcd.setCursor(0, 0);
      LCDprintTime();
      /* for (int i = 1; i<=5; i++) {
       delay(100);
       curBtn = getButton();
       checkButtons(curBtn);
       }*/
      Serial.println("Case 3 ");
      Serial.print(" lightState: ");
      Serial.println(lightState);
      Serial.print("fadeValue: "); 
      Serial.println(fadeValue);
      //  curBtn = getButton();
      //  checkButtons(curBtn);
      // } while (curBtn == 0);
      if (scroll)
        delay(2000);
      break; 
    }

  case 4: 
    {
      //do {
      lcd.setCursor(0, 0);
      LCDprintDate();
      /*for (int i = 1; i<=5; i++) {
       delay(100);
       curBtn = getButton();
       checkButtons(curBtn);
       }*/
      Serial.println("Case 4 ");
      // curBtn = getButton();
      // checkButtons(curBtn);
      // } while (curBtn == 0);
      break; 
    }

  case 5: 
    {
      // do {
      value = analogRead(analogInp);
      vout = (value * V5) / 1024.0;
      vin = vout / (R2/(R1+R2));
      Serial.print("vin=");
      Serial.println(vin);
      lcd.setCursor(0, 0);
      lcd.print(" ");
      lcd.print(vin);
      lcd.print("V  ");
      /* for (int i = 1; i<=5; i++) {
       delay(100);
       curBtn = getButton();
       checkButtons(curBtn);
       }*/
      Serial.println("Case 5 ");
      //curBtn = getButton();
      //checkButtons(curBtn);
      //  } while (curBtn == 0);
      break; 

    case 6: 
      {
        //do {
        if (scroll == 0) {
          lcd.setCursor(0, 0);
          lcd.print(" Scroll ");
          delay(250);
          scroll = 1; 
         // Serial.println("Scrolla = 1");
          break;
        } 
        else {
          iMode = prevMode + 1;
          if (prevMode == 6)
            prevMode = 1;
          //iMode = prevMode;
          setMode(iMode);
          //      lcd.setCursor(0, 0);
          //  lcd.print("Mode: ");lcd.print(iMode);
          //Serial.println("Scroll = 1");
          go = 0;
        }

        //Serial.println("Case 6 ");
        // curBtn = getButton();
        // checkButtons(curBtn);
        // } while (curBtn == 0);
        break; 
      }

    }
  default: 
    {
      lcd.setCursor(0, 0);
      lcd.print("Default");
      break;
    }


  } //End Switch iMode

  prevMode = iMode;

  for (int i = 1; i<=10; i++) {
    tmpBtn = curBtn;
    curBtn = getButton();
    if (!go) break;
    if (tmpBtn != curBtn) {
      if (scroll == 1)
        scroll = 0;
      checkButtons(curBtn);
      break;  
    }
    delay(100);
  }
  digitalWrite(13,1);
  Serial.print("Go = "); 
  Serial.println(go);
  Serial.print("Scroll = "); 
  Serial.println(scroll);
  if (go && scroll)
    iMode = 6;

  //if (day() % 2 == 0)   {  
    finished = millis();
    finished2 = now();
    elapsed = finished - start;
    elapsed2 = finished2 - start2;
    elapsed2 *= 1000;
    result = elapsed - elapsed2;
 
    if (result > 998) {  // If time out of sync by more than 1 second (1000 millis)...
      unsigned long tm = now();
      tm += (result / 1000); //get secs from millisecs
      setTime(tm);
      Serial.print("Added (ms)");
      Serial.println(result);
      lcd.setCursor(0, 0);
       lcd.print("Tc=");
       lcd.print(result);

    }
    //if (average == 0){
     //average = result;
     
     //Serial.print(" avg = res *2 : "); Serial.println(average);  
     //}
    // average += result;
     //Serial.print(" avg += res : "); Serial.println(average);  
     //average /= 2.0;
    // Serial.print(" - - - - - - Average = "); Serial.println(average);    
     //*/
    //Serial.print("Elapsed millis = "); 
    //Serial.println(elapsed);
    //Serial.print("Elapsed secs = "); 
    //Serial.println(elapsed2);
    Serial.print("Difference = "); 
    Serial.println(result);


//  }
}

//--------------------------------
void LCDprintTime (time_t t) {
  lcd.print(LCDlZero(hour(t)));
  lcd.print(":");
  lcd.print(LCDlZero(minute(t)));
  lcd.print(":");       
  lcd.print(LCDlZero(second(t)));
}

void LCDprintDate (time_t t) {
  lcd.print(" ");

  lcd.print(day(t));
  lcd.print(".");
  lcd.print(monthShortStr(month(t)));
  lcd.print("  ");

}

void LCDprintDate2 (time_t t) {
  lcd.print(LCDlZero(day(t)));
  lcd.print("/");
  lcd.print(LCDlZero(month(t)));
  lcd.print("/");
  int yr=year(t);
  if (yr>2000)
    yr = yr - 2000;
  lcd.print(LCDlZero(yr));
}

void LCDprintTime () {
  LCDprintTime(now());
}
void LCDprintDate () {
  LCDprintDate(now());
}

void LCDprintDate2 () {
  LCDprintDate2(now());
}

int LCDlZero(int t) { //Leading zero
  if (t<10) lcd.print("0");
  return t;
}

//-------TIme

void digitalClockDisplay(){
  // digital clock display of the time
  Serial.print(hour());
  printDigits(minute());
  printDigits(second());
  Serial.print(" ");
  Serial.print(day());
  Serial.print(" ");
  Serial.print(month());
  Serial.print(" ");
  Serial.print(year()); 
  Serial.println(); 
}

void printDigits(int digits){
  // utility function for digital clock display: prints preceding colon and leading 0
  Serial.print(":");
  if(digits < 10)
    Serial.print('0');
  Serial.print(digits);
}

void processSyncMessage() {
  // if time sync available from serial port, update time and return true
  while(Serial.available() >=  TIME_MSG_LEN ){  // time message consists of a header and ten ascii digits
    char c = Serial.read() ; 
    Serial.print(c);  
    if( c == TIME_HEADER ) {       
      time_t pctime = 0;
      for(int i=0; i < TIME_MSG_LEN -1; i++){   
        c = Serial.read();          
        if( c >= '0' && c <= '9'){   
          pctime = (10 * pctime) + (c - '0') ; // convert digits to a number    
        }
      }   
      Serial.print("PCtime: "); 
      Serial.print(pctime);   // Sync Arduino clock to the time received on the serial port
      setTime(pctime);
      //setTime(int hr,int min,int sec,int day, int month, int yr);
    }  
  }
}

/*void processSyncMessage() {
 // if time sync available from serial port, update time and return true
 while(Serial.available() >=  TIME_MSG_LEN ){  // time message consists of a header and ten ascii digits
 char c = Serial.read() ; 
 Serial.print(c);  
 if( c == TIME_HEADER ) {       
 //time_t pctime = 0;
 for(int i=0; i < TIME_MSG_LEN -1; i++){   
 c = Serial.read();          
 if( c >= '0' && c <= '9'){   
 hr=c;
 // pctime = (10 * pctime) + (c - '0') ; // convert digits to a number    
 }
 }   
 //setTime(pctime);   // Sync Arduino clock to the time received on the serial port
 setTime(int hr,int min,int sec,int day, int month, int yr);
 }  
 }
 }
 */
time_t requestSync()
{
  Serial.print(TIME_REQUEST,BYTE);  
  return 0; // the time will be sent later in response to serial mesg
}

//----------------------------------------


bool buttOn(int buttonPin) {
  if (digitalRead(buttonPin) == LOW)
    return HIGH;
  else
    return LOW;
}

int getButton() {
  if (buttOn(bPin1)) {
    prevBtn = curBtn;
    return bPin1;
  }
  if (buttOn(bPin2)) { 
    prevBtn = curBtn;
    return bPin2;
  }
  return 0;
}


bool buttOnHold(int buttonPin, int del) {
  delay(100);
  if (buttOn(buttonPin)) {
    for (int i=1;i<del;i++) {
      delay(100);
      if (!buttOn(buttonPin)) 
        return LOW;
    }
    return HIGH;
  }
  else
    return LOW;
}

/*void checkButtons() {
 // delay(150);
 
 if (buttOn(bPin2)) {
 if (buttOnHold(bPin2,5))  
 setClock();
 // Serial.println("Button 1 HOLD"); 
 else {
 setMode(iMode++);
 }
 }
 if (buttOn(bPin1)) {  
 setMode(iMode--);
 }
 }
 */
void checkButtons(int btn) {
  // delay(150);
  if (btn != prevBtn) {

    if (btn == bPin2) {
      if (buttOnHold(bPin2,5))  
        setClock();
      // Serial.println("Button 1 HOLD"); 
      else {
        iMode++;
        setMode(iMode);
      }
    }

    if (btn == bPin1) { 
      if (buttOnHold(bPin2,4)) {
        iMode--;
        setMode(iMode);
      }

      else{
        iMode--;
        setMode(iMode);
      }
    }
  }

}

//----------------------- SET CLOCK --------------------------------
void setClock() {
  int hh=hour();
  int mm=minute();
  int ss=second();

  lcd.clear();
  lcd.print("  Menu  ");
  delay(1000);
  lcd.setCursor(0, 0);
  LCDprintTime();
  lcd.setCursor(2, 0);
  lcd.blink();

  //-----------------------TIME-------------------
  do {
    delay(175);
    if (buttOn(bPin1)){

      hh++;
      if (hh>23){
        hh=0;
      }
      lcd.setCursor(0, 0);  
      lcd.print(LCDlZero(hh));
    }

  } 
  while (!buttOn(bPin2));

  lcd.setCursor(5, 0);
  //lcd.print("");  

  do {
    delay(175);
    if (buttOn(bPin1)){

      mm++;
      if (mm>59){
        mm=0;
      }
      lcd.setCursor(3, 0);
      lcd.print(LCDlZero(mm));
    }

  } 
  while (!buttOn(bPin2)); 

  lcd.setCursor(7, 0);
  //lcd.print("");  

  do {
    delay(175);
    if (buttOn(bPin1)){

      ss++;
      if (ss>59){
        ss=0;
      }
      lcd.setCursor(6, 0);
      lcd.print(LCDlZero(ss));
    }

  } 
  while (!buttOn(bPin2)); 
  //-----------------------/TIME-------------------
  setTime(hh,mm,ss,day(),month(),year());
  //-----------------------DATE--------------------

  int dd=day();
  int mo=month();
  int yy=year();

  if (yy>2000)
    yy = yy - 2000;

  lcd.setCursor(0, 0);
  LCDprintDate2();
  lcd.setCursor(2, 0);

  do {
    delay(175);
    if (buttOn(bPin1)){

      dd++;
      if (dd>31){
        dd=1;
      }
      lcd.setCursor(0, 0);  
      lcd.print(LCDlZero(dd));
    }

  } 
  while (!buttOn(bPin2));

  lcd.setCursor(5, 0); 

  do {
    delay(175);
    if (buttOn(bPin1)){

      mo++;
      if (mo>12){
        mo=1;
      }
      lcd.setCursor(3, 0);  
      lcd.print(LCDlZero(mo));
    }

  } 
  while (!buttOn(bPin2));

  lcd.setCursor(7, 0); 

  do {
    delay(175);
    if (buttOn(bPin1)){

      yy++;
      if (yy>30){
        yy=11;
      }
      lcd.setCursor(6, 0);  
      lcd.print(LCDlZero(yy));
    }

  } 
  while (!buttOn(bPin2));
  //----------------------/DATE--------------------
  setTime(hour(),minute(),second(),dd,mo,yy+2000);
  start = millis();
  start2 = now();
  lcd.noBlink();

  lcd.clear();
  lcd.print("  Exit  ");
  delay(1000);
}
//----------------------- END of SET CLOCK --------------------------------

void setMode(int Mode) {

  Serial.print("Starting setMode, Mode = ");
  Serial.print(Mode); 
  Serial.print(" -> ");
  if (Mode>maxMode){ 
    Mode = minMode;
    iMode = Mode;
  }
  if (Mode<minMode) {
    Mode = maxMode;
    iMode = Mode;
  }
  Serial.println(Mode);


}

void fadeIn(int pinNr) {
  if (fadeValue < 255) {  
    // tempFade = fadeValue;
    // fade in from min to max in increments of 5 points:
    for(fadeValue = 0; fadeValue<=255; fadeValue += 5) { 
      // sets the value (range from 0 to 255):
      //fadeValue = fadeValue + 5;
      analogWrite(pinNr, fadeValue);         
      // wait for 30 milliseconds to see the dimming effect    
      delay(25);                            
    }
    if (fadeValue > 255)
      fadeValue = 255;
  }
}

void fadeOut(int pinNr) {
  if (fadeValue > 0) { 
    // tempFade = fadeValue; 
    // fade in from min to max in increments of 5 points:
    for(fadeValue = 255; fadeValue >=0; fadeValue -= 5) {  
      // sets the value (range from 0 to 255):
      //fadeValue = fadeValue - 5;
      analogWrite(pinNr, fadeValue);         
      // wait for 30 milliseconds to see the dimming effect    
      delay(25);                            
    }
    if (fadeValue < 0)
      fadeValue = 0;
  }

}



