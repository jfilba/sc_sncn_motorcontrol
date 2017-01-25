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
 **/

#include "pwm_convert_width.h"

/**
 * @brief Converts PWM structure reference to address.
 *
 * @param pwm_ps Pointer to PWM control structure
 * @return Address
 */
unsigned long get_pwm_struct_address( // Converts PWM structure reference to address
	PWM_ARRAY_TYP * pwm_ps // Pointer to PWM control structure
) // Return wrapped offset
{
	return (unsigned long)pwm_ps; // Return Address
} // get_pwm_struct_address


/**
 * @brief Convert pulse width to a 32-bit pattern and a time-offset
 *
 * @param pwm_comms_ps          Pointer to structure containing PWM communication data
 * @param rise_port_data_ps     Pointer to port data structure (for one leg of balanced line for rising edge )
 * @param fall_port_data_ps     Pointer to port data structure (for one leg of balanced line for falling edge)
 * @param inp_wid
 * @param pwm_deadtime
 * @param pwm_max_value
 * @param pwm_deadtime
 *
 * @return void
 */
static void convert_pulse_width(
	PWM_COMMS_TYP * pwm_comms_ps,
	PWM_PORT_TYP  * rise_port_data_ps,
	PWM_PORT_TYP  * fall_port_data_ps,
	unsigned inp_wid,
	unsigned pwm_max_value,
	unsigned pwm_deadtime
)
{
	unsigned num_zeros; // No of Zero bits in 32-bit unsigned
	unsigned tmp;


	// Check for short pulse
	if (inp_wid < _PWM_PORT_WID)/// PWM_PORT_WID = 32
	{ // Short Pulse:

		rise_port_data_ps->time_off = -_PWM_PORT_WID; // NB Fixed time-offset is at previous 32-bit boundary
		tmp = (inp_wid + 1) >> 1; // Range [0..16]
		tmp = ((1 << tmp)-1); // Range 0x0000_0000 .. 0x0000_FFFF
		rise_port_data_ps->pattern = bitrev( tmp ); // Pattern in range 0x0000_0000 .. 0xFFFF_0000

		// NB Need MSB to be zero, as this lasts for long low section of pulse
		fall_port_data_ps->time_off = 0; // NB Fixed time-offset is at datum
		tmp = (inp_wid >> 1); // Range [0..15]
		fall_port_data_ps->pattern = ((1 << tmp)-1); // Pattern in range 0x0000_0000 .. 0x7FFF_0000

	} // if (inp_wid < PWM_PORT_WID)
	else
	{ // NOT a short pulse
		num_zeros = pwm_max_value - inp_wid; // Calculate No. of 0's in this pulse

		// Check for mid-range pulse
		if (num_zeros > (_PWM_PORT_WID - 1))
		{ // Mid-range Pulse

			rise_port_data_ps->pattern = 0xFFFF0000; // Fixed rising-edge pattern
			rise_port_data_ps->time_off = -((inp_wid + (_PWM_PORT_WID + 1)) >> 1); // Earlier time-offset based on pulse-width

			fall_port_data_ps->pattern = 0x0000FFFF; // Fixed falling-edge pattern
			fall_port_data_ps->time_off = ((inp_wid - _PWM_PORT_WID) >> 1); // Later time-offset based on pulse-width
		} // if (num_zeros > (PWM_PORT_WID - 1))
		else
		{ // Long pulse

			// NB Need MSB to be 1, as this lasts for long high section of pulse
			rise_port_data_ps->time_off = -(pwm_max_value >> 1); // Fixed time-offset is half PWM-cycle earlier
			tmp = (num_zeros >> 1); // Range [15..0]
			tmp = ((1 << tmp)-1); // Range 0x0000_7FFF .. 0x0000_0000
			rise_port_data_ps->pattern = ~tmp; // Invert Pattern: Range 0xFFFF_8000 .. 0xFFFF_FFFF

			fall_port_data_ps->time_off = (pwm_max_value >> 1) - _PWM_PORT_WID; // Fixed time-offset is (half PWM-cycle - 32 bits) later
			tmp = ((num_zeros + 1) >> 1); // Range [16..0]
			tmp = ((1 << tmp)-1); // Range 0x0000_FFFF .. 0x0000_0000
			tmp = ~tmp; // Invert Pattern: Range 0xFFFF_0000 .. 0xFFFF_FFFF
			fall_port_data_ps->pattern = bitrev( tmp ); // Invert Pattern: Range 0x0000_FFFF .. 0xFFFF_FFFF

		} // else !(num_zeros > (PWM_PORT_WID - 1))
	} // else !(inp_wid < PWM_PORT_WID)

	return;
} // convert_pulse_width


