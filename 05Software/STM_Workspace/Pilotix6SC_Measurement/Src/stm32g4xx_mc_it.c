
/**
  ******************************************************************************
  * @file    stm32g4xx_mc_it.c
  * @author  Motor Control SDK Team, ST Microelectronics
  * @brief   Main Interrupt Service Routines.
  *          This file provides exceptions handler and peripherals interrupt
  *          service routine related to Motor Control for the STM32G4 Family.
  ******************************************************************************
  * @attention
  *
  * <h2><center>&copy; Copyright (c) 2026 STMicroelectronics.
  * All rights reserved.</center></h2>
  *
  * This software component is licensed by ST under Ultimate Liberty license
  * SLA0044, the "License"; You may not use this file except in compliance with
  * the License. You may obtain a copy of the License at:
  *                             www.st.com/SLA0044
  *
  ******************************************************************************
  * @ingroup STM32G4xx_IRQ_Handlers
  */

/* Includes ------------------------------------------------------------------*/
#include "mc_config.h"
#include "mc_type.h"
//cstat -MISRAC2012-Rule-3.1
#include "mc_tasks.h"
//cstat +MISRAC2012-Rule-3.1
#include "parameters_conversion.h"

/* USER CODE BEGIN Includes */

/* USER CODE END Includes */

/** @addtogroup MCSDK
  * @{
  */

/** @addtogroup STM32G4xx_IRQ_Handlers STM32G4xx IRQ Handlers
  * @{
  */

/* USER CODE BEGIN PRIVATE */

/* Private typedef -----------------------------------------------------------*/
/* Private define ------------------------------------------------------------*/
/* Private macro -------------------------------------------------------------*/
/* Private variables ---------------------------------------------------------*/
/* Private function prototypes -----------------------------------------------*/
/* Private functions ---------------------------------------------------------*/

/* USER CODE END PRIVATE */

void BEMF_READING_IRQHandler(void);
void PERIOD_COMM_IRQHandler(void);
void TIMx_BRK_M1_IRQHandler(void);

/**
  * @brief  This function handles BEMF sensing interrupt request from ADC1 and ADC2.
  * @param[in] None
  */
void BEMF_ADC1_2_READING_IRQHandler(void)
{
  /* USER CODE BEGIN CURRENT_REGULATION_IRQn 0 */

  /* USER CODE END CURRENT_REGULATION_IRQn 0 */

  if (LL_ADC_IsActiveFlag_AWD1(ADC1) != 0U)
  {
    if (LL_ADC_IsEnabledIT_AWD1(ADC1) != 0U)
    {
      /* Clear Flags. */
      LL_ADC_ClearFlag_AWD1(ADC1);
      MC_Perf_Measure_Start(&PerfTraces, (uint8_t)MEASURE_TSK_ADCTimerM1);
      TSK_BEMF_ZCD_Task();
      MC_Perf_Measure_Stop(&PerfTraces, (uint8_t)MEASURE_TSK_ADCTimerM1);
    }
    else
    {
      /* Nothing to do. */
    }
  }
  else
  {
    /* Nothing to do. */
  }

  if (LL_ADC_IsActiveFlag_AWD1(ADC2) != 0U)
  {
    if (LL_ADC_IsEnabledIT_AWD1(ADC2) != 0U)
    {
      /* Clear Flags. */
      LL_ADC_ClearFlag_AWD1(ADC2);
      MC_Perf_Measure_Start(&PerfTraces, (uint8_t)MEASURE_TSK_ADCTimerM1);
      TSK_BEMF_ZCD_Task();
      MC_Perf_Measure_Stop(&PerfTraces, (uint8_t)MEASURE_TSK_ADCTimerM1);
    }
    else
    {
      /* Nothing to do. */
    }
  }
  else
  {
    /* Nothing to do. */
  }

  /* USER CODE BEGIN CURRENT_REGULATION_IRQn 1 */

  /* USER CODE END CURRENT_REGULATION_IRQn 1 */

}

/**
  * @brief     LFtimer interrupt handler.
  * @param[in] None
  */
void PERIOD_COMM_IRQHandler(void)
{
  /* TIM Capture compare 1 event. */
  MC_Perf_Measure_Start(&PerfTraces, (uint8_t)MEASURE_TSK_SpeedTimerM1);

  if (LL_TIM_IsActiveFlag_CC1(TIM2) != 0U)
  {
    if (LL_TIM_IsEnabledIT_CC1(TIM2) != 0U)
    {
      LL_TIM_ClearFlag_CC1(TIM2);
      TSK_SpeedTIM_task();
    }
    else
    {
      /* Nothing to do. */
    }
  }
  else
  {
    /* Nothing to do. */
  }

  MC_Perf_Measure_Stop(&PerfTraces, (uint8_t)MEASURE_TSK_SpeedTimerM1);
}

/**
  * @brief  This function handles TIMx break-in interrupt request.
  * @param  None
  */
void TIMx_BRK_M1_IRQHandler(void)
{
  /* USER CODE BEGIN TIMx_BRK_M1_IRQn 0 */

  /* USER CODE END TIMx_BRK_M1_IRQn 0 */

  if (LL_TIM_IsActiveFlag_BRK(TIM1) != 0U)
  {
    LL_TIM_ClearFlag_BRK(TIM1);
    (void)PWMC_BRK_IRQHandler(&PWM_Handle_M1);
  }
  else
  {
    /* Nothing to do. */
  }

  if (LL_TIM_IsActiveFlag_BRK2(TIM1) != 0U)
  {
    LL_TIM_ClearFlag_BRK2(TIM1);
    (void)PWMC_BRK_IRQHandler(&PWM_Handle_M1);
  }
  else
  {
    /* Nothing to do. */
  }

  /* Systick is not executed due low priority so is necessary to call MC_Scheduler here. */
  MC_RunMotorControlTasks();

  /* USER CODE BEGIN TIMx_BRK_M1_IRQn 1 */

  /* USER CODE END TIMx_BRK_M1_IRQn 1 */
}

/* USER CODE BEGIN 1 */

/* USER CODE END 1 */

/**
  * @}
  */

/**
  * @}
  */
/******************* (C) COPYRIGHT 2026 STMicroelectronics *****END OF FILE****/
