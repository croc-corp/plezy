/// Where this build's source code is published, which the GPL requires anyone
/// distributing the app to offer. `.github/workflows/pages.yml` passes the
/// repository it builds from as `SOURCE_URL`.
const String sourceRepositoryUrl = String.fromEnvironment(
  'SOURCE_URL',
  defaultValue: 'https://github.com/croc-corp/plezy',
);

const String _gitCommit = String.fromEnvironment('GIT_COMMIT');

/// The exact commit this build came from when known, else the repository.
Uri get sourceCodeUri => Uri.parse(_gitCommit.isEmpty ? sourceRepositoryUrl : '$sourceRepositoryUrl/tree/$_gitCommit');
