/* global axios */
import ApiClient from './ApiClient';

class VoiceCountryRoutesAPI extends ApiClient {
  constructor() {
    super('inboxes', { accountScoped: true });
  }

  index(inboxId) {
    return axios.get(`${this.url}/${inboxId}/voice_country_routes`);
  }

  create(inboxId, { countryName, phonePrefix, userId }) {
    return axios.post(`${this.url}/${inboxId}/voice_country_routes`, {
      voice_country_route: {
        country_name: countryName,
        phone_prefix: phonePrefix,
        user_id: userId,
      },
    });
  }

  delete(inboxId, id) {
    return axios.delete(`${this.url}/${inboxId}/voice_country_routes/${id}`);
  }
}

export default new VoiceCountryRoutesAPI();
