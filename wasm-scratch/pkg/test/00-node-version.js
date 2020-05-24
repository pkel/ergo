const semver = require('semver');
const version = require('../package').engines.node;
const assert = require('assert')

describe('Environment', function () {
  it(`Node version should be ${version}`, function () {
    assert(semver.satisfies(process.version, version));
  });
});