/**
 * @brief Convert PWM pulse widths for current phase to pattern/time_offset port data.
 * WARNING: Both legs of the balanced line must NOT be switched at the same time. Safety Critical.
 * Calculate PWM Pulse data for low leg (V+) of balanced line
 *
 * @param pwm_comms_ps          Pointer to structure containing PWM communication data
 * @param rise_port_data_ps     Pointer to PWM output data structure for rising edge of current phase
 * @param fall_port_data_ps     Pointer to PWM output data structure for falling edge of current phase
 * @param inp_wid               PWM pulse-width value for Hi-leg
 * @param pwm_max_value         PWM maximum value
 * @param pwm_deadtime          deadtime value (in clock ticks)
 *
 * @return void
 */
static void convert_phase_pulse_widths(
	PWM_COMMS_TYP * pwm_comms_ps,
	PWM_PHASE_TYP * rise_phase_data_ps,
	PWM_PHASE_TYP * fall_phase_data_ps,
	unsigned hi_wid,
	unsigned int pwm_max_value,
	unsigned int pwm_deadtime
)
{
	unsigned lo_wid = (hi_wid + pwm_deadtime);

	assert(lo_wid < pwm_max_value); // Ensure Low-leg pulse NOT too wide

	// Calculate PWM Pulse data for high leg (V+) of balanced line
	convert_pulse_width( pwm_comms_ps ,&(rise_phase_data_ps->hi) ,&(fall_phase_data_ps->hi) ,hi_wid, pwm_max_value, pwm_deadtime );

	// NB In do_pwm_period() (pwm_service_inv.xc) ADC Sync occurs at (ref_time + HALF_DEAD_TIME)

	convert_pulse_width( pwm_comms_ps ,&(rise_phase_data_ps->lo) ,&(fall_phase_data_ps->lo) ,lo_wid, pwm_max_value, pwm_deadtime );
} // convert_phase_pulse_widths


/**
 * @brief Convert all PWM pulse widths to pattern/time_offset port data
 *
 * @param pwm_comms_ps      Pointer to structure containing PWM communication data
 * @param pwm_buf_ps        Pointer to Structure containing buffered PWM output data
 * @param pwm_max_value     Maximum pwm value which can be sent to pwm server (number of clock ticks)
 * @param pwm_deadtime      Number of clock ticks in over deadtime period
 *
 * @return void
 */
void convert_all_pulse_widths( // Convert all PWM pulse widths to pattern/time_offset port data
	PWM_COMMS_TYP * pwm_comms_ps, // Pointer to structure containing PWM communication data
	PWM_BUFFER_TYP * pwm_buf_ps,   // Pointer to Structure containing buffered PWM output data
	unsigned int pwm_max_value,
	unsigned int pwm_deadtime
)
{
	for (int phase_cnt = 0; phase_cnt < _NUM_PWM_PHASES; phase_cnt++)
	{ // Convert PWM pulse widths for this phase to pattern/time_offset port data

		convert_phase_pulse_widths( pwm_comms_ps ,&(pwm_buf_ps->rise_edg.phase_data[phase_cnt])
			,&(pwm_buf_ps->fall_edg.phase_data[phase_cnt]) ,pwm_comms_ps->params.widths[phase_cnt], pwm_max_value, pwm_deadtime );
	} // for phase_cnt
} // convert_all_pulse_widths


/**
 * @brief Converts PWM Pulse-width to port data in shared memory
 *
 * @param pwm_comms_ps      Pointer to structure containing PWM communication data
 * @param pwm_max_value     Maximum pwm value which can be sent to pwm server (number of clock ticks)
 * @param pwm_deadtime      Number of clock ticks in over deadtime period
 *
 * @return void
 */
void convert_widths_in_shared_mem( // Converts PWM Pulse-width to port data in shared memory area
	PWM_COMMS_TYP * pwm_comms_ps, // Pointer to structure containing PWM communication data
    unsigned int pwm_max_value,
    unsigned int pwm_deadtime)
{	// Cast shared memory address pointer to PWM double-buffered data structure
	PWM_ARRAY_TYP * pwm_ctrl_ps = (PWM_ARRAY_TYP *)pwm_comms_ps->mem_addr;

	// Convert widths and write to current PWM buffer
	convert_all_pulse_widths( pwm_comms_ps ,&(pwm_ctrl_ps->buf_data[pwm_comms_ps->buf]), pwm_max_value, pwm_deadtime );

} // convert_widths_in_shared_mem
