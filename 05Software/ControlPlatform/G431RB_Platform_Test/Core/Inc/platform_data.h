#ifndef PLATFORM_DATA_H
#define PLATFORM_DATA_H

#include <stdint.h>
#include "main.h"

typedef struct
{
	float Angle_Ref;	   /* Rotor position reference in rad */
	float Velocity_Ref;     /* Rotor speed reference in rad/s */
    float Angle;           /* Rotor position in rad */
    float Velocity;		   /* Rotor speed in rad/s */
    float PhaseA_Current;  /* Ia in Amps */
    float PhaseB_Current;  /* Ib in Amps */
    float PhaseC_Current;  /* Ic in Amps */
    float PhaseA_Voltage;  /* Va in Volts */
    float PhaseB_Voltage;  /* Vb in Volts */
    float PhaseC_Voltage;  /* Vc in Volts */
    float BusVoltage;      /* DC bus voltage in Volts */
} PlatformData_t;

void platform_printData(UART_HandleTypeDef *huart, const PlatformData_t *pData);

#endif /* PLATFORM_DATA_H */
