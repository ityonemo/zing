defmodule Zing.Packet do

  defstruct [:type, :id, seq: 0]

  @type_to_code %{request: <<8, 0>>}
  @empty_checksum <<0, 0>>

  #############################################################################
  ## API

  def encode(list) when is_list(list), do: encode(struct(__MODULE__, list))
  def encode(%__MODULE__{type: :request, id: id, seq: seq}) do
    insert_checksum(
      <<@type_to_code[:request] :: binary, @empty_checksum :: binary,
        seq :: 16, :erlang.phash2(id) :: 16, random_payload() :: binary>>)
  end

  def decode(binary) do
    IO.inspect(binary)
  end

  #############################################################################
  ## helper functions: encode

  defp insert_checksum(payload = <<first::16, @empty_checksum>> <> rest) do
    <<first::16, sum16compl(payload) :: 16, rest :: binary>>
  end

  defp sum16compl(binary, sum16 \\ 0)
  defp sum16compl(<<first::16>>, sum16) do
    Bitwise.~~~(first + sum16)
  end
  defp sum16compl(<<first::16>> <> rest, sum16) do
    sum16compl(rest, first + sum16)
  end

  defp random_payload, do: <<0::56 * 8>> #:crypto.strong_rand_bytes(56)

  #############################################################################
  ## helper functions: decode

end
