import { Elm } from './src/Surveys.elm';
export function start_elm(flags) {
  return Elm.Surveys.init({
    node: document.getElementById("myapp"),
    flags: flags
  });
};