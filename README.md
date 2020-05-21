# Zing

## ICMP Ping for Elixir

Experimental ICMP Ping server for Elixir

Uses a Zig NIF.  This library is a testbed to understand the
deficiencies in the Zigler package with regard to deploying an actually
useful product.  Currently, VERY experimental.  PRs welcomed.

Currently only tested on linux.  Won't work on Windows.

IPv6 is not currently supported.

## Installation (current)

`git clone https://github.com/ityonemo/zing`

`mix zigler.get_zig 0.6.0`

Don't forget to `sudo setcap cap_net_raw=+ep <path/to/beam.smp>`!

## Usage

```
iex> Zing.start_link(name: :zing)
iex> Zing.ping(:zing, {1, 1, 1, 1})  # pong for success
:pong
iex> Zing.ping(:zing, {255, 255, 255, 255}) # pang for timeout
:pang
iex> Zing.ping_time(:zing, {1, 1, 1, 1}) # also returns round trip time. (includes some time in BEAM vm)
{:pong, 23}
```

## Installation (future)

This package will be added to `hex.pm` once three things are completed:

- Sane auto-compilation within zigler (you shouldn't have to run `mix zigler.get_zig`) to *use* the library
- `/lib/include/erl_drv.h` is no longer necessary as a shim to address
  deficiencies in the zigler driver asset
- zigler releases 0.3.0 with proper support for zig 0.6.0

The package can be installed by adding `zing` to your list of
dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:zing, "~> 0.1.0"}
  ]
end
```

Documentation can be found at [https://hexdocs.pm/zing](https://hexdocs.pm/zing).

