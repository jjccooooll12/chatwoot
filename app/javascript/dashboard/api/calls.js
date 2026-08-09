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

  ticket(id, data = {}) {
    return axios.post(`${this.url}/${id}/ticket`, data);
  }
}

export default new CallsAPI();
