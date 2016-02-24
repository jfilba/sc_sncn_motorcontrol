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

/////////////////////////////////////////////
//////  GENERAL MOTOR CONFIGURATION
////////////////////////////////////////////

// MOTOR TYPE [BLDC_MOTOR, BDC_MOTOR]
#define MOTOR_TYPE  BLDC_MOTOR

// NUMBER OF POLE PAIRS (if applicable)
#define POLE_PAIRS  2

// WINDING TYPE (if applicable) [STAR_WINDING, DELTA_WINDING]
#define BLDC_WINDING_TYPE   STAR_WINDING
