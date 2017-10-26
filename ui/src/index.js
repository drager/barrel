import './app-theme.html';
import './main.css';
import 'app-layout/app-drawer-layout/app-drawer-layout.html';
import 'app-layout/app-drawer/app-drawer.html';
import 'app-layout/app-header-layout/app-header-layout.html';
import 'app-layout/app-header/app-header.html';
import 'app-layout/app-scroll-effects/app-scroll-effects.html';
import 'app-layout/app-toolbar/app-toolbar.html';
import 'iron-icons/iron-icons.html';
import 'iron-icons/hardware-icons.html';
import 'neon-animation/neon-animations.html';
import 'neon-animation/web-animations.html';
import 'paper-button/paper-button.html';
import 'paper-input/paper-input.html';
import 'paper-dialog/paper-dialog.html';
import 'paper-icon-button/paper-icon-button.html';
import 'paper-item/paper-icon-item.html';
import 'paper-item/paper-item-body.html';
import 'paper-item/paper-item.html';
import 'paper-styles/color.html';
import 'paper-styles/classes/global.html';
import 'font-roboto/roboto.html';
import 'paper-styles/typography.html';
import { Main } from './Main.elm';

var app = Main.embed(document.getElementById('app'));

function initPorts(ports) {
  function removeItemInList([key, value], storage) {
    const item = getItem(key, storage);
    const list = item instanceof Object ? item : {};
    const newList = Object.keys(list)
      .filter(i => (console.log('i', i), i !== value))
      .reduce((obj, key) => {
        obj[key] = list[key];
        return obj;
      }, {});
    setItem([key, newList], storage);
  }

  function setItem([key, value], storage) {
    console.log('Setting by key', key);
    console.log('Setting for value', value);
    storage.setItem(key, JSON.stringify(value));
  }

  function removeItem([key, value], storage) {
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

  ports.setItemInLocalStorage.subscribe(function (keyValue) {
    setItem(keyValue, localStorage);
  });

  ports.removeItemInLocalStorage.subscribe(function (key) {
    localStorage.removeItem(key);
  });

  ports.getItemInLocalStorage.subscribe(function (key) {
    const item = getItem(key, localStorage);
    console.log('LocalItem', item);
    ports.localStorageGetItemResponse.send([key, item]);
  });

  ports.clearLocalStorage.subscribe(function (i) {
    localStorage.clear();
  });

  ports.pushItemInLocalStorage.subscribe(function (keyValue) {
    pushItem(keyValue, localStorage);
  });

  ports.removeItemFromListInLocalStorage.subscribe(function (keyValue) {
    removeItemInList(keyValue, localStorage);
  });

  ports.setItemInSessionStorage.subscribe(function (keyValue) {
    setItem(keyValue, sessionStorage);
  });

  ports.removeItemInSessionStorage.subscribe(function (key) {
    sessionStorage.removeItem(key);
  });

  ports.getItemInSessionStorage.subscribe(function (key) {
    const item = getItem(key, sessionStorage);
    console.log('SessionItem', item);
    ports.sessionStorageGetItemResponse.send([key, item]);
  });

  ports.clearSessionStorage.subscribe(function (i) {
    sessionStorage.clear();
  });

  ports.pushItemInSessionStorage.subscribe(function (keyValue) {
    pushItem(keyValue, sessionStorage);
  });

  ports.removeItemFromListInSessionStorage.subscribe(function (keyValue) {
    removeItemInList(keyValue, sessionStorage);
  });
}

initPorts(app.ports);
