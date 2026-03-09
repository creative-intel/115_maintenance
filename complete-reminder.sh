#!/bin/zsh
# Reminder Completion Handler
# Called when someone marks a reminder as complete
# Usage: ./complete-reminder.sh <reminder-id>

REPO_DIR="$HOME/github/creative-maintenance"
REMINDERS_FILE="$REPO_DIR/reminders.yaml"

if [[ -z "$1" ]]; then
    echo "Usage: $0 <reminder-id>"
    exit 1
fi

REMINDER_ID="$1"
TODAY=$(date +%Y-%m-%d)

cd "$REPO_DIR" || exit 1

# Pull latest
git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || true

python3 << PYTHON_SCRIPT
import yaml
import datetime
import os
import subprocess
import sys

REPO_DIR = os.path.expanduser("~/github/creative-maintenance")
REMINDERS_FILE = os.path.join(REPO_DIR, "reminders.yaml")
REMINDER_ID = "$REMINDER_ID"
TODAY = "$TODAY"

def parse_recurrence(recurrence):
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
    dt = datetime.datetime.strptime(date_str, "%Y-%m-%d")
    dt = dt + datetime.timedelta(days=days)
    return dt.strftime("%Y-%m-%d")

with open(REMINDERS_FILE, 'r') as f:
    data = yaml.safe_load(f) or {'reminders': []}

reminders = data.get('reminders', [])
updated = False

for reminder in reminders:
    if reminder.get('id') == REMINDER_ID:
        recurrence = reminder.get('recurrence')
        
        if recurrence:
            # Recurring: calculate next due date
            days = parse_recurrence(recurrence)
            if days:
                current_due = reminder.get('due_date', TODAY)
                next_due = add_days(current_due, days)
                reminder['due_date'] = next_due
                reminder['status'] = 'pending'
                print(f"Updated {REMINDER_ID}: next due {next_due}")
        else:
            # Non-recurring: remove from list
            reminders.remove(reminder)
            print(f"Removed one-time reminder: {REMINDER_ID}")
        
        updated = True
        break

if updated:
    with open(REMINDERS_FILE, 'w') as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False, allow_unicode=True)
    
    os.chdir(REPO_DIR)
    subprocess.run(["git", "add", "reminders.yaml"])
    subprocess.run(["git", "commit", "-m", f"Complete reminder {REMINDER_ID} - {TODAY}"])
    subprocess.run(["git", "push"])
    print("Changes committed and pushed")
else:
    print(f"Reminder {REMINDER_ID} not found")
    sys.exit(1)
PYTHON_SCRIPT
