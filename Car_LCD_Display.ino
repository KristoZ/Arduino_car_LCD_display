/*
* Car_LCD_display.ino
 * v0.23
 * KristoZ
 * For more info visit:
 * http://kristoz.com/projects/arduino-car-lcd-display/
 * https://bitbucket.org/KristoZ/arduino-car-lcd-display/src
 *
 */
#include <OneWire.h>
#include <DallasTemperature.h>
#include <LiquidCrystal.h>
#include <Time.h>

// Initialize the library with the numbers of the interface pins
LiquidCrystal lcd(12, 11, 5, 4, 3, 2);
// Data wire is plugged into port X on the Arduino
#define ONE_WIRE_BUS 8
/*
From http://www.maximintegrated.com/app-notes/index.mvp/id/4377
 DS18B20 Conversion Times and Resolution Settings
 Resolution 	      9 bit   10 bit  11 bit  12 bit
 Conversion Time (ms)  93.75   187.5    375      750
 LSB (°C) 	      0.5     0.25    0.125   0.0625
 I.e. higher bit resolution gives you better resolution, but takes longer time to calculate
 */
#define TEMPERATURE_PRECISION 12

#define TIME_MSG_LEN  11   // time sync to PC is HEADER followed by unix time_t as ten ascii digits
#define TIME_HEADER  'T'   // Header tag for serial time sync message
#define TIME_REQUEST  7    // ASCII bell character requests a time sync message 

// Setup a oneWire instance to communicate with any OneWire devices (not just Maxim/Dallas temperature ICs)
OneWire oneWire(ONE_WIRE_BUS);

// Pass our oneWire reference to Dallas Temperature. 
DallasTemperature sensors(&oneWire);

// Arrays to hold device addresses
DeviceAddress insideThermometer, outsideThermometer;

// ----Buttons---
// the numbers of the pushbutton pins
const byte bPin1 = 10; // 'UP' button
const byte bPin2 = 9;  // 'DOWN'/'MENU' button

// ---- Voltage divider settings ----
byte analogInp = A1; //This will be used to read the voltage from
float vout = 0.0;
float vin = 0.0;
// --Define the resistor values for the voltage divider in ohms (1000 ohms = 1 Kohm)
float R1 = 105600.0;   //91000.0; /87700.0; /100100.0;
float R2 = 46500.0;    //47000.0; /46100.0; /46200.0;
// Manually measure and set the +5V arduino voltage
float V5 = 5.04;       // 4.92;
word value = 0;        //Value to store the battery voltage

// Initial mode to start in
byte iMode = 1;
const byte minMode = 1;
const byte maxMode = 6;
byte prevMode = 0;

// Button states
byte curBtn = 0;
byte prevBtn = 0;
byte tmpBtn = 0;
bool scroll = 0; //whether the scroll mode is on or not
bool go = 0;

const byte ledPin = 6;       // LED backlight connected to digital pin
const byte lightPin = 7;     // The remote "Headlights on" pin
int lightState = 0;         // variable for reading the pushbutton status
int fadeValue = 0 ;         // value for fading backlight
int tts = 1;                // Number of times to show the current value (scroll mode)
void setup(void)
{
  // start serial port
  Serial.begin(9600);
  lcd.begin(8,1);
  // Start up the DS library
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

  // Search for devices on the bus and assign based on an index.
  if (!sensors.getAddress(insideThermometer, 0)) Serial.println("Unable to find address for Device 0"); 
  if (!sensors.getAddress(outsideThermometer, 1)) Serial.println("Unable to find address for Device 1"); 

  // set the resolution for both sensors
  sensors.setResolution(insideThermometer, TEMPERATURE_PRECISION);
  sensors.setResolution(outsideThermometer, TEMPERATURE_PRECISION);
  // Sets the current temporary time
  setTime(00,00,00,04,12,2012);

  // set the voltage divider reader pin
  pinMode(analogInp, INPUT);
  // initialize the LED pin as an output:
  pinMode(ledPin, OUTPUT); 
  // initialize the pushbutton pin as an input:
  pinMode(lightPin, INPUT);    

} // End of void setup()

