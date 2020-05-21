# Zing

## ICMP Ping for Elixir

Experimental ICMP Ping server for Elixir

Uses a Zig NIF.  This library is a testbed to understand the
deficiencies in the Zigler package with regard to deploying an actually
useful product.  Currently, VERY experimental.  PRs welcomed.

## Testing (current)

`git clone https://github.com/ityonemo/zing`

Don't forget to `sudo setcap cap_net_raw=+ep <path/to/beam.smp>`!

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

