# Koji Commonly used commands

## Adding Builder

`koji add-host <name/fqdn> <arch>`

## Adding users

`koji add-user <user>`

`koji grant-permission --new <permission> <user>`

`koji list-permissions --user <user>`

# Importing Packages

`koji import /path/to/package1.src.rpm /path/to/package2.src.rpm ...`

`koji list-pkgs --quiet | xargs koji add-pkg --owner <user> <tag>`

`koji list-untagged | xargs -n 1 koji call tagBuildBypass <tag>`

# Exporting repositories

`koji dist-repo <f38>`

