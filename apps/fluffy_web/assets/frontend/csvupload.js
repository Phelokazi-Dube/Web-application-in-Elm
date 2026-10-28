import { Elm } from './src/CsvUpload.elm';

// Preserve the collection that opened CSV import, without allowing
// external or cross-collection Cancel destinations.
const collectionPages = {
  Countries: '/records/countries',
  Continents: '/records/continents',
  Implementers: '/records/implementers',
  Surveys: '/uploadpage'
};

function cancelDestination(collection, requestedReturn) {
  const fallback = collectionPages[collection] || '/records';

  if (!requestedReturn || !requestedReturn.startsWith('/') ||
      requestedReturn.startsWith('//') || requestedReturn.includes('\\')) {
    return fallback;
  }

  try {
    const target = new URL(requestedReturn, window.location.origin);
    const allowedPaths = collection === 'Surveys'
      ? ['/uploadpage', '/surveys']
      : [fallback];

    if (target.origin !== window.location.origin ||
        !allowedPaths.includes(target.pathname) || target.hash) {
      return fallback;
    }

    return target.pathname + target.search;
  } catch (_error) {
    return fallback;
  }
}

export function start_elm(flags) {
  const params = new URLSearchParams(window.location.search);
  return Elm.CsvUpload.init({
    node: document.getElementById('myapp'),
    flags: {
      ...flags,
      returnUrl: cancelDestination(flags.collection, params.get('return'))
    }
  });
}