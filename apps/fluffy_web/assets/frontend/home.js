import { Elm } from './src/Homepage.elm';
export function start_elm(flags) {
  return Elm.Homepage.init({
    node: document.getElementById("myapp"),
    flags: flags
  });
};