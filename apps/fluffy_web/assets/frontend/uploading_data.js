import { Elm } from './src/UploadingData.elm';
export function start_elm(flags) {
  return Elm.UploadingData.init({
    node: document.getElementById("myapp"),
    flags: flags
  });
};