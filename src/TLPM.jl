module TLPM

using BitFlags

include("_tlpm.jl")
using .tlpm

import Base: open

# Resources
export find_resources, get_resource_name, get_resource_info
# Main Type
export TLPMDevice
# Other Types
export SensorInfo,
       PowerCalibrationInformation
# Enums
export PowerUnit,
       SensorType,
       SensorSubtype
# BitFlags
export SensorFlags
# Connection
export connect!, disconnect, open
# Measurement
export measure_power
# Settings
export set_avg_time, 
       set_wavelength,
       get_avg_time, 
       get_minimum_avg_time, 
       get_maximum_avg_time, 
       get_default_avg_time,
       get_wavelength,
       get_minimum_wavelength,
       get_maximum_wavelength
export start_dark_adjust,
       get_dark_offset,
       get_dark_adjust_state,
       cancel_dark_adjust
export get_power_range,
       get_minimum_power_range,
       get_maximum_power_range,
       set_power_range,
       get_power_unit,
       set_power_unit,
       get_power_auto_range,
       set_power_auto_range,
       get_power_ref,
       get_minimum_power_ref,
       get_maximum_power_ref,
       get_default_power_ref,
       set_power_ref
# Utility Functions
export get_calibration_message,
       get_sensor_info,
       get_timeout_value,
       set_timeout_value
# Calibration
export reinit_sensor,
       get_power_calibration_points,
       get_power_calibration_points_information


"""
    TLPMDevice(resource_name::String) -> TLPMDevice

Create a new `TLPMDevice` containing the instrument handle and the resource
name.

## Arguments
- `resource_name::String`: the resource name of the device returned by
  `get_resource_name`

## Returns
- `TLPMDevice`: a `struct` representing the device
"""
mutable struct TLPMDevice
    instr_handle::UInt32
    resource_name::String
    
    TLPMDevice(resource_name::String) = new(UInt32(0), resource_name)
end

@enum PowerUnit::Int16 Watt dBm

@enum SensorType::Int16 begin
    TYPE_NONE=0x00
    PD_SINGLE=0x01
    THERMO=0x02
    PYRO=0x03
end

@enum SensorSubtype::Int16 begin
    SUBTYPE_NONE=0x00
    ADAPTER=0x01
    STD=0x02
    FSR=0x03
    STD_T=0x12
end

@bitflag SensorFlags::UInt16 begin
    IS_POWER=0x0001
    IS_ENERGY=0x0002
    IS_RESP_SET=0x0010
    IS_WAVEL_SET=0x0020
    IS_TAU_SET=0x0040
    HAS_TEMP=0x0100
end

struct SensorInfo
    name::String
    serial_number::String
    calibration_message::String
    type::SensorType
    subtype::SensorSubtype
    flags::SensorFlags
end

struct ResourceInfo
    device_name::String
    serial_number::String
    manufacturer::String
    available::Bool
end

"""
## Fields
+ `serial_number::String`
+ `calibration_date::String`
+ `calibration_points_count::UInt16`: Number of calibration points of the power calibration with this sensor
+ `author::String`
+ `sensor_position::UInt16`: The position of the sencor switch of a Thorlabs S130C
    + `1` = 5mW
    + `2` = 500mW
"""
struct PowerCalibrationInformation
    serial_number::String
    calibration_date::String
    calibration_points_count::UInt16
    author::String
    sensor_position::UInt16
end

struct PowerCalibrationPoints
    wavelengths::Vector{Float64}
    power_correction_factors::Vector{Float64}
end


# Helper Functions

function _error_message(err, instr_handle=@VI_NULL)
    description = fill(UInt8(0), 512)
    TLPM_errorMessage(instr_handle, err, description)
    description |> _to_ascii_string
end

function _handle_error(err::Int32, instr_handle=@VI_NULL)
    if err == @VI_SUCCESS
        nothing
    else
        msg = _error_message(err, instr_handle)
        error(msg)
    end
end

