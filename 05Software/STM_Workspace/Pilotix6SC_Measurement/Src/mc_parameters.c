
/**
  ******************************************************************************
  * @file    mc_parameters.c
  * @author  Motor Control SDK Team, ST Microelectronics
  * @brief   This file provides definitions of HW parameters specific to the
  *          configuration of the subsystem.
  *
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
  */

/* Includes ------------------------------------------------------------------*/
//cstat -MISRAC2012-Rule-21.1
#include "main.h" //cstat !MISRAC2012-Rule-21.1
//cstat +MISRAC2012-Rule-21.1
#include "parameters_conversion.h"
#include "pwmc_sixstep.h"

/* USER CODE BEGIN Additional include */

/* USER CODE END Additional include */
#define UH_POLARITY                 (uint16_t)(0x0000)
#define VH_POLARITY                 (uint16_t)(0x0000)
#define WH_POLARITY                 (uint16_t)(0x0000)
#define CCER_POLARITY_STEP14        UH_POLARITY | VH_POLARITY
#define CCER_POLARITY_STEP25        UH_POLARITY | WH_POLARITY
#define CCER_POLARITY_STEP36        WH_POLARITY | VH_POLARITY
#define CCER_POLARITY_MIDSTEP       UH_POLARITY | VH_POLARITY | WH_POLARITY

#define CCER_UH_VH                  (uint16_t)(0x1011)
#define CCER_UH_WH                  (uint16_t)(0x1101)
#define CCER_VH_WH                  (uint16_t)(0x1110)
#define CCER_UH_VH_WH               (uint16_t)(0x1111)
#define CCER_OFF                    (uint16_t)(0x1000)
#define CCER_STEP14                 CCER_UH_VH | CCER_POLARITY_STEP14
#define CCER_STEP25                 CCER_UH_WH | CCER_POLARITY_STEP25
#define CCER_STEP36                 CCER_VH_WH | CCER_POLARITY_STEP36
#define CCER_MIDSTEP                CCER_UH_VH_WH | CCER_POLARITY_MIDSTEP

#define CCER_OTF_BRAKE               CCER_OFF | CCER_POLARITY_MIDSTEP

#define CCMR1_CW_STEP1_MIDALIGN     (uint16_t)(0x4868)
#define CCMR1_CW_STEP2_MIDALIGN     (uint16_t)(0x4868)
#define CCMR1_CW_STEP3_MIDALIGN     (uint16_t)(0x6868)
#define CCMR1_CW_STEP4_MIDALIGN     (uint16_t)(0x6848)
#define CCMR1_CW_STEP5_MIDALIGN     (uint16_t)(0x6848)
#define CCMR1_CW_STEP6_MIDALIGN     (uint16_t)(0x4848)
#define CCMR2_CW_STEP1_MIDALIGN     (uint16_t)(0x6868)
#define CCMR2_CW_STEP2_MIDALIGN     (uint16_t)(0x6848)
#define CCMR2_CW_STEP3_MIDALIGN     (uint16_t)(0x6848)
#define CCMR2_CW_STEP4_MIDALIGN     (uint16_t)(0x6848)
#define CCMR2_CW_STEP5_MIDALIGN     (uint16_t)(0x6868)
#define CCMR2_CW_STEP6_MIDALIGN     (uint16_t)(0x6868)

#define CCMR1_CCW_STEP1_MIDALIGN    (uint16_t)(0x4868)
#define CCMR1_CCW_STEP2_MIDALIGN    (uint16_t)(0x6868)
#define CCMR1_CCW_STEP3_MIDALIGN    (uint16_t)(0x6848)
#define CCMR1_CCW_STEP4_MIDALIGN    (uint16_t)(0x6848)
#define CCMR1_CCW_STEP5_MIDALIGN    (uint16_t)(0x4848)
#define CCMR1_CCW_STEP6_MIDALIGN    (uint16_t)(0x4868)
#define CCMR2_CCW_STEP1_MIDALIGN    (uint16_t)(0x6848)
#define CCMR2_CCW_STEP2_MIDALIGN    (uint16_t)(0x6848)
#define CCMR2_CCW_STEP3_MIDALIGN    (uint16_t)(0x6848)
#define CCMR2_CCW_STEP4_MIDALIGN    (uint16_t)(0x6868)
#define CCMR2_CCW_STEP5_MIDALIGN    (uint16_t)(0x6868)
#define CCMR2_CCW_STEP6_MIDALIGN    (uint16_t)(0x6868)

