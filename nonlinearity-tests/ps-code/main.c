#include "xparameters.h"
#include "xil_io.h"
#include "xstatus.h"
#include "xuartps.h"
#include "xuartps_hw.h"

#include <stdint.h>

#define SAMPLES_PER_RX              128
#define RX_COUNT                    3
#define FRAME_SAMPLES               (SAMPLES_PER_RX * RX_COUNT)

#define BUF_BASE                    XPAR_FMCW_OUTPUT_SLAVE_0_BASEADDR

#define REG_CONTROL                 0x00U
#define REG_STATUS                  0x04U
#define REG_OUT_DATA                0x08U

#define STATUS_OUT_VALID            0x02U

#define UART_BASEADDR               XPAR_XUARTPS_0_BASEADDR
#define UART_BAUD_RATE              921600U

static XUartPs Uart;

static int uart_init(void)
{
    XUartPs_Config *config;
    int status;

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

static uint8_t uart_read_byte(void)
{
    return XUartPs_RecvByte(UART_BASEADDR);
}

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

static void uart_write_uint16_le(uint16_t value)
{
    uart_write_byte((uint8_t)(value & 0xFFU));
    uart_write_byte((uint8_t)((value >> 8) & 0xFFU));
}

static void uart_write_frame_marker(void)
{
    uart_write_string("NEXT_FRAME\n");
}

int main(void)
{
    int i;

    uint32_t raw_sample;
    uint16_t sample;

    if (uart_init() != XST_SUCCESS) {
        while (1) {
            
        }
    }

    // Wait until the laptop sends the character 'S'.
    while (uart_read_byte() != (uint8_t)'S') {
    }

    uart_write_string("READY\r\n");

    Xil_Out32(BUF_BASE + REG_CONTROL, 1U);

    while (1) {

        // Wait until the first raw sample of the frame is available.
        while (
            (Xil_In32(BUF_BASE + REG_STATUS) &
             STATUS_OUT_VALID) == 0U
        ) {
        }
        
        // Mark the beginning of a new frame.

        uart_write_frame_marker();

        for (i = 0; i < FRAME_SAMPLES; i++) {

            while (
                (Xil_In32(BUF_BASE + REG_STATUS) &
                 STATUS_OUT_VALID) == 0U
            ) {
            }

            raw_sample = Xil_In32(
                BUF_BASE + REG_OUT_DATA
            );

            sample = (uint16_t)(raw_sample & 0x0FFFU);
            uart_write_uint16_le(sample);
        }
    }

    return 0;
}