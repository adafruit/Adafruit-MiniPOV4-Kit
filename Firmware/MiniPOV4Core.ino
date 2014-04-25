/*
  MiniPOV4 Core firmware, Arduino-esque edition
  Written by Frank Zhao for Adafruit Industries

  Project can be opened with Arduino IDE and programmed via USBtiny bootlader
  by holding down shift while uploading (select USBtinyISP as programmer)

  Licensed under GPL v2
*/

#include <avr/io.h>
#include <avr/eeprom.h>
#include <avr/pgmspace.h>
#include <avr/interrupt.h>
#include <avr/wdt.h>
#include <util/delay.h>
#include "debug.h"

// enable/disable features here
#define ENABLE_USB_DETECT

// how many 'color loops'
#define COLORLOOPS 1

// hardware pin config for higher speeds!
#define LED_CATHODES_DDRx  DDRB
#define LED_CATHODES_PORTx PORTB
#define LED_RED_PINNUM 4
#define LED_GREEN_PINNUM 3
#define LED_BLUE_PINNUM 5

#define LED_8_4_PORTx PORTD
#define LED_3_1_PORTx PORTC

/// arduino pin defines
#define BLUE  13
#define RED   12
#define GREEN 11
#define LED1 A0
#define LED2 A1
#define LED3 A2
#define LED4 3
#define LED5 4
#define LED6 5
#define LED7 6
#define LED8 7
#define TILTSW 10
#define USBDETECT 8

#define MINSPEED 100 // actually, the fastest speed
#define MAXSPEED 1000 // actually, the slowest speed

uint8_t led_anodes[] = {LED1, LED2, LED3, LED4, LED5, LED6, LED7, LED8};
uint8_t led_cathodes[] = {RED, GREEN, BLUE};
////

volatile int ani_length;
volatile int ani_idx;
volatile uint8_t colour_idx = 0; // 0 = R, 1 = G, 2 = B, repeating
volatile uint8_t shade_idx = 0;
volatile byte frame_buffer[8];

int speed = 0;

void setup()
{
  Serial.begin(115200);
  Serial.println("Welcome to MiniPOV 4!");
  
  // pin direction setup
  pinMode(RED, OUTPUT); 
  pinMode(BLUE, OUTPUT); 
  pinMode(GREEN, OUTPUT); 
  
  pinMode(LED8, OUTPUT);
  pinMode(LED7, OUTPUT);
  pinMode(LED6, OUTPUT);
  pinMode(LED5, OUTPUT);
  pinMode(LED4, OUTPUT);
  pinMode(LED3, OUTPUT);
  pinMode(LED2, OUTPUT);
  pinMode(LED1, OUTPUT);

  pinMode(TILTSW, INPUT);
  pinMode(USBDETECT, INPUT);
	
  // setup pull-up resistor
  digitalWrite(TILTSW, HIGH); // TILTSWITCH_PORTx |= _BV(TILTSWITCH_PINNUM);
  
  // default off
  digitalWrite(RED, LOW);
  digitalWrite(BLUE, LOW);;
  digitalWrite(GREEN, LOW); 
  
  digitalWrite(LED1, LOW);
  digitalWrite(LED2, LOW);
  digitalWrite(LED3, LOW);
  digitalWrite(LED4, LOW);
  digitalWrite(LED5, LOW);
  digitalWrite(LED6, LOW);
  digitalWrite(LED7, LOW);
  digitalWrite(LED1, LOW);
  
  digitalWrite(USBDETECT, LOW);
  
  // Strobe all the LEDs (a nice easy test
  for (uint8_t c=0; c<3; c++) {
    // turn on one color at a time
    digitalWrite(led_cathodes[c], HIGH);
    for (uint8_t a=0; a<8; a++) {
      // turn on one LED at a time
      digitalWrite(led_anodes[a], HIGH);
      delay(30);
    }
    // turn it off
    digitalWrite(led_cathodes[c], LOW);
    for (uint8_t a=0; a<8; a++) {
      digitalWrite(led_anodes[a], LOW);
    }
  }

  // check the animation length
  ani_length = (eeprom_read_byte((uint8_t*)0) << 8) + eeprom_read_byte((uint8_t*)1);
  Serial.print("Found a "); Serial.print(ani_length); Serial.println(" byte image");
  
  pinMode(10, OUTPUT);
  
  speed = analogRead(3);
  Serial.print("Setting speed to "); Serial.println(speed);  
  // start timer
  TCCR1A = 0;
  TCCR1B = _BV(WGM12) | 0x05;
  OCR1A = map(speed, 0, 1024, MINSPEED, MAXSPEED); // this should not be lower than 500
  TIMSK1 |= _BV(OCIE1A);   // Output Compare Interrupt Enable (timer 1, OCR1A)
}

