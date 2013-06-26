/*
 *
 * File:    qei_client.h
 *
 * Get the position from the QEI server
 *
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
 */                                   
#ifndef __QEI_CLIENT_H__
#define __QEI_CLIENT_H__

#include<dc_motor_config.h>

///only position and valid
{unsigned, unsigned} get_qei_position(chanend c_qei );

//counted up position and direction
{int, int} get_qei_position_count(chanend c_qei);




#endif /* __QEI_CLIENT_H__ */
