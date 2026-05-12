"""
2D MMO Game Server
Obsługuje połączenia WebSocket od klientów Godot.
Zarządza graczami, pozycjami i czatem.
PostgreSQL: zapisuje konta graczy, historię czatu, ostatnią pozycję.
"""

import asyncio
import json
import logging
import uuid
import os
import websockets
import asyncpg
from websockets import ServerConnection

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger(__name__)

HOST = "0.0.0.0"
PORT = 9999

# Konfiguracja bazy – ustaw przez zmienne środowiskowe lub wpisz bezpośrednio
DB_CONFIG = {
    "host":     os.getenv("DB_HOST", "localhost"),
    "port":     int(os.getenv("DB_PORT", "5432")),
    "database": os.getenv("DB_NAME", "mmo_game"),
    "user":     os.getenv("DB_USER", "mmo_user"),
    "password": os.getenv("DB_PASS", "warehouse2024"),
}

# Globalny pool połączeń do bazy
db_pool: asyncpg.Pool = None  # type: ignore

# Słownik aktywnych graczy: {player_id: {"ws": ws, "name": str, "x": float, "y": float, "color": str}}
players: dict[str, dict] = {}


async def init_db():
    """Tworzy tabele jeśli nie istnieją."""
    async with db_pool.acquire() as conn:
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS players (
                name        VARCHAR(20) PRIMARY KEY,
                color       VARCHAR(10) NOT NULL DEFAULT '#ffffff',
                last_x      FLOAT NOT NULL DEFAULT 400,
                last_y      FLOAT NOT NULL DEFAULT 300,
                created_at  TIMESTAMP DEFAULT NOW(),
                last_seen   TIMESTAMP DEFAULT NOW()
            )
        """)
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS chat_log (
                id          SERIAL PRIMARY KEY,
                player_name VARCHAR(20) NOT NULL,
                message     TEXT NOT NULL,
                sent_at     TIMESTAMP DEFAULT NOW()
            )
        """)
    log.info("Baza danych zainicjalizowana.")


async def db_save_player(name: str, color: str, x: float, y: float):
    """Zapisz/zaktualizuj gracza w bazie."""
    try:
        async with db_pool.acquire() as conn:
            await conn.execute("""
                INSERT INTO players (name, color, last_x, last_y, last_seen)
                VALUES ($1, $2, $3, $4, NOW())
                ON CONFLICT (name) DO UPDATE
                SET color=$2, last_x=$3, last_y=$4, last_seen=NOW()
            """, name, color, x, y)
    except Exception as e:
        log.error(f"db_save_player error: {e}")


async def db_load_player(name: str) -> dict | None:
    """Załaduj ostatnią pozycję i kolor gracza z bazy."""
    try:
        async with db_pool.acquire() as conn:
            row = await conn.fetchrow(
                "SELECT color, last_x, last_y FROM players WHERE name=$1", name
            )
            if row:
                return {"color": row["color"], "x": row["last_x"], "y": row["last_y"]}
    except Exception as e:
        log.error(f"db_load_player error: {e}")
    return None


async def db_save_chat(player_name: str, text: str):
    """Zapisz wiadomość czatu do bazy."""
    try:
        async with db_pool.acquire() as conn:
            await conn.execute(
                "INSERT INTO chat_log (player_name, message) VALUES ($1, $2)",
                player_name, text
            )
    except Exception as e:
        log.error(f"db_save_chat error: {e}")


async def broadcast(message: dict, exclude_id: str | None = None):
    """Wyślij wiadomość do wszystkich podłączonych graczy."""
    data = json.dumps(message)
    for pid, pdata in list(players.items()):
        if pid == exclude_id:
            continue
        try:
            await pdata["ws"].send(data)
        except websockets.ConnectionClosed:
            pass


async def send_to(player_id: str, message: dict):
    """Wyślij wiadomość do konkretnego gracza."""
    pdata = players.get(player_id)
    if pdata:
        try:
            await pdata["ws"].send(json.dumps(message))
        except websockets.ConnectionClosed:
            pass


