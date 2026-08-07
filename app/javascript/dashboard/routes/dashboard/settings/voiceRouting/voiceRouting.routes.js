import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import VoiceRoutingIndex from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/voice-routing'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'voice_routing_index',
          component: VoiceRoutingIndex,
          meta: {
            permissions: ['administrator'],
            requiresSuperAdmin: true,
          },
        },
      ],
    },
  ],
};
