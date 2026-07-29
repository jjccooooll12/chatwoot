import { throwErrorMessage } from 'dashboard/store/utils/api';
import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import * as types from '../mutation-types';
import CannedResponseFolderAPI from '../../api/cannedResponseFolder';

const state = {
  records: [],
  uiFlags: {
    fetchingList: false,
    creatingItem: false,
    updatingItem: false,
    deletingItem: false,
  },
};

const getters = {
  getCannedResponseFolders(_state) {
    return [..._state.records].sort((a, b) => a.name.localeCompare(b.name));
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
};

const actions = {
  getCannedResponseFolders: async function getCannedResponseFolders({
    commit,
  }) {
    commit(types.default.SET_CANNED_RESPONSE_FOLDER_UI_FLAG, {
      fetchingList: true,
    });
    try {
      const response = await CannedResponseFolderAPI.get();
      commit(types.default.SET_CANNED_RESPONSE_FOLDERS, response.data);
      commit(types.default.SET_CANNED_RESPONSE_FOLDER_UI_FLAG, {
        fetchingList: false,
      });
    } catch (error) {
      commit(types.default.SET_CANNED_RESPONSE_FOLDER_UI_FLAG, {
        fetchingList: false,
      });
    }
  },

  createCannedResponseFolder: async function createCannedResponseFolder(
    { commit },
    folderObj
  ) {
    commit(types.default.SET_CANNED_RESPONSE_FOLDER_UI_FLAG, {
      creatingItem: true,
    });
    try {
      const response = await CannedResponseFolderAPI.create(folderObj);
      commit(types.default.ADD_CANNED_RESPONSE_FOLDER, response.data);
      commit(types.default.SET_CANNED_RESPONSE_FOLDER_UI_FLAG, {
        creatingItem: false,
      });
      return response.data;
    } catch (error) {
      commit(types.default.SET_CANNED_RESPONSE_FOLDER_UI_FLAG, {
        creatingItem: false,
      });
      return throwErrorMessage(error);
    }
  },

  updateCannedResponseFolder: async function updateCannedResponseFolder(
    { commit },
    { id, ...updateObj }
  ) {
    commit(types.default.SET_CANNED_RESPONSE_FOLDER_UI_FLAG, {
      updatingItem: true,
    });
    try {
      const response = await CannedResponseFolderAPI.update(id, updateObj);
      commit(types.default.EDIT_CANNED_RESPONSE_FOLDER, response.data);
      commit(types.default.SET_CANNED_RESPONSE_FOLDER_UI_FLAG, {
        updatingItem: false,
      });
      return response.data;
    } catch (error) {
      commit(types.default.SET_CANNED_RESPONSE_FOLDER_UI_FLAG, {
        updatingItem: false,
      });
      return throwErrorMessage(error);
    }
  },

  deleteCannedResponseFolder: async function deleteCannedResponseFolder(
    { commit },
    id
  ) {
    commit(types.default.SET_CANNED_RESPONSE_FOLDER_UI_FLAG, {
      deletingItem: true,
    });
    try {
      await CannedResponseFolderAPI.delete(id);
      commit(types.default.DELETE_CANNED_RESPONSE_FOLDER, id);
      commit(types.default.SET_CANNED_RESPONSE_FOLDER_UI_FLAG, {
        deletingItem: false,
      });
      return id;
    } catch (error) {
      commit(types.default.SET_CANNED_RESPONSE_FOLDER_UI_FLAG, {
        deletingItem: false,
      });
      return throwErrorMessage(error);
    }
  },
};

const mutations = {
  [types.default.SET_CANNED_RESPONSE_FOLDER_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },

  [types.default.SET_CANNED_RESPONSE_FOLDERS]: MutationHelpers.set,
  [types.default.ADD_CANNED_RESPONSE_FOLDER]: MutationHelpers.create,
  [types.default.EDIT_CANNED_RESPONSE_FOLDER]: MutationHelpers.update,
  [types.default.DELETE_CANNED_RESPONSE_FOLDER]: MutationHelpers.destroy,
};

export default {
  state,
  getters,
  actions,
  mutations,
};
