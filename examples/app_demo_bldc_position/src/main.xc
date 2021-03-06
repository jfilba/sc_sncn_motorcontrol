/* INCLUDE BOARD SUPPORT FILES FROM module_board-support */
#include <CORE_BOARD_REQUIRED>
#include <IFM_BOARD_REQUIRED>

/**
 * @file test_position-ctrl.xc
 * @brief Test illustrates usage of profile position control
 * @author Synapticon GmbH (www.synapticon.com)
 */

//BLDC Motor drive libs
#include <qei_service.h>
#include <hall_service.h>
#include <biss_service.h>
#include <pwm_service.h>
#include <watchdog_service.h>
#include <motorcontrol_service.h>

//Position control + profile libs
#include <position_ctrl_service.h>
#include <profile_control.h>

//Configuration headers
#include <user_config.h>

/* Test Profile Position function */
void position_profile_test(interface PositionControlInterface client i_position_control,
                           interface HallInterface client ?i_hall,
                           interface QEIInterface client ?i_qei,
                           interface BISSInterface client ?i_biss)
{
    int target_position = 16000;        // HALL: 1 rotation = 4096 x nr. pole pairs; QEI: your encoder documented resolution x 4 = one rotation
    int velocity        = 2000;         // rpm
    int acceleration    = 4000;         // rpm/s
    int deceleration    = 4000;         // rpm/s

    ProfilerConfig profiler_config;
    profiler_config.polarity = POLARITY;
    profiler_config.max_position = MAX_POSITION_LIMIT;
    profiler_config.min_position = MIN_POSITION_LIMIT;

    profiler_config.max_velocity = MAX_VELOCITY;
    profiler_config.max_acceleration = MAX_ACCELERATION;
    profiler_config.max_deceleration = MAX_DECELERATION;

    /* Initialise the position profile generator */
    init_position_profiler(profiler_config, i_position_control, i_hall, i_qei, i_biss);

    /* Set new target position for profile position control */
    set_profile_position(target_position, velocity, acceleration, deceleration, i_position_control);
}

PwmPorts pwm_ports = SOMANET_IFM_PWM_PORTS;
WatchdogPorts wd_ports = SOMANET_IFM_WATCHDOG_PORTS;
FetDriverPorts fet_driver_ports = SOMANET_IFM_FET_DRIVER_PORTS;
HallPorts hall_ports = SOMANET_IFM_HALL_PORTS;
#if(MOTOR_FEEDBACK_SENSOR == QEI_SENSOR)
QEIPorts qei_ports = SOMANET_IFM_QEI_PORTS;
#else
BISSPorts biss_ports = {QEI_PORT, SOMANET_IFM_GPIO_D0, IFM_TILE_CLOCK_2};
#endif

