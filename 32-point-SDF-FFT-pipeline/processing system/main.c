#include "xparameters.h"
#include "xil_io.h"
#include "xil_printf.h"
#include <stdint.h>

#define BUF_BASE         XPAR_FFT_32_POINT_0_BASEADDR
#define REG_COUNTER      0x00
#define REG_STATUS       0x04
#define REG_INDATA       0x08
#define REG_OUTDATA      0x0C

#define STATUS_IN_READY  0x1
#define STATUS_OUT_VALID 0x2

extern char inbyte(void);
extern void outbyte(char c);

static uint8_t uart_read_byte(void)
{
    return (uint8_t)inbyte();
}

static void uart_write_byte(uint8_t b)
{
    outbyte((char)b);
}

static int16_t uart_read_int16_le(void)
{
    uint8_t lo = uart_read_byte();
    uint8_t hi = uart_read_byte();

    return (int16_t)((uint16_t)lo | ((uint16_t)hi << 8));
}

static void uart_write_int16_le(int16_t x)
{
    uint16_t u = (uint16_t)x;

    uart_write_byte((uint8_t)(u & 0xFF));
    uart_write_byte((uint8_t)((u >> 8) & 0xFF));
}

int main()
{
    int i;
    int16_t input_sample;
    uint32_t packed_sample;
    uint32_t out;

    int16_t out_real;
    int16_t out_imag;

char start;

    start = inbyte();

    //Wait until the Python program has sent the start signal
    if (start != 'S') {
        while (1) {
        }
    }

    //Ready marker 
    xil_printf("READY\r\n");
    
    //Receive 32 real int16 samples from Python
    for (i = 0; i < 32; i++) {
        input_sample = uart_read_int16_le();

        while ((Xil_In32(BUF_BASE + REG_STATUS) & STATUS_IN_READY) == 0) {
        }

        packed_sample = ((uint32_t)(uint16_t)input_sample << 16) | 0x0000;
        Xil_Out32(BUF_BASE + REG_INDATA, packed_sample);
    }

    //Marker before binary output
    xil_printf("RESULTS\r\n");
    
    //Read 32 FFT outputs from PL and send them back to Python
    for (i = 0; i < 32; i++) {
        while ((Xil_In32(BUF_BASE + REG_STATUS) & STATUS_OUT_VALID) == 0) {
        }

        out = Xil_In32(BUF_BASE + REG_OUTDATA);

        out_real = (int16_t)((out >> 16) & 0xFFFF);
        out_imag = (int16_t)(out & 0xFFFF);

        uart_write_int16_le(out_real);
        uart_write_int16_le(out_imag);
    }

    //Done marker
    xil_printf("DONE\r\n");

    while (1) {
    }

    return 0;
}