#define CCMR1_STEP1_HSMOD           (uint16_t)(0x4868)
#define CCMR1_STEP2_HSMOD           (uint16_t)(0x0868)
#define CCMR1_STEP3_HSMOD           (uint16_t)(0x6808)
#define CCMR1_STEP4_HSMOD           (uint16_t)(0x6848)
#define CCMR1_STEP5_HSMOD           (uint16_t)(0x0848)
#define CCMR1_STEP6_HSMOD           (uint16_t)(0x4808)
#define CCMR2_STEP1_HSMOD           (uint16_t)(0x6808)
#define CCMR2_STEP2_HSMOD           (uint16_t)(0x6848)
#define CCMR2_STEP3_HSMOD           (uint16_t)(0x6848)
#define CCMR2_STEP4_HSMOD           (uint16_t)(0x6808)
#define CCMR2_STEP5_HSMOD           (uint16_t)(0x6868)
#define CCMR2_STEP6_HSMOD           (uint16_t)(0x6868)

#define CCMR1_STEP1_LSMOD           (uint16_t)(0x7858)
#define CCMR1_STEP2_LSMOD           (uint16_t)(0x0858)
#define CCMR1_STEP3_LSMOD           (uint16_t)(0x5808)
#define CCMR1_STEP4_LSMOD           (uint16_t)(0x5878)
#define CCMR1_STEP5_LSMOD           (uint16_t)(0x0878)
#define CCMR1_STEP6_LSMOD           (uint16_t)(0x7808)
#define CCMR2_STEP1_LSMOD           (uint16_t)(0x6808)
#define CCMR2_STEP2_LSMOD           (uint16_t)(0x6878)
#define CCMR2_STEP3_LSMOD           (uint16_t)(0x6878)
#define CCMR2_STEP4_LSMOD           (uint16_t)(0x6808)
#define CCMR2_STEP5_LSMOD           (uint16_t)(0x6858)
#define CCMR2_STEP6_LSMOD           (uint16_t)(0x6858)
#define CCMR1_ALL_ON                (uint16_t)(0x6868)
#define CCMR2_ALL_ON               (uint16_t)(0x6868)

/**
  * @brief  Current sensor parameters Motor 1 - single shunt phase shift
  */
const PWMC_Params_t PWMC_ParamsM1 =
{
/* PWM generation parameters --------------------------------------------------*/
  .TIMx              = TIM1,
/* PWM Driving signals initialization ----------------------------------------*/
  .pwm_en_u_port     = M1_PWM_EN_U_GPIO_Port,
  .pwm_en_u_pin      = M1_PWM_EN_U_Pin,
  .pwm_en_v_port     = M1_PWM_EN_V_GPIO_Port,
  .pwm_en_v_pin      = M1_PWM_EN_V_Pin,
  .pwm_en_w_port     = M1_PWM_EN_W_GPIO_Port,
  .pwm_en_w_pin      = M1_PWM_EN_W_Pin,
};

/**
  * @brief  PWM timer registers Motor 1
  */
