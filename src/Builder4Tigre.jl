module Builder4Tigre

using Libdl

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

"""
    version() -> VersionNumber

Return Builder4Tigre package version.
"""
version() = v"0.1.0"

end # module Builder4Tigre
