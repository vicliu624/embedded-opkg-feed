/* SPDX-License-Identifier: MIT */
#include <mysql.h>
#include <mysql/client_plugin.h>
#include <assert.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv)
{
 assert(argc == 2);
 assert(mysql_library_init(0, NULL, NULL) == 0);
 assert(strstr(mysql_get_client_info(), "3.4.11") != NULL);
 MYSQL *connection = mysql_init(NULL);
 assert(connection != NULL);
 assert(mysql_options(connection, MYSQL_PLUGIN_DIR, argv[1]) == 0);
 assert(mysql_options(connection, MYSQL_SET_CHARSET_NAME, "utf8mb4") == 0);
 const char *plugins[] = {"dialog", "client_ed25519", "caching_sha2_password", "sha256_password", "auth_gssapi_client", "parsec"};
 for (unsigned int index = 0; index < sizeof(plugins)/sizeof(plugins[0]); ++index) {
  struct st_mysql_client_plugin *plugin = mysql_client_find_plugin(connection, plugins[index], MYSQL_CLIENT_AUTHENTICATION_PLUGIN);
  if (plugin == NULL) {
   fprintf(stderr, "Plugin load failed %s: %s\n", plugins[index], mysql_error(connection));
   return 1;
  }
 }
 unsigned int timeout = 1;
 assert(mysql_options(connection, MYSQL_OPT_CONNECT_TIMEOUT, &timeout) == 0);
 assert(mysql_real_connect(connection, "127.0.0.1", "fixture", NULL, "fixture", 1, NULL, 0) == NULL);
 assert(mysql_errno(connection) != 0 && mysql_error(connection)[0] != 0);
 mysql_close(connection);
 mysql_library_end();
 puts("MariaDB client: PASS initialization, UTF8 options, six authentication plugin loads and refused connection handling");
 return 0;
}
