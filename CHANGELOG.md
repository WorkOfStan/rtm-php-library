# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### `Added` for new features

### `Changed` for changes in existing functionality

- Todo: use Guzzle for HTTP requests instead of cURL

### `Deprecated` for soon-to-be removed features

### `Removed` for now removed features

### `Fixed` for any bugfixes

### `Security` in case of vulnerabilities

## [0.2] - 2025-03-11

chore: support for PHP/8.0-8.4

### Added

- GitHub Actions for automated code linting
- support for PHP/8.0-8.4

### Changed

- code readability standardized with Prettier and PHPCS
- the MIT LICENSE moved from README.md to a separate file as is standard

### Fixed

- backward PHP/5.3 compatibility
- curl_setopt parameter values

## [0.1] - 2023-02-19

### Added

- PHPStan level 9 automatic GitHub tests

### Changed

- PSR-4 ready, i.e. the library can be linked by composer
- API calls changed from HTTP to HTTPS and GET to POST

### Security

- `.htaccess` restricts access to md files

## [0.0.1] - 2012-04-22

- Auth flow now works through and through (using class `get` method for getToken)
- TODO: create a wrapper for every RTM API method, each class/rtm API method will wrap around basic `get` method and handle each accordingly

[Unreleased]: https://github.com/WorkOfStan/rtm-php-library/compare/v0.2...HEAD
[0.2]: https://github.com/WorkOfStan/rtm-php-library/compare/v0.1...v0.2
[0.1]: https://github.com/WorkOfStan/rtm-php-library/compare/v0.0.1...v0.1
[0.0.1]: https://github.com/WorkOfStan/rtm-php-library/releases/tag/v0.0.1
