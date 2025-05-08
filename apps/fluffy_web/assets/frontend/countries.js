import { Elm } from './src/Countries.elm';
export function start_elm(flags) {
  return Elm.Countries.init({
    node: document.getElementById("myapp"),
    flags: flags
  });
};