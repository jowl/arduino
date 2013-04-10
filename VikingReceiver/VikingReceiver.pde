#include "VikingReceiver.h"

void setup() {
  Serial.begin(38400);
  Serial.println("Started");
  TCCR1A = 0; // use standard options
  TCCR1B = _BV(ICNC1) | _BV(ICES1) | _BV(CS11); // enable noise-canceler, select rising edges, divide clock by 8
  TIMSK1 = _BV(ICIE1); // enable interrupts on input capture
}

volatile boolean validHigh;
volatile boolean bit;
ISR( TIMER1_CAPT_vect ) {
  TCNT1 = 0; // reset timer count
  unsigned int pulseWidth = ICR1; // get timer value (signal length)
  boolean wasLow = TCCR1B & _BV(ICES1); // was prev signal low?
  TCCR1B ^= _BV(ICES1); // detect other edge (rising/falling) next time

  if ( wasLow ) {
    if ( validHigh && VALID_LOW(pulseWidth) ) {
      writeBit(bit);
    }
    else invalidSequence();
    validHigh = false;
  } else {
    if ( VALID_HIGH_ONE(pulseWidth) ) {
      validHigh = true;
      bit = 1;
    }
    else if ( VALID_HIGH_ZERO(pulseWidth) ) {
      validHigh = true;
      bit = 0;
    }
    else invalidSequence();
  }
}

void loop() {}

int writeCount = 0;
void writeBit(boolean b) {
  Serial.print(bit, BIN);
  writeCount++;
  if(writeCount % 8 == 0) Serial.print(" ");
  if(writeCount >= 40) {
    Serial.print("\n"+String(millis()/1000)+" ");
    writeCount=0;
  }
}

int prevWriteCount = 0;
void invalidSequence() {
  if ( !(prevWriteCount == writeCount) )
    Serial.print("\n"+String(millis()/1000)+" ");
  prevWriteCount = writeCount;
}
