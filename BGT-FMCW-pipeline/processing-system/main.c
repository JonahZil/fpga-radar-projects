#include "xparameters.h"
#include "xil_io.h"
#include "xstatus.h"
#include "xuartps.h"
#include "xuartps_hw.h"

#include <stdint.h>

/*
 * Check xparameters.h after regenerating the BSP.
 *
 * Depending on the name of the AXI peripheral in the block design,
 * this may instead retain the old name:
 *
 * XPAR_CONTINUOUS_FMCW_AXI_SLAVE_0_BASEADDR
 */
#define BUF_BASE                    XPAR_FMCW_OUTPUT_SLAVE_0_BASEADDR

/*
 * AXI register offsets.
 */
#define REG_STATUS                  0x04U
#define REG_RANGE                   0x08U
#define REG_ALPHA                   0x0CU
#define REG_BETA                    0x10U

/*
 * Status register bit 1:
 *     1 = range and phase result is available
 */
#define STATUS_OUT_VALID            0x02U

/*
 * Physical PS UART 1 is the only enabled UART.
 * The XUartPs driver labels it as instance 0.
 */
#define UART_BASEADDR               XPAR_XUARTPS_0_BASEADDR
#define UART_BAUD_RATE              921600U

static XUartPs Uart;


/*
 * Initialize PS UART 1 and set its baud rate to 921600.
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
 * Send an unsigned 32-bit value in little-endian order.
 */
static void uart_write_uint32_le(uint32_t value)
{
    uart_write_byte((uint8_t)(value & 0xFFU));
    uart_write_byte((uint8_t)((value >> 8) & 0xFFU));
    uart_write_byte((uint8_t)((value >> 16) & 0xFFU));
    uart_write_byte((uint8_t)((value >> 24) & 0xFFU));
}


/*
 * Send a signed 32-bit value in little-endian order.
 *
 * Casting to uint32_t preserves the two's-complement bit pattern.
 */
static void uart_write_int32_le(int32_t value)
{
    uart_write_uint32_le((uint32_t)value);
}


static void uart_write_frame_marker(void)
{
    uart_write_string("NEXT_FRAME\n");
}


int main(void)
{
    uint32_t range;
    int32_t alpha;
    int32_t beta;

    /*
     * UART changes to 921600 before waiting for the start byte.
     * The laptop must therefore open the serial port at 921600 baud.
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
         * Wait until a complete range/phase result is available.
         */
        while (
            (Xil_In32(BUF_BASE + REG_STATUS) &
             STATUS_OUT_VALID) == 0U
        ) {
        }

        /*
         * Read all three values belonging to the result.
         *
         * REG_ELEVATION_PHASE must be read last because reading
         * address 0x10 acknowledges the result to top_io_buffer.
         *
         * The AXI slave already:
         *   - zero-extends the unsigned 24-bit range to 32 bits
         *   - sign-extends both signed 18-bit phases to 32 bits
         */
        range = Xil_In32(
            BUF_BASE + REG_RANGE
        );

        alpha = (int32_t)Xil_In32(
            BUF_BASE + REG_ALPHA
        );

        beta = (int32_t)Xil_In32(
            BUF_BASE + REG_BETA
        );

        /*
         * Each result sent to Python is:
         *
         *     "NEXT_FRAME\n"
         *     4 bytes unsigned range
         *     4 bytes signed azimuth phase
         *     4 bytes signed elevation phase
         *
         * All binary values are little-endian.
         */
        uart_write_frame_marker();

        uart_write_uint32_le(range);
        uart_write_int32_le(alpha);
        uart_write_int32_le(beta);

        /*
         * Wait for the FPGA to process the acknowledgement and
         * deassert valid before accepting another result.
         *
         * This prevents the same record from being transmitted twice
         * if the PS checks the status register immediately after
         * reading the elevation register.
         */
        while (
            (Xil_In32(BUF_BASE + REG_STATUS) &
             STATUS_OUT_VALID) != 0U
        ) {
        }
    }

    return 0;
}