import { Elm } from './src/Contact.elm';
export function start_elm(flags) {
  return Elm.Contact.init({
    node: document.getElementById("myapp"),
    flags: flags
  });
};