function _to_ascii_string(x::Vector{UInt8})
    b = UInt8[]
    for _x in x
        _x == 0x00 ? break : push!(b, _x)
    end
    String(b)
end

"""
    find_resources() -> UInt32

This function finds all driver compatible devices attached to the PC and returns
the number of found devices. The function additionally stores information like
system name about the found resources internally. This information can be
retrieved with further functions from the class, e.g. `get_resource_name`
and `get_resource_info`.
 """
function find_resources()
    device_count = Ref{UInt32}(0)
    TLPM_findRsrc(0, device_count) |> _handle_error
    device_count[]
end

"""
    get_resource_name(device_index::T) where T <: Unsigned -> String

Get the resource name of device with index `device_index` which is needed to
open a device with `TLPMDevice`. You have to first call `find_resources()`
otherwise you get a `ReadOnlyMemoryError`.

## Example

```
julia> find_resources()
0x00000001

julia> get_resource_name(0x00)
"USB0::0x1313::0x8072::1918020::INSTR"
```
"""
function get_resource_name(device_index::T) where T <: Unsigned
    rsrc_descr = fill(UInt8(0), @TLPM_BUFFER_SIZE)
    TLPM_getRsrcName(0, UInt32(device_index), rsrc_descr) |> _handle_error
    rsrc_descr |> _to_ascii_string
end

"""
    get_resource_info(device_index::T) where T <: Unsigned

This function gets information about a connected resource.

Notes:
+ The data provided by this function was updated at the last call of `find_resources`.
"""
function get_resource_info(device_index::T) where T <: Unsigned
    device_name = fill(UInt8(0), @TLPM_BUFFER_SIZE)
    serial_number = fill(UInt8(0), @TLPM_BUFFER_SIZE)
    manufacturer = fill(UInt8(0), @TLPM_BUFFER_SIZE)
    available = Ref{Bool}()

    TLPM_getRsrcInfo(0, UInt32(device_index), device_name, serial_number, manufacturer, available) |> _handle_error

    ResourceInfo(
        device_name   |> _to_ascii_string, 
        serial_number |> _to_ascii_string, 
        manufacturer  |> _to_ascii_string,
        available[]
    )
end


###############################################################################
# CONNECTION 
###############################################################################

function init(resource_name; query=true, reset=true)
    instr_handle = Ref{UInt32}()

    TLPM_init(resource_name, query, reset, instr_handle) |> _handle_error

    instr_handle[]
end

"""
    connect!(x::TLPMDevice; query=true, reset=true) -> TLPMDevice

Make a connection to the `TLPMDevice` `x`.


## Keyword Arguments

- `query=true`: This parameter specifies whether an identification query is performed during the initialization process.
- `reset=true`: This parameter specifies whether the instrument is reset during the initialization process.
"""
function connect!(x::TLPMDevice; query=true, reset=true)
    x.instr_handle = init(x.resource_name; query=query, reset=reset)
    x
end

"""
    open(f::Function, x::TLPMDevice; query=true, reset=true) -> Nothing

Opens a connection to the `TLPM` device, executes function `f` and finally disconnects from the device.

## Keyword Arguments

- `query=true`: This parameter specifies whether an identification query is performed during the initialization process.
- `reset=true`: This parameter specifies whether the instrument is reset during the initialization process.

## Example

```
julia> find_resources()

julia> resource_name = get_resource_name(0x00)
"USB0::0x1313::0x8072::1918020::INSTR"

julia> dev = TLPMDevice(resource_name)
TLPMDevice(0x00000000, "USB0::0x1313::0x8072::1918020::INSTR")

julia> open(dev) do x
           measure_power(x) |> println
       end
4.54033199e-7
```
"""
function open(f::Function, x::TLPMDevice; query=true, reset=true)
    connect!(x; query=query, reset=reset)
    try
        f(x)
    finally
        disconnect(x)
    end
end

close(instr_handle) = TLPM_close(instr_handle) |> _handle_error

"""
    disconnect(x::TLPMDevice) -> Nothing

Disconnect the `TLPMDevice`.
"""
disconnect(x::TLPMDevice) = close(x.instr_handle)

