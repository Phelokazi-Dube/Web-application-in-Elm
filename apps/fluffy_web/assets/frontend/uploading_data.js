import { Elm } from './src/UploadingData.elm';
import { startMapPicker } from '../js/mapPicker.js';
export function start_elm(flags) {
  const app = Elm.UploadingData.init({
    node: document.getElementById("myapp"),
    flags: flags
  });

  startMapPicker(app);

  // When Elm wants to open the map
  if (app.ports.pickLocationPort) {
    app.ports.pickLocationPort.subscribe(() => {
      window.pickLocation();
    });
  }

  if (app.ports.pickLocationPort) {
    app.ports.scrollToTop.subscribe(() => {
      window.scrollTo({ top: 0, behavior: "smooth" });
    });
  }
  return app;
  }