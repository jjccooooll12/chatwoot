/* global axios */
import ApiClient from './ApiClient';

class CallsAPI extends ApiClient {
  constructor() {
    super('calls', { accountScoped: true });
  }

  get(params = {}) {
    return axios.get(this.url, { params });
  }

  create(data = {}) {
    return axios.post(this.url, data);
  }

  conversations(params = {}) {
    return axios.get(`${this.url}/conversations`, { params });
  }
}

export default new CallsAPI();
