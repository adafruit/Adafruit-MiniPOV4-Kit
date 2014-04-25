#include <Arduino.h>


#define DEBUG_MODE                      (1)

void displayFreeRam(void);
void uart_putchar(char c);
void printHex(uint8_t h);
void printHex16(uint16_t h);
void DEBUGPRINT(const prog_char *fstr);
void printDec(uint8_t h);
void printDec16(uint16_t h);

#ifndef FLASHIFY
#define FLASHIFY(s) ({static const char c[] __attribute__ ((progmem)) = s;c;})
#endif

#define PRINT_F(__s)         DEBUGPRINT(FLASHIFY(__s))

#if (DEBUG_MODE == 1)
#define DEBUGPRINT_F(__s)         DEBUGPRINT(FLASHIFY(__s))
#define DEBUGPRINT_DEC(x)  printDec(x)
#define DEBUGPRINT_DEC16(x)  printDec16(x)
#define DEBUGPRINT_HEX(x)  printHex(x)
#define DEBUGPRINT_HEX16(x)  printHex16(x)
#else
#define DEBUGPRINT_F(__s)         /* do nothing! */
#define DEBUGPRINT_DEC(x)
#define DEBUGPRINT_DEC16(x)
#define DEBUGPRINT_HEX(x)
#define DEBUGPRINT_HEX16(x)
#endif
