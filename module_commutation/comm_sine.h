/*
 * comm_sine.h
 *
 *  Created on: 11.05.2012
 *      Author: mschwarz
 */

#pragma once

void comm_sine_init(chanend c_pwm_ctrl);

void comm_sine(chanend adc, chanend c_commutation, chanend c_hall, chanend c_pwm_ctrl);

void commutation(chanend c_adc, chanend  c_commutation,  chanend c_hall, chanend c_pwm_ctrl);

unsigned root_function(unsigned uSquareValue);

#define defParRpmMotorMax		3742
#define defParDefSpeedMax		4000
#define defParRPMreference		4000
#define defParAngleUser 		 300
#define defParAngleFromRPM 		 150
#define defParUmotBoost  		 100
#define defParUmotStart 		 150
#define defParSpeedKneeUmot 	3000
#define defParAngleCorrVal         1
#define defParAngleCorrMax		 300


#define defParRmsLimit			3000  // 66*4 = 264Bits/A


#define defParHysteresisPercent	   5
#define defParDiffSpeedMax		 150
#define defParUmotIntegralLimit	 512
#define defParPropGain			   8
#define defParIntegralGain		   8

#define defParViewXscope  		   0
