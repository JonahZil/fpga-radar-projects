#include "xparameters.h"
#include "xil_io.h"
#include "xstatus.h"
#include "xuartps.h"
#include "xuartps_hw.h"

#include <stdint.h>

#define FFT_N                       64

#define BUF_BASE                    XPAR_CONTINUOUS_FMCW_AXI_SLAVE_0_BASEADDR

#define REG_STATUS                  0x04U
#define REG_OUT_IMAG                0x10U
#define REG_OUT_REAL                0x14U

#define STATUS_OUT_VALID            0x02U

/*
 * Physical PS UART 1 is the only enabled UART.
 * The XUartPs driver labels it as instance 0.
 */
#define UART_BASEADDR               XPAR_XUARTPS_0_BASEADDR
#define UART_BAUD_RATE              921600U

static XUartPs Uart;

/*
 * Initialize PS UART 1 and change its baud rate to 921600.
 */
static int uart_init(void)
{
    XUartPs_Config *config;
    int status;

    /*
     * This BSP uses the SDT-style API, so LookupConfig()
     * receives the UART base address rather than a device ID.
     */
    config = XUartPs_LookupConfig(UART_BASEADDR);

    if (config == NULL) {
        return XST_FAILURE;
    }

    status = XUartPs_CfgInitialize(
        &Uart,
        config,
        config->BaseAddress
    );

    if (status != XST_SUCCESS) {
        return status;
    }

    XUartPs_SetOperMode(
        &Uart,
        XUARTPS_OPER_MODE_NORMAL
    );

    status = XUartPs_SetBaudRate(
        &Uart,
        UART_BAUD_RATE
    );

    if (status != XST_SUCCESS) {
        return status;
    }

    return XST_SUCCESS;
}

/*
 * Blocking UART receive.
 */
static uint8_t uart_read_byte(void)
{
    return XUartPs_RecvByte(UART_BASEADDR);
}

/*
 * Blocking UART transmit.
 */
static void uart_write_byte(uint8_t byte)
{
    XUartPs_SendByte(UART_BASEADDR, byte);
}

static void uart_write_string(const char *text)
{
    while (*text != '\0') {
        uart_write_byte((uint8_t)*text);
        text++;
    }
}

/*
 * Send a signed 32-bit value in little-endian order.
 */
static void uart_write_int32_le(int32_t value)
{
    uint32_t u;

    u = (uint32_t)value;

    uart_write_byte((uint8_t)(u & 0xFFU));
    uart_write_byte((uint8_t)((u >> 8) & 0xFFU));
    uart_write_byte((uint8_t)((u >> 16) & 0xFFU));
    uart_write_byte((uint8_t)((u >> 24) & 0xFFU));
}

/*
 * Sign-extend a 24-bit two's-complement value to 32 bits.
 */
static int32_t sign_extend_24(uint32_t value)
{
    value &= 0x00FFFFFFU;

    if ((value & 0x00800000U) != 0U) {
        value |= 0xFF000000U;
    }

    return (int32_t)value;
}

static void uart_write_frame_marker(void)
{
    uart_write_string("NEXT_FRAME\n");
}

int main(void)
{
    int i;

    uint32_t raw_real;
    uint32_t raw_imag;

    int32_t out_real_24;
    int32_t out_imag_24;

    /*
     * UART changes to 921600 before waiting for the start byte.
     * The laptop must therefore open the serial port at 921600.
     */
    if (uart_init() != XST_SUCCESS) {
        while (1) {
            /*
             * UART initialization failed.
             */
        }
    }

    /*
     * Wait until the laptop sends the character 'S'.
     */
    while (uart_read_byte() != (uint8_t)'S') {
    }

    /*
     * This is the only text sent before binary streaming begins.
     */
    uart_write_string("READY\r\n");

    while (1) {
        /*
         * Wait for the FPGA to finish processing a frame and make
         * its FFT output available.
         */
        while (
            (Xil_In32(BUF_BASE + REG_STATUS) &
             STATUS_OUT_VALID) == 0U
        ) {
        }

        /*
         * Send all 64 FFT bins.
         *
         * Each bin contains:
         *     4 bytes real
         *     4 bytes imaginary
         *
         * Each complete frame is therefore:
         *     64 * 8 = 512 bytes
         */

        uart_write_frame_marker();
        for (i = 0; i < FFT_N; i++) {
            /*
             * The status check is retained for every bin in case
             * the AXI peripheral deasserts valid between reads.
             */
            while (
                (Xil_In32(BUF_BASE + REG_STATUS) &
                 STATUS_OUT_VALID) == 0U
            ) {
            }

            /*
             * REG_OUT_REAL must be read second because reading it
             * advances the FPGA output-buffer address.
             */
            raw_imag = Xil_In32(
                BUF_BASE + REG_OUT_IMAG
            );

            raw_real = Xil_In32(
                BUF_BASE + REG_OUT_REAL
            );

            out_real_24 = sign_extend_24(raw_real);
            out_imag_24 = sign_extend_24(raw_imag);

            uart_write_int32_le(out_real_24);
            uart_write_int32_le(out_imag_24);
        }
    }

    return 0;
}