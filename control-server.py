#!/usr/bin/env python3
"""
vk-turn-proxy Control Server
Запускается на Linux. iOS-приложение подключается сюда и управляет прокси.

Использование:
    python3 control-server.py [--port 9001]

Протокол (TCP, текстовый):
    START:<args>  → запустить ./client-linux-amd64 <args>
    STOP          → остановить клиент
    STATUS        → вернуть статус
"""

import asyncio
import subprocess
import shutil
import os
import sys
import signal
import logging
from pathlib import Path

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")
log = logging.getLogger("control")

BINARY_NAME = "client-linux-amd64"
BINARY_PATH = Path(__file__).parent / BINARY_NAME

proxy_proc: subprocess.Popen | None = None


def find_binary() -> str | None:
    if BINARY_PATH.exists():
        return str(BINARY_PATH)
    found = shutil.which(BINARY_NAME)
    return found


async def handle_client(reader: asyncio.StreamReader, writer: asyncio.StreamWriter):
    global proxy_proc
    addr = writer.get_extra_info("peername")
    log.info(f"[iOS] Подключился {addr}")

    def send(msg: str):
        try:
            writer.write((msg + "\n").encode())
        except Exception:
            pass

    try:
        raw = await asyncio.wait_for(reader.readline(), timeout=10)
        cmd = raw.decode().strip()
        log.info(f"[CMD] {cmd}")

        if cmd == "STATUS":
            running = proxy_proc is not None and proxy_proc.poll() is None
            send(f"STATUS:{'RUNNING' if running else 'STOPPED'}")

        elif cmd == "STOP":
            if proxy_proc and proxy_proc.poll() is None:
                proxy_proc.terminate()
                try:
                    proxy_proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    proxy_proc.kill()
                send("STOPPED")
                log.info("Прокси остановлен")
            else:
                send("NOT_RUNNING")

        elif cmd.startswith("START:"):
            args_str = cmd[6:]
            binary = find_binary()
            if not binary:
                send(f"ERROR: Бинарник {BINARY_NAME} не найден. Скачай его рядом со скриптом.")
                return

            # Останавливаем старый процесс если есть
            if proxy_proc and proxy_proc.poll() is None:
                proxy_proc.terminate()
                proxy_proc.wait(timeout=3)

            # Формируем команду
            import shlex
            cmd_list = [binary] + shlex.split(args_str)
            log.info(f"Запуск: {' '.join(cmd_list)}")
            send(f"STARTING: {' '.join(cmd_list)}")

            # Запускаем процесс
            proc = subprocess.Popen(
                cmd_list,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1
            )
            proxy_proc = proc

            send(f"PID:{proc.pid}")

            # Стримим вывод обратно в iOS
            loop = asyncio.get_event_loop()

            def stream_output():
                for line in iter(proc.stdout.readline, ""):
                    line = line.rstrip()
                    if line:
                        asyncio.run_coroutine_threadsafe(
                            _safe_send(writer, line + "\n"), loop
                        )
                code = proc.wait()
                asyncio.run_coroutine_threadsafe(
                    _safe_send(writer, f"EXITED:{code}\n"), loop
                )

            import threading
            t = threading.Thread(target=stream_output, daemon=True)
            t.start()

            # Держим соединение открытым пока клиент не отключится
            try:
                await reader.read(1)
            except Exception:
                pass

        else:
            send(f"UNKNOWN:{cmd}")

    except asyncio.TimeoutError:
        send("TIMEOUT")
    except Exception as e:
        log.error(f"Ошибка: {e}")
        send(f"ERROR:{e}")
    finally:
        try:
            writer.close()
            await writer.wait_closed()
        except Exception:
            pass
        log.info(f"[iOS] Отключился {addr}")


async def _safe_send(writer: asyncio.StreamWriter, msg: str):
    try:
        writer.write(msg.encode())
        await writer.drain()
    except Exception:
        pass


async def main():
    port = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[1] == "--port" else 9001

    server = await asyncio.start_server(handle_client, "0.0.0.0", port)
    log.info(f"✅ Control Server запущен на 0.0.0.0:{port}")
    log.info(f"   Бинарник: {find_binary() or '⚠️ НЕ НАЙДЕН — скачай client-linux-amd64'}")
    log.info("   Жду подключений от iOS...")

    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        log.info("Остановлен.")
        if proxy_proc and proxy_proc.poll() is None:
            proxy_proc.terminate()
