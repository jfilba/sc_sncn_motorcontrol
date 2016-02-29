/**
 * @file adc_service.h
 * @author Synapticon GmbH <support@synapticon.com>
 */

#pragma once

#include <xs1.h>

/**
 * Max value the ADC can provide.
 */
#define MAX_ADC_VALUE 16383

/**
 * @brief Interface type to communicate with the ADC Service.
 */
interface ADCInterface{
    // *Max adc ticks are 8192 and corresponds with the max current your DC can handle:
    // DC100: 5A, DC300: 20A, DC1K 50A
    /**
     * @brief Get the ongoing current at B and C Phases.
     *
     * @return Current on B Phase [-8191:8192]. (8192 is equivalent to the max current your SOMANET IFM DC device can handle: DC100: 5A, DC300: 20A, DC1K 50A).
     * @return Current on C Phase [-8191:8192]. (8192 is equivalent to the max current your SOMANET IFM DC device can handle: DC100: 5A, DC300: 20A, DC1K 50A).
     */
    {int, int} get_currents();

    /**
     * @brief Get the value from the temperature sensor on your SOMANET device.
     *        The translation of this value into degrees will depend on your SOMANET device.
     *
     * @return Temperature [0:16383].
     */
    int get_temperature();

    /**
     * @brief Get the voltage value present at the external analog inputs of your SOMANET device.
     *
     * @return Voltage at analog input 1 [0:16384].
     * @return Voltage at analog input 2 [0:16384].
     */
    {int, int} get_external_inputs();

    /**
     * @brief Helper to convert Amps into a suitable ADC value for your SOMANET device.
     *        The output of this helper would be suitable, for instance, as target torque
     *        for a Torque Control Service.
     *
     * @return amps Ampers to convert [A]
     */
    int helper_amps_to_ticks(float amps);

    /**
     * @brief Helper to convert an ADC current value into Amps.
     *
     * @param ticks ADC current value [-8191:8192].
     * @return Amps [A].
     */
    float helper_ticks_to_amps(int ticks);
};

/**
 * Structure type to define the ports to manage the AD7949 ADC chip.
 */
typedef struct {
     buffered out port:32 ?sclk_conv_mosib_mosia;   /**< [[Nullable]] 4-bit Port for ADC management */
     in buffered port:32 ?data_a;   /**< [[Nullable]] 32-bit buffered ADC data port a */
     in buffered port:32 ?data_b;   /**< [[Nullable]] 32-bit buffered ADC data port b */
     clock ?clk;                    /**< [[Nullable]] Internal XMOS clock. */
}AD7949Ports;

/**
 * Structure type to define the ports to manage the AD7265 ADC chip.
 */
typedef struct {
    in buffered port:32 ?p32_data[2]; /**< [[Nullable]] Array of 32-bit buffered ADC data ports. */
    clock ?xclk;  /**< [[Nullable]] Internal XMOS clock. */
    out port ?p1_serial_clk; /**< [[Nullable]] Port connecting to external ADC serial clock. */
    port ?p1_ready;   /**< [[Nullable]] Port used to as ready signal for p32_adc_data ports and ADC chip. */
    out port ?p4_mux; /**< [[Nullable]] 4-bit Port used to control multiplexor on ADC chip. */
} AD7265Ports;

/**
 * Structure type for current measurement configuration.
 */
typedef struct {
    int sign_phase_b;   /**< Direction in which current on B Phase is measured [-1,1]. */
    int sign_phase_c;   /**< Direction in which current on C Phase is measured [-1,1]. */
    unsigned current_sensor_amplitude;  /**< Max amplitude of current the sensors on your DC board can handle. */
}CurrentSensorsConfig;

/**
 * Enum type with the two supported ADCs.
 */
enum ADCType {AD7949, AD7265};

/**
 * Structe type for the adc config.
 */
typedef struct {
    ADCType adc_type; /**< ADC type (AD7949, AD7265) */
} ADCConfig;

/**
 * Structure type for ports and configuration used by the ADC Service .
 */
typedef struct {
    AD7949Ports ad7949_ports;                  /**< Structure containing ports information about AD7949 chip (if applicable) */
    AD7265Ports ad7265_ports;                   /**< Structure containing ports information about AD7265 chip (if applicable) */
    CurrentSensorsConfig current_sensor_config; /**< Configuration about the current measurement */
} ADCPorts;

/**
 * @brief Service providing readings from the ADC chip in your SOMANET device.
 *        Measurements can be sampled on request, or can be triggered over a communication
 *        channel by just providing such channel.
 *
 * @param adc_ports Ports structure defining where to access the ADC chip signals.
 * @param c_trigger [[Nullable]] Channel communication to trigger sampling. If not provided, sampling takes place on request.
 * @param i_adc Array of communication interfaces to handle up to 5 different clients.
 */
void adc_service(ADCPorts &adc_ports, ADCConfig adc_config, chanend ?c_trigger, interface ADCInterface server i_adc[2]);
