/**
 * Health check server for Docker health checks and monitoring.
 * Also serves the dashboard UI at /dashboard
 */
import express, { Request, Response } from 'express';
import path from 'path';
import { fileURLToPath } from 'url';
import { getDashboardHealth } from './health-checks.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = process.env.HEALTH_PORT || 3000;

interface HealthStatus {
  status: 'healthy' | 'degraded' | 'unhealthy';
  checks: {
    openclaw: boolean;
    mem0: boolean;
  };
  uptime: number;
  timestamp: string;
}

// Track health state
let openclawReady = false;
let mem0Ready = false;

export function setOpenClawReady(ready: boolean): void {
  openclawReady = ready;
}

export function setMem0Ready(ready: boolean): void {
  mem0Ready = ready;
}

// Serve dashboard HTML
app.get('/dashboard', (_req: Request, res: Response) => {
  const dashboardPath = path.join(__dirname, 'public', 'dashboard.html');
  res.sendFile(dashboardPath);
});

// Dashboard API endpoint - comprehensive health data
app.get('/api/health', async (_req: Request, res: Response) => {
  try {
    const health = await getDashboardHealth();
    res.json(health);
  } catch (error) {
    console.error('Dashboard health check failed:', error);
    res.status(500).json({ error: 'Failed to fetch health data' });
  }
});

// Docker health check endpoint
app.get('/health', (_req: Request, res: Response) => {
  const status: HealthStatus = {
    status: openclawReady ? 'healthy' : 'degraded',
    checks: {
      openclaw: openclawReady,
      mem0: mem0Ready,
    },
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
  };

  const statusCode = status.status === 'healthy' ? 200 : 503;
  res.status(statusCode).json(status);
});

app.get('/', (_req: Request, res: Response) => {
  res.json({
    service: 'Cleo',
    version: '0.1.0',
    health: '/health',
    dashboard: '/dashboard',
    api: '/api/health',
  });
});

export function startHealthServer(): Promise<void> {
  return new Promise((resolve) => {
    app.listen(PORT, () => {
      console.log(`Health server listening on port ${PORT}`);
      resolve();
    });
  });
}
