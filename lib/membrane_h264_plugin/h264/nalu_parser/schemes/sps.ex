defmodule Membrane.H264.NALuParser.Schemes.SPS do
  @moduledoc false
  @behaviour Membrane.H26x.NALuParser.Scheme

  alias Membrane.H26x.ExpGolombConverter
  alias Membrane.H26x.NALuParser.Scheme

  @profiles_description [
    high_cavlc_4_4_4_intra: [profile_idc: 44],
    constrained_baseline: [profile_idc: 66, constraint_set1: 1],
    baseline: [profile_idc: 66],
    main: [profile_idc: 77],
    extended: [profile_idc: 88],
    constrained_high: [profile_idc: 100, constraint_set4: 1, constraint_set5: 1],
    progressive_high: [profile_idc: 100, constraint_set4: 1],
    high: [profile_idc: 100],
    high_10_intra: [profile_idc: 110, constraint_set3: 1],
    high_10: [profile_idc: 110],
    high_4_2_2_intra: [profile_idc: 122, constraint_set3: 1],
    high_4_2_2: [profile_idc: 122],
    high_4_4_4_intra: [profile_idc: 244, constraint_set3: 1],
    high_4_4_4_predictive: [profile_idc: 244]
  ]

  @impl true
  def defaults(), do: [chroma_format_idc: 1, separate_colour_plane_flag: 0]

  @impl true
  def scheme(),
    do: [
      field: {:profile_idc, :u8},
      field: {:constraint_set0, :u1},
      field: {:constraint_set1, :u1},
      field: {:constraint_set2, :u1},
      field: {:constraint_set3, :u1},
      field: {:constraint_set4, :u1},
      field: {:constraint_set5, :u1},
      field: {:reserved_zero_2bits, :u2},
      field: {:level_idc, :u8},
      field: {:seq_parameter_set_id, :ue},
      if:
        {{&(&1 in [100, 110, 122, 244, 44, 83, 86, 118, 128]), [:profile_idc]},
         field: {:chroma_format_idc, :ue},
         if: {{&(&1 == 3), [:chroma_format_idc]}, field: {:separate_colour_plane_flag, :u1}},
         field: {:bit_depth_luma_minus8, :ue},
         field: {:bit_depth_chroma_minus8, :ue},
         field: {:qpprime_y_zero_transform_bypass_flag, :u1},
         field: {:seq_scaling_matrix_present_flag, :u1},
         if:
           {{&(&1 == 1), [:seq_scaling_matrix_present_flag]},
            for: {
              [
                iterator: :i,
                from: 1,
                to:
                  {fn chroma_format_idc -> if chroma_format_idc != 3, do: 8, else: 12 end,
                   [:chroma_format_idc]}
              ],
              field: {:seq_scaling_list_present_flag, :u1},
              if:
                {{fn seq_scaling_list_present_flag, i ->
                    seq_scaling_list_present_flag[i] == 1
                  end, [:seq_scaling_list_present_flag, :i]},
                 if:
                   {{&(&1 <= 6), [:i]},
                    execute: fn payload, state, iterators ->
                      scaling_list(payload, state, iterators, 16)
                    end},
                 if:
                   {{&(&1 > 6), [:i]},
                    execute: fn payload, state, iterators ->
                      scaling_list(payload, state, iterators, 64)
                    end}}
            }}},
      field: {:log2_max_frame_num_minus4, :ue},
      field: {:pic_order_cnt_type, :ue},
      if: {{&(&1 == 0), [:pic_order_cnt_type]}, field: {:log2_max_pic_order_cnt_lsb_minus4, :ue}},
      if:
        {{&(&1 == 1), [:pic_order_cnt_type]},
         field: {:delta_pic_order_always_zero_flag, :u1},
         field: {:offset_for_non_ref_pic, :se},
         field: {:offset_for_top_to_bottom_field, :se},
         field: {:num_ref_frames_in_pic_order_cnt_cycle, :se},
         for: {
           [iterator: :i, from: 1, to: {& &1, [:num_ref_frames_in_pic_order_cnt_cycle]}],
           field: {:offset_for_ref_frame, :se}
         }},
      field: {:max_num_ref_frames, :ue},
      field: {:gaps_in_frame_num_value_allowed_flag, :u1},
      field: {:pic_width_in_mbs_minus1, :ue},
      field: {:pic_height_in_map_units_minus1, :ue},
      field: {:frame_mbs_only_flag, :u1},
      if: {{&(&1 != 1), [:frame_mbs_only_flag]}, field: {:mb_adaptive_frame_field_flag, :u1}},
      field: {:direct_8x8_inference_flag, :u1},
      field: {:frame_cropping_flag, :u1},
      if:
        {{&(&1 == 1), [:frame_cropping_flag]},
         field: {:frame_crop_left_offset, :ue},
         field: {:frame_crop_right_offset, :ue},
         field: {:frame_crop_top_offset, :ue},
         field: {:frame_crop_bottom_offset, :ue}},
      field: {:vui_parameters_present_flag, :u1},
      if: {
        {&(&1 == 1), [:vui_parameters_present_flag]},
        vui_parameters(true)
      },
      execute: &resolution_and_profile/3,
      save_state_as_global_state: {&{:sps, &1}, [:seq_parameter_set_id]}
    ]

  @spec vui_parameters(boolean()) :: Scheme.t()
  def vui_parameters(should_skip) do
    if should_skip == true,
      do: [],
      else: [
        field: {:aspect_ratio_present_flag, :u1},
        if:
          {{&(&1 == 1), [:aspect_ratio_present_flag]},
           field: {:aspect_ratio_idc, :u8},
           if:
             {{&(&1 == 255), [:aspect_ratio_idc]},
              field: {:sar_width, :u16}, field: {:sar_height, :u16}}},
        field: {:overscan_info_present_flag, :u1},
        if:
          {{&(&1 == 1), [:overscan_info_present_flag]}, field: {:overscan_appropriate_flag, :u1}},
        field: {:video_signal_type_present_flag, :u1},
        if:
          {{&(&1 == 1), [:video_signal_type_present_flag]},
           field: {:video_format, :u3},
           field: {:video_full_range_flag, :u1},
           field: {:colour_description_present_flag, :u1},
           if:
             {{&(&1 == 1), [:colour_description_present_flag]},
              field: {:colour_primaries, :u8},
              field: {:transfer_characteristics, :u8},
              field: {:matrix_coefficients, :u8}}},
        field: {:chroma_loc_info_present_flag, :u1},
        if:
          {{&(&1 == 1), [:chroma_loc_info_present_flag]},
           field: {:chroma_sample_loc_type_top_field, :ue},
           field: {:chroma_sample_loc_type_bottom_field, :ue}},
        field: {:timing_info_present_flag, :u1},
        if:
          {{&(&1 == 1), [:timing_info_present_flag]},
           field: {:num_units_in_tick, :u32},
           field: {:time_scale, :u32},
           field: {:fixed_frame_rate_flag, :u1}},
        field: {:nal_hrd_parameters_present_flag, :u1},
        if: {{&(&1 == 1), [:nal_hrd_parameters_present_flag]}, hrd_parameters()},
        field: {:vcl_hrd_parameters_present_flag, :u1},
        if: {{&(&1 == 1), [:vcl_hrd_parameters_present_flag]}, hrd_parameters()},
        if:
          {{&(&1 == 1 or &2 == 1),
            [:nal_hrd_parameters_present_flag, :vcl_hrd_parameters_present_flag]},
           field: {:low_delay_hrd_flag, :u1}},
        field: {:pic_struct_present_flag, :u1},
        field: {:bitstream_restriction_flag, :u1},
        if:
          {{&(&1 == 1), [:bitstream_restriction_flag]},
           field: {:motion_vectors_over_pic_boundaries_flag, :u1},
           field: {:max_bytes_per_pic_denom, :ue},
           field: {:max_bits_per_mb_denom, :ue},
           field: {:log2_max_mv_length_horizontal, :ue},
           field: {:log2_max_mv_length_vertical, :ue},
           field: {:max_num_reorder_frames, :ue},
           field: {:max_dec_frame_buffering, :ue}}
      ]
  end

  defp hrd_parameters(),
    do: [
      field: {:cpb_cnt_minus1, :ue},
      field: {:bit_rate_scale, :u4},
      field: {:cpb_size_scale, :u4},
      for:
        {[iterator: :schedSeiIdx, from: 1, to: {&(&1 + 1), [:cpb_cnt_minus1]}],
         field: {:bit_rate_value_minus1, :ue},
         field: {:cpb_size_value_minus1, :ue},
         field: {:cbr_flag, :u1}},
      field: {:initial_cpb_removal_delay_length_minus1, :u5},
      field: {:cpb_removal_delay_length_minus1, :u5},
      field: {:dpb_output_delay_length_minus1, :u5},
      field: {:time_offset_length, :u5}
    ]

  defp scaling_list(payload, state, _iterators, size_of_scaling_list) do
    last_scale = 8
    next_scale = 8

    {payload, state, _last_scale, _next_scale} =
      1..size_of_scaling_list
      |> Enum.reduce({payload, state, last_scale, next_scale}, fn _j,
                                                                  {payload, state, last_scale,
                                                                   next_scale} ->
        {payload, next_scale} =
          if next_scale != 0 do
            {delta_scale, payload} = ExpGolombConverter.to_integer(payload, negatives: true)
            next_scale = rem(last_scale + delta_scale + 256, 256)
            {payload, next_scale}
          else
            {payload, next_scale}
          end

        last_scale = if next_scale == 0, do: last_scale, else: next_scale
        {payload, state, last_scale, next_scale}
      end)

    {payload, state}
  end

  defp resolution_and_profile(payload, state, _iterators) do
    sps = state.__local__

    chroma_array_type = if sps.separate_colour_plane_flag == 0, do: sps.chroma_format_idc, else: 0

    {sub_width_c, sub_height_c} =
      case sps.chroma_format_idc do
        1 -> {2, 2}
        2 -> {2, 1}
        3 -> {1, 1}
        _other -> {nil, nil}
      end

    {crop_unit_x, crop_unit_y} =
      if chroma_array_type == 0,
        do: {1, 2 - sps.frame_mbs_only_flag},
        else: {sub_width_c, sub_height_c * (2 - sps.frame_mbs_only_flag)}

    {width_offset, height_offset} =
      if sps.frame_cropping_flag == 1,
        do:
          {(sps.frame_crop_right_offset + sps.frame_crop_left_offset) * crop_unit_x,
           (sps.frame_crop_top_offset +
              sps.frame_crop_bottom_offset) * crop_unit_y},
        else: {0, 0}

    width_in_mbs = sps.pic_width_in_mbs_minus1 + 1
    width = width_in_mbs * 16 - width_offset

    height_in_map_units = sps.pic_height_in_map_units_minus1 + 1
    height_in_mbs = (2 - sps.frame_mbs_only_flag) * height_in_map_units
    height = height_in_mbs * 16 - height_offset

    profile = parse_profile(sps)

    {payload,
     Map.update(
       state,
       :__local__,
       %{},
       &Map.merge(&1, %{width: width, height: height, profile: profile})
     )}
  end

  defp parse_profile(fields) do
    {profile_name, _constraints_list} =
      Enum.find(@profiles_description, {nil, nil}, fn {_profile_name, constraints_list} ->
        Enum.all?(constraints_list, fn {key, value} ->
          Map.has_key?(fields, key) and fields[key] == value
        end)
      end)

    if profile_name == nil, do: raise("Cannot read the profile name based on SPS's fields.")
    profile_name
  end
end
