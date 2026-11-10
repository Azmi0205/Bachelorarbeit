#include "main.h"
#include "timer.h"
#include "platform_data.h"

// static variables
static uint32_t ms_timer = 0;

// static function prototypes
static void USER_tim3_task();

//-----------------------------------------------------------------------------

// function definitions
void tim3_task(UART_HandleTypeDef *huart, PlatformData_t* pData) {
	static uint8_t count = 0;
	if (count >= 10) {
		count = 0;
		ms_timer = ms_timer + 1;
		if (count >= 100){
			platform_printData(huart, pData);
		}
	}
}
