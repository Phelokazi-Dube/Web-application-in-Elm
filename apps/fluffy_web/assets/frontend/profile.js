import { Elm } from './src/Profile.elm';
export function start_elm(flags) {
  return Elm.Profile.init({
    node: document.getElementById("myapp"),
    flags: flags
  });
};