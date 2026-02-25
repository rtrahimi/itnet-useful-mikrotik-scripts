#!/usr/bin/env python3
import argparse
import datetime
import ipaddress
import socket
import struct
import threading
from pathlib import Path


OPENAI_DOMAIN_SUFFIXES = {
    "openai.com",
    "chatgpt.com",
    "oaistatic.com",
    "oaiusercontent.com",
    "statsigapi.net",
    "challenges.cloudflare.com",
    "js.stripe.com",
    "intercom.io",
    "browser-intake-datadoghq.com",
    "ct.sendgrid.net",
    "chatgpt.livekit.cloud",
    "workos.imgix.net",
}

DISCORD_DOMAIN_SUFFIXES = {
    "discord.com",
    "discord.gg",
    "discordapp.com",
    "discordapp.net",
    "discord.media",
    "discordcdn.com",
    "discordstatus.com",
    "dis.gd",
}


def normalize_domain(name: str) -> str:
    return name.rstrip(".").lower().strip()


def domain_matches_suffix(domain: str, suffix: str) -> bool:
    return domain == suffix or domain.endswith("." + suffix)


def classify_domain(domain: str) -> set[str]:
    result: set[str] = set()
    d = normalize_domain(domain)
    if not d:
        return result
    for suffix in OPENAI_DOMAIN_SUFFIXES:
        if domain_matches_suffix(d, suffix):
            result.add("openai")
            break
    for suffix in DISCORD_DOMAIN_SUFFIXES:
        if domain_matches_suffix(d, suffix):
            result.add("discord")
            break
    return result


def read_name(packet: bytes, offset: int) -> tuple[str, int]:
    labels: list[str] = []
    jumped = False
    next_offset = offset
    steps = 0
    while True:
        if offset >= len(packet):
            raise ValueError("dns name offset out of range")
        length = packet[offset]
        if length & 0xC0 == 0xC0:
            if offset + 1 >= len(packet):
                raise ValueError("truncated compression pointer")
            pointer = ((length & 0x3F) << 8) | packet[offset + 1]
            if pointer >= len(packet):
                raise ValueError("compression pointer out of range")
            if not jumped:
                next_offset = offset + 2
                jumped = True
            offset = pointer
            steps += 1
            if steps > len(packet):
                raise ValueError("compression loop")
            continue
        if length == 0:
            if not jumped:
                next_offset = offset + 1
            break
        offset += 1
        if offset + length > len(packet):
            raise ValueError("truncated label")
        labels.append(packet[offset:offset + length].decode("ascii", errors="ignore"))
        offset += length
        if not jumped:
            next_offset = offset
    return normalize_domain(".".join(labels)), next_offset


def parse_dns_message(packet: bytes) -> dict:
    if len(packet) < 12:
        raise ValueError("dns packet too small")
    _id, _flags, qdcount, ancount, nscount, arcount = struct.unpack("!HHHHHH", packet[:12])
    offset = 12
    question_names: list[str] = []
    observed_names: list[str] = []
    a_records: list[str] = []
    for _ in range(qdcount):
        qname, offset = read_name(packet, offset)
        if offset + 4 > len(packet):
            raise ValueError("truncated question")
        question_names.append(qname)
        observed_names.append(qname)
        offset += 4
    total_rr = ancount + nscount + arcount
    for _ in range(total_rr):
        name, offset = read_name(packet, offset)
        if offset + 10 > len(packet):
            raise ValueError("truncated rr header")
        rr_type, _rr_class, _ttl, rdlength = struct.unpack("!HHIH", packet[offset:offset + 10])
        offset += 10
        if offset + rdlength > len(packet):
            raise ValueError("truncated rdata")
        if name:
            observed_names.append(name)
        if rr_type == 1 and rdlength == 4:
            a_records.append(str(ipaddress.IPv4Address(packet[offset:offset + 4])))
        elif rr_type in (2, 5, 12):
            try:
                target, _ = read_name(packet, offset)
                if target:
                    observed_names.append(target)
            except ValueError:
                pass
        offset += rdlength
    return {
        "questions": question_names,
        "names": observed_names,
        "a_records": a_records,
    }


def make_servfail(query: bytes) -> bytes:
    if len(query) < 12:
        return b""
    response = bytearray(query)
    response[2] |= 0x80
    response[3] = (response[3] & 0xF0) | 0x02
    response[6:12] = b"\x00\x00\x00\x00\x00\x00"
    return bytes(response)


def recv_exact(sock: socket.socket, length: int) -> bytes | None:
    data = bytearray()
    while len(data) < length:
        chunk = sock.recv(length - len(data))
        if not chunk:
            return None
        data.extend(chunk)
    return bytes(data)


