import { Elm } from './src/Countries.elm';

export function start_elm(flags) {
  const params = new URLSearchParams(window.location.search);
  const requestedPage = Number(params.get('page'));
  const page = Number.isSafeInteger(requestedPage) && requestedPage >= 1
    ? requestedPage
    : 1;

  const app = Elm.Countries.init({
    node: document.getElementById("myapp"),
    flags: {
      ...flags,
      search: params.get('search') || '',
      page
    }
  });

  if (app.ports.downloadCsvPort) {
    app.ports.downloadCsvPort.subscribe((url) => {
      const a = document.createElement("a");
      a.href = url;
      a.target = "_blank";
      a.download = "";
      a.click();
    });
  }

  app.ports.rememberCountriesUrl.subscribe((url) => {
    if (typeof url === 'string' &&
        (url === '/records/countries' || url.startsWith('/records/countries?'))) {
      window.history.replaceState(window.history.state, '', url);
    }
  });

  return app;
};