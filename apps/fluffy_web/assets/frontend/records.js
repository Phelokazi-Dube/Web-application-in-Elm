import { Elm } from './src/Records.elm';
export function start_elm(flags) {
  return Elm.Records.init({
    node: document.getElementById("myapp"),
    flags: flags
  });
};