import { Elm } from './src/Homepage.elm';
const $root = document.getElementById("elm-app");
export function start_elm_home(flags, phoenix_setup) {
  let app = Elm.Main.init({
    node: $root,
    flags: flags
  });
  phoenix_setup(app);
  // now do things with hooking up ports, if you want to; the app will start to run after all the immediate JS is done, as per usual JS semantics.
};