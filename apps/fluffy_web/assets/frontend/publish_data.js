import { Elm } from './src/PublishData.elm';
export function start_elm(flags) {
  return Elm.PublishData.init({
    node: document.getElementById("myapp"),
    flags: flags
  });
};