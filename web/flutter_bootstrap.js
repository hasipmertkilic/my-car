{{flutter_js}}
{{flutter_build_config}}

(async () => {
  window.myCarGoogleMapsRequested = false;
  window.myCarGoogleMapsReady = false;
  window.myCarGoogleMapsFailed = false;
  await new Promise(resolve => {
    const config = document.createElement('script');
    config.src = 'google_maps_config.js';
    config.onload = resolve;
    config.onerror = resolve;
    document.head.appendChild(config);
  });
  const key = window.myCarGoogleMapsKey;
  if (key) {
    window.myCarGoogleMapsRequested = true;
    await new Promise(resolve => {
      let completed = false;
      const finish = success => {
        if (completed) return;
        completed = true;
        clearTimeout(timeout);
        window.myCarGoogleMapsReady = success;
        window.myCarGoogleMapsFailed = !success;
        resolve();
      };
      const timeout = setTimeout(() => finish(false), 20000);
      window.myCarGoogleMapsLoaded = () => finish(true);
      window.gm_authFailure = () => { window.myCarGoogleMapsFailed = true; };
      const script = document.createElement('script');
      script.src = 'https://maps.googleapis.com/maps/api/js?' + new URLSearchParams({key, callback: 'myCarGoogleMapsLoaded', language: 'tr', region: 'TR'});
      script.async = true;
      script.onerror = () => finish(false);
      document.head.appendChild(script);
    });
  }
  _flutter.loader.load();
})();
