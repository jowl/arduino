#include "VikingReceiver.h"

void setup() {
  Serial.begin(9600);
  TCCR1A = 0;                      // use standard options
  TCCR1B = _BV(ICNC1) | _BV(CS11); // enable noise-canceler, divide clock by 8
  TIMSK1 = _BV(ICIE1);             // enable interrupts on input capture
  DDRB &= ~_BV(0);                 // read from pin 8
}

Message msg;
int bitCount = 0;
unsigned long data = 0;
byte crc = 0;
volatile boolean validLow;
volatile bit value;
ISR( TIMER1_CAPT_vect ) {
  TCNT1 = 0;                            // reset timer count
  unsigned int pulseWidth = ICR1;       // get timer value (signal length)
  boolean wasLow = TCCR1B & _BV(ICES1); // was prev signal low?
  TCCR1B ^= _BV(ICES1);                 // detect other edge (rising/falling)

  if ( wasLow ) {
    validLow = VALID_LOW(pulseWidth);
    if ( !validLow ) invalidSequence();
  } else {
    if ( validLow && VALID_HIGH_ONE(pulseWidth) ) {
      handleBit(1);
    }
    else if ( validLow && VALID_HIGH_ZERO(pulseWidth) ) {
      handleBit(0);
    }
    else invalidSequence();
    validLow = false;
  }
}

boolean newMsg=false;
void loop() {
  if ( newMsg ) {
    printMsg();
    newMsg = false;
  }
}

/*
   5 bytes: 1???aaaa aaaasttt tttttttt hhhhhhhh cccccccc

   ? = unknown
   a = address
   s = temperature sign
   t = temperature
   h = humidity
   c = crc
*/
void handleBit(bit b) {
  if ( bitCount + b == 0 ) return; // messages should start with a one
  if ( bitCount < 32 )
    data = (data << 1) | b;
  else
    crc = (crc << 1) | b;
  bitCount++;
  if ( bitCount >= 40 ) {
    if ( (~crc & 0xff) == crc8(~data) ) {
      msg = parse(~data, ~crc); // input is negated
      newMsg = true;
    }
    reset();
  }
}

Message parse(unsigned long data, byte crc) {
  Message msg = {0,0,0,0,0,0};
  msg.unknown = (data >> 28) & 0x0f;
  msg.address = (data >> 20) & 0xff;
  msg.negative = (data >> 19) & 0x1;
  msg.temperature = (data >> 8) & 0x07ff;
  msg.humidity = data & 0xff;
  msg.crc = crc;
  return msg;
}

void printMsg() {
  String address = String(msg.address, DEC);
  String temperature = String(msg.temperature / 10, DEC) + "." +
    String(msg.temperature % 10,DEC);
  if ( msg.negative ) temperature = "-" + temperature;
  Serial.println("{\"device\" : \"viking\", \"address\" : " + address + ", \"temperature\" : " + temperature + "}");
}

void invalidSequence() {
  reset();
}

void reset() {
  data = 0;
  crc = 0;
  bitCount = 0;
}

byte crc8(long data) {
  byte crc = 0;
  for ( int i = 0; i < 32; i++ ) {
    int inv = ((data>>(31-i)) ^ (crc>>7)) & 0x1;
    crc = ((crc << 1) | inv) ^ ((inv << 4) | ((inv << 5)));
  }
  return crc & 0xff;
}
