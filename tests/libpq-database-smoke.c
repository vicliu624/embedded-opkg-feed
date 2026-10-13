/* SPDX-License-Identifier: MIT */
#include <libpq-fe.h>
#include <assert.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv)
{
 assert(argc == 2);
 PGconn *connection = PQconnectdb(argv[1]);
 if (PQstatus(connection) != CONNECTION_OK) {
  fprintf(stderr, "Test database connection failed: %s", PQerrorMessage(connection));
  PQfinish(connection); return 1;
 }
 assert(PQsslInUse(connection));
 assert(PQsslAttribute(connection, "protocol") != NULL);
 const unsigned char binary[] = {0, 1, 39, 92, 127, 255};
 const char *values[] = {(const char *)binary};
 int lengths[] = {sizeof(binary)}, formats[] = {1};
 Oid types[] = {17};
 PGresult *result = PQexecParams(connection, "SELECT $1::bytea", 1, types, values, lengths, formats, 1);
 assert(PQresultStatus(result) == PGRES_TUPLES_OK && PQntuples(result) == 1);
 assert(PQgetlength(result, 0, 0) == sizeof(binary));
 assert(memcmp(PQgetvalue(result, 0, 0), binary, sizeof(binary)) == 0);
 PQclear(result);
 result = PQexec(connection, "CREATE TEMP TABLE tdvp_fixture (value integer)");
 assert(PQresultStatus(result) == PGRES_COMMAND_OK); PQclear(result);
 result = PQexec(connection, "BEGIN");
 assert(PQresultStatus(result) == PGRES_COMMAND_OK); PQclear(result);
 result = PQexec(connection, "INSERT INTO tdvp_fixture VALUES (42)");
 assert(PQresultStatus(result) == PGRES_COMMAND_OK); PQclear(result);
 result = PQexec(connection, "ROLLBACK");
 assert(PQresultStatus(result) == PGRES_COMMAND_OK); PQclear(result);
 result = PQexec(connection, "SELECT count(*) FROM tdvp_fixture");
 assert(PQresultStatus(result) == PGRES_TUPLES_OK && strcmp(PQgetvalue(result, 0, 0), "0") == 0);
 PQclear(result); PQfinish(connection);
 const char *keys[] = {"dbname", "password", NULL};
 const char *wrong_values[] = {argv[1], "wrong-public-fixture-passphrase", NULL};
 connection = PQconnectdbParams(keys, wrong_values, 1);
 assert(PQstatus(connection) == CONNECTION_BAD);
 assert(strstr(PQerrorMessage(connection), "password authentication failed") != NULL);
 PQfinish(connection);
 puts("libpq database: PASS verified TLS connection, authenticated binary query, transaction rollback and wrong-password rejection");
 return 0;
}
