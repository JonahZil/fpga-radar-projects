#include "xparameters.h"
#include "xil_io.h"
#include "xil_printf.h"
#include <stdint.h>

#define FFT_N              4096
#define BUF_BASE           XPAR_FFT_4096_0_BASEADDR

#define REG_COUNTER        0x00
#define REG_STATUS         0x04
#define REG_IN_IMAG        0x08
#define REG_IN_REAL        0x0C
#define REG_OUT_IMAG       0x10
#define REG_OUT_REAL       0x14

#define STATUS_IN_READY    0x1
#define STATUS_OUT_VALID   0x2

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

static void uart_write_int32_le(int32_t x)
{
    uint32_t u = (uint32_t)x;

    uart_write_byte((uint8_t)(u & 0xFF));
    uart_write_byte((uint8_t)((u >> 8) & 0xFF));
    uart_write_byte((uint8_t)((u >> 16) & 0xFF));
    uart_write_byte((uint8_t)((u >> 24) & 0xFF));
}

//Convert signed 16 bit Q1.15 input to 24 bit Q9.15
static uint32_t int16_to_q9_15_24(int16_t x)
{
    return ((uint32_t)((int32_t)x)) & 0x00FFFFFF;
}

//Sign extend signed 24 bit value stored in lower 24 bits of a 32-bit register
static int32_t sign_extend_24(uint32_t x)
{
    x &= 0x00FFFFFF;

    if (x & 0x00800000) {
        x |= 0xFF000000;
    }

    return (int32_t)x;
}

int main()
{
    int i;

    int16_t input_sample;
    uint32_t input_real_24;
    uint32_t input_imag_24;

    uint32_t raw_real;
    uint32_t raw_imag;

    int32_t out_real_24;
    int32_t out_imag_24;

    char start;

    start = inbyte();

    //Wait until Python sends the start signal
    if (start != 'S') {
        while (1) {
        }
    }

    xil_printf("READY\r\n");

    //Send FFT_N real int16 Q1.15 samples to the PL
    for (i = 0; i < FFT_N; i++) {
        input_sample = uart_read_int16_le();

        while ((Xil_In32(BUF_BASE + REG_STATUS) & STATUS_IN_READY) == 0) {
        }

        input_real_24 = int16_to_q9_15_24(input_sample);
        input_imag_24 = 0x00000000;

        Xil_Out32(BUF_BASE + REG_IN_IMAG, input_imag_24);
        Xil_Out32(BUF_BASE + REG_IN_REAL, input_real_24);
    }

    xil_printf("RESULTS\r\n");

    // Read FFT_N complex FFT outputs from the PL
    for (i = 0; i < FFT_N; i++) {
        while ((Xil_In32(BUF_BASE + REG_STATUS) & STATUS_OUT_VALID) == 0) {
        }
        
        raw_imag = Xil_In32(BUF_BASE + REG_OUT_IMAG);
        raw_real = Xil_In32(BUF_BASE + REG_OUT_REAL);

        out_real_24 = sign_extend_24(raw_real);
        out_imag_24 = sign_extend_24(raw_imag);

        // Send real then imag back to Python
        uart_write_int32_le(out_real_24);
        uart_write_int32_le(out_imag_24);
    }

    xil_printf("DONE\r\n");

    while (1) {
    }

    return 0;
}