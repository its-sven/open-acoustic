import Darwin

/// Host time (`mach_absolute_time`, the clock CoreMIDI timestamps use) in milliseconds.
enum HostClock {
    private static let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    static func ms(fromHostTime t: UInt64) -> Double {
        Double(t) * Double(timebase.numer) / Double(timebase.denom) / 1_000_000
    }

    static var nowMs: Double { ms(fromHostTime: mach_absolute_time()) }
}
