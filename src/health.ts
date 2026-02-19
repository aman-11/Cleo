/**
 * Health check server for Docker health checks and monitoring.
 */
import express, { Request, Response } from 'express';

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
