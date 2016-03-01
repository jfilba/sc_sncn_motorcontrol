/**
 * @file bldc_motorcontrol.h
 * @brief Commutation Loop based on sinusoidal commutation method
 * @author Synapticon GmbH <support@synapticon.com>
 */

#pragma once

#include <motorcontrol_service.h>
#include <adc_service.h>

/**
 * @brief Sinusoidal based Commutation Loop
 *
 * @param hall_config Structure defines the pole-pairs and gear ratio
 * @param qei_config the Structure defines sensor type and resolution parameters for QEI
 * @param i_hall Interface to hall Service
 * @param i_qei Interface to Incremental Encoder Service (QEI)
 * @param i_biss Interface to BiSS Encoder Service (QEI)
 * @param i_watchdog Interface to watchdog
 * @param i_motorcontrol Array of interfaces towards clients
 * @param c_pwm_ctrl channel to set PWM level output to motor phases
 * @param fet_driver_ports Structure containing FED driver ports
 * @param commutation_params Structure defines the commutation angle parameters
 *
 */
[[combinable]]
void bldc_loop(HallConfig hall_config, QEIConfig qei_config,
                            interface HallInterface client ?i_hall,
                            interface QEIInterface client ?i_qei,
                            interface BISSInterface client ?i_biss,
                            interface WatchdogInterface client i_watchdog,
                            interface MotorcontrolInterface server i_motorcontrol[4],
                            chanend c_pwm_ctrl,
                            FetDriverPorts &fet_driver_ports,
                            MotorcontrolConfig &commutation_params);

void foc_loop  (    FetDriverPorts &fet_driver_ports, server interface foc_base i_foc,
                    chanend c_pwm_ctrl, interface ADCInterface client ?i_adc, interface HallInterface client ?i_hall, interface WatchdogInterface client i_watchdog);

void space_vector_pwm(int umot, int angle,  int pwm_on_off, unsigned pwmout[]);
