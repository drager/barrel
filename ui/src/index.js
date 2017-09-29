import './main.css';
import { Main } from './Main.elm';

var app = Main.embed(document.getElementById('app'));

function initPorts(ports) {
  function setItem([key, value], storage) {
    console.log('Setting by key', key);
    console.log('Setting for value', value);
    storage.setItem(key, JSON.stringify(value));
  }

  function getItem(key, storage) {
    console.log('Getting by key', key, JSON.parse(storage.getItem(key)));
    const item = () => {
      try {
        return JSON.parse(storage.getItem(key));
      } catch (e) {
        return null;
      }
    };
    return item();
  }

  function pushItem([key, value], storage) {
    const item = getItem(key, storage);
    const list = item instanceof Object ? item : {};

    const objectKey = Object.keys(value)[0];

    if (!list[objectKey]) {
      list[objectKey] = Object.values(value)[0];
    }

    setItem([key, list], storage);
  }

  ports.setItemInLocalStorage.subscribe(function(keyValue) {
    setItem(keyValue, localStorage);
  });

  ports.removeItemInLocalStorage.subscribe(function(key) {
    localStorage.removeItem(key);
  });

  ports.getItemInLocalStorage.subscribe(function(key) {
    const item = getItem(key, localStorage);
    console.log('LocalItem', item);
    ports.localStorageGetItemResponse.send([key, item]);
  });

  ports.clearLocalStorage.subscribe(function(i) {
    localStorage.clear();
  });

  ports.pushItemInLocalStorage.subscribe(function(keyValue) {
    pushItem(keyValue, localStorage);
  });

  ports.setItemInSessionStorage.subscribe(function(keyValue) {
    setItem(keyValue, sessionStorage);
  });

  ports.removeItemInSessionStorage.subscribe(function(key) {
    sessionStorage.removeItem(key);
  });

  ports.getItemInSessionStorage.subscribe(function(key) {
    const item = getItem(key, sessionStorage);
    console.log('SessionItem', item);
    ports.sessionStorageGetItemResponse.send([key, item]);
  });

  ports.clearSessionStorage.subscribe(function(i) {
    sessionStorage.clear();
  });

  ports.pushItemInSessionStorage.subscribe(function(keyValue) {
    pushItem(keyValue, sessionStorage);
  });
}

initPorts(app.ports);