void loop(void) { 

  go = 1;
  //Check whether to turn on the LCD backlight 
  //   based on the Headlights state 
  lightState = digitalRead(lightPin);
  if (lightState == HIGH)
    fadeIn(ledPin);
  else
    fadeOut(ledPin);

  lcd.setCursor(0, 0);

  //Shows the corresponding data in the given mode
  switch (iMode) {
    // Display the indoor temperature
  case 1: 
    {
      lcd.print("In: ");
      printTemperature(outsideThermometer);
      sensors.requestTemperatures();
      Serial.println("Case 1 ");
      break;
    }
    // Display the outdoor temperature
  case 2: 
    {
      if (scroll)   //Updates the values within the scroll cycle
        tts = 4;    // times to update 
      else
        tts = 1;
      for (int t = 0; t<tts; t++) {
        if (scroll)
          delay(800);
        lcd.print("Out:");
        printTemperature(insideThermometer);
        sensors.requestTemperatures();
        Serial.println("Case 2 ");
        lcd.setCursor(0, 0);
      }
      break; 
    }
    // Display the current time
  case 3: 
    {
      if (scroll)
        tts = 6;
      else
        tts = 1; 
      for (int t = 0; t<tts; t++) {
        if (scroll)
          delay(500);
        LCDprintTime();
        lcd.setCursor(0, 0);
      }
      break; 
    }
    // Display the current date
  case 4: 
    {
      //lcd.setCursor(0, 0);
      LCDprintDate();
      Serial.println("Case 4 ");
      break; 
    }
    // Display the current battery voltage
  case 5: 
    {
      // Read the value from the voltage divider
      //  and calculate the voltage
      value = analogRead(analogInp);
      vout = (value * V5) / 1024.0;
      vin = vout / (R2/(R1+R2));
      Serial.print("vin=");
      Serial.println(vin);
      lcd.print(" ");
      lcd.print(vin);
      lcd.print("V  ");
      Serial.println("Case 5 ");
      break; 
      // Enter the scroll mode
    case 6: 
      {
        if (scroll == 0) {
          lcd.print(" Scroll ");
          delay(250);
          scroll = 1; 
          break;
        } 
        else { //if already in scroll mode, display next
          iMode = prevMode + 1;
          if (prevMode == 6)
            prevMode = 1;
          setMode(iMode);
          go = 0;
        }
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

  //Check whether a button has been pressed
  for (int i = 1; i<=10; i++) {
    tmpBtn = curBtn;
    curBtn = getButton();
    if (!go) break;
    // If currently in scroll mode, go out of it
    if (tmpBtn != curBtn) { 
      if (scroll == 1)
        scroll = 0;
      checkButtons(curBtn);
      break;  
    }
    delay(100);
  }

  Serial.print("Go = "); 
  Serial.println(go);
  Serial.print("Scroll = "); 
  Serial.println(scroll);
  if (go && scroll)
    iMode = 6;
} // End loop void()


//----------- Functions -------------

// function to print the temperature for a device
void printTemperature(DeviceAddress deviceAddress)
{
  float tempC = sensors.getTempC(deviceAddress);
  Serial.print("Temp C: ");
  Serial.println(tempC);
  //Adjust the temperature position based on the characted count
  if (tempC <= -10.0F){
    lcd.setCursor(3, 0);
    //Serial.println("Adjusting position...");
  }
  lcd.print(tempC);
  //Serial.print(" Temp F: ");
  // Serial.print(sensors.getTempF(deviceAddress));
}

//------- ->Date and time functions -------
// Prints given time on LCD
void LCDprintTime (time_t t) {
  lcd.print(LCDlZero(hour(t)));
  lcd.print(":");
  lcd.print(LCDlZero(minute(t)));
  lcd.print(":");       
  lcd.print(LCDlZero(second(t)));
}

// Prints given date on LCD
void LCDprintDate (time_t t) {
  lcd.print(" ");
  lcd.print(day(t));
  lcd.print(".");
  lcd.print(monthShortStr(month(t)));
  lcd.print("  ");
}

// Prints date on LCD for the Menu
void LCDprintDate2 (time_t t) {
  lcd.print(LCDlZero(day(t)));
  lcd.print("/");
  lcd.print(LCDlZero(month(t)));
  lcd.print("/");
  word yr=year(t);
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

// Leading zero formatter function
int LCDlZero(byte t) {
  if (t<10) lcd.print("0");
  return t;
}

//------- <-Date and time functions -------

// This is a function to set the time from the connected computer via Serial connection
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

//------- ->Button functions -------
// Checks whether a button has been pressed 
bool buttOn(byte buttonPin) {
  if (digitalRead(buttonPin) == LOW)
    return true;
  else
    return false;
}

// Checks whether a button 1 or 2 has been pressed
//    and return its pin number
byte getButton() {
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

// Checks whether a button is being held down
bool buttOnHold(byte buttonPin, int del) {
  delay(100);
  //wait 100ms and check if the button is still pressed
  if (buttOn(buttonPin)) {
    for (int i=1;i<del;i++) { //check every next 'del' times
      delay(100);
      // if the button is not pressed amymore in the specified
      //   time interval then exit 
      if (!buttOn(buttonPin)) 
        return false;
    }
    // The button was pressed down the whole time
    return true;
  }
  else
    return false;
}

// Detects button state and sets the corresponding mode
void checkButtons(byte btn) {
  if (btn != prevBtn) { // If the pressed button did not change..
    if (btn == bPin2) { // If it is the "Menu" button..
      if (buttOnHold(bPin2,5))  // .. and it is being long pressed
        setClock();             // Enter the menu
      else {            //..otherwise change mode
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
//------- <-Button functions -------

//----------------------- SET CLOCK MENU ------------------------
void setClock() {
  word DELAY = 175;
  lcd.clear();
  lcd.print("  Menu  ");
  delay(1000);
  lcd.blink();
  //-----------------------DATE--------------------
  // Assign the current date to the values
  byte dd=day();
  byte mo=month();
  word tempY=year();

  //Save the two last significant digits of the year
  if (tempY>2000)
    tempY = tempY - 2000;
  byte yy = (byte) tempY;

  lcd.setCursor(0, 0);
  LCDprintDate2();
  lcd.setCursor(2, 0);

  do {
    setTD(dd, 31, 0);    //Set date
  } 
  while (!buttOn(bPin2));
  delay(DELAY);
  lcd.setCursor(5, 0); 
  do {
    setTD(mo, 12, 3);    //Set month
  } 
  while (!buttOn(bPin2));
  delay(DELAY);
  lcd.setCursor(7, 0);  
  do {
    setTD(yy, 30, 6);    //Set year
  } 
  while (!buttOn(bPin2));
  delay(DELAY);
  //----------------------/DATE--------------------
  setTime(hour(),minute(),second(),dd,mo,yy+2000);
  // Assign the current time to the values
  byte hh=hour();
  byte mm=minute();
  byte ss=second();

  lcd.setCursor(0, 0);
  LCDprintTime();
  lcd.setCursor(2, 0);
  //-----------------------TIME-------------------
  do {
    setTD(hh, 23, 0);    //Set hours
  }
  while (!buttOn(bPin2));
  delay(DELAY);
  lcd.setCursor(5, 0);    //Switch to the minute field
  do {
    setTD(mm, 59, 3);     //Set minutes
  } 
  while (!buttOn(bPin2));
  delay(DELAY);
  lcd.setCursor(7, 0);     //Switch to the seconds field
  do {
    setTD(ss, 59, 6);      //Set seconds
  } 
  while (!buttOn(bPin2));
  //-----------------------/TIME-------------------
  setTime(hh,mm,ss,day(),month(),year()); //Save the values to the current time
  lcd.noBlink();

  lcd.clear();
  lcd.print("  Exit  ");
  delay(1000);
}

// Sets the current time or date value using buttons
void setTD(byte &value, byte lessThan, byte cursorPos) {
  delay(175);                  // Read every 175ms
  if (buttOn(bPin1)){      //If the button 1 was pressed...
    value++;               // adjust the value
    if (value>lessThan){
      value=0;
    }
    // update the LCD with the new value
    lcd.setCursor(cursorPos, 0);
    lcd.print(LCDlZero(value));
  }
}
//----------------------- END of SET CLOCK MENU ------------------------

// Sets the desired mode
void setMode(byte Mode) {
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

// Fades in the backlight on specified pin number
void fadeIn(int pinNr) {
  if (fadeValue < 255) {
    // fade in from min to max in increments of 5 points:
    for(fadeValue = 0; fadeValue<=255; fadeValue += 5) { 
      // sets the value (range from 0 to 255):
      analogWrite(pinNr, fadeValue);         
      // wait for xx milliseconds to see the dimming effect    
      delay(25);                            
    }
    if (fadeValue > 255)
      fadeValue = 255;

  }
}

// Fades out the backlight on specified pin number
void fadeOut(int pinNr) {
  if (fadeValue > 0) { 
    // fade out from max to min in increments of 5 points:
    for(fadeValue = 255; fadeValue >=0; fadeValue -= 5) {  
      analogWrite(pinNr, fadeValue); 
      // wait for xx milliseconds to see the dimming effect    
      delay(25);                            
    }
    if (fadeValue < 0)
      fadeValue = 0;  
  }
}




