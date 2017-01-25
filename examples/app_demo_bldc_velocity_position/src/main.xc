/* PLEASE REPLACE "CORE_BOARD_REQUIRED" AND "IFM_BOARD_REQUIRED" WITH AN APPROPRIATE BOARD SUPPORT FILE FROM module_board-support */
#include <CORE_C22-rev-a.bsp>
#include <IFM_DC1K-rev-c3.bsp>


/**
 * @brief Test illustrates usage of module_commutation
 * @date 17/06/2014
 */

//#include <pwm_service.h>
#include <pwm_server.h>
#include <adc_service.h>
#include <user_config.h>
#include <tuning.h>
#include <motor_control_interfaces.h>
#include <advanced_motor_control.h>
#include <advanced_motorcontrol_licence.h>
#include <position_feedback_service.h>

PwmPorts pwm_ports = SOMANET_IFM_PWM_PORTS;
WatchdogPorts wd_ports = SOMANET_IFM_WATCHDOG_PORTS;
FetDriverPorts fet_driver_ports = SOMANET_IFM_FET_DRIVER_PORTS;
ADCPorts adc_ports = SOMANET_IFM_ADC_PORTS;
HallPorts hall_ports = SOMANET_IFM_HALL_PORTS;
QEIPorts qei_ports = SOMANET_IFM_QEI_PORTS;
SPIPorts spi_ports = SOMANET_IFM_SPI_PORTS;
port ?gpio_port_0 = SOMANET_IFM_GPIO_D0;
port ?gpio_port_1 = SOMANET_IFM_GPIO_D1;
port ?gpio_port_2 = SOMANET_IFM_GPIO_D2;
port ?gpio_port_3 = SOMANET_IFM_GPIO_D3;

