# WordPress in a box

Allows you to run temporary WordPress installation with automatically installed themes and plug-ins.

## Prerequisite

A running MySql container

```$ docker run -d --name wpbox-db -e MYSQL_ROOT_PASSWORD=wordpress mysql```


## Examples

Default install with editor theme

```$ docker run -p 80:80 -e "THEME=editor" --link wpbox-db:mysql dz0ny/wpbox```

Default install with plug-in and theme

```$ docker run -p 80:80 -e "THEME=editor"  -e "PLUGIN=debug-bar" --link wpbox-db:mysql dz0ny/wpbox```

Default install with local plug-in

```$ docker run -p 80:80 -v ./my_plugin:/var/www/html/wp-content/plugins/my_plugin:r --link wpbox-db:mysql dz0ny/wpbox```

Default install with local theme

```$ docker run -p 80:80 -v ./child_theme:/var/www/html/wp-content/themes/child_theme:r --link wpbox-db:mysql dz0ny/wpbox``` 