###############################################################################
# MEASURE 
###############################################################################

"""
    measure_power(x::TLPMDevice) -> Float64

Obtain a power reading from the instrument. This function starts a new
measurement cycle and after finishing measurement the result is received.
Subject to the actual Average Time this may take up to seconds. Refer to
`set_avg_time` and `get_avg_time`.
"""
function measure_power(instr_handle)
    power = Ref{Float64}()
    TLPM_measPower(instr_handle, power) |> _handle_error
    power[]
end
measure_power(x::TLPMDevice) = measure_power(x.instr_handle)

###############################################################################
# Configure
###############################################################################

######
## Set
######

"""
Sets the average time for measurement value generation.
"""
function set_avg_time(x::TLPMDevice, average_time::Float64)
    TLPM_setAvgTime(x.instr_handle, average_time) |> _handle_error
end

######
## Get
######

"""
This function returns the average time for measurement value generation.

## Parameters
+ `instrHandle`: This parameter accepts the instrument handle returned by <Initialize> to select the desired instrument driver session.
+ `attribute`: This parameter specifies the value to be queried.

Acceptable values for `attribute`:
0: Set value
1: Minimum value
2: Maximum value
3: Default value
"""
function _get_avg_time(instr_handle::UInt32, attribute::Int16)
    avg_time = Ref{Float64}()
    TLPM_getAvgTime(instr_handle, attribute, avg_time) |> _handle_error
    avg_time[]
end

"""
    get_avg_time(x::TLPMDevice) -> Float64

Return the average time for measurement value generation.
"""
get_avg_time(x::TLPMDevice) = _get_avg_time(x.instr_handle, Int16(0))

"""
    get_minimum_avg_time(x::TLPMDevice) -> Float64

Return the minimum average time for measurement value generation that can be set.
"""
get_minimum_avg_time(x::TLPMDevice) = _get_avg_time(x.instr_handle, Int16(1))

"""
    get_maximum_avg_time(x::TLPMDevice) -> Float64

Return the maximum average time for measurement value generation that can be set.
"""
get_maximum_avg_time(x::TLPMDevice) = _get_avg_time(x.instr_handle, Int16(2))

"""
    get_default_avg_time(x::TLPMDevice) -> Float64

Return the default average time for measurement value generation that can be set.
"""
get_default_avg_time(x::TLPMDevice) = _get_avg_time(x.instr_handle, Int16(3))

###############################################################################
# Correction
###############################################################################

######
## Set
######

"""
    set_wavelength(x::TLPMDevice, wavelength::Float64) -> Nothing

This function sets the users wavelength in nanometer [nm]. The wavelength set
value is used for calculating power.
"""
function set_wavelength(x::TLPMDevice, wavelength::Float64)
    TLPM_setWavelength(x.instr_handle, wavelength) |> _handle_error
end

######
## Get
######

"""
This function returns the users wavelength in nanometer [nm]. The wavelength set
value is used for calculating power.
"""
function _get_wavelength(instr_handle, attribute::Int16)
    wavelength = Ref{Float64}()
    TLPM_getWavelength(instr_handle, attribute, wavelength) |> _handle_error
    wavelength[]
end

"""
    get_wavelength(x::TLPMDevice) -> Float64

This function returns the users wavelength in nanometer [nm]. The wavelength set
value is used for calculating power.
"""
get_wavelength(x::TLPMDevice) = _get_wavelength(x.instr_handle, Int16(0))

"""
    get_minimum_wavelength(x::TLPMDevice) -> Float64

This function returns the minimum wavelength in nanometer [nm] that can be set
by the user. The wavelength set value is used for calculating power.
"""
get_minimum_wavelength(x::TLPMDevice) = _get_wavelength(x.instr_handle, Int16(1))

"""
    get_maximum_wavelength(x::TLPMDevice) -> Float64

This function returns the maximum wavelength in nanometer [nm] that can be set
by the user. The wavelength set value is used for calculating power.
"""
get_maximum_wavelength(x::TLPMDevice) = _get_wavelength(x.instr_handle, Int16(2))

