import { Elm } from './src/Continents.elm';
export function start_elm(flags) {
  return Elm.Continents.init({
    node: document.getElementById("myapp"),
    flags: flags
  });
};