int main(void)
{
    // Motor control channels
    chan c_pwm_ctrl;            // pwm channel

    interface WatchdogInterface i_watchdog[2];
    interface MotorcontrolInterface i_motorcontrol[5];
    interface HallInterface i_hall[5];
#if(MOTOR_FEEDBACK_SENSOR == QEI_SENSOR)
    interface QEIInterface i_qei[5];
#else
    interface BISSInterface i_biss[5];
#endif

    interface PositionControlInterface i_position_control[3];

    par
    {
        /* Test Profile Position Client function*/
        on tile[APP_TILE]:
        {
#if(MOTOR_FEEDBACK_SENSOR == QEI_SENSOR)
            position_profile_test(i_position_control[0], i_hall[2], i_qei[2], null);      // test PPM on slave side
#else
            position_profile_test(i_position_control[0], i_hall[2], null, i_biss[2]);      // test PPM on slave side
#endif
        }

        on tile[APP_TILE]:
        /* XScope monitoring */
        {
            int actual_position, target_position;

            while(1)
            {
                /* Read actual position from the Position Control Server */
                actual_position = i_position_control[1].get_position();
                target_position = i_position_control[1].get_target_position();

                xscope_int(TARGET_POSITION, target_position/10); //Divided by 10 for better displaying
                xscope_int(ACTUAL_POSITION, actual_position/10); //Divided by 10 for better displaying

                delay_milliseconds(10); /* 1 ms wait */
            }
        }

        on tile[APP_TILE]:
        /* Position Control Loop */
        {
            ControlConfig position_control_config;

            position_control_config.feedback_sensor = MOTOR_FEEDBACK_SENSOR;

            position_control_config.Kp_n = POSITION_Kp;    // Divided by 10000
            position_control_config.Ki_n = POSITION_Ki;    // Divided by 10000
            position_control_config.Kd_n = POSITION_Kd;    // Divided by 10000

            position_control_config.control_loop_period = CONTROL_LOOP_PERIOD; //us

            /* Control Loop */
#if(MOTOR_FEEDBACK_SENSOR == QEI_SENSOR)
            position_control_service(position_control_config, i_hall[1], i_qei[1], null, i_motorcontrol[0],
                                     i_position_control);
#else
            position_control_service(position_control_config, i_hall[1], null, i_biss[1], i_motorcontrol[0],
                                     i_position_control);
#endif
        }

        /************************************************************
         * IFM_TILE
         ************************************************************/
        on tile[IFM_TILE]:
        {
            par
            {
                /* PWM Service */
                pwm_service(pwm_ports, c_pwm_ctrl);

                /* Watchdog Service */
                watchdog_service(wd_ports, i_watchdog);

                /* Hall sensor Service */
                {
                    HallConfig hall_config;
                    hall_config.pole_pairs = POLE_PAIRS;

                    hall_service(hall_ports, hall_config, i_hall);
                }

#if(MOTOR_FEEDBACK_SENSOR == QEI_SENSOR)
                /* Quadrature Encoder sensor Service */
                {
                    QEIConfig qei_config;
                    qei_config.signal_type = QEI_SENSOR_SIGNAL_TYPE;        // Encoder signal type (just if applicable)
                    qei_config.index_type = QEI_SENSOR_INDEX_TYPE;          // Indexed encoder?
                    qei_config.ticks_resolution = QEI_SENSOR_RESOLUTION;    // Encoder resolution
                    qei_config.sensor_polarity = QEI_SENSOR_POLARITY;       // CW

                    qei_service(qei_ports, qei_config, i_qei);
                }
#else
                /* BiSS service */
                {
                    BISSConfig biss_config;
                    biss_config.multiturn_length = BISS_MULTITURN_LENGTH;
                    biss_config.multiturn_resolution = BISS_MULTITURN_RESOLUTION;
                    biss_config.singleturn_length = BISS_SINGLETURN_LENGTH;
                    biss_config.singleturn_resolution = BISS_SINGLETURN_RESOLUTION;
                    biss_config.status_length = BISS_STATUS_LENGTH;
                    biss_config.crc_poly = BISS_CRC_POLY;
                    biss_config.pole_pairs = POLE_PAIRS;
                    biss_config.polarity = BISS_POLARITY;
                    biss_config.clock_dividend = BISS_CLOCK_DIVIDEND;
                    biss_config.clock_divisor = BISS_CLOCK_DIVISOR;
                    biss_config.timeout = BISS_TIMEOUT;
                    biss_config.max_ticks = BISS_MAX_TICKS;
                    biss_config.velocity_loop = BISS_VELOCITY_LOOP;
                    biss_config.offset_electrical = BISS_OFFSET_ELECTRICAL;

                    biss_service(biss_ports, biss_config, i_biss);
                }
#endif

                /* Motor Control Service */
                {
                    MotorcontrolConfig motorcontrol_config;
                    motorcontrol_config.motor_type = BLDC_MOTOR;
                    motorcontrol_config.commutation_sensor = MOTOR_COMMUTATION_SENSOR;
                    motorcontrol_config.bldc_winding_type = BLDC_WINDING_TYPE;
                    motorcontrol_config.hall_offset[0] = COMMUTATION_OFFSET_CLK;
                    motorcontrol_config.hall_offset[1] = COMMUTATION_OFFSET_CCLK;
                    motorcontrol_config.commutation_loop_period =  COMMUTATION_LOOP_PERIOD;

#if(MOTOR_FEEDBACK_SENSOR == QEI_SENSOR)
                    motorcontrol_service(fet_driver_ports, motorcontrol_config,
                                         c_pwm_ctrl, i_hall[0], i_qei[0], null, i_watchdog[0], i_motorcontrol);
#else
                    motorcontrol_service(fet_driver_ports, motorcontrol_config,
                                         c_pwm_ctrl, i_hall[0], null, i_biss[0], i_watchdog[0], i_motorcontrol);
#endif
                }
            }
        }
    }

    return 0;
}
