# TLPM.jl

[![Main](https://img.shields.io/badge/docs-main-blue.svg)](https://mlackner.github.io/TLPM.jl/)

Julia bindings to the *Thorlabs* `TLPM.dll` library.

## Prerequsites

You have to install the [*Optical Power Monitor*](https://www.thorlabs.de/software_pages/ViewSoftwarePage.cfm?Code=OPM) software from [*Thorlabs*](https://www.thorlabs.de/newgrouppage9.cfm?objectgroup_id=4037&pn=PM100USB).

## Install

```julia
julia> using Pkg

julia> Pkg.add("https://github.com/MLackner/TLPM.jl")
...
```

## Example

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
