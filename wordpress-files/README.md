`install_wordpress.bash` is a script that installs Wordpress and Raspisignage relevant plugins to `/var/www/html` using `wp-cli.phar`.
The files in this folder and subfolders can be used to get Raspisignage working even some plugins e.g. **Foyer** are no longer available from official sources.
The subfolder `files` contains all files needed.
**Hint:** You can trick `wp-cli.phar` not to download Wordpress Core from internet if you copy it to `~/.wp-cli/cache/core/` before executing:

```bash
# variables
wplocale='de_DE'
wppath='/var/www/html'
corecache=/root/.wp-cli/cache/core
wpversion='6.6.1'
lfiles=./files

# fake the cache
cp "$lfiles/wordpress-$wpversion-de_DE.tar.gz" "$corecache"
cp "$lfiles/wordpress-$wpversion-en_US.tar.gz" "$corecache"

# initiate download but instead use cache
php wp-cli.phar --allow-root --path=${wppath} core download --locale=${wplocale} --version=$wpversion
```
