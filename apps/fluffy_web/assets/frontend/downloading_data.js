import { Elm } from './src/DownloadingData.elm';
export function start_elm(flags) {
  return Elm.DownloadingData.init({
    node: document.getElementById("myapp"),
    flags: flags
  });
};