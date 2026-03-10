#!/bin/bash
# Creative Maintenance Reminder Listener
# Runs continuously to listen for completion confirmations

REPO_DIR="$HOME/github/115_maintenance"
REMINDERS_FILE="$REPO_DIR/reminders.yaml"
LOG_FILE="$HOME/logs/creative-maintenance.log"
CONFIG_FILE="$REPO_DIR/config.yaml"
STATE_FILE="$REPO_DIR/.bot-state.json"

# Ensure log directory exists
mkdir -p "$HOME/logs"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] LISTENER: $1" | tee -a "$LOG_FILE"
}

cd "$REPO_DIR" || exit 1

# Activate virtual environment
source "$REPO_DIR/venv/bin/activate"

log "Starting reminder listener..."

python3 << 'PYTHON_SCRIPT'
import asyncio
import json
import yaml
import os
import subprocess
from datetime import datetime, timedelta
from telegram import Update
from telegram.ext import Application, MessageHandler, filters, ContextTypes

REPO_DIR = os.path.expanduser("~/github/115_maintenance")
REMINDERS_FILE = os.path.join(REPO_DIR, "reminders.yaml")
CONFIG_FILE = os.path.join(REPO_DIR, "config.yaml")
STATE_FILE = os.path.join(REPO_DIR, ".bot-state.json")

def load_config():
    """Load config with bot token from separate file"""
    config = {}
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, 'r') as f:
            config = yaml.safe_load(f) or {}
    
    token_file = config.get('token_file', 'token.yaml')
    token_path = os.path.join(REPO_DIR, token_file)
    if os.path.exists(token_path):
        with open(token_path, 'r') as f:
            token_config = yaml.safe_load(f) or {}
            config['telegram_bot_token'] = token_config.get('telegram_bot_token')
    
    return config

def load_state():
    """Load bot state (message ID -> reminder ID mapping)"""
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE, 'r') as f:
            return json.load(f)
    return {"message_map": {}}  # message_id -> reminder_id

def save_state(state):
    """Save bot state"""
    with open(STATE_FILE, 'w') as f:
        json.dump(state, f, indent=2)

def parse_recurrence(recurrence):
    """Parse recurrence string like '30d', '90d', '1y' into days"""
    if not recurrence:
        return None
    
    recurrence = str(recurrence).lower().strip()
    
    if recurrence.endswith('d'):
        return int(recurrence[:-1])
    elif recurrence.endswith('w'):
        return int(recurrence[:-1]) * 7
    elif recurrence.endswith('m'):
        return int(recurrence[:-1]) * 30
    elif recurrence.endswith('y'):
        return int(recurrence[:-1]) * 365
    return None

def add_days(date_str, days):
    """Add days to a date string"""
    dt = datetime.strptime(date_str, "%Y-%m-%d")
    dt = dt + timedelta(days=days)
    return dt.strftime("%Y-%m-%d")

def update_reminders(reminder_id):
    """Update reminders.yaml when a reminder is completed"""
    print(f"Processing completion for reminder: {reminder_id}")
    
    with open(REMINDERS_FILE, 'r') as f:
        data = yaml.safe_load(f) or {'reminders': []}
    
    reminders = data.get('reminders', [])
    updated = False
    
    for reminder in reminders:
        if reminder.get('id') == reminder_id:
            recurrence = reminder.get('recurrence')
            
            if recurrence:
                # Recurring reminder: update due_date
                days = parse_recurrence(recurrence)
                if days:
                    new_due = add_days(datetime.now().strftime("%Y-%m-%d"), days)
                    reminder['due_date'] = new_due
                    reminder['status'] = 'pending'
                    reminder['last_completed'] = datetime.now().strftime("%Y-%m-%d")
                    if 'last_sent' in reminder:
                        del reminder['last_sent']
                    print(f"Updated recurring reminder '{reminder_id}' next due: {new_due}")
                else:
                    print(f"Unknown recurrence format: {recurrence}")
                    return False
            else:
                # One-time reminder: mark for removal
                reminder['_remove'] = True
                print(f"Marked one-time reminder '{reminder_id}' for removal")
            
            updated = True
            break
    
    if updated:
        # Remove one-time reminders
        data['reminders'] = [r for r in reminders if not r.get('_remove')]
        
        # Save updated reminders
        with open(REMINDERS_FILE, 'w') as f:
            yaml.dump(data, f, default_flow_style=False, sort_keys=False, allow_unicode=True)
        
        # Commit and push
        os.chdir(REPO_DIR)
        subprocess.run(["git", "add", "reminders.yaml"])
        subprocess.run(["git", "commit", "-m", f"Complete reminder: {reminder_id}"])
        subprocess.run(["git", "push"])
        print(f"Changes committed and pushed for {reminder_id}")
        return True
    
    print(f"Reminder '{reminder_id}' not found")
    return False

async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle incoming messages"""
    if not update.message:
        return
    
    message_text = update.message.text or ""
    
    # Check if this is a completion confirmation
    if '✅' in message_text or '✓' in message_text or 'done' in message_text.lower():
        # Try to find the original reminder from the message being replied to
        if update.message.reply_to_message:
            replied_message_id = str(update.message.reply_to_message.message_id)
            state = load_state()
            
            reminder_id = state.get("message_map", {}).get(replied_message_id)
            
            if reminder_id:
                print(f"Completion confirmed for reminder: {reminder_id}")
                if update_reminders(reminder_id):
                    await update.message.reply_text(f"✅ Reminder '{reminder_id}' marked complete!")
                else:
                    await update.message.reply_text(f"⚠️ Could not process reminder '{reminder_id}'")
            else:
                print(f"No reminder found for message ID: {replied_message_id}")
                # Try to parse from message content
                await update.message.reply_text("⚠️ Could not identify which reminder to complete. Please reply directly to the reminder message with ✅")

async def main():
    config = load_config()
    bot_token = config.get('telegram_bot_token')
    
    if not bot_token:
        print("ERROR: No telegram_bot_token found")
        return
    
    application = Application.builder().token(bot_token).build()
    
    # Handle all text messages
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
    
    print("Starting reminder listener...")
    await application.initialize()
    await application.start()
    await application.updater.start_polling(drop_pending_updates=True)
    
    # Keep running
    try:
        while True:
            await asyncio.sleep(60)
    except KeyboardInterrupt:
        print("Shutting down listener...")
    finally:
        await application.stop()

if __name__ == "__main__":
    asyncio.run(main())
PYTHON_SCRIPT
