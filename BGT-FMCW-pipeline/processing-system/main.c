#include "xparameters.h"
#include "xil_io.h"
#include "xstatus.h"
#include "xuartps.h"
#include "xuartps_hw.h"

#include <stdint.h>
#define BUF_BASE                    XPAR_FMCW_OUTPUT_SLAVE_0_BASEADDR


// AXI registers
#define REG_STATUS                  0x04U
#define REG_RANGE                   0x08U
#define REG_ALPHA                   0x0CU
#define REG_BETA                    0x10U

#define STATUS_OUT_VALID            0x02U

#define UART_BASEADDR               XPAR_XUARTPS_0_BASEADDR
#define UART_BAUD_RATE              921600U

static XUartPs Uart;


/*
 * Initialize PS UART 1 and set its baud rate to 921600.
 */
static int uart_init(void) {
    XUartPs_Config *config;
    int status;

    config = XUartPs_LookupConfig(UART_BASEADDR);
    
    status = XUartPs_CfgInitialize(&Uart, config, config->BaseAddress);

    if (status != XST_SUCCESS) {
        return status;
    }

    XUartPs_SetOperMode(&Uart, XUARTPS_OPER_MODE_NORMAL);

    status = XUartPs_SetBaudRate(&Uart, UART_BAUD_RATE);

    if (status != XST_SUCCESS) {
        return status;
    }

    return XST_SUCCESS;
}

static uint8_t uart_read_byte(void) {
    return XUartPs_RecvByte(UART_BASEADDR);
}


static void uart_write_byte(uint8_t byte) {
    XUartPs_SendByte(UART_BASEADDR, byte);
}


static void uart_write_string(const char *text) {
    while (*text != '\0') {
        uart_write_byte((uint8_t)*text);
        text++;
    }
}

// Send an unsigned 32-bit value in little-endian order.
static void uart_write_uint32_le(uint32_t value) {
    uart_write_byte((uint8_t)(value & 0xFFU));
    uart_write_byte((uint8_t)((value >> 8) & 0xFFU));
    uart_write_byte((uint8_t)((value >> 16) & 0xFFU));
    uart_write_byte((uint8_t)((value >> 24) & 0xFFU));
}


// Send a signed 32-bit value in little-endian order.
static void uart_write_int32_le(int32_t value) {
    uart_write_uint32_le((uint32_t)value);
}


static void uart_write_frame_marker(void) {
    uart_write_string("NEXT_FRAME\n");
}


int main(void) {
    uint32_t range;
    int32_t alpha;
    int32_t beta;
    
    if (uart_init() != XST_SUCCESS) {
        while (1) {
            // UART failed
        }
    }
    
    // Wait until Python sends marker
    while (uart_read_byte() != (uint8_t)'S') {
    }
    
    uart_write_string("READY\r\n");

    while (1) {
        
        // Wait until AXI slave is valid
        while (
            (Xil_In32(BUF_BASE + REG_STATUS) &
             STATUS_OUT_VALID) == 0U
        ) {
        }
        
        range = Xil_In32(
            BUF_BASE + REG_RANGE
        );

        alpha = (int32_t)Xil_In32(
            BUF_BASE + REG_ALPHA
        );

        beta = (int32_t)Xil_In32(
            BUF_BASE + REG_BETA
        );

        uart_write_frame_marker();

        uart_write_uint32_le(range);
        uart_write_int32_le(alpha);
        uart_write_int32_le(beta);

        while (
            (Xil_In32(BUF_BASE + REG_STATUS) &
             STATUS_OUT_VALID) != 0U
        ) {
        }
    }

    return 0;
}