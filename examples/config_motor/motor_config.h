/**
 * @file motor_config.h
 * @brief Motor Control config file (define your motor specifications here)
 * @author Synapticon GmbH <support@synapticon.com>
 *
 *   Example motor config file
 */

/**************************************************
 *********      USER CONFIGURATION       **********
 **************************************************/
#include <motor_config_MABI_Hohlwellenservomotor_A5.h>

/////////////////////////////////////////////
//////  APPLICATION CONFIGURATIONS
////////////////////////////////////////////

#define MILLI_SQRT_TWO_THIRD 1224 //1000 * sqrt(2/3)

#define VDC             48

/////////////////////////////////////////////
//////  GENERAL MOTOR CONFIGURATION
////////////////////////////////////////////

// MOTOR TYPE [BLDC_MOTOR, BDC_MOTOR]
#define MOTOR_TYPE  BLDC_MOTOR

// WINDING TYPE (if applicable) [STAR_WINDING, DELTA_WINDING]
#define BLDC_WINDING_TYPE   STAR_WINDING

// MOTOR POLARITY [NORMAL_POLARITY, INVERTED_POLARITY]
#define MOTOR_POLARITY      NORMAL_POLARITY





