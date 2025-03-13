import { Elm } from './src/UploadPage.elm';
export function start_elm(flags) {
  return Elm.UploadPage.init({
    node: document.getElementById("myapp"),
    flags: flags
  });
};