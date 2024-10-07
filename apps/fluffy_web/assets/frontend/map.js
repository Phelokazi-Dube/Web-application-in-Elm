import { Elm } from './src/Map.elm';
export function start_elm(flags) {
  return Elm.Map.init({
    node: document.getElementById("myapp"),
    flags: flags
  });
};