"""
    get_dark_offset(x::TLPMDevice)

This function returns the dark/zero offset. The unit of the returned offset
value depends on the sensor type. Photodiodes return the dark offset in ampere
[A]. Thermal sensors return the dark offset in volt [V]. The function is not
supported with energy sensors.
"""
function get_dark_offset(x::TLPMDevice)
    dark_offset = Ref{Float64}()
    TLPM_getDarkOffset(x.instr_handle, dark_offset) |> _handle_error
    dark_offset[]
end

"""
    start_dark_adjust(x::TLPMDevice) -> Nothing

This function starts the dark current/zero offset adjustment procedure.

Remark:
+ You have to darken the input before starting dark/zero adjustment.
+ You can get the state of dark/zero adjustment with `get_dark_adjust_state`
+ You can stop dark/zero adjustment with `cancel_dark_adjust`
+ You get the dark/zero value with `get_dark_offset`
+ Energy sensors do not support this function
"""
function start_dark_adjust(x::TLPMDevice)
    TLPM_startDarkAdjust(x.instr_handle) |> _handle_error
end

"""
    get_dark_adjust_state(x::TLPMDevice) -> Int16

This function returns the state of a dark current/zero offset adjustment
procedure previously initiated by <Start Dark Adjust>.

Possible return values are:
+ `0`: no dark adjustment running
+ `1`: dark adjustment is running
 """
function get_dark_adjust_state(x::TLPMDevice)
    state = Ref{Int16}()
    TLPM_getDarkAdjustState(x.instr_handle, state) |> _handle_error
    state[]
end

"""
    cancel_dark_adjust(x::TLPMDevice) -> Nothing

This function cancels a running dark current/zero offset adjustment procedure.
"""
function cancel_dark_adjust(x::TLPMDevice)
    TLPM_cancelDarkAdjust(x.instr_handle) |> _handle_error
end


###############################################################################
# Power Measurement
###############################################################################

function _get_power_range(instr_handle, attribute::Int16)
    power_range = Ref{Float64}()
    TLPM_getPowerRange(instr_handle, attribute, power_range) |> _handle_error
    power_range[]
end

"""
    get_power_range(x::TLPMDevice) -> Float64

Returns the power range value in watt [W].
"""
function get_power_range(x::TLPMDevice)
    _get_power_range(x.instr_handle, Int16(0))
end

"""
    get_minimum_power_range(x::TLPMDevice) -> Float64

Returns the minimum power range value in watt [W].
"""
function get_minimum_power_range(x::TLPMDevice)
    _get_power_range(x.instr_handle, Int16(1))
end

"""
    get_maximum_power_range(x::TLPMDevice) -> Float64

Returns the maximum power range value in watt [W].
"""
function get_maximum_power_range(x::TLPMDevice)
    _get_power_range(x.instr_handle, Int16(2))
end

"""
    set_power_range(x::TLPMDevice, power_to_measure::Float64) -> Nothing

Sets the sensor's power range. `power_to_measure` specifies the most positive
signal level expected for the sensor input in watt [W].
 """
function set_power_range(x::TLPMDevice, power_to_measure::Float64)
    TLPM_setPowerRange(x.instr_handle, power_to_measure) |> _handle_error
end

"""
    get_power_unit(x::TLPMDevice) -> PowerUnit

This function returns the unit of the power value. Can be either the type
`TLPM.Watt` or `TLPM.dBm`.
 """
function get_power_unit(x::TLPMDevice)
    power_unit = Ref{PowerUnit}()
    TLPM_getPowerUnit(x.instr_handle, power_unit) |> _handle_error
    power_unit[]
end

"""
    set_power_unit(x::TLPMDevice, power_unit::PowerUnit) -> Nothing

Set the unit of the power value. `power_unit` can be either `TLPM.Watt` or
`TLPM.dBm`.
 """
