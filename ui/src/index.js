import './main.css';
import { Main } from './Main.elm';
import { Ports } from './Ports.elm';

var app = Main.embed(document.getElementById('app'));

app.ports.setItemInLocalStorage.subscribe(function(keyValue) {
  var [key, value] = keyValue;
  localStorage.setItem(key, JSON.stringify(value));
});

app.ports.removeItemInLocalStorage.subscribe(function(key) {
  localStorage.removeItem(key);
});

app.ports.clearLocalStorage.subscribe(function(i) {
  localStorage.clear();
});

app.ports.setItemInSessionStorage.subscribe(function(keyValue) {
  var [key, value] = keyValue;
  sessionStorage.setItem(key, JSON.stringify(value));
});

app.ports.removeItemInSessionStorage.subscribe(function(key) {
  sessionStorage.removeItem(key);
});

app.ports.clearSessionStorage.subscribe(function(i) {
  sessionStorage.clear();
});
