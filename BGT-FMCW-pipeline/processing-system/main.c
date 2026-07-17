#include "xparameters.h"
#include "xil_io.h"
#include "xil_printf.h"
#include <stdint.h>

#define FFT_N              64

#define BUF_BASE           XPAR_BGT_AXI_SLAVE_0_BASEADDR

#define REG_STATUS         0x04
#define REG_OUT_IMAG       0x10
#define REG_OUT_REAL       0x14

#define STATUS_OUT_VALID   0x2

extern char inbyte(void);
extern void outbyte(char c);

static void uart_write_byte(uint8_t b)
{
    outbyte((char)b);
}

static void uart_write_int32_le(int32_t x)
{
    uint32_t u = (uint32_t)x;

    uart_write_byte((uint8_t)(u & 0xFF));
    uart_write_byte((uint8_t)((u >> 8) & 0xFF));
    uart_write_byte((uint8_t)((u >> 16) & 0xFF));
    uart_write_byte((uint8_t)((u >> 24) & 0xFF));
}

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

    uint32_t raw_real;
    uint32_t raw_imag;

    int32_t out_real_24;
    int32_t out_imag_24;

    char start;

    start = inbyte();

    if (start != 'S') {
        while (1) {
        }
    }

    xil_printf("READY\r\n");

    xil_printf("WAITING_FOR_FFT\r\n");

    while ((Xil_In32(BUF_BASE + REG_STATUS) & STATUS_OUT_VALID) == 0) {
    }

    xil_printf("RESULTS\r\n");

    for (i = 0; i < FFT_N; i++) {
        while ((Xil_In32(BUF_BASE + REG_STATUS) & STATUS_OUT_VALID) == 0) {
        }

        raw_imag = Xil_In32(BUF_BASE + REG_OUT_IMAG);
        raw_real = Xil_In32(BUF_BASE + REG_OUT_REAL);

        out_real_24 = sign_extend_24(raw_real);
        out_imag_24 = sign_extend_24(raw_imag);

        uart_write_int32_le(out_real_24);
        uart_write_int32_le(out_imag_24);
    }

    xil_printf("DONE\r\n");

    while (1) {
    }

    return 0;
}