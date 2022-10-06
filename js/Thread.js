import {
  NativeModules,
  DeviceEventEmitter,
} from 'react-native';

const { ThreadManager } = NativeModules;

export default class Thread {
  // 1. We can now load threads from the JS thread, as before, or preload them.
  // Therefore, we move the code in the constructor to this static initializer to load threads
  // from a file.
  static loadFromFile = (jsPath) => {
    if (!jsPath || !jsPath.endsWith('.js')) {
      throw new Error('Invalid path for thread. Only js files are supported');
    }

    const id = ThreadManager.startThread(jsPath.replace(".js", ""))
      .catch(err => { throw new Error(err) });
    return new Thread(id);
  }

  // 2. We know the ids of the preloaded worker threads ahead of time so we use this static initializer
  // to initialize them using a predetermined id.
  static loadFromId = (id) => new Thread(Promise.resolve(id))

  constructor(id) {
    this.id = id
    id.then((id) => {
      DeviceEventEmitter.addListener(`Thread${id}`, (message) => {
        !!message && this.onmessage && this.onmessage(message);
      });
    });
  }

  postMessage(message) {
    this.id.then(id => ThreadManager.postThreadMessage(id, message));
  }

  terminate() {
    this.id.then(ThreadManager.stopThread);
  }
}
