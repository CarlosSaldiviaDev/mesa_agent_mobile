#!/usr/bin/env python3
"""Mesa mobile Telegram deploy agent (runs on Mac)."""
from __future__ import annotations

import asyncio
import logging
import os
import subprocess
import threading
import time
from pathlib import Path
from queue import Queue

import yaml
from telegram import Update
from telegram.ext import Application, CommandHandler, ContextTypes, MessageHandler, filters
from telegram.request import HTTPXRequest

BASE_DIR = Path(os.environ.get("MESA_MOBILE_AGENT_DIR", Path(__file__).resolve().parent))
CONFIG_PATH = BASE_DIR / "config.yaml"
SCRIPTS_DIR = BASE_DIR / "scripts"

telegram_queue: Queue[str] = Queue()
pipeline_lock = threading.Lock()

logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(message)s")
logger = logging.getLogger("mesa-mobile-agent")

if not CONFIG_PATH.exists():
    raise RuntimeError(f"config.yaml missing at {CONFIG_PATH} — copy config.yaml.example")

with open(CONFIG_PATH) as f:
    config = yaml.safe_load(f)

TOKEN = config["telegram"]["token"]
ALLOWED_USERS = config["telegram"]["allowed_users"]

HELP_TEXT = (
    "/mobile status\n"
    "/mobile doctor\n"
    "/mobile clean\n"
    "/mobile build android|ios\n"
    "/mobile upload android|ios\n"
    "/mobile full all"
)


def send_telegram(text: str) -> None:
    telegram_queue.put(text)


async def telegram_sender(application: Application) -> None:
    loop = asyncio.get_running_loop()
    while True:
        text = await loop.run_in_executor(None, telegram_queue.get)
        try:
            await application.bot.send_message(
                chat_id=ALLOWED_USERS[0], text=text, parse_mode="Markdown"
            )
        except Exception as first:
            logger.warning("telegram markdown failed (%s); retrying plain", first)
            try:
                await application.bot.send_message(chat_id=ALLOWED_USERS[0], text=text)
            except Exception:
                logger.exception("telegram send failed")
                await asyncio.sleep(2)


def run_script(script_name: str) -> str:
    script_path = SCRIPTS_DIR / script_name
    if not script_path.exists():
        return f"script not found: {script_name}"
    start = time.time()
    try:
        result = subprocess.run(
            ["/bin/bash", "-lc", f"cd '{SCRIPTS_DIR}' && /bin/bash '{script_path.name}'"],
            capture_output=True,
            text=True,
            timeout=7200,
        )
        elapsed = int(time.time() - start)
        out = (result.stdout or "").strip()
        err = (result.stderr or "").strip()
        if result.returncode != 0:
            combined = "\n".join(x for x in (out, err) if x).strip()
            return f"failed ({elapsed}s)\n\n{(combined or 'no output')[-3000:]}"
        return f"finished ({elapsed}s)\n\n{(out or err or 'done')[-3000:]}"
    except subprocess.TimeoutExpired:
        return "timed out (120 min)"
    except Exception as exc:
        return f"exception: {exc}"


def run_full_pipeline() -> None:
    if not pipeline_lock.acquire(blocking=False):
        send_telegram("pipeline locked")
        return
    try:
        steps = [
            ("1/5 clean", "clean.sh"),
            ("2/5 build android", "build_android.sh"),
            ("3/5 upload android", "upload_android.sh"),
            ("4/5 build ios", "build_ios.sh"),
            ("5/5 upload ios", "upload_ios.sh"),
        ]
        start = time.time()
        send_telegram("full mobile pipeline started…")
        for title, script in steps:
            send_telegram(f"{title}…")
            result = run_script(script)
            if result.startswith("failed") or "timed out" in result:
                send_telegram(f"{title} failed\n\n```{result[-2500:]}```")
                return
            send_telegram(f"{title} ok")
        send_telegram(f"full mobile pipeline finished\n⏱ `{int(time.time() - start)}s`")
    finally:
        pipeline_lock.release()


async def reply_help(update: Update) -> None:
    if not update.message:
        return
    if not update.effective_user or update.effective_user.id not in ALLOWED_USERS:
        await update.message.reply_text("not authorized")
        return
    await update.message.reply_text(HELP_TEXT)


async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    await reply_help(update)


async def unknown_message(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    await reply_help(update)


async def mobile_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if update.effective_user.id not in ALLOWED_USERS:
        await update.message.reply_text("not authorized")
        return

    if not context.args:
        await update.message.reply_text(HELP_TEXT)
        return

    key = tuple(context.args)
    if key == ("full", "all"):
        await update.message.reply_text("full mobile pipeline started")
        threading.Thread(target=run_full_pipeline, daemon=True).start()
        return

    scripts = {
        ("status",): "mobile_status.sh",
        ("doctor",): "doctor.sh",
        ("clean",): "clean.sh",
        ("build", "android"): "build_android.sh",
        ("build", "ios"): "build_ios.sh",
        ("upload", "android"): "upload_android.sh",
        ("upload", "ios"): "upload_ios.sh",
    }
    if key not in scripts:
        await update.message.reply_text(f"unknown\n{HELP_TEXT}")
        return

    script = scripts[key]
    await update.message.reply_text(f"`{script}` started", parse_mode="Markdown")

    def runner() -> None:
        send_telegram(f"running `{script}`…")
        result = run_script(script)
        send_telegram(f"```{result[-3500:]}```")

    threading.Thread(target=runner, daemon=True).start()


async def post_init(application: Application) -> None:
    asyncio.create_task(telegram_sender(application))
    await asyncio.sleep(2)
    send_telegram("mesa-mobile-agent online")


def main() -> None:
    request = HTTPXRequest(connect_timeout=20, read_timeout=20, write_timeout=20, pool_timeout=20)
    app = (
        Application.builder()
        .token(TOKEN)
        .request(request)
        .post_init(post_init)
        .build()
    )
    app.add_handler(CommandHandler("mobile", mobile_command))
    app.add_handler(CommandHandler("start", help_command))
    app.add_handler(CommandHandler("help", help_command))
    app.add_handler(MessageHandler(filters.TEXT | filters.COMMAND, unknown_message))
    app.run_polling()


if __name__ == "__main__":
    main()
