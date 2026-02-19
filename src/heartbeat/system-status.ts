/**
 * System status checker for heartbeat messages.
 *
 * Checks health of all Cleo dependencies and formats
 * status for Discord heartbeat message.
 */
import axios from 'axios';
import { isOpenClawHealthy } from './openclaw-client.js';

const MEM0_API_URL = process.env.MEM0_API_URL || 'http://mem0:8080';

interface SystemHealth {
  openclawHealthy: boolean;
  mem0Responsive: boolean;
  pendingJobs: number;
}

export async function checkMem0Health(): Promise<boolean> {
  try {
    const response = await axios.get(`${MEM0_API_URL}/health`, {
      timeout: 5000,
    });
    return response.status === 200 && response.data?.status === 'healthy';
  } catch (error) {
    console.error('mem0 health check failed:', error);
    return false;
  }
}

async function getPendingJobsCount(): Promise<number> {
  // Phase 1: No job queue yet, always return 0
  // Phase 2+ will implement actual job queue
  return 0;
}

export async function getSystemStatus(): Promise<string> {
  const health: SystemHealth = {
    openclawHealthy: await isOpenClawHealthy(),
    mem0Responsive: await checkMem0Health(),
    pendingJobs: await getPendingJobsCount(),
  };

  // Format per CONTEXT.md: "All containers healthy, mem0 responsive, no pending jobs"
  const openclawStatus = health.openclawHealthy ? 'OpenClaw connected' : 'OpenClaw DOWN';
  const mem0Status = health.mem0Responsive ? 'mem0 responsive' : 'mem0 DOWN';
  const jobStatus = health.pendingJobs === 0 ? 'no pending jobs' : `${health.pendingJobs} pending jobs`;

  return `${openclawStatus}, ${mem0Status}, ${jobStatus}`;
}

export async function getFullSystemHealth(): Promise<SystemHealth> {
  return {
    openclawHealthy: await isOpenClawHealthy(),
    mem0Responsive: await checkMem0Health(),
    pendingJobs: await getPendingJobsCount(),
  };
}