PWMC_TimerCfg_t ThreePwm_TimerCfgM1 =
{
  .CCER_cfg = {
                CCER_STEP14,
                CCER_STEP25,
                CCER_STEP36,
                CCER_STEP14,
                CCER_STEP25,
                CCER_STEP36,
              },
  .CCER_Align_cfg = CCER_MIDSTEP,
  .CCMR1_BootCharge = CCMR1_ALL_ON,
  .CCMR2_BootCharge = CCMR2_ALL_ON,
  .CCMR1_Standard_cfg = {
                          CCMR1_STEP1_HSMOD,
                          CCMR1_STEP2_HSMOD,
                          CCMR1_STEP3_HSMOD,
                          CCMR1_STEP4_HSMOD,
                          CCMR1_STEP5_HSMOD,
                          CCMR1_STEP6_HSMOD,
                        },
  .CCMR2_Standard_cfg = {
                          CCMR2_STEP1_HSMOD,
                          CCMR2_STEP2_HSMOD,
                          CCMR2_STEP3_HSMOD,
                          CCMR2_STEP4_HSMOD,
                          CCMR2_STEP5_HSMOD,
                          CCMR2_STEP6_HSMOD,
                        },
  .CCMR1_CW_Align_cfg = {
                          CCMR1_CW_STEP2_MIDALIGN,
                          CCMR1_CW_STEP3_MIDALIGN,
                          CCMR1_CW_STEP4_MIDALIGN,
                          CCMR1_CW_STEP5_MIDALIGN,
                          CCMR1_CW_STEP6_MIDALIGN,
                          CCMR1_CW_STEP1_MIDALIGN,
                        },
  .CCMR2_CW_Align_cfg = {
                          CCMR2_CW_STEP2_MIDALIGN,
                          CCMR2_CW_STEP3_MIDALIGN,
                          CCMR2_CW_STEP4_MIDALIGN,
                          CCMR2_CW_STEP5_MIDALIGN,
                          CCMR2_CW_STEP6_MIDALIGN,
                          CCMR2_CW_STEP1_MIDALIGN,
                        },
  .CCMR1_CCW_Align_cfg = {
                          CCMR1_CCW_STEP6_MIDALIGN,
                          CCMR1_CCW_STEP1_MIDALIGN,
                          CCMR1_CCW_STEP2_MIDALIGN,
                          CCMR1_CCW_STEP3_MIDALIGN,
                          CCMR1_CCW_STEP4_MIDALIGN,
                          CCMR1_CCW_STEP5_MIDALIGN,
                        },
  .CCMR2_CCW_Align_cfg = {
                          CCMR2_CCW_STEP6_MIDALIGN,
                          CCMR2_CCW_STEP1_MIDALIGN,
                          CCMR2_CCW_STEP2_MIDALIGN,
                          CCMR2_CCW_STEP3_MIDALIGN,
                          CCMR2_CCW_STEP4_MIDALIGN,
                          CCMR2_CCW_STEP5_MIDALIGN,
                        },
  .CCMR1_LSMod_cfg = {
                          CCMR1_STEP1_LSMOD,
                          CCMR1_STEP2_LSMOD,
                          CCMR1_STEP3_LSMOD,
                          CCMR1_STEP4_LSMOD,
                          CCMR1_STEP5_LSMOD,
                          CCMR1_STEP6_LSMOD,
                         },
  .CCMR2_LSMod_cfg = {
                          CCMR2_STEP1_LSMOD,
                          CCMR2_STEP2_LSMOD,
                          CCMR2_STEP3_LSMOD,
                          CCMR2_STEP4_LSMOD,
                          CCMR2_STEP5_LSMOD,
                          CCMR2_STEP6_LSMOD,
                         },
};

OTF_TimerCfg_t OTFTimerCfgM1 =
{
  .CCER_cfg = {
                CCER_OTF_BRAKE,
                CCER_OTF_BRAKE,
                CCER_OTF_BRAKE,
                CCER_OTF_BRAKE,
                CCER_OTF_BRAKE,
                CCER_OTF_BRAKE,
              },
  .CCER_Brake_cfg = CCER_OTF_BRAKE,
};

ScaleParams_t scaleParams_M1 =
{
  .voltage = (1000 * PWM_PERIOD_CYCLES / (NOMINAL_BUS_VOLTAGE_V * NOMINAL_BUS_VOLTAGE_V)),
  .frequency = ((PWM_PERIOD_CYCLES * TIM_CLOCK_DIVIDER ) / (LF_TIMER_PSC + 1)),
};

/* USER CODE BEGIN Additional parameters */

/* USER CODE END Additional parameters */

/******************* (C) COPYRIGHT 2026 STMicroelectronics *****END OF FILE****/

