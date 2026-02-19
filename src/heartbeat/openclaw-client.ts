/**
 * OpenClaw Gateway Client
 *
 * ALL Discord (and future channel) communication goes through this client.
 * Cleo never imports discord.js or communicates with Discord directly.
 *
 * OpenClaw Gateway provides:
 * - Multi-channel routing (Discord, WhatsApp, Slack, Telegram, iMessage)
 * - Session management
 * - Message formatting
 * - Rate limit handling
 */
import axios, { AxiosInstance, AxiosError } from 'axios';

const OPENCLAW_API_URL = process.env.OPENCLAW_API_URL || 'http://openclaw:18789';

interface SendMessageRequest {
  channel: 'discord' | 'whatsapp' | 'slack' | 'telegram' | 'imessage';
  recipient: string;  // User ID, phone number, or channel ID depending on channel type
  message: string;
  metadata?: Record<string, unknown>;
}

interface SendMessageResponse {
  success: boolean;
  messageId?: string;
  channel: string;
  timestamp: string;
  error?: string;
}

interface HealthResponse {
  status: 'healthy' | 'degraded' | 'unhealthy';
  channels: {
    discord: boolean;
    [key: string]: boolean;
  };
  version: string;
}

class OpenClawClient {
  private client: AxiosInstance;
  private maxRetries = 3;
  private retryDelayMs = 2000;

  constructor(baseUrl: string = OPENCLAW_API_URL) {
    this.client = axios.create({
      baseURL: baseUrl,
      timeout: 10000,
      headers: {
        'Content-Type': 'application/json',
      },
    });
  }

  /**
   * Check OpenClaw Gateway health
   */
  async checkHealth(): Promise<HealthResponse> {
    try {
      const response = await this.client.get<HealthResponse>('/health');
      return response.data;
    } catch (error) {
      console.error('OpenClaw health check failed:', error);
      return {
        status: 'unhealthy',
        channels: { discord: false },
        version: 'unknown',
      };
    }
  }

  /**
   * Send a message via OpenClaw Gateway
   *
   * @param request Message request with channel, recipient, and message
   * @returns Response with success status and messageId
   */
  async sendMessage(request: SendMessageRequest): Promise<SendMessageResponse> {
    return this.sendMessageWithRetry(request, 0);
  }

  private async sendMessageWithRetry(
    request: SendMessageRequest,
    attempt: number
  ): Promise<SendMessageResponse> {
    try {
      const response = await this.client.post<SendMessageResponse>(
        '/api/messages/send',
        request
      );
      return response.data;
    } catch (error) {
      const axiosError = error as AxiosError<{ error?: string; retryAfter?: number }>;

      // Rate limited - retry with backoff
      if (axiosError.response?.status === 429 && attempt < this.maxRetries) {
        const retryAfter = axiosError.response.data?.retryAfter || this.retryDelayMs;
        console.warn(
          `OpenClaw rate limited, retrying after ${retryAfter}ms (attempt ${attempt + 1}/${this.maxRetries})`
        );
        await this.sleep(retryAfter);
        return this.sendMessageWithRetry(request, attempt + 1);
      }

      // Server error - retry with backoff
      if (
        axiosError.response?.status &&
        axiosError.response.status >= 500 &&
        attempt < this.maxRetries
      ) {
        console.warn(
          `OpenClaw server error ${axiosError.response.status}, retrying (attempt ${attempt + 1}/${this.maxRetries})`
        );
        await this.sleep(this.retryDelayMs * (attempt + 1));
        return this.sendMessageWithRetry(request, attempt + 1);
      }

      // Non-retryable error or max retries exceeded
      console.error('OpenClaw sendMessage failed:', axiosError.message);
      return {
        success: false,
        channel: request.channel,
        timestamp: new Date().toISOString(),
        error: axiosError.message,
      };
    }
  }

  /**
   * Send a Discord DM via OpenClaw
   *
   * Convenience method for sending Discord DMs.
   */
  async sendDiscordDM(userId: string, message: string): Promise<SendMessageResponse> {
    return this.sendMessage({
      channel: 'discord',
      recipient: userId,
      message,
    });
  }

  private sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}

// Singleton instance
export const openClawClient = new OpenClawClient();

/**
 * Send startup DM via OpenClaw Gateway
 */
export async function sendStartupDM(userId: string): Promise<void> {
  const repos = process.env.WATCHED_REPOS || '[repos to be configured]';
  const message = `Cleo is online. Monitoring ${repos}.`;

  console.log(`Sending startup DM to user ${userId} via OpenClaw...`);
  const result = await openClawClient.sendDiscordDM(userId, message);

  if (result.success) {
    console.log(`Startup DM sent successfully (messageId: ${result.messageId})`);
  } else {
    console.error(`Failed to send startup DM: ${result.error}`);
    // Don't crash if DM fails - Cleo should continue running
  }
}

/**
 * Send heartbeat DM via OpenClaw Gateway
 */
export async function sendHeartbeat(userId: string, status: string): Promise<void> {
  const message = `Heartbeat: ${status}`;

  const result = await openClawClient.sendDiscordDM(userId, message);

  if (result.success) {
    console.log('Heartbeat DM sent successfully');
  } else {
    console.error(`Failed to send heartbeat DM: ${result.error}`);
    // Don't crash - log and continue
  }
}

/**
 * Check if OpenClaw Gateway is healthy and Discord channel is connected
 */
export async function isOpenClawHealthy(): Promise<boolean> {
  const health = await openClawClient.checkHealth();
  return health.status === 'healthy' && health.channels.discord === true;
}
