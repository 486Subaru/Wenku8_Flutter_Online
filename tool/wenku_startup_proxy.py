import asyncio
import sys


async def relay(source, target):
    try:
        while block := await source.read(65536):
            target.write(block)
            await target.drain()
    except (ConnectionError, OSError):
        pass
    finally:
        if target.can_write_eof():
            try:
                target.write_eof()
            except (ConnectionError, OSError):
                pass


async def connect(client, outgoing):
    upstream = None
    try:
        line = (await asyncio.wait_for(client.readline(), 10)).decode("ascii")
        method, endpoint, _ = line.strip().split()
        if method != "CONNECT":
            outgoing.write(b"HTTP/1.1 405 Method Not Allowed\r\nConnection: close\r\n\r\n")
            await outgoing.drain()
            return
        while (await client.readline()).strip():
            pass
        host, port = endpoint.rsplit(":", 1)
        if port != "443":
            outgoing.write(b"HTTP/1.1 403 Forbidden\r\nConnection: close\r\n\r\n")
            await outgoing.drain()
            return
        print(host.lower(), flush=True)
        remote, upstream = await asyncio.wait_for(asyncio.open_connection(host, int(port)), 10)
        outgoing.write(b"HTTP/1.1 200 Connection Established\r\n\r\n")
        await outgoing.drain()
        await asyncio.wait_for(
            asyncio.gather(relay(client, upstream), relay(remote, outgoing)), 35,
        )
    except (ConnectionError, OSError, TimeoutError, ValueError):
        pass
    finally:
        if upstream is not None:
            upstream.close()
        outgoing.close()


async def main():
    server = await asyncio.start_server(connect, "127.0.0.1", int(sys.argv[1]))
    async with server:
        await server.serve_forever()


asyncio.run(main())
