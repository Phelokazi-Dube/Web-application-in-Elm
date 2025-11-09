import { Elm } from './src/UploadingData.elm';
import { startMapPicker } from '../js/mapPicker.js';
export function start_elm(flags) {
  const app = Elm.UploadingData.init({
    node: document.getElementById("myapp"),
    flags: flags
  });

  startMapPicker(app);

  // When Elm wants to open the map
  app.ports.pickLocationPort.subscribe(() => {
    window.pickLocation();
  });

};