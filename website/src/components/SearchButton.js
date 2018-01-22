import axios from 'axios';
import React from 'react';

import {GoButton} from './SearchButton.styles';

import {SDOW_API_URL} from '../resources/constants';

class SearchButton extends React.Component {
  constructor() {
    super();

    this.state = {
      isFetching: false,
    };
  }

  fetchShortestPaths(fromArticleTitle, toArticleTitle, setError, setShortestPathResults) {
    // TODO: handle cases where to or from page title is undefined

    // Cancel the previous request
    this.setState({
      isFetching: true,
    });

    setError(null);
    setShortestPathResults(null, null);

    axios({
      method: 'get',
      url: `${SDOW_API_URL}/paths/${fromArticleTitle}/${toArticleTitle}`,
    })
      .then((response) => {
        const {pages, paths} = response.data;

        const pathsDenormalized = paths.map((path) => {
          return path.map((pageId) => {
            return pages[pageId];
          });
        });

        console.log(JSON.stringify(pathsDenormalized, null, 2));

        setShortestPathResults({
          toArticleTitle,
          fromArticleTitle,
          paths: pathsDenormalized,
        });

        // TODO: measure the response time
        // See https://www.html5rocks.com/en/tutorials/webperformance/usertiming/

        this.setState({
          isFetching: false,
        });
      })
      .catch((error) => {
        setError(error.response.data.error);
      });
  }

  render() {
    const {toArticleTitle, fromArticleTitle, setError, setShortestPathResults} = this.props;

    return (
      <GoButton
        onClick={this.fetchShortestPaths.bind(
          this,
          fromArticleTitle,
          toArticleTitle,
          setError,
          setShortestPathResults
        )}
      >
        Go!
      </GoButton>
    );
  }
}

export default SearchButton;