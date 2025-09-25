import React from 'react';
import {Redirect} from '@docusaurus/router';
import useBaseUrl from '@docusaurus/useBaseUrl';

export default function Home() {
  return <Redirect to={useBaseUrl('/docs/Getting%20Started/intro')} />;
}

