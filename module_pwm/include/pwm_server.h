/*
 * The copyrights, all other intellectual and industrial
 * property rights are retained by XMOS and/or its licensors.
 * Terms and conditions covering the use of this code can
 * be found in the Xmos End User License Agreement.
 *
 * Copyright XMOS Ltd 2013
 *
 * In the case where this code is a modification of existing code
 * under a separate license, the separate license terms are shown
 * below. The modifications to the code are still covered by the
 * copyright notice above.
 *
 **/

#ifndef _PWM_SERVER_H_
#define _PWM_SERVER_H_


#include <stdio.h>
#include <stdlib.h>

#include <xs1.h>
#include <assert.h>
#include <print.h>

#include <pwm_ports.h>
#include <motor_control_interfaces.h>

/**
 * @brief Define maximum possible values for general PWM server (which is able to
 * generate PWM pulses for up to 6 outputs.
 */
#define GENERAL_PWM_MAX_VALUE   0x1612

/**
 * @brief Define maximum possible values for general PWM server (which is able to
 * generate PWM pulses for up to 6 outputs.
 */
#define GENERAL_PWM_MIN_VALUE   0x0000

/**
 * @brief Structure type to define the ports to manage the FET-driver in your IFM SOMANET device (if applicable).
 */
typedef struct {
    port ?p_coast;                  /**< [Nullable] Port for management signals. */
    out port ?p_esf_rst_pwml_pwmh;  /**< [Nullable] 4-bit Port to  enabling operation signals (if applicable in your SOMANET device). */
    port ?p_ff1;                    /**< [Nullable] Port to read out faults (if applicable in your SOMANET device). */
    port ?p_ff2;                    /**< [Nullable] Port to read out faults (if applicable in your SOMANET device). */
} FetDriverPorts;

/**
 * @brief Structure containing pwm server control data
 */
typedef struct PWM_SERV_TAG
{
	int id;
	unsigned ref_time;
	int data_ready;
} PWM_SERV_TYP;

/**
 * @brief send the brake settings to pwm server
 * Internally called to adjust the pwm service parameters which are related to brake pull/hold operation.
 */
interface update_brake
{
    void update_brake_control_data(int duty_start_brake, int duty_maintain_brake, int period_start_brake);
};


/**
 * @brief Initialize the settings of electric brake
 *
 * @param i_update_brake        interface for transfering the brake settings into pwm server
 * @param ifm_tile_usec         number of clock ticks in one microsecond in ifm tile
 * @param vdc                   dc-bus voltage in volts
 * @param voltage_pull_brake    required voltage to release the brake at startup (in milli-volts)
 * @param time_pull_brake       amout of time in which the pull-voltage is applied to the brake (in milli-seconds)
 * @param voltage_hold_brake    required voltage to hold the brake after it is released (in milli-volts)
 *
 * @return void
 */
void init_brake(client interface update_brake i_update_brake, int ifm_tile_usec,
        int v_dc, int voltage_pull_brake, int time_pull_brake, int voltage_hold_brake);

/**
 * @brief Initialize the predriver circuit in your IFM SOMANET device (if applicable)
 *
 * @param fet_driver_ports  Structure of ports to manage the FET-driver in your IFM SOMANET device (if applicable).
 *
 * @return void
 */
void predriver(FetDriverPorts &fet_driver_ports);

/**
 * @brief Configure the pwm ports before starting pwm service.
 *
 * @param ports  Structure type for PWM ports.
 *
 * @return void
 */
void pwm_config_general(PwmPortsGeneral &ports);

/**
 * @brief Service to generate center-alligned PWM signals for 6 inverter outputs (2 power switch for each leg).
 * It recieves 6 pwm values through i_update_pwm interface. The commutation frequency is 16 kHz, and the deadtime is 3 us.
 *
 * @param ports                 Structure type for PWM ports
 * @param i_update_pwm          Interface to communicate with client and update the PWM values
 *
 * @return void
 */
void pwm_service_general(
        PwmPortsGeneral &ports,
        server interface update_pwm_general i_update_pwm
);

/**
 * @brief Configure the pwm ports before starting pwm service.
 *
 * @param ports  Structure type for PWM ports
 *
 * @return void
 */
void pwm_config(PwmPorts &ports);

/**
 * @brief Service to generate center-alligned PWM signals for 3 inverter outputs.
 * it also provides PWM signals to turn on/off an electric brake.
 *
 * @param motor_id              Motor ID (the default value is 0)
 * @param ports                 Structure type for PWM ports
 * @param i_update_pwm          Interface to communicate with client and update the PWM values
 * @param duty_start_brake      PWM value which is used to start the electric brake
 * @param duty_maintain_brake   PWM value which is used to maintain the electric brake
 * @param time_start_brake      Required time to start the brake (in milliseconds)
 * @param ifm_tile_usec         Reference clock frequency of IFM tile (in MHz)
 *
 * @return void
 */
void pwm_service_task( // Implementation of the Centre-aligned, High-Low pair, PWM server, with ADC synchronization
        unsigned motor_id, // Motor identifier
        PwmPorts &ports,
        server interface update_pwm i_update_pwm,
        server interface update_brake i_update_brake,
        int ifm_tile_usec
);



#endif // _PWM_SERVER_H_
