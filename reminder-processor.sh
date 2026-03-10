#!/bin/zsh
# Creative Maintenance Reminder Processor
# Runs every 15 minutes via launchd

REPO_DIR="$HOME/github/115_maintenance"
REMINDERS_FILE="$REPO_DIR/reminders.yaml"
LOG_FILE="$HOME/logs/creative-maintenance.log"
CONFIG_FILE="$REPO_DIR/config.yaml"

# Ensure log directory exists
mkdir -p "$HOME/logs"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Pull latest changes
cd "$REPO_DIR" || exit 1
git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || true

# Activate virtual environment
source "$REPO_DIR/venv/bin/activate"

# Get today's date
TODAY=$(date +%Y-%m-%d)
log "Processing reminders for $TODAY"

# Parse and process reminders using Python
python3 << 'PYTHON_SCRIPT'
import asyncio
import yaml
import datetime
import os
import subprocess
import sys

REPO_DIR = os.path.expanduser("~/github/115_maintenance")
REMINDERS_FILE = os.path.join(REPO_DIR, "reminders.yaml")
CONFIG_FILE = os.path.join(REPO_DIR, "config.yaml")

# Client to Telegram topic mapping (from customer-work group)
CLIENT_CHANNELS = {
    "EFS": 28,           # EFS topic ID in customer-work group
    "AEBatencourt": 26,  # AEBatencourt topic ID
    "ARS": 25,           # ARS topic ID
    "Creative Intelligence": 24,  # General CI topic
    "Internal": 24,      # Same as CI
}

def load_config():
    """Load config with bot token from separate file"""
    config = {}
    # Load main config
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, 'r') as f:
            config = yaml.safe_load(f) or {}
    
    # Load token from separate file
    token_file = config.get('token_file', 'token.yaml')
    token_path = os.path.join(REPO_DIR, token_file)
    if os.path.exists(token_path):
        with open(token_path, 'r') as f:
            token_config = yaml.safe_load(f) or {}
            config['telegram_bot_token'] = token_config.get('telegram_bot_token')
    
    return config

async def send_telegram_message(topic_id, message):
    """Send message to specific topic in customer-work group using python-telegram-bot"""
    try:
        from telegram import Bot
        
        config = load_config()
        bot_token = config.get('telegram_bot_token')
        
        if not bot_token:
            print("ERROR: No telegram_bot_token found in config.yaml")
            return False
        
        chat_id = "-1003869516415"
        
        bot = Bot(token=bot_token)
        await bot.send_message(
            chat_id=chat_id,
            message_thread_id=topic_id,
            text=message,
            parse_mode='Markdown'
        )
        print(f"Message sent to topic {topic_id}")
        return True
        
    except ImportError:
        print("ERROR: python-telegram-bot not installed. Run: pip3 install python-telegram-bot")
        return False
    except Exception as e:
        print(f"Failed to send message to topic {topic_id}: {e}")
        return False

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
        return int(recurrence[:-1]) * 30  # approximate
    elif recurrence.endswith('y'):
        return int(recurrence[:-1]) * 365
    return None

def add_days(date_str, days):
    """Add days to a date string"""
    dt = datetime.datetime.strptime(date_str, "%Y-%m-%d")
    dt = dt + datetime.timedelta(days=days)
    return dt.strftime("%Y-%m-%d")

async def main():
    today = datetime.datetime.now().strftime("%Y-%m-%d")
    
    # Load reminders
    with open(REMINDERS_FILE, 'r') as f:
        data = yaml.safe_load(f) or {'reminders': []}
    
    reminders = data.get('reminders', [])
    updated = False
    
    for reminder in reminders:
        due_date = reminder.get('due_date', '')
        status = reminder.get('status', 'pending')
        
        # Check if reminder is due
        if due_date and due_date <= today and status == 'pending':
            client = reminder.get('client', 'Creative Intelligence')
            description = reminder.get('description', 'No description provided')
            recurrence = reminder.get('recurrence')
            reminder_id = reminder.get('id', 'unknown')
            
            # Build message
            message = f"🔔 **Maintenance Reminder: {client}**\n\n"
            message += f"**Task:** {reminder_id}\n"
            message += f"**Due:** {due_date}\n"
            if recurrence:
                message += f"**Recurrence:** Every {recurrence}\n"
            message += f"\n{description}\n\n"
            message += "Reply with ✅ when complete."
            
            # Get topic ID for client
            topic_id = CLIENT_CHANNELS.get(client, 24)  # Default to CI general
            
            print(f"Sending reminder: {reminder_id} for {client}")
            
            # Send message
            if await send_telegram_message(topic_id, message):
                reminder['status'] = 'sent'
                reminder['last_sent'] = today
                updated = True
            
    # Save if updated
    if updated:
        with open(REMINDERS_FILE, 'w') as f:
            yaml.dump(data, f, default_flow_style=False, sort_keys=False, allow_unicode=True)
        
        # Commit and push
        os.chdir(REPO_DIR)
        subprocess.run(["git", "add", "reminders.yaml"])
        subprocess.run(["git", "commit", "-m", f"Update reminders - sent notifications on {today}"])
        subprocess.run(["git", "push"])
        print("Changes committed and pushed")

if __name__ == "__main__":
    asyncio.run(main())
PYTHON_SCRIPT

log "Reminder processing complete"
