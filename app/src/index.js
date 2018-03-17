import React from 'react'
import ReactDOM from 'react-dom'
import { BrowserRouter as Router, Route } from 'react-router-dom'
import { Provider } from 'react-redux'
import { createStore, applyMiddleware } from 'redux'
import { composeWithDevTools } from 'redux-devtools-extension'
import axios from 'axios'
import { multiClientMiddleware } from 'redux-axios-middleware'
import Raven from 'raven-js'
import createRavenMiddleware from 'raven-for-redux'
import ApolloClient from 'apollo-client'
import gql from 'graphql-tag'
import { createHttpLink } from 'apollo-link-http'
import { setContext } from 'apollo-link-context'
import { from } from 'apollo-link'
import { onError } from 'apollo-link-error'
import { InMemoryCache } from 'apollo-cache-inmemory'
import { ApolloProvider } from 'react-apollo'
import App from './App'
import reducers from './reducers/rootReducers.js'
import { loadState, saveState } from './utils/localStorage'
import { getOrigin } from './utils/utils'
import setAuthorizationToken from './utils/setAuthorizationToken'
import { hasMetamask } from './web3Helpers'
import * as serviceWorker from './serviceWorker'
import 'semantic-ui-css/semantic.min.css'
import './index.css'

const run = (client, store, App) => {
  ReactDOM.render(
    <ApolloProvider client={client}>
      <Provider store={store}>
        <Router>
          <Route path='/' component={App} />
        </Router>
      </Provider>
    </ApolloProvider>,
    document.getElementById('root'))
  serviceWorker.register({
    onUpdate: registration => {
      console.log('App updated... Refresh your browser, please.')
    },
    onSuccess: registration => {
      console.log('Your browser makes cached SANbase version')
    }
  })
}

const handleLoad = () => {
  if (!window.env) {
    window.env = {
      RAVEN_DSN: '',
      WEBSITE_URL: process.env.REACT_APP_WEBSITE_URL || ''
    }
  }
  Raven.config(window.env.RAVEN_DSN || '', {
    release: process.env.REACT_APP_VERSION,
    environment: process.env.NODE_ENV,
    tags: {
      git_commit: process.env.REACT_APP_VERSION.split('-')[1]
    }
  }).install()
  const origin = getOrigin()

  const httpLink = createHttpLink({ uri: `${origin}/graphql` })
  const authLink = setContext((_, { headers }) => {
    // get the authentication token from local storage if it exists
    const token = loadState() ? loadState().token : undefined
    // return the headers to the context so httpLink can read them
    return {
      headers: {
        ...headers,
        authorization: token ? `Bearer ${token}` : null
      }
    }
  })

  const linkError = onError(({graphQLErrors, networkError, operation}) => {
    if (graphQLErrors) {
      if (Array.isArray(graphQLErrors)) {
        graphQLErrors.forEach(({ message, locations, path }) => {
          const errorMessage = `[GraphQL error]:
            Message: ${JSON.stringify(message)},
            Location: ${JSON.stringify(locations)},
            Path: ${JSON.stringify(path)}`
          if (process.env.NODE_ENV === 'development') {
            console.log(errorMessage)
          }
          Raven.captureException(errorMessage)
        })
      } else {
        if (process.env.NODE_ENV === 'development') {
          console.log(
            `[GraphQL error]: ${JSON.stringify(graphQLErrors)}`
          )
        }
        Raven.captureException(`[GraphQL error]: ${JSON.stringify(graphQLErrors)}`)
      }
    }

    if (networkError) {
      if (process.env.NODE_ENV === 'development') {
        console.log(networkError)
      }
      Raven.captureException(`[Network error]: ${networkError} ${operation}`)
    }
  })

  const client = new ApolloClient({
    link: from([authLink, linkError, httpLink]),
    cache: new InMemoryCache()
  })

  const clients = {
    sanbaseClient: {
      client: axios.create({
        baseURL: `${origin}/api`,
        responseType: 'json'
      })
    }
  }

  loadState() && setAuthorizationToken(loadState().token)

  const middleware = [
    multiClientMiddleware(clients),
    createRavenMiddleware(Raven)
  ]

  const store = createStore(reducers,
    {user: loadState()} || {},
    composeWithDevTools(applyMiddleware(...middleware))
  )

  client.query({
    query: gql`
      query {
        currentUser {
          id,
          email,
          username,
          ethAccounts{
            address,
            sanBalance
          }
        }
      }
    `
  })
  .then(response => {
    store.dispatch({
      type: 'CHANGE_USER_DATA',
      user: response.data.currentUser,
      hasMetamask: hasMetamask()
    })
  })
  .catch(error => Raven.captureException(error))

  const oldState = loadState()
  let prevToken = oldState ? oldState.token : null
  setInterval(() => {
    if (prevToken !== (loadState() || {}).token) {
      prevToken = (loadState() || {}).token
      window.location.reload()
    }
  }, 2000)

  store.subscribe(() => {
    // TODO: Yura Zatsepin: 2017-12-07 11:23:
    // we need add throttle when save action was hapenned
    saveState(store.getState().user)
  })

  if (!window.Intl) {
    require.ensure([
      'intl',
      'intl/locale-data/jsonp/en.js'
    ], () => {
      require('intl')
      require('intl/locale-data/jsonp/en.js')
      run(client, store, App)
    })
  } else {
    run(client, store, App)
  }
}

if (process.env.NODE_ENV === 'development') {
  handleLoad()
} else {
  const script = document.createElement('script')
  script.src = `/env.js?${process.env.REACT_APP_VERSION}`
  script.async = false
  document.body.appendChild(script)
  script.addEventListener('load', handleLoad)
}