void loop()
{
  // it might seem strange that nothing important happens in this loop
  // but it is because timer1's ISR is handling all the LED lighting
  // with extreme timing precision
  // this allows us to implement 8 bit color PWM shading

#ifdef ENABLE_USB_DETECT
  // if USB connection detected, reset and jump to bootloader
  if (digitalRead(USBDETECT)) {
    wdt_enable(WDTO_15MS); // force watchdog reset
    while (1);
  }
#endif // ENABLE_USB_DETECT

  if ( abs(speed - analogRead(3)) > 5) {
    speed = analogRead(3);
    Serial.print("Setting speed to "); Serial.println(speed);  
    OCR1A = map(speed, 0, 1024, MINSPEED, MAXSPEED);
  }
}

ISR(TIMER1_COMPA_vect)
{
  PORTB |= _BV(2);
  // show the next frame
  // data format is
  // 0bRRRGGGBB, eight of them
  uint8_t i, b, cathodeport = 0, ledport = 0;
   
  // We use direct port access is used instead of Arduino-style
  // because this needs to be fast
     
  if (colour_idx == 0) {
    cathodeport = _BV(LED_RED_PINNUM);

    for (i = 0; i < 8; i++) {
      b = (frame_buffer[i] & 0xE0) >> 5;
      if (b > shade_idx)
        ledport |= _BV(i); 
    }
  }
  else if (colour_idx == 1)
  {
    cathodeport = _BV(LED_GREEN_PINNUM);
    
    for (i = 0; i < 8; i++) {
      b = (frame_buffer[i] & 0x1C) >> 2;
      if (b > shade_idx)
        ledport |= _BV(i);
    }
  }
  else if (colour_idx == 2)
  {
    cathodeport = _BV(LED_BLUE_PINNUM);
  
    uint8_t s = shade_idx >> 1;

    for (i = 0; i < 8; i++) {
      b = frame_buffer[i] & 0x03;
      if (b > s)
        ledport |= _BV(i); 
    }
  }
  PRINT_F("\n\rLEDport = "); DEBUGPRINT_HEX(ledport);
  PRINT_F("\tcathodes = "); DEBUGPRINT_HEX(cathodeport);
  LED_3_1_PORTx &= ~(0x07);
  LED_8_4_PORTx &= ~(0xF8);
  LED_CATHODES_PORTx &= ~_BV(LED_RED_PINNUM) & ~_BV(LED_GREEN_PINNUM) & ~_BV(LED_BLUE_PINNUM);
  LED_3_1_PORTx |= ledport & 0x7;
  LED_8_4_PORTx |= ledport & 0xF8;
  LED_CATHODES_PORTx |= cathodeport;

  // next color
  colour_idx++;
  if (colour_idx >= 3) {
    colour_idx = 0;
    shade_idx++;
    if (shade_idx >= 7) {
      shade_idx = 0;
      PRINT_F("New Pixel: ");
      // simple next frame with roll over
      ani_idx++;
      if (ani_idx >= ani_length) {
        ani_idx = 0;
      }
      eeprom_read_block((void*)frame_buffer, (const void*)(2 + (ani_idx * 8)), 8); // load next frame
      for (uint8_t p=0; p<8; p++) {
        DEBUGPRINT_HEX(frame_buffer[p]);
        PRINT_F(", ");
      }
    }
  }
  PORTB &= ~_BV(2);
}