async def handle_client(ws: ServerConnection):
    """Obsługa jednego połączenia klienta."""
    player_id = str(uuid.uuid4())[:8]
    log.info(f"Nowe połączenie: {player_id} z {ws.remote_address}")

    await ws.send(json.dumps({"type": "welcome", "player_id": player_id}))

    try:
        async for raw in ws:
            try:
                msg = json.loads(raw)
            except json.JSONDecodeError:
                log.warning(f"Nieprawidłowy JSON od {player_id}: {raw}")
                continue

            msg_type = msg.get("type")

            # --- Dołączenie do gry ---
            if msg_type == "join":
                name = msg.get("name", f"Gracz_{player_id}")[:20]
                color = msg.get("color", "#ffffff")

                # Załaduj ostatnią pozycję z bazy (jeśli gracz był tu wcześniej)
                saved = await db_load_player(name)
                start_x = saved["x"] if saved else 400.0
                start_y = saved["y"] if saved else 300.0
                if saved and saved["color"]:
                    color = saved["color"]

                players[player_id] = {
                    "ws": ws,
                    "name": name,
                    "x": start_x,
                    "y": start_y,
                    "color": color,
                }
                log.info(f"Gracz dołączył: {name} ({player_id}) @ {start_x},{start_y}")

                # Wyślij nowemu graczowi jego pozycję startową
                await send_to(player_id, {
                    "type": "spawn_position",
                    "x": start_x,
                    "y": start_y,
                    "color": color,
                })

                # Lista istniejących graczy
                existing = [
                    {"player_id": pid, "name": pd["name"],
                     "x": pd["x"], "y": pd["y"], "color": pd["color"]}
                    for pid, pd in players.items() if pid != player_id
                ]
                await send_to(player_id, {"type": "existing_players", "players": existing})

                await broadcast({
                    "type": "player_joined",
                    "player_id": player_id,
                    "name": name,
                    "x": start_x,
                    "y": start_y,
                    "color": color,
                }, exclude_id=player_id)

                # Zapisz do bazy
                await db_save_player(name, color, start_x, start_y)

            # --- Ruch gracza ---
            elif msg_type == "move":
                if player_id not in players:
                    continue
                x = float(msg.get("x", 0))
                y = float(msg.get("y", 0))
                players[player_id]["x"] = x
                players[player_id]["y"] = y

                await broadcast({
                    "type": "player_moved",
                    "player_id": player_id,
                    "x": x,
                    "y": y,
                }, exclude_id=player_id)

            # --- Wiadomość czatu ---
            elif msg_type == "chat":
                if player_id not in players:
                    continue
                text = str(msg.get("text", ""))[:200].strip()
                if text:
                    name = players[player_id]["name"]
                    log.info(f"[CZAT] {name}: {text}")
                    await broadcast({"type": "chat", "player_id": player_id,
                                     "name": name, "text": text})
                    await db_save_chat(name, text)

            # --- Ping ---
            elif msg_type == "ping":
                await send_to(player_id, {"type": "pong"})

            else:
                log.warning(f"Nieznany typ wiadomości od {player_id}: {msg_type}")

    except websockets.ConnectionClosed as e:
        log.info(f"Rozłączono: {player_id} ({e.code})")
    finally:
        if player_id in players:
            pdata = players[player_id]
            name = pdata["name"]
            # Zapisz ostatnią pozycję przed wyjściem
            await db_save_player(name, pdata["color"], pdata["x"], pdata["y"])
            del players[player_id]
            await broadcast({"type": "player_left", "player_id": player_id, "name": name})
            log.info(f"Gracz opuścił grę: {name} ({player_id})")


async def main():
    global db_pool
    log.info("Łączenie z PostgreSQL...")
    try:
        db_pool = await asyncpg.create_pool(**DB_CONFIG, min_size=2, max_size=10)
        await init_db()
        log.info("PostgreSQL: połączono.")
    except Exception as e:
        log.warning(f"PostgreSQL niedostępny – tryb bez bazy: {e}")
        db_pool = None

    log.info(f"Serwer MMO startuje na ws://{HOST}:{PORT}")
    async with websockets.serve(handle_client, HOST, PORT):
        await asyncio.Future()


if __name__ == "__main__":
    asyncio.run(main())
