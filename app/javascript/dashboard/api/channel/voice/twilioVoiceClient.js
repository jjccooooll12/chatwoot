import { Device } from '@twilio/voice-sdk';
import VoiceAPI from './voiceAPIClient';

const createCallDisconnectedEvent = () => new CustomEvent('call:disconnected');

class TwilioVoiceClient extends EventTarget {
  constructor() {
    super();
    this.device = null;
    this.activeConnection = null;
    this.initialized = false;
    this.inboxId = null;
  }

  async initializeDevice(inboxId) {
    this.destroyDevice();

    const response = await VoiceAPI.getToken(inboxId);
    const { token, account_id } = response || {};
    if (!token) throw new Error('Invalid token');

    this.device = new Device(token, {
      allowIncomingWhileBusy: true,
      disableAudioContextSounds: true,
      appParams: { account_id },
    });

    this.device.removeAllListeners();
    this.device.on('connect', conn => {
      this.activeConnection = conn;
      conn.on('disconnect', this.onDisconnect);
    });

    this.device.on('disconnect', this.onDisconnect);

    this.device.on('tokenWillExpire', async () => {
      const r = await VoiceAPI.getToken(this.inboxId);
      if (r?.token) this.device.updateToken(r.token);
    });

    this.initialized = true;
    this.inboxId = inboxId;

    return this.device;
  }

  get hasActiveConnection() {
    return !!this.activeConnection;
  }

  setMuted(shouldMute) {
    if (!this.activeConnection) return false;
    this.activeConnection.mute(shouldMute);
    return shouldMute;
  }

  endClientCall() {
    if (this.activeConnection) {
      this.activeConnection.disconnect();
    }
    this.activeConnection = null;
    if (this.device) {
      this.device.disconnectAll();
    }
  }

  destroyDevice() {
    if (this.device) {
      this.device.destroy();
    }
    this.activeConnection = null;
    this.device = null;
    this.initialized = false;
    this.inboxId = null;
  }

  async joinClientCall({ to, conversationId, callSid }) {
    if (!this.device || !this.initialized || !to) return null;
    if (this.activeConnection) return this.activeConnection;

    const params = {
      To: to,
      is_agent: 'true',
      conversation_id: conversationId,
      call_sid: callSid,
    };

    const connection = await this.device.connect({ params });
    this.activeConnection = connection;

    connection.on('disconnect', this.onDisconnect);

    return connection;
  }

  // Fires for every way a call can end (agent hangs up, the other party
  // hangs up, a connection drops) - this is the one convergence point,
  // registered on both the Device and the Connection. Fully destroying the
  // Device here (not just disconnecting) releases the microphone, which is
  // what actually clears the browser's "this tab is using your mic" tab
  // indicator - disconnecting alone leaves the Device (and its mic access)
  // warm indefinitely, so the tab kept showing "on a call" long after the
  // call ended. The next joinCall() re-initializes a fresh Device anyway, so
  // there's no real cost to releasing it promptly.
  onDisconnect = () => {
    this.destroyDevice();
    this.dispatchEvent(createCallDisconnectedEvent());
  };
}

export default new TwilioVoiceClient();
