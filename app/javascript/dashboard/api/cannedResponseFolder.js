import ApiClient from './ApiClient';

class CannedResponseFolder extends ApiClient {
  constructor() {
    super('canned_response_folders', { accountScoped: true });
  }
}

export default new CannedResponseFolder();
