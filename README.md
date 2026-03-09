# Creative Maintenance Reminders

Automated reminder system for recurring maintenance tasks (SSL certificates, client secrets, renewals, etc.)

## How It Works

- Reminders are stored in `reminders.yaml`
- The system checks every 15 minutes for due reminders
- When a reminder is due, it sends a message to the appropriate Telegram channel
- After you complete a task and reply ✅, the system either:
  - **Recurring reminders**: Updates the due date based on the interval
  - **One-time reminders**: Removes them from the list

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
| `client` | Client name - determines Telegram channel (EFS, AEBatencourt, ARS, Creative Intelligence) |
| `due_date` | When to fire the reminder (YYYY-MM-DD) |
| `recurrence` | `null` for one-time, or `"30d"`, `"90d"`, `"1y"` for recurring |
| `description` | Markdown description of the task |
| `status` | `pending`, `sent`, or `completed` |

### Recurrence Formats

- `30d` - 30 days
- `90d` - 90 days  
- `6m` - 6 months (180 days)
- `1y` - 1 year (365 days)

## Client Channel Mapping

| Client | Telegram Channel |
|--------|-----------------|
| EFS | #efs topic in customer-work |
| AEBatencourt | #aebatencourt topic in customer-work |
| ARS | #ars topic in customer-work |
| Creative Intelligence / Internal | #general topic in customer-work |

## Manual Completion

If you need to mark a reminder complete outside of Telegram:

```bash
~/github/creative-maintenance/complete-reminder.sh <reminder-id>
```

## Logs

Check the logs at:
- `~/logs/creative-maintenance.log` - Normal operation
- `~/logs/creative-maintenance-error.log` - Errors

## System Status

```bash
# Check if the cron job is running
launchctl list | grep creative-intelligence

# View recent logs
tail -f ~/logs/creative-maintenance.log
```
