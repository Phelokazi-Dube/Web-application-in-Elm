import { Elm } from './src/Help.elm';
export function start_elm(flags) {
  return Elm.Help.init({
    node: document.getElementById("myapp"),
    flags: flags
  });
};