import { Elm } from './src/SignUp.elm';
window.start_elm = function(flags) {
  return Elm.SignUp.init({
    node: document.getElementById("myapp"),
    flags: flags
  });
};