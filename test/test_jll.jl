# test/test_jll.jl
# Standalone test script for Tigre_jll package

using Test
using Libdl
import Tigre_jll

@testset "Tigre_jll Package Tests" begin
    # 1. Package availability
    @test Tigre_jll.is_available() == true
    println("✅ Tigre_jll.is_available() == true")

    # 2. Library path
    libpath = Tigre_jll.libtigre_julia_path
    println("✅ Tigre_jll.libtigre_julia_path: $libpath")
    @test isfile(libpath)

    # 3. dlopen
    handle = Libdl.dlopen(libpath)
    @test handle != C_NULL

    # 4. Symbol resolution
    required_symbols = [
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

    for sym in required_symbols
        ptr = Libdl.dlsym_e(handle, sym)
        @test ptr != C_NULL
        if ptr == C_NULL
            println("❌ Missing symbol in Tigre_jll: $sym")
        else
            println("✅ Verified symbol: $sym")
        end
    end

    # 5. Safe C ABI queries
    fn_err_str = Libdl.dlsym(handle, :tigre_julia_error_string)
    str_ptr = ccall(fn_err_str, Ptr{Cchar}, (Cint,), 0)
    @test str_ptr != C_NULL
    msg = unsafe_string(str_ptr)
    println("   Status 0 string: '$msg'")
    @test occursin("success", lowercase(msg))

    # 6. GPU queries
    fn_gpu_count = Libdl.dlsym(handle, :tigre_julia_get_gpu_count)
    gpu_cnt = ccall(fn_gpu_count, Cint, ())
    println("   Detected GPU count via Tigre_jll: $gpu_cnt")
    @test gpu_cnt >= 0

    if gpu_cnt > 0
        fn_gpu_name = Libdl.dlsym(handle, :tigre_julia_get_gpu_name)
        buf = zeros(UInt8, 256)
        status = ccall(fn_gpu_name, Cint, (Cint, Ptr{UInt8}, Csize_t), 0, buf, length(buf))
        @test status == 0
        name = unsafe_string(pointer(buf))
        println("   GPU 0 Name: $name")
        @test !isempty(name)
    end

    Libdl.dlclose(handle)
end
