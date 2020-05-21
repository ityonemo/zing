defmodule Zing do
  use Connection

  defstruct [:conn, listening: false, queue: %{}, timeout: 500]

  defmodule Request do
    defstruct [:from, :ttl]
  end

  alias Zing.Nif
  alias Zing.Packet

  def start_link(opts) do
    Connection.start_link(__MODULE__, nil, opts)
  end

  def init(nil) do
    # initiate the listening socket.  The listening socket is linked to this
    # process and will go away if this process dies.
    Zing.Nif.start_listener()
    {:connect, :init, %__MODULE__{}}
  end

  defp connect_listener_impl(state), do: {:noreply, %{state | listening: true}}

  #############################################################################
  ## API

  @spec ping(GenServer.server, :inet.address) :: :pong | :pang
  def ping(server, ip), do: GenServer.call(server, {:ping, ip})
  defp ping_impl(ip = {a, b, c, d}, from, state) do
    packet = Packet.encode(type: :request, id: from)
    Nif.ping(state.conn, <<a, b, c, d>>, packet)
    expiry = DateTime.add(DateTime.utc_now, 500, :millisecond)
    request = %Request{from: from, ttl: expiry}
    Process.send_after(self(), {:timeout, ip}, state.timeout)
    {:noreply, %{state | queue: Map.put(state.queue, ip, request)}}
  end

  @spec ping_timed(GenServer.server, :inet.address) :: {:pong, non_neg_integer} | :pang
  def ping_timed(server, ip) do
    start = DateTime.utc_now()
    case ping(server, ip) do
      :pong -> {:pong, DateTime.diff(DateTime.utc_now, start, :millisecond)}
      :pang -> :pang
    end
  end

  @af_inet 2
  defp icmp_impl(@af_inet, <<_::16, a, b, c, d, _::8 * 8>>, packet, state = %{queue: queue})
      when is_map_key(queue, {a, b, c, d}) do
    #Packet.decode(packet)
    GenServer.reply(queue[{a, b, c, d}].from, :pong)
    {:noreply, state}
  end
  defp icmp_impl(_, _, _, state) do
    {:noreply, state}
  end

  defp timeout_impl(ip, state = %{queue: queue}) when is_map_key(queue, ip) do
    expiry = queue[ip].ttl
    now = DateTime.utc_now()
    case DateTime.compare(expiry, now) do
      :gt ->
        # resend the timeout message, just in case.
        leftover = DateTime.diff(expiry, now, :millisecond)
        Process.send_after(self(), {:timeout, ip}, leftover)
        {:noreply, state}
      _ ->
        GenServer.reply(queue[ip].from, :pang)
        {:noreply, %{state | queue: Map.delete(state.queue, ip)}}
    end
  end
  defp timeout_impl(_, state), do: {:noreply, state}

  #############################################################################
  ## CALLBACKS

  def connect(:init, state) do
    # connect to a sending socket.
    case Nif.connect() do
      :socket_error ->
        {:stop, :socket, state}
      conn -> {:ok, %{state | conn: conn}}
    end
  end

  def disconnect(_, state), do: {:stop, :disconnect, state}

  def handle_call({:ping, ip}, from, state), do: ping_impl(ip, from, state)

  def handle_info(:connected, state) do
    connect_listener_impl(state)
  end
  def handle_info({:icmp, family, addr_bin, packet}, state) do
    icmp_impl(family, addr_bin, packet, state)
  end
  def handle_info({:timeout, ip}, state) do
    timeout_impl(ip, state)
  end
  def handle_info(any, state) do
    IO.inspect(any)
    {:noreply, state}
  end

end
