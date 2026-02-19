/**
 * Cleo - Autonomous AI Agent
 *
 * Main entrypoint. Initializes health server, checks OpenClaw,
 * sends startup DM via OpenClaw, and schedules heartbeats.
 *
 * ARCHITECTURE: All Discord communication goes through OpenClaw Gateway.
 * Cleo never imports discord.js or communicates with Discord directly.
 */
import 'dotenv/config';
import { startHealthServer, setOpenClawReady, setMem0Ready } from './health.js';
import { startHeartbeat } from './heartbeat/scheduler.js';
import { sendStartupDM, isOpenClawHealthy } from './heartbeat/openclaw-client.js';
import { checkMem0Health } from './heartbeat/system-status.js';

// Validate required environment variables
const requiredEnvVars = ['DISCORD_USER_ID'];
for (const envVar of requiredEnvVars) {
  if (!process.env[envVar]) {
    console.error(`Missing required environment variable: ${envVar}`);
    process.exit(1);
  }
}

const DISCORD_USER_ID = process.env.DISCORD_USER_ID!;

// Main startup sequence
async function main(): Promise<void> {
  console.log('Cleo starting...');

  // 1. Start health server first (for Docker health checks)
  await startHealthServer();
  console.log('Health server started');

  // 2. Wait for OpenClaw to be healthy (with retries)
  console.log('Waiting for OpenClaw Gateway...');
  let openClawHealthy = false;
  const maxAttempts = 30;  // 30 * 2s = 60s max wait

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    openClawHealthy = await isOpenClawHealthy();
    if (openClawHealthy) {
      console.log('OpenClaw Gateway is healthy');
      setOpenClawReady(true);
      break;
    }
    console.log(`OpenClaw not ready (attempt ${attempt}/${maxAttempts}), waiting...`);
    await sleep(2000);
  }

  if (!openClawHealthy) {
    console.error('OpenClaw Gateway is not healthy after 60s - continuing with degraded mode');
  }

  // 3. Check mem0 health
  const mem0Healthy = await checkMem0Health();
  setMem0Ready(mem0Healthy);
  if (!mem0Healthy) {
    console.warn('mem0 is not healthy - continuing with degraded mode');
  }

  // 4. Send startup DM via OpenClaw (per CONTEXT.md: after health checks pass)
  if (openClawHealthy) {
    await sendStartupDM(DISCORD_USER_ID);
  } else {
    console.warn('Skipping startup DM - OpenClaw not healthy');
  }

  // 5. Start heartbeat scheduler
  startHeartbeat(DISCORD_USER_ID);

  console.log('Cleo is fully operational');
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// Error handling
process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
});

process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
  // Docker will restart us
  process.exit(1);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully...');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully...');
  process.exit(0);
});

// Start Cleo
main().catch((error) => {
  console.error('Failed to start Cleo:', error);
  process.exit(1);
});