int main(void) {

    // Motor control interfaces
    interface WatchdogInterface i_watchdog[2];
    interface update_pwm i_update_pwm;
    interface update_brake i_update_brake;
    interface ADCInterface i_adc[2];
    interface MotorcontrolInterface i_motorcontrol[2];
    interface PositionVelocityCtrlInterface i_position_control[3];
    interface PositionFeedbackInterface i_position_feedback[3];
    interface shared_memory_interface i_shared_memory[2];
    interface PositionLimiterInterface i_position_limiter;

    par
    {
        /* WARNING: only one blocking task is possible per tile. */
        /* Waiting for a user input blocks other tasks on the same tile from execution. */
        on tile[APP_TILE]:
        {

            demo_torque_position_velocity_control(i_position_control[0]);
        }

        on tile[APP_TILE_2]:
        /* Position Control Loop */
        {
            PosVelocityControlConfig pos_velocity_ctrl_config;
            /* Control Loop */
            pos_velocity_ctrl_config.control_loop_period =                  CONTROL_LOOP_PERIOD; //us

            pos_velocity_ctrl_config.min_pos =                              MIN_POSITION_LIMIT;
            pos_velocity_ctrl_config.max_pos =                              MAX_POSITION_LIMIT;
            pos_velocity_ctrl_config.pos_limit_threshold =                  POSITION_LIMIT_THRESHOLD;
            pos_velocity_ctrl_config.max_speed =                            MAX_SPEED;
            pos_velocity_ctrl_config.max_torque =                           TORQUE_CONTROL_LIMIT;
            pos_velocity_ctrl_config.polarity =                             POLARITY;

            pos_velocity_ctrl_config.enable_profiler =                      ENABLE_PROFILER;
            pos_velocity_ctrl_config.max_acceleration_profiler =            MAX_ACCELERATION_PROFILER;
            pos_velocity_ctrl_config.max_speed_profiler =                   MAX_SPEED_PROFILER;

            pos_velocity_ctrl_config.control_mode =                         NL_POSITION_CONTROLLER;

            pos_velocity_ctrl_config.P_pos =                                POSITION_Kp;
            pos_velocity_ctrl_config.I_pos =                                POSITION_Ki;
            pos_velocity_ctrl_config.D_pos =                                POSITION_Kd;
            pos_velocity_ctrl_config.integral_limit_pos =                   POSITION_INTEGRAL_LIMIT;
            pos_velocity_ctrl_config.j =                                    MOMENT_OF_INERTIA;

            pos_velocity_ctrl_config.P_velocity =                           VELOCITY_Kp;
            pos_velocity_ctrl_config.I_velocity =                           VELOCITY_Ki;
            pos_velocity_ctrl_config.D_velocity =                           VELOCITY_Kd;
            pos_velocity_ctrl_config.integral_limit_velocity =              VELOCITY_INTEGRAL_LIMIT;

            pos_velocity_ctrl_config.position_fc =                          POSITION_FC;
            pos_velocity_ctrl_config.velocity_fc =                          VELOCITY_FC;
            pos_velocity_ctrl_config.resolution  =                          POSITION_SENSOR_RESOLUTION;
            pos_velocity_ctrl_config.special_brake_release =                ENABLE_SHAKE_BRAKE;
            pos_velocity_ctrl_config.brake_shutdown_delay =                 BRAKE_SHUTDOWN_DELAY;

            pos_velocity_ctrl_config.voltage_pull_brake=                    VOLTAGE_PULL_BRAKE;
            pos_velocity_ctrl_config.time_pull_brake =                      TIME_PULL_BRAKE;
            pos_velocity_ctrl_config.voltage_hold_brake =                   VOLTAGE_HOLD_BRAKE;

            init_brake(i_update_brake, IFM_TILE_USEC, VDC,
                    pos_velocity_ctrl_config.voltage_pull_brake,
                    pos_velocity_ctrl_config.time_pull_brake,
                    pos_velocity_ctrl_config.voltage_hold_brake);

            position_velocity_control_service(pos_velocity_ctrl_config, i_motorcontrol[0], i_position_control);
        }


        on tile[IFM_TILE]:
        {
            par
            {
                /* PWM Service */
                {
                    pwm_config(pwm_ports);

                    if (!isnull(fet_driver_ports.p_esf_rst_pwml_pwmh) && !isnull(fet_driver_ports.p_coast))
                        predriver(fet_driver_ports);

                    //pwm_check(pwm_ports);//checks if pulses can be generated on pwm ports or not
                    pwm_service_task(MOTOR_ID, pwm_ports, i_update_pwm,
                            i_update_brake, IFM_TILE_USEC);

                }

                /* ADC Service */
                {
                    adc_service(adc_ports, null/*c_trigger*/, i_adc /*ADCInterface*/, i_watchdog[1], IFM_TILE_USEC);
                }

                /* Watchdog Service */
                {
                    watchdog_service(wd_ports, i_watchdog, IFM_TILE_USEC);
                }

                /* Motor Control Service */
                {
                    MotorcontrolConfig motorcontrol_config;

                    motorcontrol_config.licence =  ADVANCED_MOTOR_CONTROL_LICENCE;
                    motorcontrol_config.v_dc =  VDC;
                    motorcontrol_config.commutation_loop_period =  COMMUTATION_LOOP_PERIOD;
                    motorcontrol_config.polarity_type=MOTOR_POLARITY;
                    motorcontrol_config.current_P_gain =  TORQUE_Kp;
                    motorcontrol_config.current_I_gain =  TORQUE_Ki;
                    motorcontrol_config.current_D_gain =  TORQUE_Kd;
                    motorcontrol_config.pole_pair =  POLE_PAIRS;
                    motorcontrol_config.commutation_sensor=MOTOR_COMMUTATION_SENSOR;
                    motorcontrol_config.commutation_angle_offset=COMMUTATION_OFFSET_CLK;
                    motorcontrol_config.hall_state_1_angle=HALL_STATE_1_ANGLE;
                    motorcontrol_config.hall_state_2_angle=HALL_STATE_2_ANGLE;
                    motorcontrol_config.hall_state_3_angle=HALL_STATE_3_ANGLE;
                    motorcontrol_config.hall_state_4_angle=HALL_STATE_4_ANGLE;
                    motorcontrol_config.hall_state_5_angle=HALL_STATE_5_ANGLE;
                    motorcontrol_config.hall_state_6_angle=HALL_STATE_6_ANGLE;
                    motorcontrol_config.max_torque =  MAXIMUM_TORQUE;
                    motorcontrol_config.phase_resistance =  PHASE_RESISTANCE;
                    motorcontrol_config.phase_inductance =  PHASE_INDUCTANCE;
                    motorcontrol_config.torque_constant =  PERCENT_TORQUE_CONSTANT;
                    motorcontrol_config.current_ratio =  CURRENT_RATIO;
                    motorcontrol_config.rated_current =  RATED_CURRENT;
                    motorcontrol_config.rated_torque  =  RATED_TORQUE;
                    motorcontrol_config.percent_offset_torque =  PERCENT_OFFSET_TORQUE;
                    motorcontrol_config.recuperation = RECUPERATION;
                    motorcontrol_config.battery_e_max = BATTERY_E_MAX;
                    motorcontrol_config.battery_e_min = BATTERY_E_MIN;
                    motorcontrol_config.regen_p_max = REGEN_P_MAX;
                    motorcontrol_config.regen_p_min = REGEN_P_MIN;
                    motorcontrol_config.regen_speed_max = REGEN_SPEED_MAX;
                    motorcontrol_config.regen_speed_min = REGEN_SPEED_MIN;
                    motorcontrol_config.protection_limit_over_current =  I_MAX;
                    motorcontrol_config.protection_limit_over_voltage =  V_DC_MAX;
                    motorcontrol_config.protection_limit_under_voltage = V_DC_MIN;

                    motor_control_service(motorcontrol_config, i_adc[0], i_shared_memory[1],
                            i_watchdog[0], i_motorcontrol, i_update_pwm, IFM_TILE_USEC);
                }

                /* Shared memory Service */
                [[distribute]] memory_manager(i_shared_memory, 2);

                /* Position feedback service */
                {
                    PositionFeedbackConfig position_feedback_config;
                    position_feedback_config.sensor_type = MOTOR_COMMUTATION_SENSOR;
                    position_feedback_config.polarity    = SENSOR_POLARITY;
                    position_feedback_config.pole_pairs  = POLE_PAIRS;
                    position_feedback_config.resolution  = POSITION_SENSOR_RESOLUTION;
                    position_feedback_config.offset      = 0;
                    position_feedback_config.enable_push_service = PushAll;

                    position_feedback_config.biss_config.multiturn_length = BISS_MULTITURN_LENGTH;
                    position_feedback_config.biss_config.multiturn_resolution = BISS_MULTITURN_RESOLUTION;
                    position_feedback_config.biss_config.singleturn_length = BISS_SINGLETURN_LENGTH;
                    position_feedback_config.biss_config.status_length = BISS_STATUS_LENGTH;
                    position_feedback_config.biss_config.crc_poly = BISS_CRC_POLY;
                    position_feedback_config.biss_config.clock_dividend = BISS_CLOCK_DIVIDEND;
                    position_feedback_config.biss_config.clock_divisor = BISS_CLOCK_DIVISOR;
                    position_feedback_config.biss_config.timeout = BISS_TIMEOUT;
                    position_feedback_config.biss_config.max_ticks = BISS_MAX_TICKS;
                    position_feedback_config.biss_config.velocity_loop = BISS_VELOCITY_LOOP;

                    position_feedback_config.rem_16mt_config.filter = REM_16MT_FILTER;
                    position_feedback_config.rem_16mt_config.timeout = REM_16MT_TIMEOUT;
                    position_feedback_config.rem_16mt_config.velocity_loop = REM_16MT_VELOCITY_LOOP;

                    position_feedback_config.qei_config.index_type = QEI_SENSOR_INDEX_TYPE;
                    position_feedback_config.qei_config.signal_type = QEI_SENSOR_SIGNAL_TYPE;

                    position_feedback_config.rem_14_config.factory_settings = 1;
                    position_feedback_config.rem_14_config.hysteresis = 1;
                    position_feedback_config.rem_14_config.noise_setting = REM_14_NOISE_NORMAL;
                    position_feedback_config.rem_14_config.uvw_abi = 0;
                    position_feedback_config.rem_14_config.dyn_angle_comp = 0;
                    position_feedback_config.rem_14_config.data_select = 0;
                    position_feedback_config.rem_14_config.pwm_on = REM_14_PWM_OFF;
                    position_feedback_config.rem_14_config.abi_resolution = 0;
                    position_feedback_config.rem_14_config.max_ticks = 0x7fffffff;
                    position_feedback_config.rem_14_config.cache_time = REM_14_CACHE_TIME;
                    position_feedback_config.rem_14_config.velocity_loop = REM_14_VELOCITY_LOOP;

                    position_feedback_service(hall_ports, qei_ports, spi_ports, gpio_port_0, gpio_port_1, gpio_port_2, gpio_port_3,
                            position_feedback_config, i_shared_memory[0], i_position_feedback,
                            null, null, null);
                }
            }
        }
    }

    return 0;
}