function set_power_unit(x::TLPMDevice, power_unit::PowerUnit)
    TLPM_setPowerUnit(x.instr_handle, power_unit) |> _handle_error
end

"""
    get_power_auto_range(x::TLPMDevice) -> Bool

Returns the power auto range mode. `false` means autorange is off, `true` means
auto range is on.
 """
function get_power_auto_range(x::TLPMDevice)
    power_autorange_mode = Ref{Bool}()
    TLPM_getPowerAutorange(x.instr_handle, power_autorange_mode) |> _handle_error
    power_autorange_mode[]
end

"""
    set_power_auto_range(x::TLPMDevice, autorange::Bool) -> Nothing

Sets the power auto range mode. `false` means auto range is off, `true` means
auto range is on.
 """
function set_power_auto_range(x::TLPMDevice, autorange::Bool)
    TLPM_setPowerAutoRange(x.instr_handle, autorange) |> _handle_error
end

"""
    _get_power_ref(instr_handle, attribute::Int16) -> Float64

This function returns the power reference value.

Acceptable values for `attribute`:
+ `0`: Set value
+ `1`: Minimum value
+ `2`: Maximum value
+ `3`: Default value
"""
function _get_power_ref(instr_handle, attribute::Int16)
    power_reference_value = Ref{Float64}()
    TLPM_getPowerRef(instr_handle, attribute, power_reference_value) |> err -> _handle_error(err, instr_handle)
    power_reference_value[]
end

"""
    get_power_ref(x::TLPMDevice) -> Float64

Get the power reference value.

Remark:
+ The power reference value has the unit specified with `set_power_unit`.
+ This value is used for calculating differences between the actual power value
and this power reference value if Power Reference State is ON.
"""
function get_power_ref(x::TLPMDevice)
    _get_power_ref(x.instr_handle, Int16(0))
end

"""
    get_minimum_power_ref(x::TLPMDevice) -> Float64

Get the minimum power reference value.

Remark:
+ The power reference value has the unit specified with `set_power_unit`.
+ This value is used for calculating differences between the actual power value
and this power reference value if Power Reference State is ON.
"""
function get_minimum_power_ref(x::TLPMDevice)
    _get_power_ref(x.instr_handle, Int16(1))
end

"""
    get_maximum_power_ref(x::TLPMDevice) -> Float64

Get the maximum power reference value.

Remark:
+ The power reference value has the unit specified with `set_power_unit`.
+ This value is used for calculating differences between the actual power value
and this power reference value if Power Reference State is ON.
"""
function get_maximum_power_ref(x::TLPMDevice)
    _get_power_ref(x.instr_handle, Int16(2))
end

"""
    get_default_power_ref(x::TLPMDevice) -> Float64

Get the default power reference value.

Remark:
+ The power reference value has the unit specified with `set_power_unit`.
+ This value is used for calculating differences between the actual power value
and this power reference value if Power Reference State is ON.
"""
function get_default_power_ref(x::TLPMDevice)
    _get_power_ref(x.instr_handle, Int16(3))
end

"""
    set_power_ref(x::TLPMDevice, power_reference_value::Float64) -> Nothing

Set the power reference value.

Remark:
+ The power reference value has the unit specified with `set_power_unit`.
+ This value is used for calculating differences between the actual power value
and this power reference value if Power Reference State is ON.
"""
function set_power_ref(x::TLPMDevice, power_reference_value::Float64)
    TLPM_setPowerRef(x.instr_handle, power_reference_value) |> _handle_error
end 

###############################################################################
# Utility Functions
###############################################################################

"""
    get_calibration_message(x::TLPMDevice) -> String

Returns a human readable calibration message.
"""
function get_calibration_message(x::TLPMDevice)
    message = fill(UInt8(0), 256)
    TLPM_getCalibrationMsg(x.instr_handle, message) |> _handle_error
    message |> _to_ascii_string
end

"""
    get_sensor_info(x::TLPMDevice) -> SensorInfo

This function is used to obtain informations from the connected sensor like
sensor name, serial number, calibration message, sensor type, sensor subtype and
sensor flags.
 """
