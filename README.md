# Creative Maintenance Reminders

Automated reminder system for recurring maintenance tasks (SSL certificates, client secrets, renewals, etc.)

## How It Works

- Reminders are stored in `reminders.yaml` (git-backed, human editable)
- The processor runs every 15 minutes to check for due reminders
- When a reminder is due, it sends a message to the appropriate Telegram topic
- The listener runs continuously to watch for completion confirmations
- After you complete a task and reply ✅ to the reminder message, the system either:
  - **Recurring reminders**: Updates the due date based on the interval
  - **One-time reminders**: Removes them from the list

## Setup

### 1. Create a Telegram Bot

1. Message [@BotFather](https://t.me/BotFather) on Telegram
2. Send `/newbot` and follow instructions
3. Copy the bot token
4. Add the bot to your `customer-work` Telegram group
5. Make the bot an admin in the group

### 2. Configure the Bot Token

```bash
cd ~/github/115_maintenance
# Edit config.yaml with your bot token
nano config.yaml
```

Update the token:
```yaml
telegram_bot_token: "YOUR_BOT_TOKEN_HERE"
```

### 3. Set Up Virtual Environment

```bash
cd ~/github/115_maintenance
python3 -m venv venv
source venv/bin/activate
pip install python-telegram-bot pyyaml
```

### 4. Install LaunchAgent for Processor (sends reminders)

Copy the launchd plist and load it:

```bash
cp ~/github/115_maintenance/launchd/ai.creative-intelligence.maintenance-reminders.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/ai.creative-intelligence.maintenance-reminders.plist
```

### 5. Install LaunchAgent for Listener (processes completions)

The listener watches for ✅ replies and updates reminders:

```bash
cp ~/github/115_maintenance/launchd/ai.creative-intelligence.maintenance-listener.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/ai.creative-intelligence.maintenance-listener.plist
```

## Adding a Reminder

Edit `reminders.yaml` and add to the `reminders:` list:

```yaml
reminders:
  - id: efs-ssl-cert
    client: EFS
    due_date: "2026-04-15"
    recurrence: "90d"
    description: |
      Renew SSL certificate for efsfieldservice.com
      
      Steps:
      1. Log into Cloudflare
      2. Generate new origin certificate
      3. Update AWS ACM
      4. Verify HTTPS is working
    status: pending
```

### Fields

| Field | Description |
|-------|-------------|
| `id` | Unique identifier (lowercase, dashes) |
| `client` | Client name - determines Telegram topic (EFS, AEBatencourt, ARS, Creative Intelligence) |
| `due_date` | When to fire the reminder (YYYY-MM-DD) |
| `recurrence` | `null` for one-time, or `"30d"`, `"90d"`, `"1y"`, etc. |
| `description` | Markdown description of the task |
| `status` | `pending`, `sent`, or `completed` |

### Recurrence Formats

- `30d` - 30 days
- `90d` - 90 days  
- `6m` - 6 months (approximate)
- `1y` - 1 year (approximate)

## Client Channel Mapping

| Client | Telegram Topic ID | Channel |
|--------|-------------------|---------|
| EFS | 28 | #efs in customer-work |
| AEBatencourt | 26 | #aebatencourt in customer-work |
| ARS | 25 | #ars in customer-work |
| Creative Intelligence / Internal | 24 | #general in customer-work |

## Completing Reminders

### Automatic (Reply to Message)

Reply directly to the reminder message with ✅ (or "done"):

1. Find the reminder message in the Telegram topic
2. Swipe right or tap reply
3. Send ✅
4. The system will automatically:
   - Remove one-time reminders from reminders.yaml
   - Update due dates for recurring reminders
   - Commit and push the changes

### Manual (Command Line)

If you need to mark a reminder complete outside of Telegram:

```bash
~/github/115_maintenance/complete-reminder.sh <reminder-id>
```

## Testing

Test the Telegram integration:

```bash
cd ~/github/115_maintenance
source venv/bin/activate
python3 -c "
from telegram import Bot
import yaml

with open('config.yaml') as f:
    config = yaml.safe_load(f)

bot = Bot(token=config['telegram_bot_token'])
bot.send_message(
    chat_id='-1003869516415',
    message_thread_id=28,  # EFS topic
    text='🔔 Test message from maintenance system'
)
print('Message sent!')
"
```

## Logs

Check the logs at:
- `~/logs/creative-maintenance.log` - Normal operation
- `~/logs/creative-maintenance-error.log` - Errors

## System Status

```bash
# Check if both services are running
launchctl list | grep creative-intelligence

# View processor logs (sends reminders)
tail -f ~/logs/creative-maintenance.log

# View listener logs (processes completions)
tail -f ~/logs/creative-maintenance-listener.log

# Manual run for testing
~/github/115_maintenance/reminder-processor.sh
```

## Troubleshooting

**"python-telegram-bot not installed"**
```bash
cd ~/github/115_maintenance
source venv/bin/activate
pip install python-telegram-bot pyyaml
```

**"No telegram_bot_token found"**
- Edit `config.yaml` and add your bot token
- Make sure you created a bot with @BotFather

**Bot can't send messages**
- Ensure bot is added to the customer-work group
- Make bot an admin in the group
- Check that topic IDs in `config.yaml` match your group

## Architecture

- **YAML-based config**: Human-readable, version controlled, git-backed
- **python-telegram-bot**: Native Telegram API with topic/forum support
- **Virtual environment**: Isolated Python dependencies
- **launchd cron**: Runs every 15 minutes on macOS
- **Multi-topic routing**: Sends to client-specific Telegram topics
