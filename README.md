# Remember The Milk

_A PHP Library_

## Description

**Author**: Adam Magaña <adammagana@gmail.com>
**Last Edit**: April 18th, 2012
**Version**: 0.0.1

@see <http://www.rememberthemilk.com/services/api/>

## Usage

### Composer.json

```json
    "repositories": [
        { "type": "vcs", "url": "https://github.com/WorkOfStan/rtm-php-library" }
    ],
    "require": {
        "workofstan/lembre-se-do-leite": "^0.2",
```

### Constructor

```php
<?php
require_once __DIR__ . '/vendor/autoload.php';
use WorkOfStan\LembreSeDoLeite\RTM;
$rtm = new RTM(APP_KEY, APP_SECRET, PERMISSIONS, FORMAT);
?>
```

| Parameter   | Type   | Default         | Description                                                        |
| ----------- | ------ | --------------- | ------------------------------------------------------------------ |
| APP_KEY     | string | none (required) | Your RTM application's public key.                                 |
| APP_SECRET  | string | none (required) | Your RTM application's secret key.                                 |
| PERMISSIONS | string | read            | The RTM permission level your application requests from a user.    |
| FORMAT      | string | json            | The RTM API response format. Value can be either 'json' or 'rest'. |

### Generate Authentication URL

```php
<?php $authUrl = $rtm->getAuthUrl(); ?>
```

The value of `$authUrl` will be a RTM formatted authentication URL containing your API Key, permission level, response format, and signature.

## Development

- [./blast.sh phpstan](./blast.sh) tests the code by the PHPStan
- [./blast.sh phpstan-remove](./blast.sh) removes the PHPStan reference from composer.json
