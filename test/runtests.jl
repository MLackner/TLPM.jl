using TLPM
using Test

@show n = find_resources()
@show name = get_resource_name(0x00)
@show resource_info = get_resource_info(0x00)

dev = TLPMDevice(name)

open(dev; reset=true) do x
    # Calibration
    # The following power meters support this function: PM400, PM101x, PM102x, PM103x.
    if startswith(resource_info.device_name, r"PM400|PM101()|PM102()|PM103()")
        @show reinit_sensor(x)

        for i in UInt16(1):UInt16(5)
            @show get_power_calibration_points_information(x, i)
            @show get_power_calibration_points(x, i)
        end
    end

    # Measure
    @show measure_power(x)

    # Settings
    @show avg_time = get_avg_time(x)
    @show get_minimum_avg_time(x)
    @show get_maximum_avg_time(x)
    @show get_default_avg_time(x)
    @show set_avg_time(x, avg_time)

    @show wl = get_wavelength(x)
    @show get_minimum_wavelength(x)
    @show get_maximum_wavelength(x)
    @show set_wavelength(x, wl)

    @show start_dark_adjust(x)
    @show cancel_dark_adjust(x)

    print("Dark Adjustment ")
    @show start_dark_adjust(x)
    @show dark_adjust_state = get_dark_adjust_state(x)
    while dark_adjust_state == 1
        print('.')
        sleep(0.1)
        dark_adjust_state = get_dark_adjust_state(x)
    end
    print('\n')
    @show dark_offset = get_dark_offset(x)
    @show cancel_dark_adjust(x)
    @show dark_offset = get_dark_offset(x)

    @show power_unit = get_power_unit(x)
    @show set_power_unit(x, power_unit)
    @show auto_range = get_power_auto_range(x)
    @show set_power_auto_range(x, false)
    @show auto_range = get_power_auto_range(x)

    @show get_power_range(x)
    @show set_power_range(x, 1e-3)
    @show get_power_range(x)
    @show get_minimum_power_range(x)
    @show get_maximum_power_range(x)

    @show get_power_ref(x)
    @show get_minimum_power_ref(x)
    @show get_maximum_power_ref(x)
    @test_throws ErrorException get_default_power_ref(x)

    # Utility Functions
    @show get_calibration_message(x)
    @show get_sensor_info(x)
    @show timeout = get_timeout_value(x)
    @show set_timeout_value(x, timeout)

    # Dark Adjust and Power Range
    print("\n\n----------Dark Adjust Test------------\n")

    set_power_auto_range(x, false)

    for i in 1:1
        println("\n\n## RUN $i ##")
        println("dark adjust ...")

        start_dark_adjust(x)
        adjust_state = get_dark_adjust_state(x)

        while adjust_state == 1
            sleep(0.01)
            adjust_state = get_dark_adjust_state(x)
        end

        rmin = get_minimum_power_range(x)
        rmax = get_maximum_power_range(x)
        doff = get_dark_offset(x)
        autorange = get_power_auto_range(x)

        println("VALUES AFTER DARK ADJUSTMENT")
        println("Power Range Minimum: $rmin")
        println("Power Range Maximum: $rmax")
        println("Dark Offset:         $doff")
        println("Power Auto Range:    $autorange")

        N = 20
        y = LinRange(log10(abs(rmin)), log10(abs(rmax)), N)
        power_ranges = [10^_y for _y in y]
        println("\nsetting $N power ranges from $rmin to $rmax ...")
        for range_set in power_ranges
            set_power_range(x, range_set)
            range_get = get_power_range(x)
            println("\tset: $range_set\n\tget: $range_get\n")
        end
    end

end