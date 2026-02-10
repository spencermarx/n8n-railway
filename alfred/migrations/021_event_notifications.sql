-- Migration: 021_event_notifications.sql
-- Purpose: Track which calendar events have been notified to prevent duplicate DMs
-- Used by: Unified Task Scheduler (meeting prep dedup)

CREATE TABLE IF NOT EXISTS alfred.event_notifications (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    event_id TEXT NOT NULL,
    event_summary TEXT,
    notified_at TIMESTAMPTZ DEFAULT NOW(),
    notification_date DATE DEFAULT CURRENT_DATE,
    UNIQUE(user_id, event_id, notification_date)
);

CREATE INDEX IF NOT EXISTS idx_event_notifications_lookup
    ON alfred.event_notifications(user_id, notification_date);

-- Auto-cleanup: remove notifications older than 7 days
-- (Prevents unbounded table growth while keeping recent history for debugging)
DELETE FROM alfred.event_notifications WHERE notification_date < CURRENT_DATE - INTERVAL '7 days';
