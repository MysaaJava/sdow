import React, {Component} from 'react';

import PathResult from './PathResult';
import ArticleLink from './ArticleLink';

import {getArticleUrl} from '../utils';

import {ResultsMessage, PathResultsWrapper} from './PathResults.styles';

class PathResults extends Component {
  render() {
    const {paths, toArticleTitle, fromArticleTitle} = this.props;

    if (paths === null) {
      return null;
    }

    const toArticleUrl = getArticleUrl(toArticleTitle);
    const fromArticleUrl = getArticleUrl(fromArticleTitle);

    // No paths found.
    if (paths.length === 0) {
      return (
        <ResultsMessage>
          <p>Welp, this is awkward...</p>
          <p>No path of Wikipedia links exists from</p>
          <p>
            <ArticleLink title={fromArticleTitle} url={fromArticleUrl} /> to{' '}
            <ArticleLink title={toArticleTitle} url={toArticleUrl} />.
          </p>
        </ResultsMessage>
      );
    }

    // Add some character to results by writing a snarky comment for certain degress of separation.
    let snarkyContent;
    const degreesOfSeparation = paths[0].length - 1;
    if (degreesOfSeparation === 0) {
      snarkyContent = (
        <p>
          <b>Seriously?</b> Talk about overqualified for the job...{' '}
        </p>
      );
    } else if (degreesOfSeparation === 1) {
      snarkyContent = (
        <p>
          <b>&lt;sarcasm&gt;</b> Hmm... this was a really tough one. <b>&lt;/sarcasm&gt;</b>
        </p>
      );
    } else if (degreesOfSeparation === 5) {
      snarkyContent = (
        <p>
          <b>*wipes brow*</b> I really had to work hard for this one.
        </p>
      );
    } else if (degreesOfSeparation === 6) {
      snarkyContent = (
        <p>
          <b>*breathes heavily*</b> That was quite the workout.
        </p>
      );
    } else if (degreesOfSeparation >= 7) {
      snarkyContent = (
        <p>
          <b>*picks jaw up from floor*</b> Holy moley, THAT was intense!
        </p>
      );
    }

    const pathOrPaths = paths.length === 1 ? 'path' : 'paths';
    const degreeOrDegrees = degreesOfSeparation === 1 ? 'degree' : 'degrees';

    const pathResultsContent = paths.map((path, i) => {
      return <PathResult key={i} pages={path} />;
    });

    return (
      <div>
        <ResultsMessage>
          {snarkyContent}
          <p>
            Found{' '}
            <b>
              {paths.length} {pathOrPaths}
            </b>{' '}
            with{' '}
            <b>
              {degreesOfSeparation} {degreeOrDegrees}
            </b>{' '}
            of separation from
          </p>
          <p>
            <ArticleLink title={fromArticleTitle} url={fromArticleUrl} /> to{' '}
            <ArticleLink title={toArticleTitle} url={toArticleUrl} />!
          </p>
        </ResultsMessage>
        <PathResultsWrapper>{pathResultsContent}</PathResultsWrapper>
      </div>
    );
  }
}

export default PathResults;