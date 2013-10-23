/*
 *
 * \file
 * \brief Main project file
 *
 * Port declarations, etc.
 *
 * \author Martin Schwarz <mschwarz@synapticon.com>
 * \version 0.1 (2012-11-23 1850)
 *\Motor 3 motion profile size optimized code for position ctrl loops
 */

#include <xs1.h>
#include <platform.h>
#include <print.h>
#include <stdio.h>
#include <stdint.h>
#include "ioports.h"
#include "hall_server.h"
#include "hall_client.h"
#include "hall_qei.h"
#include "qei_client.h"
#include "pwm_service_inv.h"
#include "adc_ad7949.h"
#include "test.h"
#include "comm_loop.h"
#include "refclk.h"
#include <xscope.h>
#include "qei_client.h"
#include "qei_server.h"
#include "adc_client_ad7949.h"
#include <dc_motor_config.h>
#include <torque_ctrl.h>
#include <flash_somanet.h>
#include <internal_config.h>
#include <drive_config.h>
int root_function(int arg);
#define ENABLE_xscope_main
#define COM_CORE 0
#define IFM_CORE 3

on stdcore[IFM_CORE]: clock clk_adc = XS1_CLKBLK_1;
on stdcore[IFM_CORE]: clock clk_pwm = XS1_CLKBLK_REF;

#define HALL 1
#define QEI 2



int main(void)
{
	chan c_adc, c_adctrig;
	chan c_qei_p1, c_qei_p2, c_qei_p3, c_qei_p4, c_qei_p5 ;
	chan c_hall_p1, c_hall_p2, c_hall_p3, c_hall_p4;
	chan c_commutation_p1, c_commutation_p2, c_commutation_p3;
	chan sync_output;
	chan c_pwm_ctrl;
	chan dummy, dummy1, dummy2;
	chan c_signal_adc;
	chan c_sig_1, c_signal, c_sync;
	chan c_torque_ctrl, signal_ctrl, c_calib, c_req, c_vel;

	//etherCat Comm channels
	chan coe_in; 	///< CAN from module_ethercat to consumer
	chan coe_out; 	///< CAN from consumer to module_ethercat
	chan eoe_in; 	///< Ethernet from module_ethercat to consumer
	chan eoe_out; 	///< Ethernet from consumer to module_ethercat
	chan eoe_sig;
	chan foe_in; 	///< File from module_ethercat to consumer
	chan foe_out; 	///< File from consumer to module_ethercat
	chan pdo_in;
	chan pdo_out;

	chan c_test_in;
	//
	par
	{
		on stdcore[0]:
		{
			{
				ctrl_par torque_ctrl_params;
				hall_par hall_params;
				qei_par qei_params;
				init_qei_param(qei_params);
				init_hall_param(hall_params);
				init_torque_control_param(torque_ctrl_params);
				torque_ctrl( torque_ctrl_params, hall_params, qei_params, c_adc,  sync_output, \
						c_commutation_p1,  c_hall_p3,  c_qei_p3, c_torque_ctrl);
			}
		}


		on stdcore[1]:
		{
			par
			{
				{
			xscope_register(14, XSCOPE_CONTINUOUS, "0 hall(delta)", XSCOPE_INT,
					"n", XSCOPE_CONTINUOUS, "1 qei", XSCOPE_INT, "n",
					XSCOPE_CONTINUOUS, "2 pos", XSCOPE_INT, "n",
					XSCOPE_DISCRETE, "3 ep", XSCOPE_INT, "n", XSCOPE_DISCRETE,
					"4 ev", XSCOPE_INT, "n", XSCOPE_CONTINUOUS, "5 pos_d",
					XSCOPE_INT, "n", XSCOPE_CONTINUOUS, "6 vel_d", XSCOPE_INT,
					"n", XSCOPE_CONTINUOUS, "7 speed", XSCOPE_INT, "n",
					XSCOPE_CONTINUOUS, "8 sinepos_a", XSCOPE_UINT, "n",
					XSCOPE_CONTINUOUS, "9 sinepos_b", XSCOPE_UINT, "n",
					XSCOPE_CONTINUOUS, "10 sinepos_c", XSCOPE_UINT, "n",
					XSCOPE_CONTINUOUS, "11 sine_a", XSCOPE_UINT, "n",
					XSCOPE_CONTINUOUS, "12 sine_b", XSCOPE_UINT, "n",
					XSCOPE_CONTINUOUS, "13 sine_c", XSCOPE_UINT, "n");
			xscope_config_io(XSCOPE_IO_BASIC);
				}

				{
						int command;
						int init = 0;
						timer t;
						unsigned int time;

						t:>time;
						while (1)
						{
							t when timerafter(time+2*MSEC_STD) :> time;
							init = __check_torque_init(c_torque_ctrl);
							if(init == INIT)
							{
								printstrln("torque control intialized");
								break;
							}
						}
						t:>time;
						while(1)
						{
							//t when timerafter(time+2*MSEC_STD) :> time;
							set_torque_test(c_torque_ctrl);//
						//	set_torque(c_torque_ctrl, 100);
						}
						//while(1);
					}

			}
		}

		on stdcore[2]:
		{
			par
			{
			/*	{
					hall_par hall_params;
					qei_par qei_params;
					commutation_par commutation_params;
					init_qei_param(qei_params);
					init_hall_param(hall_params);
					init_commutation_param(commutation_params, hall_params, MAX_NOMINAL_SPEED);
					hall_qei_sync(qei_params, hall_params, commutation_params, c_qei_p1, c_hall_p2, sync_output, c_calib);
				}*/

			/*	{
					hall_par hall_params;
					init_hall_param(hall_params);
					current_ctrl_loop(hall_params, c_signal_adc, c_adc, c_hall_p3,
							sync_output, c_commutation_p1, c_torque_ctrl);
				}*/


			}
		}

		/************************************************************
		 * IFM_CORE
		 ************************************************************/
		on stdcore[IFM_CORE]:
		{
			par
			{

				adc_ad7949_triggered(c_adc, c_adctrig, clk_adc,
						p_ifm_adc_sclk_conv_mosib_mosia, p_ifm_adc_misoa,
						p_ifm_adc_misob);

				do_pwm_inv_triggered(c_pwm_ctrl, c_adctrig, p_ifm_dummy_port,
						p_ifm_motor_hi, p_ifm_motor_lo, clk_pwm);

				{
					int sensor_select = 1;
					hall_par hall_params;
					qei_par qei_params;
					commutation_par commutation_params;
					init_hall_param(hall_params);
					init_qei_param(qei_params);
					init_commutation_param(commutation_params, hall_params, MAX_NOMINAL_SPEED); // initialize commutation params
					commutation_sinusoidal(c_hall_p1,  c_qei_p2,\
									 c_signal, c_sync, c_commutation_p1, c_commutation_p2,\
									 c_commutation_p3, c_pwm_ctrl, sensor_select, hall_params,\
									 qei_params, commutation_params);

				}

				{
					hall_par hall_params;
					init_hall_param(hall_params);
					run_hall(c_hall_p1, c_hall_p2, c_hall_p3, c_hall_p4, p_ifm_hall, hall_params); // channel priority 1,2..4
				}

				{
					qei_par qei_params;
					init_qei_param(qei_params);
					run_qei(c_qei_p1, c_qei_p2, c_qei_p3, c_qei_p4, p_ifm_encoder, qei_params);  // channel priority 1,2..4
				}

			}
		}

	}

	return 0;
}
