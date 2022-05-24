module tlpm
    using CBinding

    VXIPNPPATH = ENV["VXIPNPPATH64"]

    incdir = joinpath(VXIPNPPATH, "Win64", "Include")
    incdir2 = joinpath(VXIPNPPATH, "Win64", "Lib_x64", "msc")
    libdir = joinpath(VXIPNPPATH, "Win64", "Bin")

    @assert isdir(incdir)
    @assert isdir(libdir)

    c`-std=c11 -Wall -I$(incdir) -I$(incdir2) -L$(libdir) -lTLPM_64`

    c"""
        #include <stdint.h>

        typedef uint64_t ViUInt64;
        typedef int64_t  ViInt64;
        #define _VI_INT64_UINT64_DEFINED

        #include "visatype.h"
        #include "TLPM.h"
    """ji

end