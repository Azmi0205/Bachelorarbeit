#include "platform_data.h"
#include <stdio.h>
#include <string.h>

/**
 * @brief  Prints all fields of a PlatformData_t struct over UART (serial monitor).
 * @param  huart Pointer to the UART handle to transmit on (e.g. &huart2).
 * @param  pData Pointer to the PlatformData_t struct to print.
 * @note   Uses only STM32 HAL UART functions (HAL_UART_Transmit) and
 *         standard C sprintf for formatting -- no printf/stdio redirection
 *         is required.
 */
void platform_printData(UART_HandleTypeDef *huart, const PlatformData_t *pData)
{
    if (huart == NULL || pData == NULL)
    {
        return;
    }

    char buf[512];
    int len;

    len = snprintf(buf, sizeof(buf),
                  "---- Platform Data ----\r\n"
                  "Angle_Ref:      %.4f rad\r\n"
                  "Velocity_Ref:   %.4f rad/s\r\n"
                  "Angle:          %.4f rad\r\n"
                  "Velocity:       %.4f rad/s\r\n"
                  "PhaseA_Current: %.4f A\r\n"
                  "PhaseB_Current: %.4f A\r\n"
                  "PhaseC_Current: %.4f A\r\n"
                  "PhaseA_Voltage: %.4f V\r\n"
                  "PhaseB_Voltage: %.4f V\r\n"
                  "PhaseC_Voltage: %.4f V\r\n"
                  "BusVoltage:     %.4f V\r\n"
                  "------------------------\r\n",
                  pData->Angle_Ref,
                  pData->Velocity_Ref,
                  pData->Angle,
                  pData->Velocity,
                  pData->PhaseA_Current,
                  pData->PhaseB_Current,
                  pData->PhaseC_Current,
                  pData->PhaseA_Voltage,
                  pData->PhaseB_Voltage,
                  pData->PhaseC_Voltage,
                  pData->BusVoltage);

    if (len < 0)
    {
        return; /* formatting error */
    }

    HAL_UART_Transmit(huart, (uint8_t *)buf, (uint16_t)len, HAL_MAX_DELAY);
}
