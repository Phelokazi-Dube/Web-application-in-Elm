import { Elm } from './src/New.elm';
export function start_elm(flags) {
  return Elm.New.init({
    node: document.getElementById("myapp"),
    flags: flags
  });
};