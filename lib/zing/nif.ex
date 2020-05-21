defmodule Zing.Nif do
  use Zigler

  ~Z"""
  const os = @import("std").os;
  const mem = @import("std").mem;

  // provisional requirement until more blessed erlang headers arrive
  // from zigler.
  const d = @cImport({
    @cInclude("erl_drv.h");
  });

  /////////////////////////////////////////////////////////////////////////////
  // LISTENER

  /// a `listener` is an os thread running as a sidecar outside of the beam
  /// scheduler.  It sits in loop, polling `recv` against the network socket.
  /// if an ICMP request has arrived, it will send icmp messages back to the
  /// process that called it.
  ///
  /// NB: the listener also checks to make sure that the process that launched
  /// it is still alive.
  ///
  /// nif: start_listener/0
  fn start_listener(env: beam.env) beam.term {
    var tid: d.ErlDrvTid = undefined;
    const name: [*c]const u8 = "listener";

    var parent: *beam.pid = beam.allocator.create(beam.pid)
      catch return beam.make_error_atom(env, "enomem");
    // don't deallocate as ownership will be passed to the thread.

    _ = e.enif_self(env, parent);
    var payload: *c_void = @ptrCast(*c_void, parent);

    var res = d.erl_drv_thread_create(name, &tid, listener, payload, null);
    return beam.make_atom(env, "ok");
  }

  export fn listener(param: ?*c_void) ?*c_void {
    var raw_parent: *c_void = param.?;

    // note that ownership of this pointer has been passed from start_listener
    // function.  We have to clean it up when the listener thread is done.
    var parent =
      @ptrCast(*beam.pid, @alignCast(@alignOf(beam.pid), param));
    defer beam.allocator.destroy(parent);

    // it's necessary to build an environment, or else we can't
    // send messages with custom terms out from this environment.
    var env: beam.env = e.enif_alloc_env();
    defer e.enif_free_env(env);

    // create the socket.
    var socket = os.socket(os.AF_INET, os.SOCK_RAW, os.IPPROTO_ICMP) catch {
      send_error(env, parent, "socket");
      return null;
    };
    defer os.close(socket);

    // set the socket timeout.  Defaults to 1 second.
    var ts = os.timespec{.tv_sec = 1, .tv_nsec = 0};

    os.setsockopt(socket, os.SOL_SOCKET, os.SO_RCVTIMEO, mem.asBytes(&ts)) catch {
      send_error(env, parent, "socket");
      return null;
    };
    send_connected(env, parent);

    var recv_addr: os.sockaddr = undefined;
    var packet: [64]u8 = undefined;

    while (true) {
      if (recv_ping(socket, &recv_addr, packet[0..])) | _result | {
        send_icmp(env, parent, &recv_addr, packet[0..]);
      } else |err| switch(err) {
        os.RecvFromError.WouldBlock => _ = null, // normal timeout.
        os.RecvFromError.SystemResources => {
          send_error(env, parent, "resources");
          break;  // terminates the receive loop
        },
        os.RecvFromError.ConnectionRefused => {
          send_error(env, parent, "refused");
          break; // terminates the receive loop
        },
        error.Unexpected => {
          send_error(env, parent, "unexpected");
          break; // terminates the receive loop
        },
      }
      // check to make sure that the parent process is alive.
      // TODO: slightly hacky due to lack of proper nif library support.
      if (0 == d.enif_is_process_alive(@ptrCast(?*d.ErlNifEnv, env), @ptrCast(?*d.ErlNifPid, parent))) break;
    }

    // send the parent process a died signal if it fails.
    send_error(env, parent, "dead");

    return null;
  }

  fn recv_ping(socket: os.fd_t, recv_addr: *os.sockaddr, packet: []u8) !void {
    var addrlen: u32 = @sizeOf(os.sockaddr);
    _ = try os.recvfrom(socket, packet, 0, recv_addr, &addrlen);
  }

  fn send_connected(env: beam.env, parent: *beam.pid) void {
    _ = e.enif_send(null, parent, env, beam.make_atom(env, "connected"));
  }

  fn send_error(env: beam.env, parent: *beam.pid, message: []const u8) void {
    _ = e.enif_send(null, parent, env, beam.make_error_binary(env, message));
  }

  fn send_icmp(env: beam.env, parent: *beam.pid, recv_addr: *os.sockaddr, packet: []u8) void {
    var payload_list = [4]beam.term{
      beam.make_atom(env, "icmp"),
      beam.make_u32(env, @intCast(u32, recv_addr.family)),
      beam.make_slice(env, recv_addr.data[0..]),
      beam.make_slice(env, packet)
    };
    var payload = beam.make_tuple(env, payload_list[0..]);
    _ = e.enif_send(null, parent, env, payload);
  }

  /////////////////////////////////////////////////////////////////////////////
  // SENDER

  /// resource: ping_socket definition
  const ping_socket = os.fd_t;

  /// nif: connect/0
  fn connect(env: beam.env) beam.term {
    var new_socket = setup_socket()
      catch return beam.make_atom(env, "socket_error");
    return __resource__.create(ping_socket, env, new_socket)
      catch return beam.make_atom(env, "resource_error");
  }

  // cleans up a ping socket.  This is done by closing the socket,
  // using zig's builtin os.close
  /// resource: ping_socket cleanup
  fn ping_socket_cleanup(env: beam.env, sockptr: *ping_socket) void {
    os.close(sockptr.*);
  }

  /// nif: ping/3
  fn ping(env: beam.env, conn: beam.term, ip_addr: []u8, packet: []u8) beam.term {
    if (ip_addr.len != 4) return beam.make_atom(env, "ip_error");

    var socket = __resource__.fetch(ping_socket, env, conn)
      catch return beam.make_error_atom(env, "einval");

    send_ping(socket, packet, ip_addr)
      catch return beam.make_error_atom(env, "ping_error");

    return beam.make_atom(env, "ok");
  }

  const IP_TTL = 2;

  fn setup_socket() !os.fd_t {
    // 64 ms TTL
    var ttl_val = [4]u8{64, 0, 0, 0};

    // create the socket.
    var socket = try os.socket(os.AF_INET, os.SOCK_RAW, os.IPPROTO_ICMP);

    try os.setsockopt(socket, os.SOL_IP, IP_TTL, ttl_val[0..]);

    return socket;
  }

  fn send_ping(socket: os.fd_t, packet: []u8, ip: []u8) !void {
    var dest_addr = os.sockaddr{
      .family = os.AF_INET,
      .data = [14]u8{0, 0, ip[0], ip[1], ip[2], ip[3], 0, 0,
                     0, 0, 0, 0, 0, 0}
    };

    // next, send the icmp packet down the pipe.
    var res = try os.sendto(socket, packet, 0, &dest_addr, @sizeOf(os.sockaddr));
  }
  """
end
