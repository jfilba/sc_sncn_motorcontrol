/**
 * @file  position_ctrl_server.xc
 * @brief Position Control Loop Server Implementation
 * @author Synapticon GmbH <support@synapticon.com>
*/
#include <xs1.h>
#include <xscope.h>
#include <print.h>
#include <stdlib.h>

#include <position_ctrl_service.h>
#include <a4935.h>
#include <mc_internal_constants.h>
#include <hall_service.h>
#include <qei_service.h>

void init_position_control(interface PositionControlInterface client i_position_control)
{
    int ctrl_state;

    while (1) {
        ctrl_state = i_position_control.check_busy();
        if (ctrl_state == INIT_BUSY) {
            i_position_control.enable_position_ctrl();
        }

        if (ctrl_state == INIT) {
#ifdef debug_print
            printstrln("position control intialized");
#endif
            break;
        }
    }
}

int position_limit(int position, int max_position_limit, int min_position_limit)
{
    if (position > max_position_limit) {
        position = max_position_limit;
    } else if (position < min_position_limit) {
        position = min_position_limit;
    }
    return position;
}

void position_control_service(ControlConfig &position_control_config,
                              interface HallInterface client ?i_hall,
                              interface QEIInterface client ?i_qei,
                              interface BISSInterface client ?i_biss,
                              interface MotorcontrolInterface client i_motorcontrol,
                              interface PositionControlInterface server i_position_control[3])
{
    int actual_position = 0;
    int target_position = 0;
    int error_position = 0;
    int error_position_D = 0;
    int error_position_I = 0;
    int previous_error = 0;
    int position_control_out = 0;

    int position_control_out_limit = 0;
    int error_position_I_limit = 0;

    timer t;
    unsigned int ts;

    int activate = 0;

    int config_update_flag = 1;

    int check_sensor = 1;

    printstr(">>   SOMANET POSITION CONTROL SERVICE STARTING...\n");

    t :> ts;

