# test/symbols.jl
# Verify that libtigre_julia exports all required C ABI symbols.

using Libdl
using Test

const REQUIRED_SYMBOLS = [
    :tigre_julia_ax,
    :tigre_julia_atb,
    :tigre_julia_min_tv,
    :tigre_julia_awmin_tv,
    :tigre_julia_tvdenoise,
    :tigre_julia_piccs_tv,
    :tigre_julia_get_gpu_count,
    :tigre_julia_get_gpu_name,
    :tigre_julia_clear_last_error,
    :tigre_julia_last_error_message,
    :tigre_julia_last_error_tag,
    :tigre_julia_error_string,
]

function find_test_library()
    # 1. Environment variable override
    if haskey(ENV, "LIBTIGRE_PATH") && isfile(ENV["LIBTIGRE_PATH"])
        return ENV["LIBTIGRE_PATH"]
    end
    # 2. Extracted built products from BinaryBuilder (new libtigre, fallback libtigre_julia)
    for libname in ("libtigre", "libtigre_julia")
        extracted = normpath(joinpath(@__DIR__, "..", "products", "extracted", "lib", "$(libname).$(Libdl.dlext)"))
        isfile(extracted) && return extracted
        local_prod = normpath(joinpath(@__DIR__, "..", "products", "$(libname).$(Libdl.dlext)"))
        isfile(local_prod) && return local_prod
    end
    # 3. Local Tigre.jl compiled library (if present)
    for libname in ("libtigre", "libtigre_julia")
        candidate = "/home/jov/git/prj/Tigre.jl/deps/usr/lib/$(libname).$(Libdl.dlext)"
        isfile(candidate) && return candidate
    end
    return nothing
end

function test_symbols(libpath::String)
    println("Testing symbols in: $libpath")
    handle = Libdl.dlopen(libpath)
    try
        @testset "C ABI Exported Symbols" begin
            for sym in REQUIRED_SYMBOLS
                ptr = Libdl.dlsym_e(handle, sym)
                @test ptr != C_NULL
                if ptr == C_NULL
                    println("❌ Missing symbol: $sym")
                else
                    println("✅ Found symbol: $sym")
                end
            end
        end
    finally
        Libdl.dlclose(handle)
    end
end

function main()
    libpath = find_test_library()
    if libpath === nothing
        println("⚠️ No libtigre_julia shared library found to test symbols against.")
        println("   Set LIBTIGRE_PATH or compile the library first.")
        println("   Skipping symbol test (not failing).")
        return
    end

    test_symbols(libpath)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
