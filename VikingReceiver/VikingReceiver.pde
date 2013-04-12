#include "VikingReceiver.h"

void setup() {
  Serial.begin(9600);
  Serial.println("Started");
  TCCR1A = 0;                      // use standard options
  TCCR1B = _BV(ICNC1) | _BV(CS11); // enable noise-canceler, divide clock by 8
  TIMSK1 = _BV(ICIE1);             // enable interrupts on input capture
  DDRB &= ~_BV(0);                 // read from pin 8
}

Message msg = {0,0,0,0,0,0};
int bitCount = 0;
unsigned long data = 0;
unsigned char crc = 0;
volatile boolean validHigh;
volatile bit value;
ISR( TIMER1_CAPT_vect ) {
  TCNT1 = 0;                            // reset timer count
  unsigned int pulseWidth = ICR1;       // get timer value (signal length)
  boolean wasLow = TCCR1B & _BV(ICES1); // was prev signal low?
  TCCR1B ^= _BV(ICES1);                 // detect other edge (rising/falling)

  if ( wasLow ) {
    if ( validHigh && VALID_LOW(pulseWidth) ) {
      handleBit(value);
    }
    else invalidSequence();
    validHigh = false;
  } else {
    if ( VALID_HIGH_ONE(pulseWidth) ) {
      validHigh = true;
      value = 1;
    }
    else if ( VALID_HIGH_ZERO(pulseWidth) ) {
      validHigh = true;
      value = 0;
    }
    else invalidSequence();
  }
}

void loop() { }

/*
   36 bits: ????aaaa aaaasttt tttttttt hhhhhhhh cccc

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
  if ( bitCount >= 36 ) {
    printMsg(parse(~data, ~crc)); // input is negated
    reset();
  }
}

Message parse(unsigned long data, unsigned char crc) {
  Message msg = {0,0,0,0,0,0};
  msg.unknown = (data >> 28) & 0x0f;
  msg.address = (data >> 20) & 0xff;
  msg.negative = (data >> 19) & 0x1;
  msg.temperature = (data >> 8) & 0x07ff;
  msg.humidity = data & 0xff;
  msg.crc = crc;
  return msg;
}

void printMsg(Message msg) {
  String address = String(msg.address,DEC);
  String temperature = String(msg.temperature / 10,DEC) + "." +
    String(msg.temperature % 10,DEC);
  Serial.println("{\"device\" : \"viking\", \"id\" : " + address +
                 ", \"temperature\" : " + temperature + "}");
}

void invalidSequence() {
  reset();
}

void reset() {
  data = 0;
  crc = 0;
  bitCount = 0;
  msg.unknown = 0;
  msg.address = 0;
  msg.negative = 0;
  msg.temperature = 0;
  msg.humidity = 0;
  msg.crc = 0;
}