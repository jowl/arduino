typedef unsigned char bit;
typedef struct {
  unsigned char unknown;
  unsigned char address;
  unsigned char negative;
  unsigned int temperature;
  unsigned char humidity;
  unsigned char crc;
} Message;

#define CYCLES_PER_US     (F_CPU/1000000UL)
#define TIMER_PRESC       (8)
#define VIKING_LOW        (940*CYCLES_PER_US/TIMER_PRESC)
#define VIKING_HIGH_ONE   (1483*CYCLES_PER_US/TIMER_PRESC)
#define VIKING_HIGH_ZERO  (550*CYCLES_PER_US/TIMER_PRESC)
#define VIKING_TOL_DIV    (3)

#define VALID_HIGH_ONE(PW) (PW > VIKING_HIGH_ONE - VIKING_HIGH_ONE/VIKING_TOL_DIV && PW < VIKING_HIGH_ONE + VIKING_HIGH_ONE/VIKING_TOL_DIV)
#define VALID_HIGH_ZERO(PW) (PW > VIKING_HIGH_ZERO - VIKING_HIGH_ZERO/VIKING_TOL_DIV && PW < VIKING_HIGH_ZERO + VIKING_HIGH_ZERO/VIKING_TOL_DIV)
#define VALID_LOW(PW) (PW > VIKING_LOW - VIKING_LOW/VIKING_TOL_DIV && PW < VIKING_LOW + VIKING_LOW/VIKING_TOL_DIV)

