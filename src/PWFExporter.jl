module PWFExporter

import PWF
import Format

export import_pwf, export_pwf, edit_pwf_dbar


const _dbar_dtypes = [("NUMBER", Int64, 1:5), ("OPERATION", Char, 6), 
    ("STATUS", Char, 7), ("TYPE", Int64, 8), ("BASE VOLTAGE GROUP", String, 9:10),
    ("NAME", String, 11:22), ("VOLTAGE LIMIT GROUP", String, 23:24),
    ("VOLTAGE", Float64, 25:28, 25), ("ANGLE", Float64, 29:32),
    ("ACTIVE GENERATION", Float64, 33:37), ("REACTIVE GENERATION", Float64, 38:42),
    ("MINIMUM REACTIVE GENERATION", Float64, 43:47),
    ("MAXIMUM REACTIVE GENERATION",Float64, 48:52), ("CONTROLLED BUS", Int64, 53:58),
    ("ACTIVE CHARGE", Float64, 59:63), ("REACTIVE CHARGE", Float64, 64:68),
    ("TOTAL REACTIVE POWER", Float64, 69:73), ("AREA", Int64, 74:76),
    ("CHARGE DEFINITION VOLTAGE", Float64, 77:80, 77), ("VISUALIZATION", Int64, 81),
    ("AGGREGATOR 1", Int64, 82:84), ("AGGREGATOR 2", Int64, 85:87),
    ("AGGREGATOR 3", Int64, 88:90), ("AGGREGATOR 4", Int64, 91:93),
    ("AGGREGATOR 5", Int64, 94:96), ("AGGREGATOR 6", Int64, 97:99),
    ("AGGREGATOR 7", Int64, 100:102), ("AGGREGATOR 8", Int64, 103:105),
    ("AGGREGATOR 9", Int64, 106:108), ("AGGREGATOR 10", Int64, 109:111)]

const _default_dbar = Dict("NUMBER" => nothing, "OPERATION" => 'A', "STATUS" => 'L',
    "TYPE" => 0, "BASE VOLTAGE GROUP" => " 0", "NAME" => nothing, "VOLTAGE LIMIT GROUP" => " 0",
    "VOLTAGE" => 1.0, "ANGLE" => 0.0, "ACTIVE GENERATION" => 0.0,
    "REACTIVE GENERATION" => 0.0, "MINIMUM REACTIVE GENERATION" => 0.0,
    "MAXIMUM REACTIVE GENERATION" => 0.0, "CONTROLLED BUS" => nothing,
    "ACTIVE CHARGE" => 0.0, "REACTIVE CHARGE" => 0.0, "TOTAL REACTIVE POWER" => 0.0,
    "AREA" => 1, "CHARGE DEFINITION VOLTAGE" => 1.0, "VISUALIZATION" => 0,
    "AGGREGATOR 1" => nothing, "AGGREGATOR 2" => nothing, "AGGREGATOR 3" => nothing, 
    "AGGREGATOR 4" => nothing, "AGGREGATOR 5" => nothing, "AGGREGATOR 6" => nothing, 
    "AGGREGATOR 7" => nothing, "AGGREGATOR 8" => nothing, "AGGREGATOR 9" => nothing, 
    "AGGREGATOR 10" => nothing)


function import_pwf(network_path::AbstractString)
    network = PWF.parse_file(network_path; pm = false)
    return network
end

function export_pwf(pwf_file::IOStream, network_dict::AbstractDict)
    pwf_str = ""

    pwf_str *= "TITU\n" * network_dict["TITU"] * "\nDOPC IMPR\n"

    dopc_impr_row = 1
    for (dopc_impr_item_name, dopc_impr_item_value) in network_dict["DOPC IMPR"]
        pwf_str *= "$(dopc_impr_item_name) $(dopc_impr_item_value) "
        dopc_impr_row += 1
        if dopc_impr_row >= 11
            pwf_str *= "\n"
            dopc_impr_row = 1
        end
    end
    if !endswith(pwf_str, "\n")
        pwf_str *= "\n"
    end
    pwf_str *= "99999\nDBAR\n"

    pwf_str *= get_dbar_str(network_dict)
    
    pwf_str *= "99999\n"

    write(pwf_file, pwf_str)

    return nothing
end

function export_pwf(pwf_filepath::AbstractString, network_dict::AbstractDict)
    open(pwf_filepath, "w") do pwf_file
        export_pwf(pwf_file, network_dict)
    end
    return nothing
end

function edit_pwf_dbar(pwf_file::IOStream, original_pwf_filepath::AbstractString, network_dict::AbstractDict)
    dbar_str = get_dbar_str(network_dict)

    original_pwf = read(original_pwf_filepath, String)

    pattern = Regex(raw"(DBAR\s*\n)(.*?)(\n\s*99999)", "s")
    substuition = SubstitutionString("DBAR\n" * dbar_str * "99999")
    new_pwf = replace(original_pwf, pattern => substuition)

    write(pwf_file, new_pwf)
    return nothing
end

function edit_pwf_dbar(pwf_filepath::AbstractString, original_pwf_filepath::AbstractString, network_dict::AbstractDict)
    open(pwf_filepath, "w") do pwf_file
        edit_pwf_dbar(pwf_file, original_pwf_filepath, network_dict)
    end
    return nothing
end

function get_dbar_str(network_dict::AbstractDict)
    pwf_str = "(No )OETGb(   nome   )Gl( V)( A)( Pg)( Qg)( Qn)( Qm)(Bc  )( Pl)( Ql)( Sh)Are(Vf)\n"
    for dbar_item in sort(collect(values(network_dict["DBAR"])), by=v->v["NUMBER"])
        for dbar_attr in _dbar_dtypes
            dbar_attr_name = dbar_attr[1]
            dbar_attr_type = dbar_attr[2]
            dbar_attr_columns = dbar_attr[3]
            dbar_attr_length = length(dbar_attr_columns)
            dbar_attr_value = dbar_item[dbar_attr_name]

            if !isnothing(dbar_attr_value) && (dbar_attr_value != _default_dbar[dbar_attr_name] || dbar_attr_name == "VOLTAGE") && !(dbar_attr_name == "CONTROLLED BUS" && dbar_attr_value == dbar_item["NUMBER"])
                if dbar_attr_type <: Integer
                    attr = Format.format("{1:>$(dbar_attr_length)d}", dbar_attr_value)
                elseif dbar_attr_type <: AbstractFloat
                    if !iszero(dbar_attr_value)
                        attr = Format.format("{1:>$(dbar_attr_length).$(2)f}", dbar_attr_value)
                    else
                        attr = Format.format("{1:>$(dbar_attr_length)s}", " ")
                    end
                    if length(attr) > dbar_attr_length
                        attr = attr[1:dbar_attr_length]
                    end
                    if endswith(attr, ".")
                        attr = " " * attr[1:end-1]
                    end
                else
                    attr = Format.format("{1:>$(dbar_attr_length)s}", dbar_attr_value)
                end
            else
                attr = Format.format("{1:>$(dbar_attr_length)s}", " ")
            end
            pwf_str *= "$(attr)"
        end
        pwf_str *= "\n"
    end
    return pwf_str
end

end
