/**
 * Heartbeat scheduler using node-cron.
 *
 * Sends periodic heartbeats to Discord DM via OpenClaw Gateway per CONTEXT.md:
 * - Every 30 minutes (configurable via HEARTBEAT_CRON)
 * - Contains system status summary
 */
import cron from 'node-cron';
import { sendHeartbeat } from './openclaw-client.js';
import { getSystemStatus } from './system-status.js';

// Default: every 30 minutes
const HEARTBEAT_CRON = process.env.HEARTBEAT_CRON || '*/30 * * * *';

let heartbeatTask: cron.ScheduledTask | null = null;

export function startHeartbeat(userId: string): void {
  console.log(`Starting heartbeat scheduler: ${HEARTBEAT_CRON}`);

  // Validate cron expression
  if (!cron.validate(HEARTBEAT_CRON)) {
    console.error(`Invalid HEARTBEAT_CRON expression: ${HEARTBEAT_CRON}`);
    console.error('Using default: */30 * * * *');
  }

  heartbeatTask = cron.schedule(
    cron.validate(HEARTBEAT_CRON) ? HEARTBEAT_CRON : '*/30 * * * *',
    async () => {
      console.log('Heartbeat triggered');
      try {
        const status = await getSystemStatus();
        await sendHeartbeat(userId, status);
        console.log('Heartbeat sent successfully via OpenClaw');
      } catch (error) {
        console.error('Heartbeat failed:', error);
        // Don't throw - heartbeat failures shouldn't crash the app
      }
    },
    {
      timezone: 'UTC', // Use UTC for consistency
    }
  );

  console.log('Heartbeat scheduler started');
}

export function stopHeartbeat(): void {
  if (heartbeatTask) {
    heartbeatTask.stop();
    heartbeatTask = null;
    console.log('Heartbeat scheduler stopped');
  }
}