class DNSCollector:
    def __init__(
        self,
        listen_host: str,
        listen_port: int,
        upstream_host: str,
        upstream_port: int,
        timeout: float,
        output_file: Path,
        events_file: Path,
    ) -> None:
        self.listen_host = listen_host
        self.listen_port = listen_port
        self.upstream_host = upstream_host
        self.upstream_port = upstream_port
        self.timeout = timeout
        self.output_file = output_file
        self.events_file = events_file
        self.lock = threading.Lock()
        self.known_ips = self._load_known_ips()

    def _load_known_ips(self) -> set[str]:
        if not self.output_file.exists():
            return set()
        known: set[str] = set()
        for line in self.output_file.read_text(encoding="ascii", errors="ignore").splitlines():
            value = line.strip()
            if not value:
                continue
            try:
                ip = ipaddress.IPv4Address(value)
            except ValueError:
                continue
            if ip.is_global:
                known.add(str(ip))
        return known

    def _write_ip_file(self) -> None:
        sorted_ips = sorted(self.known_ips, key=lambda x: int(ipaddress.IPv4Address(x)))
        tmp_file = Path(str(self.output_file) + ".tmp")
        payload = ""
        if sorted_ips:
            payload = "\n".join(sorted_ips) + "\n"
        tmp_file.write_text(payload, encoding="ascii")
        tmp_file.replace(self.output_file)

    def save_ips(self, ips: list[str]) -> list[str]:
        new_ips: list[str] = []
        with self.lock:
            for item in ips:
                try:
                    ip = ipaddress.IPv4Address(item)
                except ValueError:
                    continue
                if not ip.is_global:
                    continue
                text = str(ip)
                if text in self.known_ips:
                    continue
                self.known_ips.add(text)
                new_ips.append(text)
            if new_ips:
                self._write_ip_file()
        return new_ips

    def append_event(self, client: tuple[str, int], protocol: str, services: set[str], names: set[str], ips: list[str], new_ips: list[str]) -> None:
        timestamp = datetime.datetime.utcnow().replace(microsecond=0).isoformat() + "Z"
        line = (
            f"{timestamp}\tclient={client[0]}:{client[1]}\tproto={protocol}\t"
            f"services={','.join(sorted(services))}\t"
            f"domains={','.join(sorted(names))}\t"
            f"ips={','.join(sorted(set(ips)))}\t"
            f"new={','.join(sorted(set(new_ips)))}\n"
        )
        with self.lock:
            with self.events_file.open("a", encoding="utf-8") as handle:
                handle.write(line)

    def inspect_dns(self, query: bytes, response: bytes, client: tuple[str, int], protocol: str) -> None:
        try:
            q = parse_dns_message(query)
            r = parse_dns_message(response)
        except ValueError:
            return
        names = set(q["names"]) | set(r["names"])
        services: set[str] = set()
        for name in names:
            services |= classify_domain(name)
        if not services:
            return
        ips = r["a_records"]
        if not ips:
            return
        new_ips = self.save_ips(ips)
        self.append_event(client, protocol, services, names, ips, new_ips)

    def forward_udp(self, query: bytes) -> bytes | None:
        upstream = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            upstream.settimeout(self.timeout)
            upstream.sendto(query, (self.upstream_host, self.upstream_port))
            response, _ = upstream.recvfrom(65535)
            return response
        except OSError:
            return None
        finally:
            upstream.close()

    def forward_tcp(self, query: bytes) -> bytes | None:
        try:
            with socket.create_connection((self.upstream_host, self.upstream_port), timeout=self.timeout) as upstream:
                upstream.settimeout(self.timeout)
                upstream.sendall(struct.pack("!H", len(query)) + query)
                size_raw = recv_exact(upstream, 2)
                if size_raw is None:
                    return None
                size = struct.unpack("!H", size_raw)[0]
                return recv_exact(upstream, size)
        except OSError:
            return None

    def handle_udp(self, server_socket: socket.socket, payload: bytes, client: tuple[str, int]) -> None:
        response = self.forward_udp(payload)
        if not response:
            response = make_servfail(payload)
        if response:
            try:
                server_socket.sendto(response, client)
            except OSError:
                pass
            self.inspect_dns(payload, response, client, "udp")

    def serve_udp(self) -> None:
        udp_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        udp_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        udp_socket.bind((self.listen_host, self.listen_port))
        while True:
            payload, client = udp_socket.recvfrom(65535)
            threading.Thread(target=self.handle_udp, args=(udp_socket, payload, client), daemon=True).start()

    def handle_tcp_client(self, client_socket: socket.socket, client: tuple[str, int]) -> None:
        with client_socket:
            while True:
                header = recv_exact(client_socket, 2)
                if header is None:
                    return
                size = struct.unpack("!H", header)[0]
                query = recv_exact(client_socket, size)
                if query is None:
                    return
                response = self.forward_tcp(query)
                if not response:
                    response = make_servfail(query)
                if not response:
                    return
                try:
                    client_socket.sendall(struct.pack("!H", len(response)) + response)
                except OSError:
                    return
                self.inspect_dns(query, response, client, "tcp")

    def serve_tcp(self) -> None:
        tcp_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        tcp_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        tcp_socket.bind((self.listen_host, self.listen_port))
        tcp_socket.listen(256)
        while True:
            client_socket, client = tcp_socket.accept()
            threading.Thread(target=self.handle_tcp_client, args=(client_socket, client), daemon=True).start()

    def run(self) -> None:
        udp_thread = threading.Thread(target=self.serve_udp, daemon=True)
        tcp_thread = threading.Thread(target=self.serve_tcp, daemon=True)
        udp_thread.start()
        tcp_thread.start()
        udp_thread.join()
        tcp_thread.join()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--listen-host", default="0.0.0.0")
    parser.add_argument("--listen-port", type=int, default=53)
    parser.add_argument("--upstream-host", default="8.8.8.8")
    parser.add_argument("--upstream-port", type=int, default=53)
    parser.add_argument("--timeout", type=float, default=3.0)
    parser.add_argument("--output-file", default="/root/openai_discord_ipv4.txt")
    parser.add_argument("--events-file", default="/root/openai_discord_dns_events.log")
    args = parser.parse_args()

    collector = DNSCollector(
        listen_host=args.listen_host,
        listen_port=args.listen_port,
        upstream_host=args.upstream_host,
        upstream_port=args.upstream_port,
        timeout=args.timeout,
        output_file=Path(args.output_file),
        events_file=Path(args.events_file),
    )
    collector.run()


if __name__ == "__main__":
    main()
