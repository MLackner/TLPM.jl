# Examples

## Average Measurement

This example shows how to connect to a power meter, set the desired average time, a timeout compatible with that average time, retrieve the power measurement, and disconnect from the device.

```julia
julia> using TLPM

julia> find_resources()
0x00000001

julia> resource_index = 0x00
0x00

julia> get_resource_info(resource_index)
TLPM.ResourceInfo("PM100USB", "1918020", "Thorlabs", true)

julia> resource_name = get_resource_name(resource_index)
"USB0::0x1313::0x8072::1918020::INSTR"

julia> dev = TLPMDevice(resource_name)
TLPMDevice(0x00000000, "USB0::0x1313::0x8072::1918020::INSTR")

julia> connect!(dev)
TLPMDevice(0x000070b3, "USB0::0x1313::0x8072::1918020::INSTR")

julia> set_timeout_value(dev, UInt32(5000)) # set timeout to 5000 ms

julia> set_avg_time(dev, 4.0) # configure average time for measurement to 4 s

julia> @time measure_power(dev)
  4.002439 seconds (1 allocation: 16 bytes)
1.47045821e-5

julia> disconnect(dev)

```
