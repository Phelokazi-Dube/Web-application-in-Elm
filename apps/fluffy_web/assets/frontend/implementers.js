import { Elm } from './src/Implementers.elm';

export function start_elm(flags) {
  const params = new URLSearchParams(window.location.search);
  const requestedPage = Number(params.get('page'));
  const page = Number.isSafeInteger(requestedPage) && requestedPage >= 1
    ? requestedPage
    : 1;

  const app = Elm.Implementers.init({
    node: document.getElementById('myapp'),
    flags: { ...flags, search: params.get('search') || '', page }
  });

  app.ports.rememberImplementersUrl.subscribe((url) => {
    if (typeof url === 'string' &&
        (url === '/records/implementers' || url.startsWith('/records/implementers?'))) {
      window.history.replaceState(window.history.state, '', url);
    }
  });

  app.ports.downloadCsvPort.subscribe((url) => {
    const a = document.createElement('a');
    a.href = url;
    a.target = '_blank';
    a.download = '';
    a.click();
  });

  return app;
}
