/* SPDX-License-Identifier: MIT */
#include <mysql.h>
#include <assert.h>
#include <stdio.h>
#include <string.h>

static MYSQL *connect_fixture(const char *certificate, const char *password)
{
 MYSQL *connection = mysql_init(NULL);
 assert(connection != NULL);
 unsigned int timeout = 5;
 enum mysql_protocol_type protocol = MYSQL_PROTOCOL_TCP;
 my_bool verify = 1, enforce = 1;
 assert(mysql_options(connection, MYSQL_OPT_PROTOCOL, &protocol) == 0);
 assert(mysql_options(connection, MYSQL_OPT_CONNECT_TIMEOUT, &timeout) == 0);
 assert(mysql_options(connection, MYSQL_OPT_SSL_VERIFY_SERVER_CERT, &verify) == 0);
 assert(mysql_options(connection, MYSQL_OPT_SSL_ENFORCE, &enforce) == 0);
 assert(mysql_options(connection, MYSQL_OPT_SSL_CA, certificate) == 0);
 mysql_real_connect(connection, "localhost", "tdvp_fixture", password, "tdvp_fixture", 15433, NULL, 0);
 return connection;
}

int main(int argc, char **argv)
{
 assert(argc == 3);
 assert(mysql_library_init(0, NULL, NULL) == 0);
 MYSQL *connection = connect_fixture(argv[1], "public-fixture-passphrase");
 if (mysql_errno(connection) != 0) {
  fprintf(stderr, "Test database connection failed: %s\n", mysql_error(connection));
  mysql_close(connection); mysql_library_end(); return 1;
 }
 assert(mysql_get_ssl_cipher(connection) != NULL);
 MYSQL_STMT *statement = mysql_stmt_init(connection);
 assert(statement != NULL);
 assert(mysql_stmt_prepare(statement, "SELECT ?", 8) == 0);
 unsigned char binary[] = {0, 1, 39, 92, 127, 255}, output[64] = {0};
 unsigned long length = sizeof(binary), received = 0;
 MYSQL_BIND parameter = {0}, result = {0};
 parameter.buffer_type = MYSQL_TYPE_BLOB;
 parameter.buffer = binary; parameter.buffer_length = sizeof(binary); parameter.length = &length;
 result.buffer_type = MYSQL_TYPE_BLOB;
 result.buffer = output; result.buffer_length = sizeof(output); result.length = &received;
 assert(mysql_stmt_bind_param(statement, &parameter) == 0);
 assert(mysql_stmt_execute(statement) == 0);
 assert(mysql_stmt_bind_result(statement, &result) == 0);
 assert(mysql_stmt_store_result(statement) == 0);
 assert(mysql_stmt_fetch(statement) == 0);
 assert(received == sizeof(binary) && memcmp(binary, output, sizeof(binary)) == 0);
 assert(mysql_stmt_close(statement) == 0);
 assert(mysql_query(connection, "CREATE TEMPORARY TABLE tdvp_rollback (value integer)") == 0);
 assert(mysql_query(connection, "START TRANSACTION") == 0);
 assert(mysql_query(connection, "INSERT INTO tdvp_rollback VALUES (42)") == 0);
 assert(mysql_rollback(connection) == 0);
 assert(mysql_query(connection, "SELECT count(*) FROM tdvp_rollback") == 0);
 MYSQL_RES *rows = mysql_store_result(connection);
 assert(rows != NULL);
 MYSQL_ROW row = mysql_fetch_row(rows);
 assert(row != NULL && strcmp(row[0], "0") == 0);
 mysql_free_result(rows); mysql_close(connection);
 connection = connect_fixture(argv[1], "wrong-public-fixture-passphrase");
 assert(mysql_errno(connection) == 1045);
 mysql_close(connection);
 connection = connect_fixture(argv[2], "public-fixture-passphrase");
 assert(mysql_errno(connection) != 0 && mysql_get_ssl_cipher(connection) == NULL);
 mysql_close(connection); mysql_library_end();
 puts("MariaDB database: PASS verified TLS, password authentication, prepared binary query, rollback, wrong-password and untrusted-CA rejection");
 return 0;
}
