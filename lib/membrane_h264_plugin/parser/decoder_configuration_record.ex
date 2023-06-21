defmodule Membrane.H264.Parser.DecoderConfigurationRecord do
  @moduledoc """
  Utility functions for parsing AVC Configuration Record.

  The structure of the record is described in section 5.2.4.1.1 of MPEG-4 part 15 (ISO/IEC 14496-15).
  """
  @enforce_keys [
    :sps,
    :pps,
    :avc_profile_indication,
    :avc_level,
    :profile_compatibility,
    :length_size_minus_one
  ]
  defstruct @enforce_keys

  @typedoc "Structure representing the Decoder Configuartion Record"
  @type t() :: %__MODULE__{
          sps: [binary()],
          pps: [binary()],
          avc_profile_indication: non_neg_integer(),
          profile_compatibility: non_neg_integer(),
          avc_level: non_neg_integer(),
          length_size_minus_one: non_neg_integer()
        }

  @doc """
  Parses the DCR.
  """
  @spec parse(binary()) :: {:ok, t()} | {:error, any()}
  def parse(
        <<1::8, avc_profile_indication::8, profile_compatibility::8, avc_level::8, 0b111111::6,
          length_size_minus_one::2, 0b111::3, rest::bitstring>>
      ) do
    {sps, rest} = parse_sps(rest)
    {pps, _rest} = parse_pps(rest)

    %__MODULE__{
      sps: sps,
      pps: pps,
      avc_profile_indication: avc_profile_indication,
      profile_compatibility: profile_compatibility,
      avc_level: avc_level,
      length_size_minus_one: length_size_minus_one
    }
    |> then(&{:ok, &1})
  end

  def parse(_data), do: {:error, :unknown_pattern}

  defp parse_sps(<<num_of_sps::5, rest::bitstring>>) do
    do_parse_array(num_of_sps, rest)
  end

  defp parse_pps(<<num_of_pps::8, rest::bitstring>>), do: do_parse_array(num_of_pps, rest)

  defp do_parse_array(amount, rest, acc \\ [])
  defp do_parse_array(0, rest, acc), do: {Enum.reverse(acc), rest}

  defp do_parse_array(remaining, <<size::16, data::binary-size(size), rest::bitstring>>, acc),
    do: do_parse_array(remaining - 1, rest, [data | acc])
end