    while(1) {
#pragma ordered
        select {
            case t when timerafter(ts + USEC_STD * position_control_config.control_loop_period) :> ts:
                if (config_update_flag) {
                    MotorcontrolConfig motorcontrol_config = i_motorcontrol.get_config();

                    //Limits
                    if (motorcontrol_config.motor_type == BLDC_MOTOR) {
                        position_control_out_limit = BLDC_PWM_CONTROL_LIMIT;
                    } else if(motorcontrol_config.motor_type == BDC_MOTOR) {
                        position_control_out_limit = BDC_PWM_CONTROL_LIMIT;
                    }

                    if (position_control_config.feedback_sensor != HALL_SENSOR
                           && position_control_config.feedback_sensor != QEI_SENSOR
                           && position_control_config.feedback_sensor != BISS_SENSOR) {
                        position_control_config.feedback_sensor = motorcontrol_config.commutation_sensor;
                    }

                    if (position_control_config.Ki_n != 0) {
                        error_position_I_limit = position_control_out_limit * PID_DENOMINATOR / position_control_config.Ki_n;
                    }

                    if (position_control_config.feedback_sensor == HALL_SENSOR && !isnull(i_hall)) {
                        actual_position = i_hall.get_hall_position_absolute();
                    } else if (position_control_config.feedback_sensor == QEI_SENSOR && !isnull(i_qei)) {
                         // Check if a QEI sensor is connected
                         if (check_sensor) {
                             // Get status from sensor. Flag is set, when QEI service has detected a sensor transition
                             if (!i_qei.get_sensor_is_active())
                                 // Turn motor...
                                 i_motorcontrol.set_voltage(50);
                                 // ... and wait 10 ms
                                 delay_milliseconds(10);
                                 i_motorcontrol.set_voltage(0);
                             // Check, if transition was detected.
                             // If not, exit task
                             if (!i_qei.get_sensor_is_active()) {
                                 printstr("Error: QEI Sensor not connected\n");
                                 return;
                             }
                             else {
                                 check_sensor = 0;
                             }
                         }

                        actual_position = i_qei.get_qei_position_absolute();
                    } else if (position_control_config.feedback_sensor == BISS_SENSOR && !isnull(i_biss)) {
                        { actual_position, void, void } = i_biss.get_biss_position();
                    }

                    config_update_flag = 0;
                }

                if (activate == 1) {
                    /* acquire actual position hall/qei/sensor */
                    switch (position_control_config.feedback_sensor) {
                        case HALL_SENSOR:
                            if(!isnull(i_hall)){
                                actual_position = i_hall.get_hall_position_absolute();
                            }
                            else{
                                printstrln("ERROR: Hall interface is not provided but requested");
                                exit(-1);
                            }
                            break;

                        case QEI_SENSOR:
                            if(!isnull(i_qei)){
                                actual_position =  i_qei.get_qei_position_absolute();
                            }
                            else{
                                printstrln("ERROR: Encoder interface is not provided but requested");
                                exit(-1);
                            }
                            break;

                        case BISS_SENSOR:
                            if(!isnull(i_biss)){
                                { actual_position, void, void } = i_biss.get_biss_position();
                            }
                            else{
                                printstrln("ERROR: BiSS interface is not provided but requested");
                                exit(-1);
                            }
                            break;

                    }
                    /*
                     * Or any other sensor interfaced to the IFM Module
                     * place client functions here to acquire position
                     */

                    /* PID Controller */

                    error_position = (target_position - actual_position);
                    error_position_I = error_position_I + error_position;
                    error_position_D = error_position - previous_error;

                    if (error_position_I > error_position_I_limit) {
                        error_position_I = error_position_I_limit;
                    } else if (error_position_I < -error_position_I_limit) {
                        error_position_I = - error_position_I_limit;
                    }

                    position_control_out = (position_control_config.Kp_n * error_position) +
                                           (position_control_config.Ki_n * error_position_I) +
                                           (position_control_config.Kd_n * error_position_D);

                    position_control_out /= PID_DENOMINATOR;

                    if (position_control_out > position_control_out_limit) {
                        position_control_out = position_control_out_limit;
                    } else if (position_control_out < -position_control_out_limit) {
                        position_control_out =  -position_control_out_limit;
                    }

                   // set_commutation_sinusoidal(c_commutation, position_control_out);
                    i_motorcontrol.set_voltage(position_control_out);

#ifdef DEBUG
                    xscope_int(ACTUAL_POSITION, actual_position);
                    xscope_int(TARGET_POSITION, target_position);
#endif
                    //xscope_int(TARGET_POSITION, target_position);
                    previous_error = error_position;
                }

                break;

            case !isnull(i_hall) => i_hall.notification():

                switch (i_hall.get_notification()) {
                    case MOTCTRL_NTF_CONFIG_CHANGED:
                        config_update_flag = 1;
                        break;
                    default:
                        break;
                }
                break;

            case !isnull(i_qei) => i_qei.notification():

                switch (i_qei.get_notification()) {
                    case MOTCTRL_NTF_CONFIG_CHANGED:
                        config_update_flag = 1;
                        break;
                    default:
                        break;
                }
                break;

            case i_motorcontrol.notification():

                switch (i_motorcontrol.get_notification()) {
                    case MOTCTRL_NTF_CONFIG_CHANGED:
                        config_update_flag = 1;
                        break;
                    default:
                        break;
                }
                break;

            case i_position_control[int i].set_position(int in_target_position):

                target_position = in_target_position;

                break;

            case i_position_control[int i].get_position() -> int out_position:

                out_position = actual_position;
                break;

            case i_position_control[int i].get_target_position() -> int out_target_position:

                out_target_position = target_position;
                break;

            case i_position_control[int i].set_position_control_config(ControlConfig in_params):

                position_control_config = in_params;
                config_update_flag = 1;
                break;

            case i_position_control[int i].get_position_control_config() ->  ControlConfig out_config:

                out_config = position_control_config;
                break;

            case i_position_control[int i].set_position_sensor(int in_sensor_used):

                position_control_config.feedback_sensor = in_sensor_used;
                target_position = actual_position;
                config_update_flag = 1;

                break;

            case i_position_control[int i].check_busy() -> int out_activate:

                out_activate = activate;
                break;

            case i_position_control[int i].enable_position_ctrl():

                activate = 1;
                while (1) {
                    if (i_motorcontrol.check_busy() == INIT) { //__check_commutation_init(c_commutation);
#ifdef debug_print
                        printstrln("commutation intialized");
#endif
                        if (i_motorcontrol.get_fets_state() == 0) { // check_fet_state(c_commutation);
                            i_motorcontrol.set_fets_state(1);
                            delay_milliseconds(2);
                        }

                        break;
                    }
                }
#ifdef debug_print
                printstrln("position control activated");
#endif
                break;

            case i_position_control[int i].disable_position_ctrl():

                activate = 0;
                i_motorcontrol.set_voltage(0); //set_commutation_sinusoidal(c_commutation, 0);
                error_position = 0;
                error_position_D = 0;
                error_position_I = 0;
                previous_error = 0;
                position_control_out = 0;
                i_motorcontrol.set_fets_state(0); // disable_motor(c_commutation);
                delay_milliseconds(30); //wait_ms(30, 1, ts); //
#ifdef debug_print
                printstrln("position control disabled");
#endif
                break;
        }
    }
}

