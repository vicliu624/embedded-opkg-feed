/* SPDX-License-Identifier: MIT */
#include <libpq-fe.h>
#include <assert.h>
#include <stdio.h>
#include <string.h>

int main(void)
{
 assert(PQlibVersion() == 180006);
 char *error = NULL;
 PQconninfoOption *options = PQconninfoParse("postgresql://fixture@localhost:5432/vision?sslmode=require", &error);
 assert(options != NULL && error == NULL);
 int found_host = 0, found_tls = 0, found_database = 0;
 for (PQconninfoOption *option = options; option->keyword != NULL; ++option) {
  if (!strcmp(option->keyword, "host")) found_host = option->val && !strcmp(option->val, "localhost");
  if (!strcmp(option->keyword, "sslmode")) found_tls = option->val && !strcmp(option->val, "require");
  if (!strcmp(option->keyword, "dbname")) found_database = option->val && !strcmp(option->val, "vision");
 }
 assert(found_host && found_tls && found_database);
 PQconninfoFree(options);
 options = PQconninfoParse("tdvp_unknown_option=invalid", &error);
 assert(options == NULL && error != NULL);
 PQfreemem(error);
 const unsigned char binary[] = {0, 1, 39, 92, 127, 255};
 size_t escaped_size = 0, decoded_size = 0;
 unsigned char *escaped = PQescapeBytea(binary, sizeof(binary), &escaped_size);
 assert(escaped != NULL && escaped_size > sizeof(binary));
 assert(strlen((const char *)escaped) + 1 == escaped_size);
 assert(strstr((const char *)escaped, "''") != NULL);
 /* Decoding consumes a server bytea text value, after SQL literal parsing. */
 unsigned char *decoded = PQunescapeBytea((const unsigned char *)"\\x0001275c7fff", &decoded_size);
 assert(decoded != NULL && decoded_size == sizeof(binary) && !memcmp(binary, decoded, sizeof(binary)));
 PQfreemem(decoded); PQfreemem(escaped);
 PGconn *connection = PQconnectdb("hostaddr=127.0.0.1 port=1 connect_timeout=1 user=fixture dbname=fixture sslmode=require");
 assert(connection != NULL && PQstatus(connection) == CONNECTION_BAD);
 assert(PQerrorMessage(connection)[0] != 0);
 PQfinish(connection);
 puts("libpq: PASS URI/TLS parameter parsing, invalid option rejection, SQL binary escaping, hex decoding and refused connection handling");
 return 0;
}