function get_sensor_info(x::TLPMDevice)
    buffer_size = 256
    sensor_name = fill(UInt8(0), buffer_size)
    sensor_serial_number = fill(UInt8(0), buffer_size)
    sensor_calibration_message = fill(UInt8(0), buffer_size)
    sensor_type = Ref{SensorType}()
    sensor_subtype = Ref{SensorSubtype}()
    sensor_flags = Ref{SensorFlags}()

    TLPM_getSensorInfo(
        x.instr_handle, 
        sensor_name, 
        sensor_serial_number, 
        sensor_calibration_message,
        sensor_type,
        sensor_subtype,
        sensor_flags
    ) |> _handle_error

    SensorInfo(
        sensor_name |> _to_ascii_string,
        sensor_serial_number |> _to_ascii_string,
        sensor_calibration_message |> _to_ascii_string,
        sensor_type[],
        sensor_subtype[],
        sensor_flags[]
    )
end

"""
    get_timeout_value(x::TLPMDevice) -> UInt32

Returns the communication timeout value in ms.
"""
function get_timeout_value(x::TLPMDevice)
    value = Ref{UInt32}()
    TLPM_getTimeoutValue(x.instr_handle, value) |> _handle_error
    value[]
end

"""
    set_timeout_value(x::TLPMDevice, timeout_value::UInt32) -> Nothing

Set the communication timeout value in ms.
"""
function set_timeout_value(x::TLPMDevice, timeout_value::UInt32)
    TLPM_setTimeoutValue(x.instr_handle, timeout_value) |> _handle_error
end

###############################################################################
# User Power Calibration
###############################################################################

"""
    reinit_sensor(x::TLPMDevice) -> Nothing

To use the user power calibration, the sensor has to be reconnected. Either
manually remove and reconnect the sensor to the instrument or use this function.
This function will wait 2 seconds until the sensor has been reinitialized.

The following power meters support this function: PM400, PM101x, PM102x, PM103x.
 """
function reinit_sensor(x::TLPMDevice)
    TLPM_reinitSensor(x.instr_handle) |> _handle_error
end

"""
    get_power_calibration_points(x::TLPMDevice, index::UInt16) -> PowerCalibrationPoints

Returns a list of wavelength and the corresponding power correction factor.

The following power meters support this function: PM400, PM101x, PM102x, PM103x.

## Arguments

+ `index`: Index of the power calibration (range 1...5)
 """
function get_power_calibration_points(x::TLPMDevice, index::UInt16, point_counts::UInt16)
    wavelengths = Vector{Float64}(undef, point_counts)
    power_correction_factors = Vector{Float64}(undef, point_counts)
    TLPM_getPowerCalibrationPoints(x.instr_handle, index, point_counts, wavelengths, power_correction_factors) |> _handle_error
    PowerCalibrationPoints(wavelengths, power_correction_factors)
end

"""
    get_power_calibration_points_information(x::TLPMDevice, index::UInt16) -> PowerCalibrationInformation

Queries the customer adjustment header like serial nr, cal date, nr of points at
given index.

The following power meters support this function: PM400, PM101x, PM102x, PM103x.

## Arguments

+ `index`: Index of the power calibration (range 1...5)
 """
function get_power_calibration_points_information(x::TLPMDevice, index::UInt16)
    serial_number = Vector{UInt8}(undef, 256)
    calibration_date = Vector{UInt8}(undef, 256)
    calibration_points_count = Ref{UInt16}()
    author = Vector{UInt8}(undef, 256)
    sensor_position = Ref{UInt16}()

    TLPM_getPowerCalibrationPointsInformation(x.instr_handle, index, serial_number, calibration_date, calibration_points_count, author, sensor_position) |> _handle_error

    PowerCalibrationInformation(
        serial_number |> _to_ascii_string,
        calibration_date |> _to_ascii_string,
        calibration_points_count[],
        author |> _to_ascii_string,
        sensor_position[]
    )
end

end