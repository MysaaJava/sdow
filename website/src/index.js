import React from 'react';
import {createRoot} from 'react-dom/client';
import {Provider} from 'react-redux';
import Loadable from 'react-loadable';
import Particles, {initParticlesEngine} from "@tsparticles/react";
import {loadFull} from "tsparticles";
import {ThemeProvider} from 'styled-components';
import {Route, Switch} from 'react-router-dom';
import {ConnectedRouter} from 'connected-react-router';
import configureStore, {history} from './configureStore.js';

import registerServiceWorker from './registerServiceWorker';

import Home from './components/Home';

import theme from './resources/theme.json';
import particlesConfig from './resources/particles.config.json';

import './index.css';

// Load fonts
require('typeface-quicksand');
require('typeface-crimson-text');

// Async components
const AsyncBlog = Loadable({
  loader: () => import('./components/blog/Blog'),
  loading: () => null,
});

const AsyncBlogPost = Loadable({
  loader: () => import('./components/blog/BlogPost'),
  loading: () => null,
});

// Create the Redux store.
const store = configureStore();

const root = createRoot(document.getElementById('root'));

function App() {
    const [init, setInit] = React.useState(false);

    React.useEffect(() => {
        if (init) {
            return;
        }

        initParticlesEngine(async (engine) => {
            await loadFull(engine);
        }).then(() => {
            setInit(true);
        });
    }, [init]);
  return (
    <ThemeProvider theme={theme}>
      <React.Fragment>
        <Particles
          options={particlesConfig}
          style={{
            position: 'fixed',
            top: 0,
            left: 0,
            zIndex: -1,
          }}
        />
        <Provider store={store}>
          <ConnectedRouter history={history}>
            <>
              <Switch>
                <Route path="/blog/:postId">
                  <AsyncBlogPost />
                </Route>
                <Route path="/blog">
                  <AsyncBlog />
                </Route>
                <Route path="/">
                  <Home />
                </Route>
              </Switch>
            </>
          </ConnectedRouter>
        </Provider>
      </React.Fragment>
    </ThemeProvider>
  );
}

root.render(
    <React.StrictMode>
        <App />
    </React.StrictMode>
);

registerServiceWorker();
