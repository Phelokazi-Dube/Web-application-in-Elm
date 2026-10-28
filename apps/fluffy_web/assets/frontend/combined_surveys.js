import { Elm } from './src/CombinedSurveys.elm';

export function start_elm(flags) {
  const params = new URLSearchParams(window.location.search);
  const requestedPage = Number(params.get('page'));
  const page = Number.isSafeInteger(requestedPage) && requestedPage >= 1
    ? requestedPage
    : 1;

  const app = Elm.CombinedSurveys.init({
    node: document.getElementById('myapp'),
    flags: {
      ...flags,
      search: params.get('search') || '',
      page
    }
  });

  app.ports.rememberCombinedUrl.subscribe((url) => {
    if (typeof url === 'string' && (url === '/combined' || url.startsWith('/combined?'))) {
      window.history.replaceState(window.history.state, '', url);
    }
  });

  return app;
}